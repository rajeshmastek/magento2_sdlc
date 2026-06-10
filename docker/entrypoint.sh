#!/bin/bash
set -e

MAGENTO_ROOT=/var/www/html
LOCK_FILE="${MAGENTO_ROOT}/.setup_complete"

log() { echo "[entrypoint] $*"; }

# ------ Wait for MySQL ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
wait_for_db() {
  log "Waiting for MySQL at ${MAGENTO_DB_HOST}..."
  for i in $(seq 1 60); do
    if php -r "new PDO('mysql:host=${MAGENTO_DB_HOST}','${MAGENTO_DB_USER}','${MAGENTO_DB_PASS}'); echo 'ok';" 2>/dev/null | grep -q ok; then
      log "MySQL ready"
      return 0
    fi
    log "  Attempt ${i}/60 - retrying in 3s..."
    sleep 3
  done
  log "ERROR: MySQL not available after 3 minutes"
  exit 1
}

# ------ Wait for Redis ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
wait_for_redis() {
  if [ -z "${MAGENTO_REDIS_HOST}" ]; then return 0; fi
  log "Waiting for Redis at ${MAGENTO_REDIS_HOST}..."
  for i in $(seq 1 30); do
    if redis-cli -h "${MAGENTO_REDIS_HOST}" ping 2>/dev/null | grep -q PONG; then
      log "Redis ready"
      return 0
    fi
    sleep 2
  done
  log "WARNING: Redis not available - continuing without Redis"
}

