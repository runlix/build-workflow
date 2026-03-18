# CI

The supported `build-workflow` interface is the versionless CI contract:

- `.github/workflows/pr-validation.yml`
- `.github/workflows/release.yml`
- `.github/workflows/sync-release-metadata.yml`

`v1` remains available only for legacy `docker-matrix` callers.

## Branch Model

- `release`: runtime, build, and CI implementation
- `main`: metadata and automation configuration

Caller repositories should keep thin wrappers on those branches and pin them to a merged full commit SHA from `runlix/build-workflow`.

## Config

The caller contract is one explicit file: `.ci/config.json`.

Each enabled target is one build unit and declares:

- final manifest tag
- one architecture
- one Dockerfile
- one pinned base reference
- optional test script
- optional extra build args

Canonical assets:

- schema: `schema/ci-config.schema.json`
- metadata schemas: `schema/release-metadata.schema.json`, `schema/releases.schema.json`
- config examples: `examples/ci/`
- fixtures: `test-fixtures/ci/`
- contract workflow: `.github/workflows/test-ci.yml`

`image` must be `ghcr.io/runlix/<name>`.

## Required Pinning

Supported callers must use the same merged full `build-workflow` SHA in three places:

- the reusable workflow `uses:` ref
- the `build-workflow-ref` workflow input
- the raw GitHub `$schema` URL in `.ci/config.json`

`build-workflow-ref` is required because GitHub associates the `github` context in a called workflow with the caller repository. The reusable workflow cannot reliably discover its own repository ref at runtime, so callers must pass the exact SHA explicitly.

## Workflow Behavior

PR validation:

1. validates `.ci/config.json`
2. renders the build matrix
3. builds each enabled target locally
4. runs the target test if configured
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
2. verifies the triggering workflow provenance
3. downloads `release-metadata.json` from the triggering run
4. writes `releases.json`
5. commits only when the metadata changed

## Design Rules

- reusable workflows are the public interface
- internal implementation lives under `.github/actions/internal/ci/`
- internal composite actions may use action-local `run.sh` entrypoints, but callers should not invoke them directly
- no branch refs or preview tags in supported callers
- no legacy `docker-matrix` compatibility in the supported interface
- metadata sync is standardized on `Release`, `release`, `main`, and `release-metadata`
- callers should rely on default inputs unless they have a documented reason not to
- `publish: false` on the release workflow is for contract testing and maintainer dry runs
