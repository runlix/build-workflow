# Build Workflow

`build-workflow` has one supported interface and one legacy interface:

- `CI`: the supported reusable-workflow contract for new repositories
- `v1`: the legacy `docker-matrix` workflow surface kept for existing consumers

If you are starting fresh, use `CI`.

## Quick Start

Recommended repository shape:

```text
release branch:
  .ci/config.json
  .github/workflows/validate.yml
  .github/workflows/release.yml

main branch:
  .github/workflows/sync-release-record.yml
  release.json
```

Starter files:

- config examples: `examples/ci/service-config.json` and `examples/ci/base-image-config.json`
- wrapper workflows: `examples/wrappers/validate.yml`, `examples/wrappers/release.yml`, `examples/wrappers/sync-release-record.yml`
- schemas: `schema/ci-config.schema.json` and `schema/release-record.schema.json`
- CI tool image: `ghcr.io/runlix/build-workflow-tools@sha256:YOUR_TOOL_IMAGE_DIGEST`

Pin the wrapper workflows to a merged full commit SHA from `runlix/build-workflow`.
Pass the planner image explicitly with `tool-image`, pinned either by digest or by `:sha-<build-workflow git sha>` for maintainer branch validation.
If you want release notifications, map only `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` into the release wrapper.

The supported contract is intentionally scoped to publishing `ghcr.io/runlix/...` images.

The canonical guide is [docs/ci.md](./docs/ci.md).

## CI Interface

Public reusable workflows:

- `.github/workflows/validate.yml`
- `.github/workflows/release.yml`
- `.github/workflows/sync-release-record.yml`

Canonical assets:

- schemas: `schema/ci-config.schema.json`, `schema/release-record.schema.json`
- config examples: `examples/ci/`
- wrapper examples: `examples/wrappers/`
- contract tests: `.github/workflows/test-ci.yml`
- fixtures: `test-fixtures/ci/`
- CI tool image: `tools/ci/`

## CI Design

The supported `CI` path uses a planner/executor split:

- reusable workflows are the public orchestration layer
- the `build-workflow-ci` tool is the planning and validation layer
- Docker build, push, and manifest creation stay on the GitHub runner
- pure config validation and release-record generation run inside the CI tool image

This avoids the caller-context problems that come from trying to load implementation files from a called workflow repository at runtime.

## Config Contract

The caller contract is one explicit file: `.ci/config.json`.

Top level keys:

- `image`
- optional `version`
- optional `defaults`
- `targets`

`defaults` supports:

- `context`
- `test`
- `build_args`

Each enabled target declares:

- `name`
- `manifest_tag`
- `platform`
- `dockerfile`
- optional `build_args`
- optional `test`

Dockerfiles should consume full immutable refs directly via build args such as `BASE_REF` or `BUILDER_REF`.

## CI Behavior

Validate:

1. validates `.ci/config.json`
2. renders the build matrix
3. builds each enabled target locally
4. runs the target test when configured
5. emits the aggregate check `validate / summary`

Release:

1. validates `.ci/config.json`
2. renders the build matrix
3. builds and tests each enabled target
4. pushes one temporary single-arch tag per target
5. creates final manifest tags
6. uploads `release-record.json` as artifact `release-record`
7. sends an optional non-blocking Telegram notification when the caller maps `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`

Sync:

1. runs from `main` after a successful `Release` workflow on `release`
2. downloads `release-record.json`
3. verifies the triggering workflow provenance
4. writes `release.json`
5. commits only when the metadata changed

## Local Validation

The same tool used in GitHub Actions can run locally:

```bash
docker run --rm \
  -v "$PWD:/workspace" \
  -w /workspace \
  ghcr.io/runlix/build-workflow-tools@sha256:YOUR_TOOL_IMAGE_DIGEST \
  validate-config .ci/config.json
```

Other useful local commands:

```bash
docker run --rm -v "$PWD:/workspace" -w /workspace \
  ghcr.io/runlix/build-workflow-tools@sha256:YOUR_TOOL_IMAGE_DIGEST \
  plan-matrix .ci/config.json --short-sha 1234567

docker run --rm -v "$PWD:/workspace" -w /workspace \
  ghcr.io/runlix/build-workflow-tools@sha256:YOUR_TOOL_IMAGE_DIGEST \
  render-release-record .ci/config.json \
  --source-sha 1234567890abcdef1234567890abcdef12345678 \
  --published-at 2026-03-18T00:00:00Z
```

## Legacy `v1`

`v1` remains available for existing repositories:

- reusable workflow: `.github/workflows/build-images-rebuild.yml`
- schema: `schema/docker-matrix-schema.json`
- docs: [docs/v1/README.md](./docs/v1/README.md)
- examples: `examples/v1/`
- fixtures: `test-fixtures/v1/`

Use `v1` only if you are maintaining an existing `docker-matrix` integration.
