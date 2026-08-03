#!/usr/bin/env bash
# Smoke-test locally built wsams/httpd-next image flavors.
#
# Usage:
#   ./scripts/test-images.sh ci
#   IMAGE_NAME=wsams/httpd-next ./scripts/test-images.sh local
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-wsams/httpd-next}"
VERSION="${1:?Usage: $0 <version>}"
CURL_OPTS=(--silent --show-error --fail --max-time 10)

PASS_COUNT=0
FAIL_COUNT=0
CLEANUP_IDS=()

cleanup() {
  local id
  for id in "${CLEANUP_IDS[@]+"${CLEANUP_IDS[@]}"}"; do
    [[ -n "${id}" ]] || continue
    docker rm -f "${id}" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

log() {
  printf '==> %s\n' "$*"
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS: %s\n' "$*"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL: %s\n' "$*" >&2
}

require_image() {
  local tag="$1"
  if ! docker image inspect "${tag}" >/dev/null 2>&1; then
    echo "Missing image: ${tag}" >&2
    echo "Build first with: ./scripts/build-images.sh ${VERSION}" >&2
    exit 1
  fi
}

wait_for_http() {
  local url="$1"
  local attempts="${2:-45}"
  local i
  for ((i = 1; i <= attempts; i++)); do
    if curl "${CURL_OPTS[@]}" -k -o /dev/null "${url}" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

start_container() {
  local name="$1"
  shift
  local id
  id="$(docker run -d --name "${name}" "$@")"
  CLEANUP_IDS+=("${id}")
  echo "${id}"
}

assert_body_contains() {
  local url="$1"
  local needle="$2"
  local body
  body="$(curl "${CURL_OPTS[@]}" -k "${url}")"
  if [[ "${body}" == *"${needle}"* ]]; then
    return 0
  fi
  printf 'Expected body to contain %q, got:\n%s\n' "${needle}" "${body}" >&2
  return 1
}

nginx_env=(
  -e NGINX_SERVER_NAME=localhost
  -e SSL_CERTIFICATE_FILE=/nginx-cert.pem
  -e SSL_CERTIFICATE_KEY_FILE=/nginx-key.pem
)

log "Checking required images for version ${VERSION}"
require_image "${IMAGE_NAME}:${VERSION}"
require_image "${IMAGE_NAME}:php-${VERSION}"
require_image "${IMAGE_NAME}:python-${VERSION}"
require_image "${IMAGE_NAME}:go-${VERSION}"
require_image "${IMAGE_NAME}:stack-${VERSION}"

# --- base ---
log "Testing base image"
start_container "httpd-next-test-base-$$" \
  -p 18080:80 -p 18443:443 \
  "${nginx_env[@]}" \
  "${IMAGE_NAME}:${VERSION}" >/dev/null
if wait_for_http "http://127.0.0.1:18080/" \
  && assert_body_contains "http://127.0.0.1:18080/" "Nginx is working" \
  && assert_body_contains "https://127.0.0.1:18443/" "Nginx is working"; then
  pass "base serves static content over HTTP and HTTPS"
else
  fail "base flavor smoke test failed"
fi

# --- php ---
log "Testing php image"
start_container "httpd-next-test-php-$$" \
  -p 18081:80 -p 18444:443 \
  "${nginx_env[@]}" \
  "${IMAGE_NAME}:php-${VERSION}" >/dev/null
if wait_for_http "http://127.0.0.1:18081/" \
  && assert_body_contains "http://127.0.0.1:18081/" "PHP-FPM is working" \
  && assert_body_contains "https://127.0.0.1:18444/" "PHP-FPM is working"; then
  pass "php serves PHP-FPM over HTTP and HTTPS"
else
  fail "php flavor smoke test failed"
fi

# --- python ---
log "Testing python image"
start_container "httpd-next-test-python-$$" \
  -p 18082:80 -p 18445:443 \
  "${nginx_env[@]}" \
  "${IMAGE_NAME}:python-${VERSION}" >/dev/null
if wait_for_http "http://127.0.0.1:18082/" \
  && assert_body_contains "http://127.0.0.1:18082/" "Python (Uvicorn/ASGI) is working" \
  && assert_body_contains "https://127.0.0.1:18445/" "Python (Uvicorn/ASGI) is working"; then
  pass "python proxies to Uvicorn over HTTP and HTTPS"
else
  fail "python flavor smoke test failed"
fi

# --- go ---
log "Testing go image"
start_container "httpd-next-test-go-$$" \
  -p 18083:80 -p 18446:443 \
  "${nginx_env[@]}" \
  "${IMAGE_NAME}:go-${VERSION}" >/dev/null
if wait_for_http "http://127.0.0.1:18083/" \
  && assert_body_contains "http://127.0.0.1:18083/" "Go is working" \
  && assert_body_contains "https://127.0.0.1:18446/" "Go is working"; then
  pass "go proxies to Go binary over HTTP and HTTPS"
else
  fail "go flavor smoke test failed"
fi

# --- stack ---
log "Testing stack image"
start_container "httpd-next-test-stack-$$" \
  -p 18084:80 -p 18447:443 \
  "${nginx_env[@]}" \
  "${IMAGE_NAME}:stack-${VERSION}" >/dev/null
if wait_for_http "http://127.0.0.1:18084/" \
  && assert_body_contains "http://127.0.0.1:18084/" "PHP-FPM is working" \
  && assert_body_contains "http://127.0.0.1:18084/api/py/" "Python (Uvicorn/ASGI) is working" \
  && assert_body_contains "http://127.0.0.1:18084/api/go/" "Go is working" \
  && assert_body_contains "https://127.0.0.1:18447/api/py/" "Python (Uvicorn/ASGI) is working" \
  && assert_body_contains "https://127.0.0.1:18447/api/go/" "Go is working"; then
  pass "stack routes PHP, Python, and Go over HTTP and HTTPS"
else
  fail "stack flavor smoke test failed"
fi

log "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if [[ "${FAIL_COUNT}" -ne 0 ]]; then
  exit 1
fi
