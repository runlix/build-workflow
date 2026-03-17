# Build Workflow

`build-workflow` now has two tracks:

- `v2`: the supported reusable-workflow interface for new repositories
- `v1`: the legacy `docker-matrix` workflow surface kept for existing consumers

If you are starting fresh, use `v2`.

## Quick Start (`v2`)

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

- config examples: `examples/ci-v2/service-config.json` and `examples/ci-v2/base-image-config.json`
- wrapper workflows: `examples/pr-validation.yml`, `examples/release.yml`, `examples/sync-release-metadata.yml`
- schema: `schema/ci-config-v2.schema.json`

Pin the wrapper workflows to a merged full commit SHA from `runlix/build-workflow`.

`v2` is intentionally scoped to publishing `ghcr.io/runlix/...` images.

The canonical `v2` guide is [docs/ci-v2.md](./docs/ci-v2.md).

## `v2` Interface

Public reusable workflows:

- `.github/workflows/pr-validation-v2.yml`
- `.github/workflows/release-v2.yml`
- `.github/workflows/sync-release-metadata-v2.yml`

Internal reusable workflow:

- `.github/workflows/plan-v2-internal.yml`

Canonical `v2` assets:

- schema: `schema/ci-config-v2.schema.json`
- config examples: `examples/ci-v2/`
- contract tests: `.github/workflows/test-workflow-v2.yml`
- fixtures: `test-fixtures/v2/`

## `v2` Behavior

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
3. writes `releases.json`
4. commits only when the metadata changed

## Legacy `v1`

`v1` remains available for existing repositories:

- reusable workflow: `.github/workflows/build-images-rebuild.yml`
- schema: `schema/docker-matrix-schema.json`
- docs: [docs/v1/README.md](./docs/v1/README.md)
- examples: `examples/v1/`
- fixtures: `test-fixtures/v1/`

Use `v1` only if you are maintaining an existing `docker-matrix` integration.
