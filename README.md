# Build Workflow

`build-workflow` exposes one supported interface for new repositories and one legacy interface for existing consumers:

- `CI v3`: reusable workflows for build validation, release publishing, and release metadata validation
- `v1`: the legacy `docker-matrix` workflow surface

## Quick Start

Recommended caller layout:

```text
release branch:
  .ci/build.json
  .github/workflows/validate-build.yml
  .github/workflows/publish-release.yml

main branch:
  .github/workflows/validate-release-metadata.yml
  release.json
```

Starter files:

- build config examples: `examples/build-config/base-image.json`, `examples/build-config/service-image.json`
- wrapper examples: `examples/wrappers/validate-build.yml`, `examples/wrappers/publish-release.yml`, `examples/wrappers/validate-release-metadata.yml`
- schemas: `schema/build-config.schema.json`, `schema/release-json.schema.json`
- canonical guide: [docs/ci-v3.md](./docs/ci-v3.md)

Callers pin only the reusable workflow SHA from `runlix/build-workflow`.
The reusable workflows derive their matching internal tool image from the pinned reusable workflow ref and fall back to the current repository SHA only for provider self-tests, so callers do not pass or pin a separate planner image anymore.
If you want automated `main` sync on protected branches, map `RUNLIX_APP_ID` and `RUNLIX_PRIVATE_KEY` into the publish wrapper.
The publish wrapper must grant `contents: read`, `packages: write`, `attestations: write`, and `id-token: write`.

## Supported CI Surface

Public reusable workflows:

- `.github/workflows/validate-build.yml`
- `.github/workflows/publish-release.yml`
- `.github/workflows/validate-release-metadata.yml`

Canonical assets:

- schemas: `schema/build-config.schema.json`, `schema/release-json.schema.json`
- build config examples: `examples/build-config/`
- wrapper examples: `examples/wrappers/`
- contract tests: `.github/workflows/test-contract.yml`
- fixtures: `test-fixtures/ci/`
- internal tool image: `tools/ci/`

## CI Design

The supported CI path uses a narrow public contract and an internal planner/executor split:

- reusable workflows are the public orchestration layer
- `build-workflow-ci` is the internal planning and validation layer
- Docker build, push, manifest creation, attestation, and optional `main` sync stay on the GitHub runner
- pure config validation and `release.json` rendering run inside the internal tool image that matches the reusable workflow commit

This keeps callers simple while avoiding workflow-time self-checkout of implementation files from the provider repository.

## Legacy `v1`

`v1` remains available for existing repositories:

- reusable workflow: `.github/workflows/build-images-rebuild.yml`
- schema: `schema/docker-matrix-schema.json`
- docs: [docs/v1/README.md](./docs/v1/README.md)
- examples: `examples/v1/`
- fixtures: `test-fixtures/v1/`
