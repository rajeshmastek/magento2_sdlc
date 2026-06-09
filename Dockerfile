# ──────────────────────────────────────────────────────────────────────────────
# Magento 2.4.9 Production Docker Image
# Base: PHP 8.3 FPM + nginx + all required extensions
# ──────────────────────────────────────────────────────────────────────────────
ARG MAGENTO_VERSION=2.4.9
FROM php:8.3-fpm-bookworm AS base

LABEL maintainer="SDLC AI Platform"
LABEL org.opencontainers.image.description="Magento 2.4.9 with custom modules"

# ── System dependencies ──────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    supervisor \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libxpm-dev \
    libicu-dev \
    libxml2-dev \
    libxslt-dev \
    libzip-dev \
    libsodium-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libonig-dev \
    libpq-dev \
    curl \
    git \
    unzip \
    cron \
    gettext-base \
  && rm -rf /var/lib/apt/lists/*

# ── PHP extensions ───────────────────────────────────────────────────────────
RUN docker-php-ext-configure gd \
      --with-freetype --with-jpeg --with-webp --with-xpm \
  && docker-php-ext-install -j$(nproc) \
      bcmath \
      gd \
      intl \
      mbstring \
      opcache \
      pdo_mysql \
      soap \
      sockets \
      xsl \
      zip \
      sodium \
  && pecl install redis xdebug-3.3.0 \
  && docker-php-ext-enable redis \
  && rm -rf /tmp/pear

# ── PHP configuration ────────────────────────────────────────────────────────
COPY docker/php/php.ini    /usr/local/etc/php/conf.d/magento.ini
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# ── nginx configuration ──────────────────────────────────────────────────────
COPY docker/nginx/nginx.conf       /etc/nginx/nginx.conf
COPY docker/nginx/magento.conf     /etc/nginx/conf.d/magento.conf

# ── Composer ─────────────────────────────────────────────────────────────────
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_HOME=/var/cache/composer \
    COMPOSER_ALLOW_SUPERUSER=1

# ── Application user ─────────────────────────────────────────────────────────
RUN useradd -r -u 1001 -g www-data -s /bin/bash -d /var/www/html magento \
  && mkdir -p /var/www/html \
  && chown -R magento:www-data /var/www/html

WORKDIR /var/www/html

# ── Magento files ─────────────────────────────────────────────────────────────
# Copy Magento source (must be in repo root or fetched via Composer)
COPY --chown=magento:www-data . /var/www/html/

# ── Install Composer dependencies ─────────────────────────────────────────────
RUN --mount=type=cache,target=/var/cache/composer \
    composer install \
      --no-dev \
      --optimize-autoloader \
      --no-interaction \
      --no-progress \
    && composer clear-cache

# ── Set permissions ───────────────────────────────────────────────────────────
RUN find /var/www/html -type f -exec chmod 644 {} \; \
  && find /var/www/html -type d -exec chmod 755 {} \; \
  && chmod +x /var/www/html/bin/magento \
  && chown -R magento:www-data \
       /var/www/html/var \
       /var/www/html/pub \
       /var/www/html/generated \
       /var/www/html/app/etc

# ── Supervisor configuration ──────────────────────────────────────────────────
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 443

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
