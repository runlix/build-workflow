# CI v2

`v2` keeps the existing branch model:

- `release`: runtime, build, and CI implementation
- `main`: metadata and automation configuration

`v2` is consumed through reusable workflows exported from `build-workflow`:

- `.github/workflows/pr-validation-v2.yml`
- `.github/workflows/release-v2.yml`
- `.github/workflows/sync-release-metadata-v2.yml`

Service repositories should use thin wrapper workflows pinned to a full commit SHA.

## Config

`v2` uses one explicit config file: `.ci/config.json`.

Each enabled target is one build unit and declares:

- final manifest tag
- one architecture
- one Dockerfile
- one pinned base reference
- optional test script
- optional extra build args

The canonical schema is:

- `schema/ci-config-v2.schema.json`

Generic examples live in:

- `examples/ci-v2/service-config.json`
- `examples/ci-v2/base-image-config.json`

## Workflow behavior

PR validation:

1. validates `.ci/config.json`
2. renders the build matrix
3. builds each enabled target locally
4. runs the target test if configured

Release:

1. validates `.ci/config.json`
2. renders the build matrix
3. builds each target locally
4. runs the target test if configured
5. pushes one temporary single-arch image per target
6. creates final multi-arch manifests
7. uploads `release-metadata.json`

Metadata sync:

1. runs from `main` on successful `Release`
2. downloads `release-metadata.json`
3. writes `releases.json`
4. commits only when metadata changes

## Design rules

- `v2` keeps `v1` untouched
- reusable workflows are the public interface
- no internal checkout of `build-workflow`
- no second SHA input
- no legacy `docker-matrix` support in `v2`
- no runtime downloads for core logic except artifact retrieval from the triggering run
