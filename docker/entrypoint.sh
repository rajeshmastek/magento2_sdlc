#!/bin/bash
set -e

MAGENTO_ROOT=/var/www/html

# ── Wait for MySQL ────────────────────────────────────────────────────────────
wait_for_db() {
  echo "Waiting for database ${MAGENTO_DB_HOST}:${MAGENTO_DB_PORT:-3306}..."
  for i in {1..60}; do
    if php -r "
      \$pdo = new PDO(
        'mysql:host=${MAGENTO_DB_HOST};port=${MAGENTO_DB_PORT:-3306};dbname=${MAGENTO_DB_NAME}',
        '${MAGENTO_DB_USER}', '${MAGENTO_DB_PASS}'
      );
      echo 'ok';
    " 2>/dev/null | grep -q 'ok'; then
      echo "✓ Database ready"
      return 0
    fi
    echo "  Attempt $i/60..."
    sleep 2
  done
  echo "ERROR: Database not available after 2 minutes"
  exit 1
}

# ── Wait for Redis ────────────────────────────────────────────────────────────
wait_for_redis() {
  if [ -n "${MAGENTO_REDIS_HOST}" ]; then
    echo "Waiting for Redis ${MAGENTO_REDIS_HOST}..."
    for i in {1..30}; do
      if redis-cli -h "${MAGENTO_REDIS_HOST}" ping 2>/dev/null | grep -q PONG; then
        echo "✓ Redis ready"
        return 0
      fi
      sleep 2
    done
    echo "WARNING: Redis not available — continuing without Redis"
  fi
}

# ── Install or upgrade Magento ────────────────────────────────────────────────
setup_magento() {
  cd $MAGENTO_ROOT

  if [ ! -f "$MAGENTO_ROOT/app/etc/env.php" ]; then
    echo "Running Magento installation..."
    php bin/magento setup:install \
      --base-url="${MAGENTO_BASE_URL:-http://localhost/}" \
      --base-url-secure="${MAGENTO_BASE_URL_SECURE:-https://localhost/}" \
      --db-host="${MAGENTO_DB_HOST}" \
      --db-name="${MAGENTO_DB_NAME}" \
      --db-user="${MAGENTO_DB_USER}" \
      --db-password="${MAGENTO_DB_PASS}" \
      --admin-firstname="${MAGENTO_ADMIN_FIRSTNAME:-Admin}" \
      --admin-lastname="${MAGENTO_ADMIN_LASTNAME:-User}" \
      --admin-email="${MAGENTO_ADMIN_EMAIL:-admin@example.com}" \
      --admin-user="${MAGENTO_ADMIN_USER:-admin}" \
      --admin-password="${MAGENTO_ADMIN_PASS:-Admin123!}" \
      --language="${MAGENTO_LANGUAGE:-en_US}" \
      --currency="${MAGENTO_CURRENCY:-USD}" \
      --timezone="${MAGENTO_TIMEZONE:-America/New_York}" \
      --use-rewrites=1 \
      --use-secure=0 \
      --use-secure-admin=0 \
      --backend-frontname="${MAGENTO_ADMIN_PATH:-admin}" \
      --session-save="${MAGENTO_SESSION_SAVE:-redis}" \
      --session-save-redis-host="${MAGENTO_REDIS_HOST:-redis}" \
      --session-save-redis-port="${MAGENTO_REDIS_PORT:-6379}" \
      --session-save-redis-db=2 \
      --cache-backend=redis \
      --cache-backend-redis-server="${MAGENTO_REDIS_HOST:-redis}" \
      --cache-backend-redis-db=0 \
      --page-cache=redis \
      --page-cache-redis-server="${MAGENTO_REDIS_HOST:-redis}" \
      --page-cache-redis-db=1 \
      --elasticsearch-host="${MAGENTO_ES_HOST:-elasticsearch}" \
      --elasticsearch-port="${MAGENTO_ES_PORT:-9200}" \
      --no-interaction

    echo "✓ Magento installed"

    # Install sample data if requested
    if [ "${INSTALL_SAMPLE_DATA:-false}" == "true" ]; then
      echo "Installing sample data..."
      php bin/magento sampledata:deploy --no-interaction || true
      php bin/magento setup:upgrade --no-interaction
      echo "✓ Sample data installed"
    fi
  else
    echo "Running setup:upgrade (existing installation)..."
    php bin/magento setup:upgrade --no-interaction || true
  fi

  # Enable custom modules
  php bin/magento module:enable --all --no-interaction || true

  # Compile and deploy
  php bin/magento setup:di:compile --no-interaction
  php bin/magento setup:static-content:deploy \
    en_US -f --no-interaction --jobs=4 || true

  # Set production mode
  php bin/magento deploy:mode:set production --no-interaction || true

  # Flush cache
  php bin/magento cache:flush --no-interaction
  echo "✓ Magento setup complete"
}

# ── Configure nginx ───────────────────────────────────────────────────────────
configure_nginx() {
  BASE_URL="${MAGENTO_BASE_URL:-http://localhost/}"
  SERVER_NAME=$(echo "$BASE_URL" | sed 's|https\?://||;s|/||')
  export SERVER_NAME
  envsubst '${SERVER_NAME}' < /etc/nginx/conf.d/magento.conf.template \
    > /etc/nginx/conf.d/magento.conf 2>/dev/null || true
}

# ── Health endpoint ───────────────────────────────────────────────────────────
setup_health() {
  echo "<?php http_response_code(200); echo 'OK';" > $MAGENTO_ROOT/pub/health.php
}

# ── Main ──────────────────────────────────────────────────────────────────────
echo "=== Magento 2.4.9 Container Starting ==="
echo "Base URL: ${MAGENTO_BASE_URL:-http://localhost/}"
echo "DB: ${MAGENTO_DB_HOST}/${MAGENTO_DB_NAME}"

wait_for_db
wait_for_redis
setup_health
setup_magento
configure_nginx

echo "=== Starting services ==="
exec "$@"
