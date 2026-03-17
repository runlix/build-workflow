# CI v2 Prototype

This directory contains the implementation assets for a simpler CI design.

It is intentionally not wired into the current reusable workflow. The goal is to make the proposed v2 easy to inspect without changing production behavior.

## Layout

- `schema/`: draft schema for `.ci/config.json`
- `scripts/`: local wrappers around the canonical action-local runtime scripts for repo-side validation and inspection
- `.github/actions/ci-v2/`: reusable composite actions with self-contained runtime entrypoints for downstream repositories
- `examples/`: generic config examples for versioned services and versionless base-image repos

The files in `examples/` illustrate config shape only. They are not self-contained checkouts and are not intended to pass the repo-aware validator without matching Dockerfiles and test scripts.

## Design Rules

- workflow YAML only orchestrates jobs
- build logic lives in scripts
- one target equals one build unit
- `release` emits release metadata
- `main` consumes release metadata and writes `releases.json`

## Prototype Scope

The v2 implementation covers:

- config validation
- matrix planning
- build and push command construction
- manifest creation
- release metadata generation
- `main` branch metadata sync

The v2 implementation does not include:

- PR comments
- Telegram notifications
- dependency caching
- vulnerability scanning

Those can be layered on later as separate, optional workflows.

## Intentional Omission

This implementation does not embed a real service repository surface anymore.

`build-workflow` should keep shared tooling and generic examples only. Real release-branch Dockerfiles, smoke tests, and repo-specific workflows belong in downstream repositories such as `distroless-runtime`.

## Consumption

Downstream repositories should consume the exported reusable workflows directly from `build-workflow`, pinned to a full commit SHA.

Example:

```yaml
jobs:
  pr-validation:
    uses: runlix/build-workflow/.github/workflows/pr-validation-v2.yml@<full-sha>
    with:
      tooling-ref: <full-sha>
      config-path: .ci/config.json
```

The low-level composite actions remain in this repository, but they are an internal implementation detail of the reusable workflows rather than the primary downstream interface.
