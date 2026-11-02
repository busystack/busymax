#!/bin/sh
set -eu
php /fixtures/provision.php
chown -R www-data:www-data /var/www/baikal/config /var/www/baikal/Specific
exec docker-php-entrypoint "$@"
