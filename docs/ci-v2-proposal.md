# CI v2 Proposal

This document describes a clean-slate CI design for Runlix service repositories while keeping the current branch model:

- `main`: metadata and automation config
- `release`: runtime, build, and CI implementation

The prototype files that back this proposal live under [`prototypes/ci-v2/`](../prototypes/ci-v2/README.md).

## Why Change

The current reusable workflow centralizes too many responsibilities in one YAML contract:

- config validation
- matrix expansion
- local PR builds
- release pushes
- manifest creation
- `releases.json` updates
- notifications
- PR comments

That makes the system capable, but hard to read end-to-end.

The v2 design optimizes for these properties:

- workflows should orchestrate, not implement business logic
- one target should equal one build unit
- the release branch should not write to `main`
- metadata sync should be separate from image publishing
- the same commands should work locally and in CI

## Branch Contract

### `release` branch

Authoritative files:

- `.ci/config.json`
- `.ci/smoke-test.sh`
- `linux-amd64.Dockerfile`
- `linux-arm64.Dockerfile`
- `.github/workflows/pr-validation.yml`
- `.github/workflows/release.yml`

Responsibilities:

- validate release inputs
- build images
- run smoke tests
- publish arch-specific images
- create multi-arch manifests
- emit `release-metadata.json`

### `main` branch

Authoritative files:

- `README.md`
- `links.json`
- `releases.json`
- `renovate.json`
- `.github/workflows/sync-release-metadata.yml`

Responsibilities:

- publish metadata derived from successful `release` branch builds
- keep human-facing metadata and automation config separate from runtime changes

## Config Model

The current matrix format requires readers to combine:

- `variants`
- `platforms`
- `dockerfiles`
- `tag_suffix`
- implicit `BASE_*` injection rules

The v2 config replaces that with explicit targets.

Example:

```json
{
  "image": "ghcr.io/runlix/example-service",
  "version": "1.2.3",
  "targets": [
    {
      "name": "stable-amd64",
      "tag": "1.2.3-stable",
      "arch": "amd64",
      "dockerfile": "linux-amd64.Dockerfile",
      "base_ref": "ghcr.io/runlix/distroless-runtime:stable@sha256:...",
      "test": ".ci/smoke-test.sh",
      "build_args": {
        "BUILDER_IMAGE": "docker.io/library/debian",
        "BUILDER_TAG": "bookworm-slim",
        "BUILDER_DIGEST": "sha256:..."
      }
    }
  ]
}
```

Design choices:

- `version` is optional. Service images usually set it; base-image repos such as `distroless-runtime` can omit it.
- `tag` is the final manifest tag. No suffix expansion rules.
- `arch` is explicit. No platform map nested under the same variant.
- `base_ref` is a single pinned base reference. The build script can split it into `BASE_IMAGE`, `BASE_TAG`, and `BASE_DIGEST` if the Dockerfile still expects those args.
- `build_args` contains only service-specific build args.

## Workflow Topology

### PR validation on `release`

`pr-validation.yml` should only:

1. validate `.ci/config.json`
2. render the build matrix
3. build each enabled target
4. run the target smoke test

It should not:

- push images
- update `main`
- comment on PRs by default
- run notification logic

### Release publish on `release`

`release.yml` should only:

1. validate `.ci/config.json`
2. render the build matrix
3. build and push one temp tag per target
4. create multi-arch manifests from those temp tags
5. emit `release-metadata.json`

It should not:

- commit to `main`
- own metadata transforms
- own notification fan-out

### Metadata sync on `main`

`sync-release-metadata.yml` should run on successful completion of the `Release` workflow and:

1. download `release-metadata.json` from the triggering run
2. write `releases.json`
3. commit the metadata change to `main` if needed

This keeps the branch split clean:

- `release` publishes artifacts
- `main` publishes metadata

## Shared Tooling

The proposal keeps shared logic in `build-workflow`, but separates the public and internal layers more clearly.

Public reusable workflows:

- `.github/workflows/pr-validation-v2.yml`
- `.github/workflows/release-v2.yml`
- `.github/workflows/sync-release-metadata-v2.yml`

Internal composite actions:

- `.github/actions/ci-v2/validate-config`
- `.github/actions/ci-v2/plan-matrix`
- `.github/actions/ci-v2/build-target`
- `.github/actions/ci-v2/create-manifests`
- `.github/actions/ci-v2/render-release-metadata`
- `.github/actions/ci-v2/write-releases-json`

Action-local runtime scripts remain packaged under each action directory. Prototype scripts remain available only as thin local wrappers for repo-side inspection.

## What Gets Simpler

Removed from the default critical path:

- PR comments
- Telegram notifications
- GitHub App auth for normal release publishing
- schema download at runtime via `curl`
- pushing to `main` from the `release` workflow itself
- mixing metadata updates with manifest creation

Kept in the critical path:

- pinned inputs
- pinned action SHAs
- explicit target planning
- smoke testing
- manifest publishing
- deterministic metadata generation

## What Lives In `build-workflow`

This repository should carry only shared CI v2 material:

- schema
- reusable workflows
- composite actions
- generic config examples
- design documentation

It should not carry embedded release-branch surfaces for real services. Concrete repo integrations belong in downstream repositories.

## Migration Plan

1. Keep the current reusable workflow as v1.
2. Build the v2 scripts and generic examples in isolation.
3. Run one service through a full release cycle with v2.
4. Compare:
   - readability
   - number of moving parts
   - failure debugging
   - metadata correctness
5. If the first downstream integration is clean, migrate the remaining services one repo at a time.

## Non-Goals

This proposal does not try to preserve backward compatibility with:

- the existing `docker-matrix.json` shape
- current reusable workflow inputs
- current metadata JSON shape
- current PR comment and notification behavior

It is intentionally a simpler replacement, not an in-place extension.
