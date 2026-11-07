#!/bin/sh
set -e

# UID/GID in .env that don't match the owner of the project make every write
# fail, with errors that mention neither. Docker Desktop maps ownership, so
# this only triggers with Docker Engine on Linux.
if [ ! -w /var/www ]; then
  echo "/var/www (owned by $(stat -c %u:%g /var/www)) is not writable by $(id -u):$(id -g)." >&2
  echo "Set UID and GID in .env to the output of 'id -u' and 'id -g', then run: docker compose -f compose.dev.yaml up -d --build" >&2
  exit 1
fi

# On a fresh clone the stack starts before `composer install` has run in the
# workspace, and artisan would fail here, taking the container down with it
if [ -f vendor/autoload.php ]; then
  # Remove caches left by `php artisan optimize`, which would hide changes to
  # .env, routes, and events. The application cache in Redis stays.
  php artisan optimize:clear --except=cache
else
  echo "vendor/ not found, skipping artisan - run 'composer install' in the workspace container"
fi

# Link the public disk, the same as `php artisan storage:link --relative`
echo "Linking the public storage directory..."
ln -sfn ../storage/app/public /var/www/public/storage

# Run the default command (e.g., php-fpm or bash)
exec "$@"
