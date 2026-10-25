#!/bin/sh
set -e

# On a fresh clone the stack starts before `composer install` has run in the
# workspace, and artisan would fail here, taking the container down with it
if [ -f vendor/autoload.php ]; then
  # Clear configurations to avoid caching issues in development
  echo "Clearing configurations..."
  php artisan config:clear
  php artisan route:clear
  php artisan view:clear
else
  echo "vendor/ not found, skipping artisan - run 'composer install' in the workspace container"
fi

# Link the public disk, the same as `php artisan storage:link`
echo "Linking the public storage directory..."
ln -sfn ../storage/app/public /var/www/public/storage

# Run the default command (e.g., php-fpm or bash)
exec "$@"
