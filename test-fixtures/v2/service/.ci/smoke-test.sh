#!/bin/bash
set -euo pipefail

echo "Testing image: $IMAGE_TAG"

test -n "${IMAGE_TAG:-}"
docker image inspect "$IMAGE_TAG" > /dev/null

version="$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.version"}}' "$IMAGE_TAG")"
source="$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.source"}}' "$IMAGE_TAG")"
test -n "$version"
test -n "$source"

ports="$(docker inspect --format='{{range $p, $conf := .Config.ExposedPorts}}{{$p}} {{end}}' "$IMAGE_TAG")"
if [[ ! "$ports" =~ 8080 ]]; then
  echo "Expected port 8080 to be exposed" >&2
  exit 1
fi

temp_container="$(docker create "$IMAGE_TAG")"
trap 'docker rm -f "$temp_container" >/dev/null 2>&1 || true' EXIT

docker cp "$temp_container:/app/metadata.json" /tmp/service-metadata-v2.json
jq -e '.app_version == "1.2.3"' /tmp/service-metadata-v2.json > /dev/null
jq -e '.variant == "stable" or .variant == "debug"' /tmp/service-metadata-v2.json > /dev/null
rm -f /tmp/service-metadata-v2.json
