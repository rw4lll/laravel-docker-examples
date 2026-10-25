# Stage 1: Build environment and Composer dependencies
# The Debian suffix prevents a silent switch to the next Debian release, which
# renames the library packages installed with apt-get below
FROM php:8.5-fpm-trixie AS builder

# Install system dependencies and PHP extensions required for Laravel + MySQL/PostgreSQL support
# Some dependencies are required for PHP extensions only in the build stage
# Node.js is not needed here: the frontend is built in the `assets` stage below
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    libpq-dev \
    libonig-dev \
    libssl-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libicu-dev \
    libzip-dev \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    pdo_pgsql \
    pgsql \
    intl \
    zip \
    bcmath \
    soap \
    && pecl install redis-6.3.0 \
    && docker-php-ext-enable redis \
    && apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=composer/composer:2-bin /composer /usr/local/bin/composer

# Set the working directory inside the container
WORKDIR /var/www

# Copy the entire Laravel application code into the container
# -----------------------------------------------------------
# In Laravel, the `composer install` command often triggers
# scripts that need access to the entire application code.
# For example, the `post-autoload-dump` event might execute
# Artisan commands like `php artisan package:discover`. If the
# application code (including the `artisan` file) is not
# present, these commands will fail, leading to build errors.
#
# By copying the entire application code before running
# `composer install`, we ensure that all necessary files are
# available, allowing these scripts to run successfully.
# In other cases, it would be possible to copy composer files
# first, to leverage Docker's layer caching mechanism.
# -----------------------------------------------------------
COPY . /var/www

# Install Composer dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress --prefer-dist


# Stage 2: Frontend assets
# Built once here so nginx (which serves the files) and PHP (which reads
# manifest.json to render their URLs) can never disagree about which build.
# API-only project? Drop this stage and the two `COPY --from=assets` lines below.
FROM node:26-alpine AS assets

WORKDIR /var/www
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build


# Stage 3: Shared PHP runtime
FROM php:8.5-fpm-trixie AS runtime

# Install only runtime libraries needed in production
# libfcgi-bin and procps are required for the php-fpm-healthcheck script
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    libicu-dev \
    libzip-dev \
    libfcgi-bin \
    procps \
    && apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Download and install php-fpm health check script
ADD --chmod=755 --checksum=sha256:53bc616c4a30f029b98bff48fdeb0c4da252cb11e4f86656a8222a67dc4e5009 \
    https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/v0.6.0/php-fpm-healthcheck \
    /usr/local/bin/php-fpm-healthcheck

# Copy the initialization script
COPY ./docker/production/php-fpm/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy PHP extensions and libraries from the builder stage
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=builder /usr/local/bin/docker-php-ext-* /usr/local/bin/

# Use the recommended production PHP configuration
# -----------------------------------------------------------
# PHP provides development and production configurations.
# Here, we replace the default php.ini with the production
# version to apply settings optimized for performance and
# security in a live environment.
# -----------------------------------------------------------
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY ./docker/common/php/conf.d/*.ini "$PHP_INI_DIR/conf.d/"

# Keep the image-provided FPM global config intact and add pool overrides separately
COPY ./docker/common/php-fpm/conf.d/*.conf /usr/local/etc/php-fpm.d/
# Update the variables_order to include E (for ENV)
#RUN sed -i 's/variables_order = "GPCS"/variables_order = "EGPCS"/' "$PHP_INI_DIR/php.ini"

# Copy the application code and dependencies from the build stage
COPY --from=builder /var/www /var/www

# Link the public disk, the same as 'php artisan storage:link'
# -----------------------------------------------------------
# The link is relative, so it also works on the host in development.
# The 'web' stage makes the same link for Nginx.
# -----------------------------------------------------------
RUN ln -sfn ../storage/app/public /var/www/public/storage

# Set working directory
WORKDIR /var/www

# Ensure correct permissions
RUN chown -R www-data:www-data /var/www

# Switch to the non-privileged user to run the application
USER www-data

# Change the default command to run the entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Expose port 9000 and start php-fpm server
EXPOSE 9000
CMD ["php-fpm"]


# Stage 4: Production image
FROM runtime AS production

# API-only: drop this line — the stage then adds nothing, so build `runtime` instead
COPY --from=assets --chown=www-data:www-data /var/www/public/build /var/www/public/build


# Stage 5: Development image
# Built from `runtime`, not `production`, so a dev build never runs the Node
# stage - the dev stack bind-mounts the project and runs Vite in `workspace`.
FROM runtime AS development

# Use ARG to define environment variables passed from the Docker build command or Docker Compose.
ARG XDEBUG_ENABLED=true
ARG XDEBUG_MODE=develop,debug
ARG XDEBUG_HOST=host.docker.internal
ARG XDEBUG_IDE_KEY=DOCKER
ARG XDEBUG_LOG=/dev/stdout
ARG XDEBUG_LOG_LEVEL=0

USER root

# Configure Xdebug if enabled
RUN if [ "${XDEBUG_ENABLED}" = "true" ]; then \
    pecl install xdebug-3.5.3 && \
    docker-php-ext-enable xdebug && \
    echo "xdebug.mode=${XDEBUG_MODE}" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.idekey=${XDEBUG_IDE_KEY}" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.log=${XDEBUG_LOG}" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.log_level=${XDEBUG_LOG_LEVEL}" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.client_host=${XDEBUG_HOST}" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.start_with_request=trigger" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini ; \
fi

# Add ARGs for syncing permissions
ARG UID=1000
ARG GID=1000

# Create a new user with the specified UID/GID and point the php-fpm pool at it.
RUN if getent group ${GID}; then \
      group_name=$(getent group ${GID} | cut -d: -f1); \
      useradd -m -u ${UID} -g ${GID} -s /bin/bash www; \
    else \
      groupadd -g ${GID} www && \
      useradd -m -u ${UID} -g www -s /bin/bash www; \
      group_name=www; \
    fi && \
    sed -i "s/user = www-data/user = www/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i "s/group = www-data/group = ${group_name}/g" /usr/local/etc/php-fpm.d/www.conf

# Set the working directory
WORKDIR /var/www

# Copy the entrypoint script
COPY ./docker/development/php-fpm/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch back to the non-privileged user to run the application
USER www

# Change the default command to run the entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Expose port 9000 and start php-fpm server
EXPOSE 9000
CMD ["php-fpm"]


# Stage 6: Production web server
FROM nginx:1.30-alpine AS web

COPY ./docker/production/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./public /var/www/public
# API-only: drop this line
COPY --from=assets /var/www/public/build /var/www/public/build

# The same link as in the PHP image: Nginx serves these files at '/storage'
RUN ln -sfn ../storage/app/public /var/www/public/storage

WORKDIR /var/www/public

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
