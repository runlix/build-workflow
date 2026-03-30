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

It runs six jobs:

1. `validate-inputs`
2. `plan`
3. `build-and-push`
4. `publish`
5. `attest`
6. `sync-main`

Workflow concurrency:

- `release-${{ github.repository }}`
- `cancel-in-progress: false`

### `validate-inputs`

This job validates both `tool-image` and optional secret pairing.

It fails fast when:

- `tool-image` is not digest-pinned or an immutable `:sha-<git sha>` tag
- `RUNLIX_APP_ID` is mapped without `RUNLIX_PRIVATE_KEY`
- `RUNLIX_PRIVATE_KEY` is mapped without `RUNLIX_APP_ID`
- `TELEGRAM_BOT_TOKEN` is mapped without `TELEGRAM_CHAT_ID`
- `TELEGRAM_CHAT_ID` is mapped without `TELEGRAM_BOT_TOKEN`

It also exports booleans that decide whether the optional Telegram and GitHub App paths should run later.

### `plan`

`plan` runs inside the pinned planner image.

It:

- checks out the caller repository
- computes `short_sha`
- runs `build-workflow-ci validate-config`
- runs `build-workflow-ci plan-matrix`
- runs `build-workflow-ci plan-manifests`

Outputs include:

- `matrix`
- `manifests`
- `short_sha`
- `image_name`
- `version`

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
- render and validate `release.json`
- optionally notify Telegram

Manifest creation uses `plan-manifests` from the planner image, then runs:

- `docker buildx imagetools create -t ghcr.io/runlix/<name>:<manifest_tag> ...`

for each unique manifest tag.

It resolves each final manifest digest with `docker buildx imagetools inspect` and passes the manifest payload into `build-workflow-ci render-release-json`.

`release.json` is uploaded only when `publish: true` under artifact name:

- `release-json`

When `publish: false`, release mode still:

- validates config
- plans the matrix
- builds and tests targets

But it skips:

- GHCR login
- temporary ref pushes
- manifest creation
- `release.json` rendering and validation
- release artifact upload
- Telegram notification

That means the optional `main` sync path has no metadata payload to use from a `publish: false` release run.

Telegram notification behavior:

- only runs when `publish: true`
- only sends when both Telegram secrets are mapped
- masks both Telegram secrets before use
- is non-blocking because the step uses `continue-on-error: true`

### `attest`

`attest` runs only when `publish: true`.

It requests:

- `attestations: write`
- `contents: read`
- `id-token: write`
- `packages: write`

It runs `actions/attest-build-provenance` once per published manifest digest using the final digest resolved in `publish`.

### `sync-main`

`sync-main` runs only when:

- `publish: true`
- `RUNLIX_APP_ID` and `RUNLIX_PRIVATE_KEY` were both mapped

This job uses a GitHub App token instead of widening the workflow `GITHUB_TOKEN`.

It:

- creates a GitHub App token with `contents: write` and `pull-requests: write`
- checks out `main`
- stages the rendered `release.json` payload on branch `automation/sync-release-json`
- creates or updates the sync PR into `main`
- enables `--auto --merge` with `--match-head-commit`

If no metadata changed:

- no commit is created
- no new PR is opened or updated

If metadata changed:

- the bot force-pushes the sync branch with `--force-with-lease`
- the sync PR title matches the release commit title
- auto-merge is enabled in merge-commit mode

## Main Validation

The supported main-side guard is the caller-managed `validate-main.yml` wrapper shown in `examples/wrappers/validate-main.yml`.

That wrapper:

- stays read-only
- validates only `release.json`
- remains available through `workflow_dispatch` for manual metadata checks

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
- release-json transforms
- wrapper-contract assertions

Real caller-context reusable-workflow behavior is validated downstream in repositories such as `distroless-runtime`.
