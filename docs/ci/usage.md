# CI Usage

## Start from the Public Examples

Use these files together:

- `examples/ci/base-image-config.json`
- `examples/ci/service-config.json`
- `examples/wrappers/validate.yml`
- `examples/wrappers/release.yml`
- `examples/wrappers/validate-main.yml`

Use `examples/ci/` for schema shape and review.
Use `test-fixtures/ci/` when you need runnable examples with real Dockerfiles and smoke tests.

## Wrapper Placement

On `release`:

- `validate.yml`
- `release.yml`

On `main`:

- `validate-main.yml`
- `release.json`

Keep the wrappers thin:

- define the trigger
- define path filters
- define minimal permissions
- call one pinned reusable workflow

## Wrapper Pinning

Every wrapper should pin:

- the reusable workflow by merged full `build-workflow` commit SHA
- `tool-image` by immutable digest

Maintainer exception:

- `ghcr.io/runlix/build-workflow-tools:sha-<40-char build-workflow git sha>` is acceptable for branch testing when that tag was published intentionally

Do not use:

- branch refs
- preview tags
- the mutable `ghcr.io/runlix/build-workflow-tools:ci` tag

## Path Filters

The release-branch examples treat these as build inputs:

- `.ci/config.json`
- `.ci/*.sh`
- `.dockerignore`
- `linux-*.Dockerfile`
- the release-branch wrapper files

Why:

- config changes alter the matrix
- smoke-test changes alter validation behavior
- `.dockerignore` changes the build context
- Dockerfile changes alter the image
- wrapper changes alter permissions, workflow SHAs, or planner image pins

The minimal supported `validate-main.yml` example watches:

- `release.json`

and exposes `workflow_dispatch` for wrapper-only or manual validation runs.
If a caller also wants wrapper edits to auto-run the check, it can add `.github/workflows/validate-main.yml` to the wrapper's own top-level `paths` list without changing the reusable workflow contract.

## `.ci/config.json`

The supported config has four top-level concepts:

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

Defaults behavior:

- `defaults.context` becomes the build context for every target unless the whole config changes
- `defaults.test` becomes the effective test when the target omits `test`
- `defaults.build_args` are merged first, then target `build_args` override or extend them

## Path Semantics

Caller paths are interpreted from the checked-out repository root.

That applies to:

- `config-path`
- `defaults.context`
- target `dockerfile`
- effective `test`
- `release-json-path`

The planner does not reinterpret those values relative to the config file directory.
Write each path exactly the way the caller repository root should address it after checkout.

## Base Image vs Service Repositories

Base-image repositories usually:

- omit `version`
- publish tags such as `stable` and `debug`
- pass immutable upstream refs such as `BASE_REF`

Service repositories usually:

- set `version`
- publish tags such as `1.2.3-stable`
- keep shared app args in `defaults.build_args`
- override only the target-specific immutable ref or variant args per target

## Dockerfiles

The supported CI contract does not require the older `BASE_IMAGE` / `BASE_TAG` / `BASE_DIGEST` split.

Instead, callers should consume full immutable refs directly through build args such as:

- `BASE_REF`
- `BUILDER_REF`

Typical pattern:

```dockerfile
ARG BASE_REF
FROM ${BASE_REF}
```

Why this pattern is preferred in the supported CI path:

- the full immutable ref stays intact
- callers control the exact build arg names they want
- the planner image only merges and forwards build args instead of rewriting Dockerfile semantics

## Smoke Tests

Smoke tests are optional.

When a target has an effective test, the workflow:

- builds and loads the image locally
- exports `IMAGE_TAG`
- exports `PLATFORM`
- executes the script path from config

The smoke test owns the runtime assertions.
Common checks include:

- image labels
- exposed ports
- files copied into the image
- simple container create / inspect behavior

## Secret Mapping

Release wrapper:

- optionally map `TELEGRAM_BOT_TOKEN`
- optionally map `TELEGRAM_CHAT_ID`
- optionally map `RUNLIX_APP_ID`
- optionally map `RUNLIX_PRIVATE_KEY`

Main validator:

- no secrets required

Avoid `secrets: inherit` in supported wrappers.

## `publish: false`

`release.yml` accepts `publish: false` for:

- provider contract tests
- maintainer dry runs

That mode still validates config, plans the matrix, builds targets, and runs smoke tests.

It skips:

- GHCR login
- pushing temporary refs
- manifest creation
- `release.json` rendering and validation
- attestation
- optional `main` sync
- Telegram notification

## Main-Branch Validation

Callers should add `validate-main.yml` on `main`.

That wrapper should:

- stay read-only
- call `validate-release-json.yml`
- validate only `release.json`
- remain available through `workflow_dispatch` for manual validation

The example wrapper is intentionally thin.
Callers should make the wrapper job's status check the required check for `release.json` updates on `main`.
