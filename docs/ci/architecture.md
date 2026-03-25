# CI Architecture

## Overview

The supported CI interface splits responsibilities between:

- caller repositories, which own repository-specific build inputs
- `runlix/build-workflow`, which owns reusable orchestration and the planner image

Caller repositories provide:

- `.ci/config.json`
- Dockerfiles and `.dockerignore`
- optional smoke-test scripts
- thin wrapper workflows on `release` and `main`
- `release.json` on `main`

`build-workflow` provides:

- reusable workflows in `.github/workflows/`
- the planner image in `tools/ci/`
- schemas in `schema/`
- examples and fixtures
- provider-side contract tests in `.github/workflows/test-ci.yml`

## Provider / Caller Split

The active design is a planner/executor split.

The planner image owns:

- schema validation
- config loading and normalization
- defaults merging
- matrix planning
- per-target build planning
- manifest planning
- release-record rendering and validation
- `release.json` writing
- Telegram message rendering

The reusable workflows own:

- GitHub permissions
- runner selection
- checkout, artifact, and GHCR login flow
- Docker build, push, and manifest side effects
- summary output and gating behavior
- sync PR creation and merge

Why this split exists:

- reusable workflows should stay thin and declarative
- the same planner logic can run locally, in provider CI, and in caller workflows
- callers no longer depend on workflow-time self-checkout of implementation files

## Branch Model

Supported callers use two branch scopes:

- `release` for runtime, build, and CI implementation
- `main` for metadata and automation

The normal layout is:

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

Why this split exists:

- release validation and publishing run from the branch that actually owns Dockerfiles and build inputs
- metadata automation stays isolated on `main`
- `main` PRs can validate wrapper and metadata changes without rebuilding runtime images

## Tool Image Publication

The planner image is published only by `.github/workflows/publish-tool-image.yml`.

Publication modes:

- push to `main` publishes the immutable `:sha-<git sha>` tag and updates the mutable `:ci` alias
- `workflow_dispatch` can publish an immutable `:sha-<git sha>` tag for maintainer testing without changing the `:ci` alias unless the run is on `main`

Supported pin forms:

- `ghcr.io/runlix/build-workflow-tools@sha256:<digest>`
- `ghcr.io/runlix/build-workflow-tools:sha-<40-char build-workflow git sha>`

Unsupported caller input:

- `ghcr.io/runlix/build-workflow-tools:ci`

Why the mutable `:ci` tag exists anyway:

- maintainer convenience for quick manual verification
- easy pointer to the latest published `main` planner image

Callers should still pin an immutable digest or immutable `:sha-<sha>` tag.

## Workflow Families

The supported public workflow surface has two groups.

Release-branch orchestration:

- `validate.yml`
- `release.yml`

Main-branch governance:

- `sync-release-record.yml`
- `validate-sync-wrapper.yml`
- `validate-release-json.yml`

The first group builds and publishes images.
The second group validates and updates metadata safely on `main`.

## Supported Boundaries

The supported interface is intentionally narrow:

- image names must be `ghcr.io/runlix/<name>`
- target platforms must be `linux/amd64` or `linux/arm64`
- callers must pin both the reusable workflow SHA and the planner image
- callers must keep wrappers thin instead of inlining custom job logic into the public wrapper files
- `v1` behavior is not part of the supported CI contract

## Downstream Proof

`build-workflow` provider CI validates:

- schemas
- CLI behavior
- fixtures
- local tool image build
- wrapper-contract fixtures

It does not prove caller-context reusable workflow behavior by self-calling the public workflows.
That proof comes from downstream canaries such as `distroless-runtime`, which exercise the public wrappers in a real caller repository.
