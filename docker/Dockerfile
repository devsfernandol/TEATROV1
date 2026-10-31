FROM php:8.5.12-fpm-alpine

RUN docker-php-ext-install pdo_mysql \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY php.ini "$PHP_INI_DIR/conf.d/zz-teatro.ini"
COPY php-fpm.conf /usr/local/etc/php-fpm.d/zz-teatro.conf