# ------ Create database if not exists ------------------------------------------------------------------------------------------------------------------------------------------
setup_database() {
  log "Creating database ${MAGENTO_DB_NAME} if not exists..."
  php << 'PHPEOF'
<?php
$host = getenv('MAGENTO_DB_HOST');
$user = getenv('MAGENTO_DB_USER');
$pass = getenv('MAGENTO_DB_PASS');
$db   = getenv('MAGENTO_DB_NAME');
try {
    $pdo = new PDO("mysql:host=$host", $user, $pass,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $pdo->exec("CREATE DATABASE IF NOT EXISTS `$db`
        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    $pdo->exec("GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,INDEX,ALTER,
        CREATE TEMPORARY TABLES,LOCK TABLES,EXECUTE,
        CREATE VIEW,SHOW VIEW,CREATE ROUTINE,ALTER ROUTINE,TRIGGER
        ON `$db`.* TO '$user'@'%'");
    $pdo->exec("FLUSH PRIVILEGES");
    echo "Database $db ready\n";
} catch (Exception $e) {
    echo "DB note: " . $e->getMessage() . "\n";
}
PHPEOF
  log "Database setup done"
}

# ------ Configure Redis ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
configure_redis() {
  if [ -z "${MAGENTO_REDIS_HOST}" ]; then
    log "No Redis host set - skipping Redis config"
    return 0
  fi
  if ! redis-cli -h "${MAGENTO_REDIS_HOST}" ping 2>/dev/null | grep -q PONG; then
    log "WARNING: Cannot reach Redis - skipping Redis config"
    return 0
  fi
  log "Configuring Redis at ${MAGENTO_REDIS_HOST}..."
  php "${MAGENTO_ROOT}/bin/magento" setup:config:set \
    --cache-backend=redis \
    --cache-backend-redis-server="${MAGENTO_REDIS_HOST}" \
    --cache-backend-redis-db=0 \
    --page-cache=redis \
    --page-cache-redis-server="${MAGENTO_REDIS_HOST}" \
    --page-cache-redis-db=1 \
    --session-save=redis \
    --session-save-redis-host="${MAGENTO_REDIS_HOST}" \
    --session-save-redis-db=2 \
    --no-interaction 2>/dev/null || log "WARNING: Redis config failed"
}

# ------ Run setup:install ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
run_setup_install() {
  log "Running Magento setup:install..."

  # Always use mysql for setup:install - avoids OpenSearch connectivity issues
  # OpenSearch is configured after install via configure_search()
  SEARCH_FLAGS="--search-engine=mysql"
  log "Using mysql search engine for setup:install"

  php "${MAGENTO_ROOT}/bin/magento" setup:install \
    --base-url="${MAGENTO_BASE_URL:-http://localhost/}" \
    --db-host="${MAGENTO_DB_HOST}" \
    --db-name="${MAGENTO_DB_NAME}" \
    --db-user="${MAGENTO_DB_USER}" \
    --db-password="${MAGENTO_DB_PASS}" \
    --db-prefix="" \
    --admin-firstname="${MAGENTO_ADMIN_FIRSTNAME:-Admin}" \
    --admin-lastname="${MAGENTO_ADMIN_LASTNAME:-User}" \
    --admin-email="${MAGENTO_ADMIN_EMAIL:-admin@example.com}" \
    --admin-user="${MAGENTO_ADMIN_USER:-admin}" \
    --admin-password="${MAGENTO_ADMIN_PASS:-Admin123!}" \
    --language="${MAGENTO_LANGUAGE:-en_US}" \
    --currency="${MAGENTO_CURRENCY:-USD}" \
    --timezone="${MAGENTO_TIMEZONE:-UTC}" \
    --use-rewrites=1 \
    --use-secure=0 \
    --use-secure-admin=0 \
    --backend-frontname="${MAGENTO_ADMIN_PATH:-admin}" \
    --session-save="db" \
    ${SEARCH_FLAGS} \
    --no-interaction

  log "setup:install complete"
}

# ------ Enable modules ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
enable_modules() {
  log "Enabling all modules..."
  php "${MAGENTO_ROOT}/bin/magento" module:enable --all --no-interaction 2>/dev/null || true
}

# ------ Setup upgrade ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
run_upgrade() {
  log "Running setup:upgrade..."
  php "${MAGENTO_ROOT}/bin/magento" setup:upgrade --no-interaction
}

# ------ DI compile ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
run_compile() {
  log "Running setup:di:compile..."
  php "${MAGENTO_ROOT}/bin/magento" setup:di:compile --no-interaction
}

# ------ Static content ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
deploy_static() {
  log "Deploying static content..."
  php "${MAGENTO_ROOT}/bin/magento" setup:static-content:deploy \
    en_US -f --no-interaction --jobs=2 || true
}

# ------ Finalize ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
finalize() {
  log "Setting production mode and flushing cache..."
  php "${MAGENTO_ROOT}/bin/magento" deploy:mode:set production --no-interaction 2>/dev/null || true
  php "${MAGENTO_ROOT}/bin/magento" cache:flush --no-interaction
  log "Cache flushed"
}

# ------ Sample data ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
install_sample_data() {
  if [ "${INSTALL_SAMPLE_DATA:-false}" != "true" ]; then return 0; fi
  log "Installing sample data..."
  php "${MAGENTO_ROOT}/bin/magento" sampledata:deploy --no-interaction 2>/dev/null || true
}

# ------ Cron ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
setup_cron() {
  log "Setting up cron..."
  php "${MAGENTO_ROOT}/bin/magento" cron:install --force 2>/dev/null || true
}

# ------ Health endpoint ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
setup_health() {
  echo '<?php http_response_code(200); echo "OK";' > "${MAGENTO_ROOT}/pub/health.php"
}

# ------ Main ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
log "=== Magento 2.4.9 Starting ==="
log "URL:  ${MAGENTO_BASE_URL:-http://localhost/}"
log "DB:   ${MAGENTO_DB_HOST}/${MAGENTO_DB_NAME}"
log "ES:   ${MAGENTO_ES_HOST:-none}"

setup_health
wait_for_db
wait_for_redis

if [ -f "${LOCK_FILE}" ]; then
  log "Existing install detected - running upgrade..."
  enable_modules
  run_upgrade
  run_compile
  finalize
else
  log "First run - full install..."
  setup_database
  run_setup_install
  configure_redis
  configure_search
  enable_modules
  install_sample_data
  run_upgrade
  run_compile
  deploy_static
  finalize
  setup_cron
  touch "${LOCK_FILE}"
  log "=== Install complete ==="
fi

log "=== Starting services ==="
exec "$@"
