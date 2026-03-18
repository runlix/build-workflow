#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: validate-release-record.sh <json-path>" >&2
  exit 1
fi

json_path="$1"

if [ ! -f "$json_path" ]; then
  echo "JSON file not found: $json_path" >&2
  exit 1
fi

jq empty "$json_path" > /dev/null

jq -e '
  ((.version == null) or (.version | type == "string" and length > 0)) and
  (.sha | type == "string" and test("^[a-f0-9]{40}$")) and
  (.short_sha | type == "string" and test("^[a-f0-9]{7,40}$")) and
  (.published_at | type == "string" and test("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")) and
  (.tags | type == "array" and length > 0) and
  all(.tags[]; type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$")) and
  ((.tags | unique | length) == (.tags | length))
' "$json_path" > /dev/null
