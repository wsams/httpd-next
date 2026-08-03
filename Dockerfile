# Base image: Nginx edge proxy with TLS and s6-overlay.
# docker build -t wsams/httpd-next:local --rm --pull .
FROM ubuntu:26.04

ARG S6_OVERLAY_VERSION=3.2.3.2

ENV DEBIAN_FRONTEND=noninteractive \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_KEEP_ENV=1 \
    NGINX_SERVER_NAME=localhost \
    SSL_CERTIFICATE_FILE=/nginx-cert.pem \
    SSL_CERTIFICATE_KEY_FILE=/nginx-key.pem \
    NGINX_TEMPLATE=/etc/nginx/templates/base.conf.template

COPY docker/install-s6.sh /tmp/install-s6.sh

RUN apt-get update && \
    apt-get -y install --no-install-recommends \
        ca-certificates \
        curl \
        gettext-base \
        nginx \
        openssl \
        xz-utils && \
    S6_OVERLAY_VERSION="${S6_OVERLAY_VERSION}" /tmp/install-s6.sh && \
    rm -f /tmp/install-s6.sh && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/www/html /etc/nginx/templates /etc/nginx/conf.d \
        /etc/s6-overlay/user-bundles.d/user/contents.d && \
    rm -f /etc/nginx/sites-enabled/default && \
    openssl req -x509 -nodes -days 365 -newkey rsa:4096 -sha256 \
        -subj "/C=US/ST=Xaero/L=Pepper/O=Zoopaz/OU=Zoopaz/CN=localhost" \
        -keyout /nginx-key.pem -out /nginx-cert.pem

COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/templates/base.conf.template /etc/nginx/templates/base.conf.template
COPY docker/s6/base/nginx/run /etc/s6-overlay/s6-rc.d/nginx/run
COPY docker/s6/base/nginx/type /etc/s6-overlay/s6-rc.d/nginx/type
COPY examples/static/index.html /var/www/html/index.html

RUN chmod 755 /etc/s6-overlay/s6-rc.d/nginx/run && \
    touch /etc/s6-overlay/user-bundles.d/user/contents.d/nginx

EXPOSE 80 443

ENTRYPOINT ["/init"]
