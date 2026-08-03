# Go flavor: Nginx + compiled Go HTTP binary via s6-overlay.
# Multi-stage: build the example binary, then layer onto the base image.
# docker build -t wsams/httpd-next:go-local -f Dockerfile.go --build-arg BASE_IMAGE=wsams/httpd-next:local .

ARG GO_BUILD_IMAGE=golang:1.24-bookworm
FROM ${GO_BUILD_IMAGE} AS go-build

WORKDIR /src
COPY examples/go/go.mod ./
COPY examples/go/main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/goapp .

ARG BASE_IMAGE=wsams/httpd-next:latest
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive \
    NGINX_TEMPLATE=/etc/nginx/templates/go.conf.template \
    GO_APP_BIN=/usr/local/bin/goapp \
    GO_APP_ADDR=127.0.0.1:8080 \
    GOTOOLCHAIN=local

COPY docker/nginx/templates/go.conf.template /etc/nginx/templates/go.conf.template
COPY docker/s6/go/goapp/run /etc/s6-overlay/s6-rc.d/goapp/run
COPY docker/s6/go/goapp/type /etc/s6-overlay/s6-rc.d/goapp/type
COPY --from=go-build /out/goapp /usr/local/bin/goapp

RUN apt-get update && \
    apt-get -y install --no-install-recommends golang-go && \
    chmod 755 /usr/local/bin/goapp /etc/s6-overlay/s6-rc.d/goapp/run && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/goapp && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*
