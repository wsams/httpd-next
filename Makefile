IMAGE_NAME ?= wsams/httpd-next
VERSION ?= local

.PHONY: build test up down release-deps lint-shell

build:
	IMAGE_NAME="$(IMAGE_NAME)" ./scripts/build-images.sh "$(VERSION)"

test: build
	IMAGE_NAME="$(IMAGE_NAME)" ./scripts/test-images.sh "$(VERSION)"

up:
	docker compose -f sample.docker-compose.yml up -d

down:
	docker compose -f sample.docker-compose.yml down

release-deps:
	npm ci

lint-shell:
	bash -n scripts/build-images.sh
	bash -n scripts/test-images.sh
	bash -n docker/install-s6.sh
