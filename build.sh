#!/usr/bin/env bash
#
# Bake pl4yrs-os images on macOS. Wraps the Docker volume actions required
# because VirtioFS bind mounts lack xattr/ACL support: the project is copied
# into a named volume, baked there, and artifacts are copied back.
#
# See https://github.com/docker/for-mac/issues/7463
#
# Usage:
#   ./build.sh                  # bake all systems (production + dev)
#   ./build.sh rpi-uboot-arm64  # bake only the listed system(s)
#   ./build.sh clean            # remove the build volume entirely (full reset)

set -euo pipefail
cd "$(dirname "$0")"

BUILD_VOLUME=${BUILD_VOLUME:-pl4yrs-rugix-build}
CACHE_VOLUME=${CACHE_VOLUME:-rugix-build-cache}
IMAGE=${RUGIX_BAKERY_IMAGE:-ghcr.io/rugix/rugix-bakery:v0.9.6}

if [ "${1:-}" = "clean" ]; then
    docker volume rm "${BUILD_VOLUME}"
    echo ">>> Removed volume ${BUILD_VOLUME}"
    exit 0
fi

if [ "$#" -gt 0 ]; then
    SYSTEMS=("$@")
else
    SYSTEMS=(rpi-uboot-arm64 rpi-uboot-arm64-dev)
fi

for vol in "${BUILD_VOLUME}" "${CACHE_VOLUME}"; do
    docker volume inspect "${vol}" >/dev/null 2>&1 || docker volume create "${vol}" >/dev/null
done

echo ">>> Syncing sources into ${BUILD_VOLUME}"
docker run --rm -v "$PWD":/src:ro -v "${BUILD_VOLUME}":/dst debian:trixie-slim \
    sh -c 'rm -rf /dst/layers /dst/mixins /dst/recipes && \
           cp -a /src/rugix-bakery.toml /src/layers /src/mixins /src/recipes /dst/'

for sys in "${SYSTEMS[@]}"; do
    echo ">>> Baking ${sys}"
    docker run --rm --privileged \
        -v "${BUILD_VOLUME}":/project \
        -v "${BUILD_VOLUME}":/run/rugix/bakery/context \
        -v "${CACHE_VOLUME}":/run/rugix/bakery/cache \
        -e RUGIX_HOST_PROJECT_DIR=/project \
        -e RUGIX_BAKERY_IMAGE="${IMAGE}" \
        "${IMAGE}" \
        bake system "${sys}" --output "/project/build/${sys}"

    docker run --rm -v "${BUILD_VOLUME}":/src:ro -v "$PWD/build":/dst \
        debian:trixie-slim \
        sh -c "rm -rf '/dst/${sys}' && cp -r '/src/build/${sys}' /dst/"

    xz -kf -T0 "build/${sys}/system.img"

    # Prune rule workspaces + materialized trees
    docker run --rm -v "${BUILD_VOLUME}":/project debian:trixie-slim \
        sh -c 'rm -rf /project/.rugix/rules/task-* /project/.rugix/rules/.tmp* \
                      /project/.rugix/rules/trees /project/.rugix/rules/*/trees' || true

    echo ">>> Done: build/${sys}/"
done
