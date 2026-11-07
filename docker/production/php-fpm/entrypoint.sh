#!/bin/sh
set -e

# Without a key, /up and the health checks pass while every page is a 500
if [ -z "$APP_KEY" ]; then
  echo "APP_KEY is not set. Generate one with 'openssl rand -base64 32' and set APP_KEY=base64:<key> in .env" >&2
  exit 1
fi

# Cache the configuration, events, routes, and views. This runs at startup,
# not during the build, because the configuration comes from the environment.
# Migrations run once, in the 'migrate' service in compose.prod.yaml.
php artisan optimize

# Run the default command
exec "$@"
