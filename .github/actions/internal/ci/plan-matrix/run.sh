#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: run.sh <config-path> <short-sha>" >&2
  exit 1
fi

config_path="$1"
short_sha="$2"

jq -c --arg short_sha "$short_sha" '
  . as $root
  | [
      .targets[]
      | select(.enabled // true)
      | {
          name,
          image: $root.image,
          version: ($root.version // ""),
          tag,
          arch,
          platform: ("linux/" + .arch),
          runner: (
            if .arch == "arm64" then
              "ubuntu-24.04-arm"
            else
              "ubuntu-24.04"
            end
          ),
          dockerfile,
          base_ref,
          test: (.test // ""),
          build_args: (.build_args // {}),
          pr_local_tag: ("pr-" + $short_sha + "-" + .name),
          release_temp_tag: (.tag + "-" + .arch + "-" + $short_sha)
        }
    ]
' "$config_path"
