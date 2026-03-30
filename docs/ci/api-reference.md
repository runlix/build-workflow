# CI API Reference

## Public Reusable Workflows

### `.github/workflows/validate.yml`

Purpose:

- validate `.ci/config.json`
- plan enabled targets
- build each enabled target locally
- run effective smoke tests
- summarize the branch-check result

Inputs:

- `config-path`
  - type: `string`
  - required: no
  - default: `.ci/config.json`
  - intended use: maintainer override for fixtures
- `tool-image`
  - type: `string`
  - required: yes
  - accepted values:
    - `ghcr.io/runlix/build-workflow-tools@sha256:<digest>`
    - `ghcr.io/runlix/build-workflow-tools:sha-<40-char git sha>`

Expected wrapper permissions:

- `contents: read`

Workflow concurrency:

- `validate-${{ github.repository }}-${{ github.ref }}-${{ inputs.config-path }}`
- `cancel-in-progress: true`

### `.github/workflows/release.yml`

Purpose:

- validate `.ci/config.json`
- plan enabled targets
- build and test targets
- push temporary single-arch refs
- create final manifest tags
- render and upload `release.json`
- attest published manifests
- optionally open or update the `main` sync PR
- optionally send Telegram notification

Inputs:

- `config-path`
  - type: `string`
  - required: no
  - default: `.ci/config.json`
- `publish`
  - type: `boolean`
  - required: no
  - default: `true`
- `tool-image`
  - type: `string`
  - required: yes
  - same accepted forms as validate

Secrets:

- `TELEGRAM_BOT_TOKEN`
  - optional
- `TELEGRAM_CHAT_ID`
  - optional
- `RUNLIX_APP_ID`
  - optional
- `RUNLIX_PRIVATE_KEY`
  - optional

Expected wrapper permissions:

- `contents: read`
- `packages: write`
- `attestations: write`
- `id-token: write`

Artifacts:

- `release-json`
  - file: `release.json`

Workflow concurrency:

- `release-${{ github.repository }}`
- `cancel-in-progress: false`

### `.github/workflows/validate-release-json.yml`

Purpose:

- read-only validation of caller `release.json`

Inputs:

- `tool-image`
  - type: `string`
  - required: yes
- `release-json-path`
  - type: `string`
  - required: no
  - default: `release.json`

Expected wrapper permissions:

- `contents: read`

## `.ci/config.json`

Schema:

- `schema/ci-config.schema.json`

Top-level fields:

- `$schema`
  - optional schema hint
- `image`
  - required
  - must match `ghcr.io/runlix/<name>`
- `version`
  - optional non-empty string
- `defaults`
  - optional object
  - supports `context`, `test`, and `build_args`
- `targets`
  - required non-empty array

### `defaults`

- `context`
  - optional string
  - default: `.`
- `test`
  - optional string
  - becomes the effective test when a target omits `test`
- `build_args`
  - optional object of string values
  - merged into each target before target-specific overrides

### `targets[]`

- `name`
  - required
  - lowercase letters, digits, and `-`
- `manifest_tag`
  - required
  - final manifest tag to publish
- `platform`
  - required
  - `linux/amd64` or `linux/arm64`
- `dockerfile`
  - required
  - file must exist
- `build_args`
  - optional object of string values
- `test`
  - optional string
- `enabled`
  - optional boolean
  - default: `true`

Additional invariants enforced by the planner tool:

- at least one target must be enabled
- target names must be unique
- enabled `manifest_tag` / `platform` pairs must be unique
- `defaults.context` must exist as a directory
- the effective test script must exist when configured

Path semantics:

- `config-path` is repo-root-relative after checkout
- `defaults.context` is the repo-root-relative Docker build context
- `dockerfile` is a repo-root-relative path passed to `docker buildx build -f`
- the effective test path is repo-root-relative and executed directly on the runner
- `release-json-path` is repo-root-relative after checkout

## Matrix and Tag Semantics

Runner mapping:

- `linux/amd64 -> ubuntu-24.04`
- `linux/arm64 -> ubuntu-24.04-arm`

Validate-mode local tag:

- `ghcr.io/runlix/<name>:pr-<short_sha>-<target_name>`

Release-mode temporary tag:

- `ghcr.io/runlix/<name>:<manifest_tag>-<arch>-<short_sha>`

Final manifest tag:

- `ghcr.io/runlix/<name>:<manifest_tag>`

## Planner Commands

The public CI design depends on these `build-workflow-ci` commands:

- `validate-config`
- `validate-config-payload`
- `plan-matrix`
- `plan-build-target`
- `plan-manifests`
- `render-release-json`
- `validate-release-json`
- `render-telegram-notification`

`validate-config-payload` is schema-only.
`validate-config` is stronger: it includes model validation such as duplicate detection, effective test resolution, and context path checks.

### `validate-config`

Returns:

- `image_name`
- `version`
- `enabled_count`
- `manifest_tags`
- `context_dir`

### `plan-matrix`

Returns one object per enabled target with:

- `name`
- `image`
- `version`
- `manifest_tag`
- `arch`
- `platform`
- `runner`
- `dockerfile`
- `context_dir`
- `test`
- `build_args`
- `pr_local_tag`
- `release_temp_tag`

### `plan-build-target`

Returns one resolved target payload with:

- `name`
- `image_name`
- `version`
- `manifest_tag`
- `arch`
- `platform`
- `dockerfile`
- `context_dir`
- `test`
- `image_tag`
- `release_temp_tag`
- `build_args`
- `labels`

Mode-specific tag behavior:

- `--mode pr` returns the validate-mode `pr-<short_sha>-<target_name>` local tag
- `--mode release` returns the temporary single-arch release tag

### `plan-manifests`

Returns one object per final manifest with:

- `tag`
- `refs`
- `platforms`

### `render-release-json`

Returns the normalized digest-first metadata record that is committed as `release.json`.

### `validate-release-json`

Validates `release.json` against `schema/release-json.schema.json`.

## `release.json`

Schema:

- `schema/release-json.schema.json`

Top-level fields:

- `image`
- `version`
- `sha`
- `short_sha`
- `published_at`
- `manifests`

Each `manifests[]` entry declares:

- `tag`
- `digest`
- `platforms`
