# syntax=docker/dockerfile:1

# PHP extensions, compiled once for every PHP image
# The Debian suffix prevents a silent switch to the next Debian release, which
# renames the library packages installed with apt-get here and in `runtime`
FROM php:8.5-fpm-trixie AS extensions

# Headers for the extensions below. The base image already includes the
# compilers, and the libraries for mbstring, curl, and openssl.
# pcntl lets queue workers stop between jobs and enforce job timeouts.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libicu-dev \
    libpq-dev \
    libxml2-dev \
    libzip-dev \
    unzip \
    && docker-php-ext-install -j"$(nproc)" \
    bcmath \
    intl \
    pcntl \
    pdo_mysql \
    pdo_pgsql \
    pgsql \
    soap \
    zip \
    && pecl install redis-6.3.0 \
    && docker-php-ext-enable redis \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

COPY --from=composer/composer:2-bin /composer /usr/local/bin/composer


# Composer dependencies, installed from the lock file only
# This layer is rebuilt only when composer.json or composer.lock changes.
# The scripts run in `app`, because they need the application code.
FROM extensions AS vendor

WORKDIR /var/www
COPY composer.json composer.lock ./
RUN --mount=type=cache,target=/root/.composer/cache \
    composer install --no-dev --no-scripts --no-autoloader --no-interaction --no-progress --prefer-dist


# The application code with an optimized autoloader
FROM vendor AS app

# Without docker/, so editing the Docker configuration doesn't rebuild this stage
COPY --exclude=docker . .

# Runs the post-autoload-dump scripts, such as `package:discover`
RUN composer dump-autoload --optimize --no-dev --no-interaction


# Node.js for the `assets` and `workspace` stages
FROM node:26-trixie-slim AS node


# Frontend assets
# Built once here so nginx (which serves the files) and PHP (which reads
# manifest.json to render their URLs) can never disagree about which build.
# API-only project? Drop this stage and the two `COPY --from=assets` lines below.
FROM node AS assets

WORKDIR /var/www
# .npmrc sets ignore-scripts, which npm ci only applies if the file is here
COPY package.json package-lock.json .npmrc ./
RUN --mount=type=cache,target=/root/.npm npm ci

# Tailwind scans Blade views in vendor/, such as Laravel's pagination views
# (see `@source` in resources/css/app.css), and skips a missing path silently
COPY --from=vendor /var/www/vendor ./vendor
COPY --exclude=docker . .
RUN npm run build


# Shared PHP runtime for the production and development images
FROM php:8.5-fpm-trixie AS runtime

# Only the libraries that the compiled extensions load, and cgi-fcgi for the
# php-fpm-healthcheck script
RUN apt-get update && apt-get install -y --no-install-recommends \
    libfcgi-bin \
    libicu76 \
    libpq5 \
    libzip5 \
    && rm -rf /var/lib/apt/lists/*

# Download and install php-fpm health check script
ADD --chmod=755 --checksum=sha256:53bc616c4a30f029b98bff48fdeb0c4da252cb11e4f86656a8222a67dc4e5009 \
    https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/v0.6.0/php-fpm-healthcheck \
    /usr/local/bin/php-fpm-healthcheck

# Copy the compiled extensions and their ini files
COPY --from=extensions /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=extensions /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Fail the build if an extension can't load, such as after adding one without its library
RUN ! php -m 2>&1 | grep -i 'unable to load'

# Use the recommended production PHP configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY ./docker/common/php/conf.d/*.ini "$PHP_INI_DIR/conf.d/"

# Keep the image-provided FPM global config intact and add pool overrides separately
COPY ./docker/common/php-fpm/conf.d/*.conf /usr/local/etc/php-fpm.d/

WORKDIR /var/www


# Production image
FROM runtime AS production

# www-data's home is /var/www, which root owns in this image, and tools such
# as `php artisan tinker` fail without a writable home
RUN mkdir /home/www-data \
    && chown www-data:www-data /home/www-data \
    && usermod -d /home/www-data www-data

COPY --chmod=755 ./docker/production/php-fpm/entrypoint.sh /usr/local/bin/entrypoint.sh

# The code belongs to root, so PHP can't change it. www-data owns only the
# directories that Laravel writes to.
COPY --from=app /var/www /var/www
# API-only: drop this line
COPY --from=assets /var/www/public/build /var/www/public/build
RUN chown -R www-data:www-data storage bootstrap/cache

# Link the public disk, the same as `php artisan storage:link --relative`.
# The `web` stage makes the same link for nginx.
RUN ln -sfn ../storage/app/public public/storage

USER www-data

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]


# Development image
# Built from `runtime`, not `production`, so a dev build skips Composer and the
# Node stage - the dev stack bind-mounts the project and runs Vite in `workspace`.
FROM runtime AS development

# Xdebug reads its settings from the environment when the container starts,
# see docker/development/php/conf.d/xdebug.ini
ARG XDEBUG_ENABLED=true
RUN if [ "${XDEBUG_ENABLED}" = "true" ]; then \
      pecl install xdebug-3.5.3 && docker-php-ext-enable xdebug && rm -rf /tmp/pear; \
    fi
COPY ./docker/development/php/conf.d/xdebug.ini "$PHP_INI_DIR/conf.d/"

COPY --chmod=755 ./docker/development/php-fpm/entrypoint.sh /usr/local/bin/entrypoint.sh

# A user with your host UID and GID, so the files that PHP-FPM writes to the
# bind-mounted project belong to you. An existing group is reused, such as
# GID 20 (`dialout` here, `staff` on macOS).
# The ARGs come last: a changed value rebuilds only the layers after them.
ARG UID=1000
ARG GID=1000
RUN if ! getent group "${GID}" >/dev/null; then groupadd -g "${GID}" www; fi \
    && useradd -l -m -u "${UID}" -g "${GID}" -s /bin/bash www

USER www

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]


# Development toolchain for the `workspace` service: the development image,
# so Artisan and the tests run with the same PHP as PHP-FPM, plus Composer
# and Node.js
FROM development AS workspace

USER root

# git and unzip for Composer, and the PostgreSQL client for `php artisan db`
# and `schema:dump`. Debian's client is version 17, and its pg_dump refuses
# newer servers, so the client comes from the PostgreSQL apt repository with
# the same major version as the `postgres` image in the Compose files.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    postgresql-common \
    unzip \
    && /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y \
    && apt-get install -y --no-install-recommends postgresql-client-18 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer/composer:2-bin /composer /usr/local/bin/composer
COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

USER www

# The PHP-FPM entrypoint clears caches and links the public disk, which
# php-fpm already does on every start
ENTRYPOINT []
CMD ["bash"]


# Production web server
FROM nginx:1.30-alpine AS web

COPY ./docker/common/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY ./public /var/www/public
# API-only: drop this line
COPY --from=assets /var/www/public/build /var/www/public/build

# The same link as in the PHP image: nginx serves these files at /storage
RUN ln -sfn ../storage/app/public /var/www/public/storage
