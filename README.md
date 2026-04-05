# Build Workflow

`build-workflow` exposes one supported interface: `CI v3`.

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

Callers pin two immutable refs from `runlix/build-workflow`:

- the reusable workflow SHA
- the matching tool image tag `ghcr.io/runlix/build-workflow-tools:sha-<same workflow sha>`

Supported caller pins come from merged commits on `build-workflow` `main`.
There is no separate supported provider `release` branch.
Merged commits on `main` automatically publish the matching exact-commit tool image tag.

For side-branch validation of downstream callers, publish the exact commit tool image first.
Until `ghcr.io/runlix/build-workflow-tools:sha-<that branch sha>` exists, caller workflows pinned to that branch SHA will fail to pull `tool-image`.

If you want automated `main` sync on protected branches, map `RUNLIX_APP_ID` and `RUNLIX_PRIVATE_KEY` into the publish wrapper.
If you want Telegram release notifications, map `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` into the publish wrapper.
Telegram delivery is optional and best-effort after the release cycle completes successfully.
Only the publish wrapper needs `id-token: write` because attestation runs inside the provider publish workflow.
The publish wrapper must also grant `contents: read`, `packages: write`, and `attestations: write`.

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
- pure config validation and `release.json` rendering run inside the immutable tool image pinned alongside the reusable workflow SHA

This keeps callers simple while avoiding workflow-time self-checkout of implementation files from the provider repository.
