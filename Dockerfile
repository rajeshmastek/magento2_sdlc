# ──────────────────────────────────────────────────────────────────────────────
# Magento 2.4.9 Production Docker Image
# Installs Magento via Composer during build — no pre-copied source needed
# ──────────────────────────────────────────────────────────────────────────────
ARG MAGENTO_VERSION=2.4.9
ARG MAGENTO_PUBLIC_KEY=""
ARG MAGENTO_PRIVATE_KEY=""

FROM php:8.3-fpm-bookworm AS base

LABEL maintainer="SDLC AI Platform"
LABEL org.opencontainers.image.description="Magento 2.4.9 production image"

# ── System dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    supervisor \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libicu-dev \
    libxml2-dev \
    libxslt-dev \
    libzip-dev \
    libsodium-dev \
    libonig-dev \
    libssl-dev \
    curl \
    git \
    unzip \
    cron \
    redis-tools \
    default-mysql-client \
  && rm -rf /var/lib/apt/lists/*

# ── PHP extensions ────────────────────────────────────────────────────────────
RUN docker-php-ext-configure gd \
      --with-freetype --with-jpeg --with-webp \
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
  && pecl install redis \
  && docker-php-ext-enable redis \
  && rm -rf /tmp/pear

# ── PHP configuration ─────────────────────────────────────────────────────────
COPY docker/php/php.ini     /usr/local/etc/php/conf.d/magento.ini
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# ── nginx configuration ───────────────────────────────────────────────────────
COPY docker/nginx/nginx.conf   /etc/nginx/nginx.conf
COPY docker/nginx/magento.conf /etc/nginx/conf.d/magento.conf

# ── Composer 2 ───────────────────────────────────────────────────────────────
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_HOME=/var/cache/composer \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_NO_INTERACTION=1

# ── Application user ──────────────────────────────────────────────────────────
RUN useradd -r -u 1001 -g www-data -s /bin/bash -d /var/www/html magento \
  && mkdir -p /var/www/html \
  && chown -R magento:www-data /var/www/html

WORKDIR /var/www/html

# ── Install Magento 2.4.9 from Marketplace ────────────────────────────────────
ARG MAGENTO_PUBLIC_KEY
ARG MAGENTO_PRIVATE_KEY
ARG MAGENTO_VERSION=2.4.9

RUN --mount=type=cache,target=/var/cache/composer,uid=1001 \
    # Configure Marketplace auth if keys provided
    if [ -n "${MAGENTO_PUBLIC_KEY}" ]; then \
      composer config --global http-basic.repo.magento.com \
        "${MAGENTO_PUBLIC_KEY}" "${MAGENTO_PRIVATE_KEY}"; \
    fi \
    # Create Magento project
    && composer create-project \
        --repository-url=https://repo.magento.com/ \
        magento/project-community-edition="${MAGENTO_VERSION}" \
        /var/www/html \
        --no-dev \
        --no-interaction \
        --no-progress \
    && composer clear-cache

# ── Copy custom modules (app/code/Vendor) ─────────────────────────────────────
# Only copies if app/code/Vendor exists in build context
COPY --chown=magento:www-data app/code/ /var/www/html/app/code/

# ── Set permissions ───────────────────────────────────────────────────────────
RUN find /var/www/html -type d -exec chmod 755 {} \; \
  && find /var/www/html -type f -exec chmod 644 {} \; \
  && chmod +x /var/www/html/bin/magento \
  && chown -R magento:www-data \
       /var/www/html/var \
       /var/www/html/pub \
       /var/www/html/generated \
       /var/www/html/app/etc \
  && mkdir -p /var/log/supervisor /run/php

# ── Supervisor configuration ──────────────────────────────────────────────────
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=5 \
  CMD curl -f http://localhost/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
