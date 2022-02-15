#!/usr/bin/env bash
set -eu
set -o pipefail

IMAGE="${1}"
ARCH="${2}"

docker run --rm --platform "${ARCH}" --entrypoint=php "${IMAGE}" -v | grep -E '^PHP 5\.3'
docker run --rm --platform "${ARCH}" --entrypoint=php-fpm "${IMAGE}" -v | grep -E '^PHP 5\.3'
