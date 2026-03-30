# CI

The supported `build-workflow` interface is the versionless `CI` contract:

- `.github/workflows/validate.yml`
- `.github/workflows/release.yml`
- `.github/workflows/validate-release-json.yml`

`v1` remains available only for legacy `docker-matrix` callers.

## Guide Map

- [Architecture](./ci/architecture.md): provider/caller split, branch model, planner image, and supported boundaries
- [Usage](./ci/usage.md): repo layout, wrapper placement, path semantics, config shape, Dockerfiles, pinning, and common caller cases
- [Workflow Behavior](./ci/workflow-behavior.md): validate, release, attestation, optional main sync, and main-branch validation end to end
- [API Reference](./ci/api-reference.md): reusable workflow inputs, wrapper requirements, config fields, planner command outputs, tag rules, and `release.json` shape
- [Testing and Maintenance](./ci/testing-and-maintenance.md): tool responsibilities, fixture coverage, provider CI, tool-image publication, and downstream canaries
- [Troubleshooting](./ci/troubleshooting.md): common failure modes and what they usually mean

## Surface Map

### Public Caller Surface

| Path | What it does | Why it exists |
| --- | --- | --- |
| `.github/workflows/validate.yml` | Validates `.ci/config.json`, plans enabled targets, builds each enabled target locally, runs optional smoke tests, and emits `validate / summary`. | Catches release-branch build and smoke-test regressions before merge without publishing anything. |
| `.github/workflows/release.yml` | Validates config, builds and tests enabled targets, pushes temporary per-target tags, creates final manifests, renders digest-first `release.json`, attests published manifests, optionally opens a `main` sync PR, and optionally sends Telegram notifications. | Centralizes the full trusted publish path so callers publish images and metadata the same way. |
| `.github/workflows/validate-release-json.yml` | Validates `release.json` using the same planner image used in release mode. | Gives `main` pull requests a read-only metadata validation check. |
| `schema/ci-config.schema.json` | JSON Schema for `.ci/config.json`. | Defines the stable caller config shape. |
| `schema/release-json.schema.json` | JSON Schema for `release.json`. | Keeps committed metadata on an explicit contract. |
| `examples/ci/` | Schema-only config examples. | Shows supported config shape without requiring runnable fixture repos. |
| `examples/wrappers/` | Starter wrappers for validate, release, and `validate-main`. | Gives callers the supported thin-wrapper patterns and pinning model. |

### Maintainer And Support Paths

| Path | What it does | Why it exists |
| --- | --- | --- |
| `tools/ci/` | Contains the `build-workflow-ci` implementation, tests, Dockerfile, and packaging for the planner image. | Reusable workflows run in the caller repo; shipping the planner in a pinned image is how they get stable implementation logic. |
| `.github/workflows/test-ci.yml` | Provider-side self-test for schemas, fixtures, wrapper examples, planner commands, local planner image behavior, docs navigation, and public workflow contract assertions. | Lets `build-workflow` verify the supported contract without pretending that provider CI fully replaces caller-context proof. |
| `.github/workflows/publish-tool-image.yml` | Publishes immutable planner image refs and updates the mutable `:ci` alias on `main`. | Makes the planner image independently pinnable from the reusable workflow SHA. |
| `test-fixtures/ci/` | Runnable fixture repos for a service image, a base image, and `release.json` samples. | Exercises the supported contract end to end in maintainer tests and local smoke checks. |

## Recommended Caller Shape

```text
release branch:
  .ci/config.json
  .github/workflows/validate.yml
  .github/workflows/release.yml

main branch:
  .github/workflows/validate-main.yml
  release.json
```

Supported callers should:

- keep wrappers thin
- pin reusable workflows to merged full `build-workflow` commit SHAs
- pin `tool-image` explicitly
- treat `ghcr.io/runlix/build-workflow-tools:ci` as maintainer-only, not caller input

## Design Summary

The active design is a planner/executor split:

- planner/tool layer: `build-workflow-ci` in `tools/ci/`
- executor layer: the reusable workflows in `.github/workflows/`

The planner image owns config loading, defaults merging, matrix planning, per-target build planning, manifest planning, `release.json` rendering and validation, and Telegram message rendering.
The workflow layer owns permissions, runner selection, checkout, Docker side effects, attestation, summary output, and optional GitHub App PR automation.

