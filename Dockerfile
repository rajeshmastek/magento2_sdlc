# ──────────────────────────────────────────────────────────────────────────────
# Magento 2.4.9 Production Docker Image
# Base: PHP 8.3 FPM + nginx + all required extensions
# ──────────────────────────────────────────────────────────────────────────────
ARG MAGENTO_VERSION=2.4.9
ARG MAGENTO_PUBLIC_KEY=""
ARG MAGENTO_PRIVATE_KEY=""
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

# ── Download Magento 2.4.9 via Composer ──────────────────────────────────────
# Requires MAGENTO_PUBLIC_KEY + MAGENTO_PRIVATE_KEY build args
# OR pre-copy source into repo under magento_src/
ARG MAGENTO_PUBLIC_KEY=""
ARG MAGENTO_PRIVATE_KEY=""

RUN --mount=type=cache,target=/var/cache/composer \
    if [ -n "$MAGENTO_PUBLIC_KEY" ]; then \
      composer config --global http-basic.repo.magento.com \
        "$MAGENTO_PUBLIC_KEY" "$MAGENTO_PRIVATE_KEY"; \
    fi

# If composer.json already exists (source copied into repo), just install deps.
# Otherwise create the Magento project from scratch.
COPY --chown=magento:www-data . /var/www/html/

# Install or skip Composer dependencies
# If vendor/magento already present (source copied from server), skip install
# If composer.json present but no vendor, run install with marketplace keys
# MAGENTO_PUBLIC_KEY / MAGENTO_PRIVATE_KEY build args are optional
RUN --mount=type=cache,target=/var/cache/composer \
    if [ -d "vendor/magento" ]; then \
      echo "vendor/ already present — skipping composer install"; \
    elif [ -f "composer.json" ]; then \
      echo "Running composer install..." && \
      if [ -n "$MAGENTO_PUBLIC_KEY" ]; then \
        composer config --global http-basic.repo.magento.com \
          "$MAGENTO_PUBLIC_KEY" "$MAGENTO_PRIVATE_KEY"; \
      fi && \
      composer install \
        --no-dev \
        --optimize-autoloader \
        --no-interaction \
        --no-progress && \
      composer clear-cache; \
    else \
      echo "ERROR: No composer.json and no vendor/ directory found." && \
      echo "Please either:" && \
      echo "  1. Copy Magento source into repo root (recommended)" && \
      echo "  2. Set MAGENTO_PUBLIC_KEY + MAGENTO_PRIVATE_KEY build args" && \
      exit 1; \
    fi

# ── Set permissions ───────────────────────────────────────────────────────────
RUN find /var/www/html -type f -exec chmod 644 {} \; \
  && find /var/www/html -type d -exec chmod 755 {} \; \
  && chmod +x /var/www/html/bin/magento \
  && chown -R magento:www-data \
       /var/www/html/var \
       /var/www/html/pub \
       /var/www/html/generated \
       /var/www/html/app/etc \
  && mkdir -p /var/log/supervisor /run/php \
  && touch /run/php/php-fpm.sock

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
