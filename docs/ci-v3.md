# CI v3

`CI v3` is the supported reusable-workflow contract for new repositories.

## Public Workflows

- `validate-build.yml`
  - validates `.ci/build.json`
  - plans enabled targets
  - builds every enabled target locally
  - runs the effective smoke test when configured
- `publish-release.yml`
  - validates and plans the release build
  - builds and tests each enabled target
  - pushes temporary single-arch tags
  - creates final manifest tags
  - renders and uploads `release.json`
  - attests published manifests
  - optionally opens or updates a `main` sync PR when App credentials are mapped
- `validate-release-metadata.yml`
  - read-only validation of `release.json`

## Caller Contract

On `release`:

- `.ci/build.json`
- `.github/workflows/validate-build.yml`
- `.github/workflows/publish-release.yml`

On `main`:

- `.github/workflows/validate-release-metadata.yml`
- `release.json`

Callers pin only the reusable workflow SHA.
The reusable workflows resolve the matching internal tool image from GitHub's reusable-workflow OIDC `job_workflow_sha` claim.
All caller wrappers grant `id-token: write` so the provider can request that claim and pull the matching immutable tool image.
The `main` metadata wrapper should trigger on `release.json` and its own workflow file so required checks still run when the wrapper changes.

## Build Config

The caller contract file is `.ci/build.json`.

Top-level keys:

- `image`
- optional `version`
- optional `defaults`
- `targets`

`defaults` supports:

- `context`
- `test`
- `build_args`

Each enabled target declares:

- `name`
- `manifest_tag`
- `platform`
- `dockerfile`
- optional `build_args`
- optional `test`
- optional `enabled`

## Release Metadata

`release.json` is the published metadata record committed on `main`.

It contains:

- `image`
- optional `version`
- `sha`
- `short_sha`
- `published_at`
- `manifests[]`

Each manifest entry contains:

- `tag`
- `digest`
- `platforms[]`

## Local Testing

```bash
docker build -f tools/ci/Dockerfile -t build-workflow-tools:test .

docker run --rm -v "$PWD:/workspace" -w /workspace \
  build-workflow-tools:test \
  validate-config test-fixtures/ci/service/.ci/build.json

docker run --rm -v "$PWD:/workspace" -w /workspace \
  build-workflow-tools:test \
  render-release-json test-fixtures/ci/service/.ci/build.json \
  --source-sha 1234567890abcdef1234567890abcdef12345678 \
  --published-at 2026-03-18T00:00:00Z \
  --manifests-path test-fixtures/ci/release-json/manifests.json
```
