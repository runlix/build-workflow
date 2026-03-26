# CI

The supported `build-workflow` interface is the versionless `CI` contract:

- `.github/workflows/validate.yml`
- `.github/workflows/release.yml`
- `.github/workflows/sync-release-record.yml`
- `.github/workflows/validate-sync-wrapper.yml`
- `.github/workflows/validate-release-json.yml`

`v1` remains available only for legacy `docker-matrix` callers.

## Guide Map

- [Architecture](./ci/architecture.md): provider/caller split, branch model, planner image, and supported boundaries
- [Usage](./ci/usage.md): repo layout, wrapper placement, path semantics, config shape, Dockerfiles, pinning, and common caller cases
- [Workflow Behavior](./ci/workflow-behavior.md): validate, release, sync, and main-branch validation end to end
- [API Reference](./ci/api-reference.md): reusable workflow inputs, wrapper requirements, config fields, planner command outputs, tags, and release-record shapes
- [Testing and Maintenance](./ci/testing-and-maintenance.md): tool responsibilities, fixture coverage, provider CI, and downstream canaries
- [Troubleshooting](./ci/troubleshooting.md): common failure modes and what they usually mean

## Surface Map

### Public Caller Surface

| Path | What it does | Why it exists |
| --- | --- | --- |
| `.github/workflows/validate.yml` | Validates `.ci/config.json`, plans enabled targets, builds each enabled target locally, runs optional smoke tests, and emits `validate / summary`. | Catches release-branch build and smoke-test regressions before merge without publishing anything. |
| `.github/workflows/release.yml` | Validates config, builds and tests enabled targets, pushes per-target temporary tags, creates final manifests, renders `release-record.json`, uploads artifact `release-record`, and optionally sends Telegram notifications. | Centralizes the release path so callers publish images and metadata the same way. |
| `.github/workflows/sync-release-record.yml` | Consumes the `release-record` artifact from a successful `Release` run, rewrites it to `release.json`, and creates or updates a bot-authored PR into `main`. | Keeps metadata updates on `main` reproducible and compatible with protected-branch policies. |
| `.github/workflows/validate-sync-wrapper.yml` | Inspects the caller's `main` sync wrapper file and enforces the thin-wrapper contract. | Prevents callers from widening permissions, secrets, or behavior around the metadata sync path. |
| `.github/workflows/validate-release-json.yml` | Validates `release.json` against the same schema used for `release-record.json`. | Gives `main` pull requests a read-only metadata validation check. |
| `schema/ci-config.schema.json` | JSON Schema for `.ci/config.json`. | Defines the stable caller config shape. |
| `schema/release-record.schema.json` | JSON Schema for `release-record.json` and `release.json`. | Keeps release artifacts and committed metadata on one contract. |
| `examples/ci/` | Schema-only config examples. | Shows supported config shape without requiring runnable fixture repos. |
| `examples/wrappers/` | Starter wrappers for validate, release, sync, and `validate-main`. | Gives callers the supported thin-wrapper patterns and pinning model. |

### Maintainer And Support Paths

| Path | What it does | Why it exists |
| --- | --- | --- |
| `tools/ci/` | Contains the `build-workflow-ci` implementation, tests, Dockerfile, and packaging for the planner image. | Reusable workflows run in the caller repo; shipping the planner in a pinned image is how they get stable implementation logic. |
| `.github/workflows/test-ci.yml` | Provider-side self-test for schemas, fixtures, wrapper examples, planner commands, local planner image behavior, and public workflow contract assertions. | Lets `build-workflow` verify the supported contract without pretending that provider CI can fully stand in for a caller repository. |
| `.github/workflows/publish-tool-image.yml` | Publishes immutable planner image refs and updates the mutable `:ci` alias on `main`. | Makes the planner image independently pinnable from the reusable workflow SHA. |
| `test-fixtures/ci/` | Runnable fixture repos for a service image, a base image, a sync wrapper, and release-record samples. | Exercises the supported contract end to end in maintainers' tests and local smoke checks. |

## Recommended Caller Shape

```text
release branch:
  .ci/config.json
  .github/workflows/validate.yml
  .github/workflows/release.yml

main branch:
  .github/workflows/validate-main.yml
  .github/workflows/sync-release-record.yml
  release.json
```

Supported callers should:

- keep wrappers thin
- pin reusable workflows to merged full `build-workflow` commit SHAs
- pin `tool-image` explicitly
- keep sync-wrapper `tool-image` digest-pinned
- treat `ghcr.io/runlix/build-workflow-tools:ci` as maintainer-only, not caller input

## Design Summary

The active design is a planner/executor split:

- planner/tool layer: `build-workflow-ci` in `tools/ci/`
- executor layer: the reusable workflows in `.github/workflows/`

The planner image owns config loading, defaults merging, matrix planning, per-target build planning, manifest planning, release-record rendering and validation, `release.json` writing, and Telegram message rendering.
The workflow layer owns permissions, runner selection, checkout, artifact flow, Docker side effects, and sync PR automation.

This is why provider CI validates the planner and wrapper contracts directly instead of treating provider-side self-calls as proof of caller-context release behavior.

## Pinning Summary

Supported caller `tool-image` inputs are:

- `ghcr.io/runlix/build-workflow-tools@sha256:<digest>`
- `ghcr.io/runlix/build-workflow-tools:sha-<40-char build-workflow git sha>`

The sync wrapper is intentionally stricter than the release-branch wrappers:

- `validate-sync-wrapper.yml` requires the caller sync wrapper to stay digest-pinned

Detailed behavior, exact wrapper rules, planner command outputs, and failure modes live in the focused guides above.
