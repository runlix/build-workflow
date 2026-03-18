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

Pin the wrapper workflows to a merged full commit SHA from `runlix/build-workflow`.
Supported callers must use that same SHA in three places:

- the reusable workflow `uses:` ref
- the `build-workflow-ref` input
- the raw GitHub `$schema` URL in `.ci/config.json`

Do not use branch refs or preview tags in supported callers.

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
- internal implementation: `.github/actions/internal/ci/`

The internal composite actions are not the supported consumer API. Downstream repositories should call the public reusable workflows only.

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
