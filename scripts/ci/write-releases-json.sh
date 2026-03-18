#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: write-releases-json.sh <release-metadata.json> <releases.json>" >&2
  exit 1
fi

metadata_path="$1"
releases_path="$2"

jq '{
  version,
  sha,
  short_sha,
  published_at,
  tags
}' "$metadata_path" > "$releases_path"
