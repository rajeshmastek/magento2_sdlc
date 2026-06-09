# ──────────────────────────────────────────────────────────────────────────────
# Magento 2.4.9 — source files in repo, setup:install runs at container start
# ──────────────────────────────────────────────────────────────────────────────
FROM php:8.4-fpm-bookworm

LABEL maintainer="SDLC AI Platform"

ARG MAGENTO_VERSION=2.4.9

# ── System dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx supervisor libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
    libwebp-dev libicu-dev libxml2-dev libxslt-dev libzip-dev \
    libsodium-dev libonig-dev curl git unzip cron redis-tools \
  && rm -rf /var/lib/apt/lists/*

# ── PHP extensions ────────────────────────────────────────────────────────────
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
  && docker-php-ext-install -j$(nproc) \
      bcmath gd intl mbstring opcache pdo_mysql soap sockets xsl zip sodium \
  && pecl install redis && docker-php-ext-enable redis \
  && rm -rf /tmp/pear

# ── PHP + nginx config ────────────────────────────────────────────────────────
COPY docker/php/php.ini     /usr/local/etc/php/conf.d/magento.ini
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY docker/nginx/nginx.conf   /etc/nginx/nginx.conf
COPY docker/nginx/magento.conf /etc/nginx/conf.d/default.conf

# ── Composer 2 ───────────────────────────────────────────────────────────────
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_NO_INTERACTION=1 \
    COMPOSER_PROCESS_TIMEOUT=2000

# ── Copy Magento source from repo ────────────────────────────────────────────
WORKDIR /var/www/html
COPY --chown=www-data:www-data . /var/www/html/

# ── Install PHP dependencies from committed composer.lock ────────────────────
# vendor/ should be in .gitignore — install from lock file
RUN if [ ! -d "vendor/magento" ]; then \
      echo "Installing Composer dependencies from composer.lock..." \
      && composer install \
           --no-dev \
           --optimize-autoloader \
           --no-interaction \
           --no-progress; \
    else \
      echo "vendor/ already present — skipping composer install"; \
    fi \
  && composer clear-cache

# ── Copy custom modules (overlay on top of Magento source) ───────────────────
# Already included via COPY above if app/code/Vendor is in repo
# This step is a no-op if already copied, but ensures custom code is present
RUN echo "Custom modules in app/code/:" && ls app/code/ 2>/dev/null || echo "none"

# ── Permissions ───────────────────────────────────────────────────────────────
RUN useradd -r -u 1001 -g www-data -s /bin/bash -d /var/www/html magento \
  && chown -R magento:www-data /var/www/html \
  && chmod +x /var/www/html/bin/magento \
  && mkdir -p /var/log/supervisor /run/php

# ── Supervisor + entrypoint ───────────────────────────────────────────────────
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/entrypoint.sh    /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=5 \
  CMD curl -f http://localhost/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
