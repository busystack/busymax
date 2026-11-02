FROM php:8.4.13-apache-bookworm@sha256:9a2ce5c55ce38f31062e5027ef9cf0aa008c9f7571bd3362aeec5071ef28c06e
# setup.py verifies the official archive and extracts it without changing files.
COPY .runtime/baikal/ /var/www/baikal/
COPY baikal-apache.conf /etc/apache2/sites-available/000-default.conf
COPY provision-baikal.php /fixtures/provision.php
COPY health.php /fixtures/health.php
HEALTHCHECK --interval=5s --timeout=6s --start-period=10s --retries=12 CMD ["php", "/fixtures/health.php"]
COPY baikal-entrypoint.sh /usr/local/bin/baikal-fixture
RUN chmod +x /usr/local/bin/baikal-fixture
ENTRYPOINT ["baikal-fixture"]
CMD ["apache2-foreground"]
