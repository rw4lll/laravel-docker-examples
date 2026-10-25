#!/bin/sh
set -e

# Without a key every service still reports healthy, while each page is a 500
if [ -z "$APP_KEY" ]; then
  echo "APP_KEY is not set. Generate one with 'openssl rand -base64 32' and set APP_KEY=base64:<key> in .env" >&2
  exit 1
fi

# Run Laravel migrations
# -----------------------------------------------------------
# Ensure the database schema is up to date.
# -----------------------------------------------------------
php artisan migrate --force

# Clear and cache configurations
# -----------------------------------------------------------
# Improves performance by caching config and routes.
# -----------------------------------------------------------
php artisan config:cache
php artisan route:cache

# Run the default command
exec "$@"
