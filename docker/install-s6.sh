#!/usr/bin/env bash
# Install s6-overlay into the image root.
set -euo pipefail

S6_OVERLAY_VERSION="${S6_OVERLAY_VERSION:-3.2.3.2}"
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64) S6_ARCH=x86_64 ;;
  aarch64|arm64) S6_ARCH=aarch64 ;;
  *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;;
esac

BASE_URL="https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}"

curl -fsSL "${BASE_URL}/s6-overlay-noarch.tar.xz" -o /tmp/s6-overlay-noarch.tar.xz
curl -fsSL "${BASE_URL}/s6-overlay-${S6_ARCH}.tar.xz" -o /tmp/s6-overlay-arch.tar.xz

tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
tar -C / -Jxpf /tmp/s6-overlay-arch.tar.xz
rm -f /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-arch.tar.xz