This keeps the public interface small and avoids cross-workflow artifact transport as part of the contract.
`release.yml` is the single trusted write path: it publishes images, resolves final manifest digests, renders `release.json`, and optionally opens the sync PR into `main`.

## `release.json`

`release.json` is the metadata record committed on `main`.

Shape:

- `image`
- `version`
- `sha`
- `short_sha`
- `published_at`
- `manifests`

Each `manifests[]` entry declares:

- `tag`
- `digest`
- `platforms`

This is digest-first on purpose. The old tags-only record could tell consumers what names existed, but not what immutable manifest each tag resolved to.

## Pinning And Secrets

Supported callers should pin the reusable workflow `uses:` reference to a merged full `build-workflow` commit SHA.

Supported callers should also pass `tool-image`, pinned to `ghcr.io/runlix/build-workflow-tools@sha256:<digest>`.
Maintainers may also pin to `ghcr.io/runlix/build-workflow-tools:sha-<build-workflow git sha>` when that tag was produced by the standalone publish workflow on `main` or by explicit maintainer publication.
The mutable `ghcr.io/runlix/build-workflow-tools:ci` alias tracks the latest published `main` planner image for maintainer convenience only and is not a supported caller input.

Reusable workflows do not receive repository secrets automatically.

Release callers may map:

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `RUNLIX_APP_ID`
- `RUNLIX_PRIVATE_KEY`

Telegram secrets are optional and only enable notifications.
GitHub App secrets are optional and only enable the `main` sync PR path.
If one secret of a pair is mapped without the other, `release.yml` fails fast.

Release callers must also grant:

- `contents: read`
- `packages: write`
- `attestations: write`
- `id-token: write`

Main-side validation callers should keep `validate-main.yml` read-only and validate only `release.json`.

## Workflow Behavior

Validate:

1. validates `.ci/config.json`
2. renders the build matrix
3. builds each enabled target locally
4. runs the target test if configured
5. emits the aggregate check `validate / summary`

Release:

1. validates `.ci/config.json`
2. renders the build matrix and manifest plan
3. builds and tests each enabled target
4. pushes one temporary single-arch tag per target
5. creates final manifest tags
6. resolves final manifest digests
7. renders and validates `release.json`
8. attests each published manifest digest
9. creates or updates a bot-authored PR into `main` when GitHub App credentials are mapped
10. sends an optional non-blocking Telegram notification when Telegram secrets are mapped

`publish: false` is a maintainer dry-run mode:

- target builds and tests still run
- no images are pushed
- no manifests are created
- no attestations are written
- no `release.json` is rendered
- no `main` sync or Telegram notification runs

Validate Release JSON:

1. runs from a caller-managed workflow on `main`
2. validates `release.json` with the pinned planner image
3. stays read-only and secret-free

## Local Validation

The planner image is also the local validation entrypoint:

```bash
docker run --rm \
  -v "$PWD:/workspace" \
  -w /workspace \
  ghcr.io/runlix/build-workflow-tools@sha256:YOUR_TOOL_IMAGE_DIGEST \
  validate-config .ci/config.json
```

Additional examples:

```bash
docker run --rm -v "$PWD:/workspace" -w /workspace \
  ghcr.io/runlix/build-workflow-tools@sha256:YOUR_TOOL_IMAGE_DIGEST \
  plan-matrix .ci/config.json --short-sha 1234567

docker run --rm -v "$PWD:/workspace" -w /workspace \
  ghcr.io/runlix/build-workflow-tools@sha256:YOUR_TOOL_IMAGE_DIGEST \
  render-release-json .ci/config.json \
  --source-sha 1234567890abcdef1234567890abcdef12345678 \
  --published-at 2026-03-17T12:00:00Z \
  --manifests-path test-fixtures/ci/release-json/manifests.json

docker run --rm -v "$PWD:/workspace" -w /workspace \
  ghcr.io/runlix/build-workflow-tools@sha256:YOUR_TOOL_IMAGE_DIGEST \
  validate-release-json release.json
```

## Design Rules

- reusable workflows are the public interface
- `tools/ci/` is the only supported implementation path for the `CI` contract
- no internal composite-action layer in the supported interface
- no legacy `docker-matrix` compatibility in the supported interface
- metadata sync is standardized on `release.yml` writing `release.json` into `main` through a bot-authored PR
- callers should pin both the workflow SHA and the planner image reference explicitly
- release notifications are optional and should map only the Telegram secrets needed by the release wrapper
- `publish: false` on the release workflow is for contract testing and maintainer dry runs
