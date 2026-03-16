#!/usr/bin/env bash
set -euo pipefail

if [ -z "${IMAGE_TAG:-}" ]; then
  echo "IMAGE_TAG must be set" >&2
  exit 1
fi

platform="${PLATFORM:-linux/amd64}"
container_name="sabnzbd-smoke-${RANDOM}"
config_dir="$(mktemp -d)"
host_port="$(shuf -i 20000-29999 -n 1)"

cleanup() {
  docker rm -f "$container_name" > /dev/null 2>&1 || true
  chmod -R 777 "$config_dir" > /dev/null 2>&1 || true
  rm -rf "$config_dir" > /dev/null 2>&1 || true
}

trap cleanup EXIT

docker run \
  --detach \
  --pull=never \
  --platform "$platform" \
  --name "$container_name" \
  --volume "$config_dir:/config" \
  --publish "${host_port}:8080" \
  --env PUID=1000 \
  --env PGID=1000 \
  --env TZ=UTC \
  "$IMAGE_TAG" > /dev/null

for _attempt in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${host_port}/" > /dev/null; then
    break
  fi
  sleep 2
done

curl -fsS "http://127.0.0.1:${host_port}/" > /dev/null
curl -fsS "http://127.0.0.1:${host_port}/api?mode=version" > /dev/null || true
