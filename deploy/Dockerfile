# PHP 8.5.12: incluye el parche de PHP2Shell (CVE-2026-109618 y CVE-2026-109619).
FROM php:8.5.12-fpm-alpine

RUN docker-php-ext-install pdo_mysql \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY php.ini "$PHP_INI_DIR/conf.d/zz-teatro.ini"
