#!/bin/bash
set -euo pipefail

echo "Testing image: $IMAGE_TAG"

test -n "${IMAGE_TAG:-}"
docker image inspect "$IMAGE_TAG" > /dev/null

revision="$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.revision"}}' "$IMAGE_TAG")"
created="$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.created"}}' "$IMAGE_TAG")"
source="$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.source"}}' "$IMAGE_TAG")"

test -n "$revision"
test -n "$created"
test -n "$source"

temp_container="$(docker create "$IMAGE_TAG")"
trap 'docker rm -f "$temp_container" >/dev/null 2>&1 || true' EXIT

docker cp "$temp_container:/etc/build-info" /tmp/build-info-v2.json
jq -e '.variant == "stable" or .variant == "debug"' /tmp/build-info-v2.json > /dev/null
rm -f /tmp/build-info-v2.json
