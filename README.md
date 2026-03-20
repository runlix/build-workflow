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
  .github/workflows/pr-validation.yml
  .github/workflows/release.yml

main branch:
  .github/workflows/sync-release-metadata.yml
```

Starter files:

- config examples: `examples/ci/service-config.json` and `examples/ci/base-image-config.json`
- wrapper workflows: `examples/pr-validation.yml`, `examples/release.yml`, `examples/sync-release-metadata.yml`
- schema: `schema/ci-config.schema.json`
- local CI tool image: `ghcr.io/runlix/build-workflow-tools:ci`

Pin the wrapper workflows to a merged full commit SHA from `runlix/build-workflow`.
Supported callers should normally rely on the default tool image. Maintainers can override it with the `tool-image` input when validating an unpublished `build-workflow` branch.
If you want release notifications, same-organization callers should set `secrets: inherit` on the release wrapper so `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` reach the reusable workflow. Other callers should pass those named secrets explicitly.

The supported contract is intentionally scoped to publishing `ghcr.io/runlix/...` images.

The canonical guide is [docs/ci.md](./docs/ci.md).

## CI Interface

Public reusable workflows:

- `.github/workflows/pr-validation.yml`
- `.github/workflows/release.yml`
- `.github/workflows/sync-release-metadata.yml`

Canonical assets:

- schema: `schema/ci-config.schema.json`
- metadata schemas: `schema/release-metadata.schema.json`, `schema/releases.schema.json`
- config examples: `examples/ci/`
- contract tests: `.github/workflows/test-ci.yml`
- fixtures: `test-fixtures/ci/`
- CI tool image: `tools/ci/`

## CI Design

The supported `CI` path uses a planner/executor split:

- reusable workflows are the public orchestration layer
- the `build-workflow-ci` tool is the planning and validation layer
- Docker build, push, and manifest creation stay on the GitHub runner
- pure config validation and release-metadata generation run inside the CI tool image

This avoids the caller-context problems that come from trying to load implementation files from a called workflow repository at runtime.

## Local Validation

The same tool used in GitHub Actions can run locally:

```bash
docker run --rm \
  -v "$PWD:/workspace" \
  -w /workspace \
  ghcr.io/runlix/build-workflow-tools:ci \
  validate-config .ci/config.json
```

Other useful local commands:

```bash
docker run --rm -v "$PWD:/workspace" -w /workspace \
  ghcr.io/runlix/build-workflow-tools:ci \
  plan-matrix .ci/config.json --short-sha 1234567

docker run --rm -v "$PWD:/workspace" -w /workspace \
  ghcr.io/runlix/build-workflow-tools:ci \
  render-release-metadata .ci/config.json \
  --source-sha 1234567890abcdef1234567890abcdef12345678 \
  --published-at 2026-03-18T00:00:00Z

docker run --rm -v "$PWD:/workspace" -w /workspace \
  ghcr.io/runlix/build-workflow-tools:ci \
  render-telegram-notification release-metadata.json \
  --image-name ghcr.io/runlix/example-service \
  --repository runlix/example-service \
  --server-url https://github.com \
  --run-id 123456789
```

## CI Behavior

PR validation:

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
6. uploads `release-metadata.json` as artifact `release-metadata`
7. sends an optional non-blocking Telegram notification when the caller inherits `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`

Metadata sync:

1. runs from `main` after a successful `Release` workflow on `release`
2. downloads `release-metadata.json`
3. verifies the triggering workflow provenance
4. writes `releases.json`
5. commits only when the metadata changed

## Legacy `v1`

`v1` remains available for existing repositories:

- reusable workflow: `.github/workflows/build-images-rebuild.yml`
- schema: `schema/docker-matrix-schema.json`
- docs: [docs/v1/README.md](./docs/v1/README.md)
- examples: `examples/v1/`
- fixtures: `test-fixtures/v1/`

Use `v1` only if you are maintaining an existing `docker-matrix` integration.
