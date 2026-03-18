#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: run.sh <config-path> <source-sha> <published-at>" >&2
  exit 1
fi

config_path="$1"
source_sha="$2"
published_at="$3"

version_text="$(jq -r '.version // ""' "$config_path")"
short_sha="$(printf '%s' "$source_sha" | cut -c1-7)"
tags_json="$(jq '[.targets[] | select(.enabled // true) | .tag] | unique' "$config_path")"

jq -n \
  --arg version "$version_text" \
  --arg sha "$source_sha" \
  --arg short_sha "$short_sha" \
  --arg published_at "$published_at" \
  --argjson tags "$tags_json" \
  '{
    version: (if $version == "" then null else $version end),
    sha: $sha,
    short_sha: $short_sha,
    published_at: $published_at,
    tags: $tags
  }'
