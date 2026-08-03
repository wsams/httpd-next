# PHP flavor: Nginx + PHP-FPM via s6-overlay.
# docker build -t wsams/httpd-next:php-local -f Dockerfile.php --build-arg BASE_IMAGE=wsams/httpd-next:local .
ARG BASE_IMAGE=wsams/httpd-next:latest
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive \
    NGINX_TEMPLATE=/etc/nginx/templates/php.conf.template

COPY docker/nginx/templates/php.conf.template /etc/nginx/templates/php.conf.template
COPY docker/php/zz-docker.conf /tmp/zz-docker.conf
COPY docker/php/security.ini /tmp/security.ini
COPY docker/s6/php/php-fpm/run /etc/s6-overlay/s6-rc.d/php-fpm/run
COPY docker/s6/php/php-fpm/type /etc/s6-overlay/s6-rc.d/php-fpm/type
COPY examples/php/index.php /var/www/html/index.php

RUN apt-get update && \
    apt-get -y install --no-install-recommends \
        composer \
        php-cli \
        php-curl \
        php-fpm \
        php-gd \
        php-mbstring \
        php-mysql \
        php-sqlite3 \
        php-xml \
        php-zip \
        unzip \
        zip && \
    PHP_VER="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')" && \
    ln -sf "/usr/sbin/php-fpm${PHP_VER}" /usr/local/sbin/php-fpm && \
    rm -f "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" && \
    cp /tmp/zz-docker.conf "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" && \
    cp /tmp/security.ini "/etc/php/${PHP_VER}/fpm/conf.d/99-httpd-next-security.ini" && \
    cp /tmp/security.ini "/etc/php/${PHP_VER}/cli/conf.d/99-httpd-next-security.ini" && \
    printf '%s\n' "${PHP_VER}" > /etc/httpd-next-php-version && \
    sed -i "s|^pid = .*|pid = /run/php/php-fpm.pid|" "/etc/php/${PHP_VER}/fpm/php-fpm.conf" && \
    mkdir -p /run/php && \
    chown www-data:www-data /run/php && \
    chmod 755 /etc/s6-overlay/s6-rc.d/php-fpm/run && \
    touch /etc/s6-overlay/user-bundles.d/user/contents.d/php-fpm && \
    rm -f /tmp/zz-docker.conf /tmp/security.ini && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*
