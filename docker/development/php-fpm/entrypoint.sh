#!/bin/sh
set -e

# Clear configurations to avoid caching issues in development
echo "Clearing configurations..."
php artisan config:clear
php artisan route:clear
php artisan view:clear

# Link the public disk, the same as `php artisan storage:link`
echo "Linking the public storage directory..."
ln -sfn ../storage/app/public /var/www/public/storage

# Run the default command (e.g., php-fpm or bash)
exec "$@"
