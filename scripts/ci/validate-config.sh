#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: validate-config.sh <config-path>" >&2
  exit 1
fi

config_path="$1"

if [ ! -f "$config_path" ]; then
  echo "Config file not found: $config_path" >&2
  exit 1
fi

jq empty "$config_path" > /dev/null

jq -e '
  (.image | type == "string" and test("^ghcr\\.io/runlix/[a-z0-9]+([._-][a-z0-9]+)*$")) and
  ((has("version") | not) or (.version | type == "string" and length > 0)) and
  (.targets | type == "array" and length > 0) and
  all(.targets[];
    (.name | type == "string" and test("^[a-z0-9-]+$")) and
    (.tag | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$")) and
    (.arch == "amd64" or .arch == "arm64") and
    (.dockerfile | type == "string" and length > 0) and
    (.base_ref | type == "string" and test("^.+:.+@sha256:[a-f0-9]{64}$")) and
    ((.test // "") | type == "string") and
    ((.enabled // true) | type == "boolean") and
    ((.build_args // {}) | type == "object") and
    all((.build_args // {}) | to_entries[]?;
      (.key | test("^[A-Z_][A-Z0-9_]*$")) and
      (.value | type == "string")
    )
  )
' "$config_path" > /dev/null

duplicate_names="$(jq -r '.targets[].name' "$config_path" | sort | uniq -d)"
if [ -n "$duplicate_names" ]; then
  echo "Duplicate target names detected:" >&2
  echo "$duplicate_names" >&2
  exit 1
fi

duplicate_tag_arch_pairs="$(
  jq -r '.targets[] | select(.enabled // true) | [.tag, .arch] | @tsv' "$config_path" |
    sort |
    uniq -d
)"
if [ -n "$duplicate_tag_arch_pairs" ]; then
  echo "Duplicate enabled tag/arch pairs detected:" >&2
  echo "$duplicate_tag_arch_pairs" >&2
  exit 1
fi

while IFS=$'\t' read -r target_name dockerfile test_script; do
  if [ ! -f "$dockerfile" ]; then
    echo "Target '$target_name' references a missing Dockerfile: $dockerfile" >&2
    exit 1
  fi

  if [ -n "$test_script" ] && [ ! -f "$test_script" ]; then
    echo "Target '$target_name' references a missing test script: $test_script" >&2
    exit 1
  fi
done < <(
  jq -r '.targets[] | select(.enabled // true) | [.name, .dockerfile, (.test // "")] | @tsv' "$config_path"
)

enabled_count="$(jq '[.targets[] | select(.enabled // true)] | length' "$config_path")"
if [ "$enabled_count" -eq 0 ]; then
  echo "At least one target must be enabled" >&2
  exit 1
fi

image_name="$(jq -r '.image' "$config_path")"
version_text="$(jq -r '.version // ""' "$config_path")"
manifest_tags="$(jq -r '[.targets[] | select(.enabled // true) | .tag] | unique | join(", ")' "$config_path")"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    printf 'image_name=%s\n' "$image_name"
    printf 'version=%s\n' "$version_text"
    printf 'enabled_count=%s\n' "$enabled_count"
    printf 'manifest_tags=%s\n' "$manifest_tags"
  } >> "$GITHUB_OUTPUT"
fi

echo "Validated $enabled_count enabled target(s) for $image_name"
if [ -n "$version_text" ]; then
  echo "Version: $version_text"
else
  echo "Version: <omitted>"
fi
echo "Manifest tags: $manifest_tags"
