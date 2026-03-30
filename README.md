# Build Workflow

`build-workflow` has one supported interface and one legacy interface:

- `CI`: the supported reusable-workflow contract for new repositories
- `v1`: the legacy `docker-matrix` workflow surface kept for existing consumers

If you are starting fresh, use `CI`.

## Quick Start

Recommended caller layout:

```text
release branch:
  .ci/config.json
  .github/workflows/validate.yml
  .github/workflows/release.yml

main branch:
  .github/workflows/validate-main.yml
  release.json
```

Starter files:

- config examples: `examples/ci/service-config.json` and `examples/ci/base-image-config.json`
- wrapper workflows: `examples/wrappers/validate.yml`, `examples/wrappers/release.yml`, `examples/wrappers/validate-main.yml`
- schemas: `schema/ci-config.schema.json` and `schema/release-json.schema.json`
- CI tool image: `ghcr.io/runlix/build-workflow-tools@sha256:YOUR_TOOL_IMAGE_DIGEST`

Pin the wrapper workflows to a merged full commit SHA from `runlix/build-workflow`.
Pass the planner image explicitly with `tool-image`, pinned by digest in normal caller usage.
Maintainers may also use `ghcr.io/runlix/build-workflow-tools:sha-<40-char build-workflow git sha>` for intentional branch validation when that immutable tag was published first.
The mutable `ghcr.io/runlix/build-workflow-tools:ci` tag is only a convenience alias for the latest published `main` tool image and is not a supported caller input.
If you want release notifications, map only `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` into the release wrapper.
If you want automated `main` sync on protected branches, map `RUNLIX_APP_ID` and `RUNLIX_PRIVATE_KEY` into the same release wrapper.
The release wrapper must grant `contents: read`, `packages: write`, `attestations: write`, and `id-token: write`.
The main-branch wrapper should stay read-only and validate only `release.json`.

The supported contract is intentionally scoped to publishing `ghcr.io/runlix/...` images.

The canonical guide is [docs/ci.md](./docs/ci.md).
Focused supported-CI guides live under [docs/ci/](./docs/ci/).

## CI Interface

Public reusable workflows:

- `.github/workflows/validate.yml`
- `.github/workflows/release.yml`
- `.github/workflows/validate-release-json.yml`

Canonical assets:

- schemas: `schema/ci-config.schema.json`, `schema/release-json.schema.json`
- config examples: `examples/ci/`
- wrapper examples: `examples/wrappers/`
- contract tests: `.github/workflows/test-ci.yml`
- fixtures: `test-fixtures/ci/`
- CI tool image: `tools/ci/`

Focused guides:

- [docs/ci/architecture.md](./docs/ci/architecture.md)
- [docs/ci/usage.md](./docs/ci/usage.md)
- [docs/ci/workflow-behavior.md](./docs/ci/workflow-behavior.md)
- [docs/ci/api-reference.md](./docs/ci/api-reference.md)
- [docs/ci/testing-and-maintenance.md](./docs/ci/testing-and-maintenance.md)
- [docs/ci/troubleshooting.md](./docs/ci/troubleshooting.md)

`examples/ci/` are schema-only examples for documentation.
`test-fixtures/ci/` are runnable fixture repos used by contract tests and local end-to-end checks.

## CI Design

The supported `CI` path uses a planner/executor split:

- reusable workflows are the public orchestration layer
- the `build-workflow-ci` tool is the planning and validation layer
- Docker build, push, manifest creation, attestation, and optional `main` sync stay on the GitHub runner
- pure config validation and `release.json` rendering run inside the CI tool image

This avoids the caller-context problems that come from trying to load implementation files from a called workflow repository at runtime.
`build-workflow` does not treat cross-workflow artifact transport as part of the public contract anymore; `release.yml` owns the full trusted publish path through optional `release.json` PR creation.

## Config Contract

The caller contract is one explicit file: `.ci/config.json`.

Top-level keys:

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
2. renders the build matrix and manifest plan
3. builds and tests each enabled target
4. pushes one temporary single-arch tag per target
5. creates final manifest tags
6. resolves final manifest digests
7. renders and validates `release.json`
8. attests published manifests
9. opens or updates a bot-authored PR into `main` when App credentials are mapped
10. sends an optional non-blocking Telegram notification when Telegram secrets are mapped

Main validation:

1. runs from `main`
2. validates only `release.json`
3. stays read-only and secret-free

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
  render-release-json .ci/config.json \
  --source-sha 1234567890abcdef1234567890abcdef12345678 \
  --published-at 2026-03-18T00:00:00Z \
  --manifests-path test-fixtures/ci/release-json/manifests.json

docker run --rm -v "$PWD:/workspace" -w /workspace \
  ghcr.io/runlix/build-workflow-tools@sha256:YOUR_TOOL_IMAGE_DIGEST \
  validate-release-json release.json
```

## Legacy `v1`

`v1` remains available for existing repositories:

- reusable workflow: `.github/workflows/build-images-rebuild.yml`
- schema: `schema/docker-matrix-schema.json`
- docs: [docs/v1/README.md](./docs/v1/README.md)
- examples: `examples/v1/`
- fixtures: `test-fixtures/v1/`

Use `v1` only if you are maintaining an existing `docker-matrix` integration.
