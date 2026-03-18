# CI v2

`v2` keeps the existing branch model:

- `release`: runtime, build, and CI implementation
- `main`: metadata and automation configuration

`v2` is consumed through reusable workflows exported from `build-workflow`:

- `.github/workflows/pr-validation-v2.yml`
- `.github/workflows/release-v2.yml`
- `.github/workflows/sync-release-metadata-v2.yml`

Service repositories should use thin wrapper workflows pinned to a merged full commit SHA.
Branch refs and preview tags are for temporary maintainer testing only, not for the supported `v2` surface.

`v2` is intentionally scoped to publishing `ghcr.io/runlix/...` images.

For PR validation wrappers, name the caller job `validate` so the aggregate check appears as `validate / summary`.

## Config

`v2` uses one explicit config file: `.ci/config.json`.

Each enabled target is one build unit and declares:

- final manifest tag
- one architecture
- one Dockerfile
- one pinned base reference
- optional test script
- optional extra build args

The canonical schemas are:

- `schema/ci-config-v2.schema.json`
- `schema/release-metadata-v2.schema.json`
- `schema/releases-v2.schema.json`

Generic examples live in:

- `examples/ci-v2/service-config.json`
- `examples/ci-v2/base-image-config.json`

`image` must be `ghcr.io/runlix/<name>`.

## Workflow behavior

Wrapper examples live in:

- `examples/pr-validation.yml`
- `examples/release.yml`
- `examples/sync-release-metadata.yml`

Wrapper path filters should treat `.ci/*.sh` and `.dockerignore` as build inputs, not `.ci/README.md`.

Config examples live in:

- `examples/ci-v2/service-config.json`
- `examples/ci-v2/base-image-config.json`

PR validation:

1. validates `.ci/config.json`
2. renders the build matrix
3. builds each enabled target locally
4. runs the target test if configured
5. emits a final `summary` job that is the aggregate PR gate

Release:

1. validates `.ci/config.json`
2. renders the build matrix
3. builds each target locally
4. runs the target test if configured
5. pushes one temporary single-arch image per target
6. creates final multi-arch manifests
7. uploads `release-metadata.json` as artifact `release-metadata`

`build-workflow` uses the internal workflow `.github/workflows/release-v2-internal.yml` for dry-run contract coverage. Real service wrappers should only call the public `release-v2.yml`.

Metadata sync:

1. runs from `main` on successful `Release`
2. verifies the triggering workflow and metadata provenance
3. downloads `release-metadata.json`
4. writes `releases.json`
5. commits only when metadata changes

## Design rules

- `v2` keeps `v1` untouched
- reusable workflows are the public interface
- `plan-v2-internal.yml` is an internal implementation detail for shared validation and matrix planning
- `release-v2-internal.yml` is an internal implementation detail for release dry-run coverage and shared release execution
- no internal checkout of `build-workflow`
- no second SHA input
- no legacy `docker-matrix` support in `v2`
- no runtime downloads for core logic except artifact retrieval from the triggering run
- metadata sync is standardized on `release`, `main`, and `release-metadata`
- real service wrappers should rely on default inputs unless they have a documented reason not to
- docs and examples should reference merged full SHAs only

## Testing

`build-workflow` ships dedicated `v2` coverage in:

- `.github/workflows/test-workflow-v2.yml`
- `test-fixtures/v2/base-image`
- `test-fixtures/v2/service`
- `test-fixtures/v2/release-metadata`

That coverage validates the schema/examples, exercises the PR reusable workflow against two fixture repos, verifies the artifact contract for `release-metadata.json`, and checks the `release-metadata.json` to `releases.json` transform.
