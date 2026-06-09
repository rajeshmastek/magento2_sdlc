#!/bin/bash
set -e

MAGENTO_ROOT=/var/www/html
LOCK_FILE="${MAGENTO_ROOT}/.setup_complete"

log() { echo "[entrypoint] $*"; }

# ── Wait for MySQL ─────────────────────────────────────────────────────────────
wait_for_db() {
  log "Waiting for MySQL at ${MAGENTO_DB_HOST}:${MAGENTO_DB_PORT:-3306}..."
  for i in $(seq 1 60); do
    if php -r "
      try {
        new PDO('mysql:host=${MAGENTO_DB_HOST};port=${MAGENTO_DB_PORT:-3306}',
          '${MAGENTO_DB_USER}', '${MAGENTO_DB_PASS}');
        echo 'ok';
      } catch(Exception \$e) { exit(1); }
    " 2>/dev/null | grep -q ok; then
      log "MySQL ready"
      return 0
    fi
    log "  Attempt ${i}/60 - retrying in 3s..."
    sleep 3
  done
  log "ERROR: MySQL not available after 3 minutes - aborting"
  exit 1
}

# Ensure database exists and user has all required privileges
setup_database() {
  log "Creating database ${MAGENTO_DB_NAME} if not exists..."

  # Connect as the same user - on RDS the user owns its own DB
  # This also handles the case where DB was pre-created by Terraform
  php -r "
    \$host = getenv("MAGENTO_DB_HOST");
    \$user = getenv("MAGENTO_DB_USER");
    \$pass = getenv("MAGENTO_DB_PASS");
    \$db   = getenv("MAGENTO_DB_NAME");
    try {
      \$pdo = new PDO("mysql:host=\$host", \$user, \$pass,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
      \$pdo->exec("CREATE DATABASE IF NOT EXISTS \`\$db\`
        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
      \$pdo->exec("GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,INDEX,
        ALTER,CREATE TEMPORARY TABLES,LOCK TABLES,EXECUTE,
        CREATE VIEW,SHOW VIEW,CREATE ROUTINE,ALTER ROUTINE,TRIGGER
        ON \`\$db\`.* TO \"\`\$user\`\"@\"%\"  ");
      \$pdo->exec("FLUSH PRIVILEGES");
      echo "DB ready\n";
    } catch(Exception \$e) {
      // DB may already exist and user may already have grants - continue
      echo "DB init note: " . \$e->getMessage() . "\n";
    }
  " 2>&1 || true
  log "Database setup complete"
}
  " 2>/dev/null
  log "Database check complete"
}

# ── Wait for Redis ─────────────────────────────────────────────────────────────
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
  log "WARNING: Redis not available — continuing without Redis cache"
}

# ── Create health endpoint ──────────────────────────────────────────────────────
setup_health() {
  echo '<?php http_response_code(200); echo "OK";' > "${MAGENTO_ROOT}/pub/health.php"
}

# ── Run Magento setup:install ──────────────────────────────────────────────────
run_setup_install() {
  log "Running Magento setup:install..."

  # Determine search engine and flags
  if [ -n "${MAGENTO_ES_HOST}" ]; then
    SEARCH_FLAGS="--search-engine=opensearch \
      --opensearch-host=${MAGENTO_ES_HOST} \
      --opensearch-port=${MAGENTO_ES_PORT:-9200} \
      --opensearch-index-prefix=magento2"
  else
    # Fallback: use MySQL fulltext search (no external search needed)
    SEARCH_FLAGS="--search-engine=mysql"
  fi

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


# Configure Redis only if host is set AND reachable
configure_redis() {
  if [ -z "${MAGENTO_REDIS_HOST}" ]; then
    log "MAGENTO_REDIS_HOST not set - skipping Redis, using file cache"
    return 0
  fi
  if ! redis-cli -h "${MAGENTO_REDIS_HOST}" -p 6379 ping 2>/dev/null | grep -q PONG; then
    log "WARNING: Cannot reach Redis at ${MAGENTO_REDIS_HOST} - skipping Redis config"
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
    --no-interaction 2>/dev/null || log "WARNING: Redis config failed - using db sessions"
}

# ── Enable custom modules ──────────────────────────────────────────────────────
enable_modules() {
  log "Enabling all modules..."
  php "${MAGENTO_ROOT}/bin/magento" module:enable --all --no-interaction 2>/dev/null || true
}

# ── Run setup:upgrade ──────────────────────────────────────────────────────────
run_upgrade() {
  log "Running setup:upgrade..."
  php "${MAGENTO_ROOT}/bin/magento" setup:upgrade --no-interaction
}

# ── Compile DI ─────────────────────────────────────────────────────────────────
run_compile() {
  log "Running setup:di:compile..."
  php "${MAGENTO_ROOT}/bin/magento" setup:di:compile --no-interaction
}

# ── Deploy static content ──────────────────────────────────────────────────────
deploy_static() {
  log "Deploying static content..."
  php "${MAGENTO_ROOT}/bin/magento" setup:static-content:deploy \
    en_US -f --no-interaction --jobs=2 2>/dev/null || \
  php "${MAGENTO_ROOT}/bin/magento" setup:static-content:deploy \
    en_US -f --no-interaction || true
}

# ── Set production mode + flush ────────────────────────────────────────────────
finalize() {
  log "Setting production mode..."
  php "${MAGENTO_ROOT}/bin/magento" deploy:mode:set production --no-interaction 2>/dev/null || true
  php "${MAGENTO_ROOT}/bin/magento" cache:flush --no-interaction
  log "Cache flushed"
}

# ── Sample data (optional) ─────────────────────────────────────────────────────
install_sample_data() {
  if [ "${INSTALL_SAMPLE_DATA:-false}" != "true" ]; then return 0; fi
  log "Installing sample data..."
  php "${MAGENTO_ROOT}/bin/magento" sampledata:deploy --no-interaction 2>/dev/null || \
    log "WARNING: sample data deploy failed — continuing"
}

# ── Cron setup ─────────────────────────────────────────────────────────────────
setup_cron() {
  log "Setting up Magento cron..."
  php "${MAGENTO_ROOT}/bin/magento" cron:install --force 2>/dev/null || true
}

# ── Main ───────────────────────────────────────────────────────────────────────
log "=== Magento 2.4.9 Container Starting ==="
log "Base URL:  ${MAGENTO_BASE_URL:-http://localhost/}"
log "Database:  ${MAGENTO_DB_HOST}/${MAGENTO_DB_NAME}"
log "ES Host:   ${MAGENTO_ES_HOST:-localhost}"

# Create health file immediately so ALB health checks pass during setup
setup_health

wait_for_db
wait_for_redis

if [ -f "${LOCK_FILE}" ]; then
  # ── Already installed — just upgrade ────────────────────────────────────────
  log "Existing installation detected — running upgrade..."
  enable_modules
  run_upgrade
  run_compile
  finalize
else
  # ── First run — full install ─────────────────────────────────────────────────
  log "First run — running full setup:install..."
  run_setup_install
  configure_redis
  enable_modules
  install_sample_data
  run_upgrade
  run_compile
  deploy_static
  finalize
  setup_cron
  touch "${LOCK_FILE}"
  log "=== Installation complete ==="
fi

log "=== Starting services ==="
exec "$@"
