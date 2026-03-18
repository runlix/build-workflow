#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: run.sh <config-path> <short-sha> [output-file]" >&2
  exit 1
fi

config_path="$1"
short_sha="$2"
output_file="${3:-}"

image_name="$(jq -r '.image' "$config_path")"

if [ -n "$output_file" ]; then
  : > "$output_file"
fi

while IFS= read -r manifest_tag; do
  [ -n "$manifest_tag" ] || continue

  refs=()
  while IFS=$'\t' read -r arch _target_name; do
    refs+=("${image_name}:${manifest_tag}-${arch}-${short_sha}")
  done < <(
    jq -r --arg tag "$manifest_tag" '
      .targets[]
      | select((.enabled // true) and .tag == $tag)
      | [.arch, .name]
      | @tsv
    ' "$config_path"
  )

  if [ "${#refs[@]}" -eq 0 ]; then
    echo "No platform images discovered for manifest tag: $manifest_tag" >&2
    exit 1
  fi

  echo "Creating manifest ${image_name}:${manifest_tag}"
  docker buildx imagetools create -t "${image_name}:${manifest_tag}" "${refs[@]}"

  if [ -n "$output_file" ]; then
    printf '%s\n' "$manifest_tag" >> "$output_file"
  fi
done < <(jq -r '.targets[] | select(.enabled // true) | .tag' "$config_path" | sort -u)
