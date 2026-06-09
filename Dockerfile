# ──────────────────────────────────────────────────────────────────────────────
# Magento 2.4.9 Production Docker Image
# ──────────────────────────────────────────────────────────────────────────────
FROM php:8.3-fpm-bookworm

LABEL maintainer="SDLC AI Platform"

# Build args — must be after FROM to be available in RUN
ARG MAGENTO_VERSION=2.4.9
ARG MAGENTO_PUBLIC_KEY
ARG MAGENTO_PRIVATE_KEY

# ── System dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx supervisor libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
    libwebp-dev libicu-dev libxml2-dev libxslt-dev libzip-dev \
    libsodium-dev libonig-dev curl git unzip cron \
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

# ── Install Magento 2.4.9 (exactly as it works locally) ──────────────────────
WORKDIR /var/www/html

RUN composer config --global http-basic.repo.magento.com "${MAGENTO_PUBLIC_KEY}" "${MAGENTO_PRIVATE_KEY}" \
  && composer create-project --repository-url=https://repo.magento.com magento/project-community-edition .

# ── Copy custom modules ───────────────────────────────────────────────────────
COPY app/code/ /var/www/html/app/code/

# ── Permissions ───────────────────────────────────────────────────────────────
RUN useradd -r -u 1001 -g www-data -s /bin/bash -d /var/www/html magento \
  && chown -R magento:www-data /var/www/html \
  && chmod +x /var/www/html/bin/magento \
  && mkdir -p /var/log/supervisor /run/php

# ── Supervisor + entrypoint ───────────────────────────────────────────────────
COPY docker/supervisord.conf  /etc/supervisor/conf.d/supervisord.conf
COPY docker/entrypoint.sh     /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=5 \
  CMD curl -f http://localhost/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
