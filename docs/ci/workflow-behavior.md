# CI Workflow Behavior

## Validate

The supported branch-check path is `.github/workflows/validate.yml`.

It runs four jobs:

1. `validate-inputs`
2. `plan`
3. `build`
4. `summary`

Workflow concurrency:

- `validate-${{ github.repository }}-${{ github.ref }}-${{ inputs.config-path }}`
- `cancel-in-progress: true`

### `validate-inputs`

This job validates `tool-image`.

Accepted forms:

- `ghcr.io/runlix/build-workflow-tools@sha256:<64-hex digest>`
- `ghcr.io/runlix/build-workflow-tools:sha-<40-char git sha>`

Why it exists:

- keeps invalid or mutable image refs out of the public contract
- lets later jobs reuse the normalized tool-image value

### `plan`

`plan` runs inside the pinned planner image.

It:

- checks out the caller repository
- computes `short_sha`
- runs `build-workflow-ci validate-config`
- runs `build-workflow-ci plan-matrix`

Outputs include:

- `matrix`
- `short_sha`
- `image_name`
- `version`
- `enabled_count`
- `manifest_tags`

### `build`

`build` runs once per planned target on the correct GitHub runner.

For each target it:

- checks out the caller repository
- sets up Docker Buildx
- runs `plan-build-target` in the planner image
- builds with `docker buildx build --load`
- runs the effective target test when configured

The local PR tag is:

- `ghcr.io/runlix/<name>:pr-<short_sha>-<target_name>`

No registry push happens in validate mode.

### `summary`

`summary` writes a `GITHUB_STEP_SUMMARY` and fails if planning or any target build/test failed.

When the caller wrapper job is named `validate`, the user-facing required check becomes:

- `validate / summary`

## Release

The release path is `.github/workflows/release.yml`.

It runs four jobs:

1. `validate-inputs`
2. `plan`
3. `build-and-push`
4. `publish`

Workflow concurrency:

- `release-${{ github.repository }}`
- `cancel-in-progress: false`

The first two jobs mirror validate mode.

### `build-and-push`

This job requests:

- `contents: read`
- `packages: write`

It:

- checks out the caller repository
- logs in to GHCR when `publish: true`
- sets up Docker Buildx
- plans the target with `plan-build-target --mode release`
- builds the image locally
- runs the target test when configured
- pushes the temporary per-arch ref when `publish: true`

The temporary release tag is:

- `<manifest_tag>-<arch>-<short_sha>`

Examples:

- `1.2.3-stable-amd64-abc1234`
- `stable-arm64-abc1234`

Why temporary tags exist:

- they make manifest assembly deterministic
- they avoid collisions between rapid releases
- they keep final user-facing tags stable

### `publish`

`publish` owns three responsibilities:

- create manifests
- render and validate `release-record.json`
- optionally notify Telegram

Manifest creation uses `plan-manifests` from the planner image, then runs:

- `docker buildx imagetools create -t ghcr.io/runlix/<name>:<manifest_tag> ...`

for each unique manifest tag.

`release-record.json` always gets rendered and validated.
It is uploaded only when `publish: true` under artifact name:

- `release-record`

When `publish: false`, release mode still:

- validates config
- plans the matrix
- builds and tests targets
- renders and validates `release-record.json`

But it skips:

- GHCR login
- temporary ref pushes
- manifest creation
- release-record artifact upload
- Telegram notification

That means a normal sync run has no artifact to consume from a `publish: false` release run.

Telegram notification behavior:

- only runs when `publish: true`
- only sends when both Telegram secrets are mapped
- masks both Telegram secrets before use
- is non-blocking because the step uses `continue-on-error: true`

## Sync Release Record

The supported metadata sync path is `.github/workflows/sync-release-record.yml`, called from a caller wrapper triggered by `workflow_run`.

It runs two jobs:

1. `render-release-json`
2. `commit-release-json`

### `render-release-json`

This job runs inside the pinned planner image and requests only:

- `actions: read`

It:

- verifies the triggering workflow is `Release`
- verifies the triggering branch is `release`
- verifies the triggering repository matches the current repository
- downloads artifact `release-record` from the triggering run
- validates `release-record.json`
- verifies `.sha` matches `github.event.workflow_run.head_sha`
- writes `release.json`
- validates `release.json`
- uploads normalized artifact `normalized-release-json`

Why the SHA match exists:

- the artifact must belong to the exact release commit that triggered sync

This job only runs when:

- `github.event.workflow_run.conclusion == 'success'`

### `commit-release-json`

This job uses a GitHub App token instead of widening the workflow `GITHUB_TOKEN`.

It:

- creates a GitHub App token with `contents: write` and `pull-requests: write`
- checks out `main`
- downloads the normalized `release.json`
- stages the change on branch `automation/sync-release-record`
- closes a stale open sync PR if `release.json` already matches `main`
- creates or updates the sync PR into `main`
- enables `--auto --merge` with `--match-head-commit`

If no metadata changed:

- no commit is created
- any stale open sync PR is closed

If metadata changed:

- the bot force-pushes the sync branch with `--force-with-lease`
- the sync PR title matches the release commit title
- auto-merge is enabled in merge-commit mode

## Main Validation

The supported main-side guard is the caller-managed `validate-main.yml` wrapper shown in `examples/wrappers/validate-main.yml`.

That wrapper:

- detects whether `release.json` changed
- detects whether `.github/workflows/sync-release-record.yml` changed
- runs `validate-release-json.yml` when needed
- runs `validate-sync-wrapper.yml` when needed
- exposes `validate-main-summary`
- forces both validators on during `workflow_dispatch`

### `validate-sync-wrapper.yml`

This reusable validator is read-only and secret-free.

It enforces:

- `workflow_run -> Release / release / completed`
- exact top-level permissions: `actions: read`, `contents: read`
- thin-wrapper shape
- no `workflow_dispatch`
- no `pull_request` or `pull_request_target`
- no `actions/checkout`
- no `secrets: inherit`
- pinned reusable workflow SHA
- pinned digest `tool-image`
- explicit `RUNLIX_APP_ID` and `RUNLIX_PRIVATE_KEY` mapping
- required concurrency group with `cancel-in-progress: false`

### `validate-release-json.yml`

This reusable validator is also read-only.

It:

- checks out the caller repository
- validates `release.json` using the pinned planner image

## Provider-Side CI

`build-workflow` itself does not use its own reusable validate/release workflows as a substitute for real caller proof.

Provider CI focuses on:

- planner image behavior
- schemas
- examples and fixtures
- release-record transforms
- wrapper-contract fixtures

Real caller-context reusable-workflow behavior is validated downstream in repositories such as `distroless-runtime`.
