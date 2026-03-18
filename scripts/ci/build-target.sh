#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
  echo "Usage: build-target.sh <config-path> <target-name> <pr|release> <short-sha> [context-dir]" >&2
  exit 1
fi

config_path="$1"
target_name="$2"
mode="$3"
short_sha="$4"
context_dir="${5:-.}"

if [ "$mode" != "pr" ] && [ "$mode" != "release" ]; then
  echo "Mode must be 'pr' or 'release'" >&2
  exit 1
fi

image_name="$(jq -r '.image' "$config_path")"
version_text="$(jq -r '.version // ""' "$config_path")"
target_json="$(
  jq -c --arg name "$target_name" '
    .targets[]
    | select((.enabled // true) and .name == $name)
  ' "$config_path"
)"

if [ -z "$target_json" ]; then
  echo "Enabled target not found: $target_name" >&2
  exit 1
fi

arch="$(printf '%s' "$target_json" | jq -r '.arch')"
dockerfile="$(printf '%s' "$target_json" | jq -r '.dockerfile')"
manifest_tag="$(printf '%s' "$target_json" | jq -r '.tag')"
base_ref="$(printf '%s' "$target_json" | jq -r '.base_ref')"
build_date="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
platform="linux/$arch"

base_no_digest="${base_ref%@*}"
if [ "$base_no_digest" = "$base_ref" ]; then
  echo "base_ref must include a digest: $base_ref" >&2
  exit 1
fi

base_digest="${base_ref#*@}"
base_image="${base_no_digest%:*}"
base_tag="${base_no_digest##*:}"

if [ "$mode" = "pr" ]; then
  image_tag="${image_name}:pr-${short_sha}-${target_name}"
else
  image_tag="${image_name}:${manifest_tag}-${arch}-${short_sha}"
fi

build_args=(
  --build-arg "BASE_IMAGE=$base_image"
  --build-arg "BASE_TAG=$base_tag"
  --build-arg "BASE_DIGEST=$base_digest"
)

while IFS=$'\t' read -r key value; do
  [ -n "$key" ] || continue
  build_args+=(--build-arg "$key=$value")
done < <(
  printf '%s' "$target_json" |
    jq -r '(.build_args // {}) | to_entries[]? | [.key, .value] | @tsv'
)

label_args=(
  --label "org.opencontainers.image.created=$build_date"
  --label "org.opencontainers.image.revision=${GITHUB_SHA:-local}"
  --label "org.opencontainers.image.source=${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-local/repository}"
)
if [ -n "$version_text" ]; then
  label_args+=(--label "org.opencontainers.image.version=$version_text")
fi

echo "Building target '$target_name'"
echo "  Image: $image_tag"
echo "  Platform: $platform"
echo "  Dockerfile: $dockerfile"

docker buildx build \
  --platform "$platform" \
  -f "$dockerfile" \
  "${build_args[@]}" \
  "${label_args[@]}" \
  --load \
  -t "$image_tag" \
  "$context_dir"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    printf 'image_tag=%s\n' "$image_tag"
    printf 'platform=%s\n' "$platform"
  } >> "$GITHUB_OUTPUT"
fi
