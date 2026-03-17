#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"

bash "${repo_root}/.github/actions/ci-v2/write-releases-json/run.sh" "$@"
