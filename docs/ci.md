# CI

The supported `build-workflow` interface is the versionless CI contract:

- `.github/workflows/validate.yml`
- `.github/workflows/release.yml`
- `.github/workflows/sync-release-record.yml`

`v1` remains available only for legacy `docker-matrix` callers.

## Branch Model

- `release`: runtime, build, and CI implementation
- `main`: metadata and automation configuration

Caller repositories should keep thin wrappers on those branches and pin them to a merged full commit SHA from `runlix/build-workflow`.

## Design Pattern

The active design is a planner/executor split:

- planner/tool layer: `build-workflow-ci` in `tools/ci/`
- executor layer: the reusable workflows in `.github/workflows/`

The tool layer owns:

- config validation
- build-matrix planning
- per-target build planning
- manifest planning
- release-record rendering
- release-record validation
- `release.json` writing

The workflow layer owns:

- permissions
- runner selection
- checkout and artifact flow
- Docker build, push, and manifest side effects
- summary reporting

This is clearer than the earlier script bootstrap because the reusable workflows no longer try to self-checkout implementation files from `runlix/build-workflow`.

## Config

The caller contract is one explicit file: `.ci/config.json`.

Top-level keys:

- `image`
- optional `version`
- optional `defaults`
- `targets`

`defaults` supports:

- `context`
- `test`
- `build_args`

Each enabled target is one build unit and declares:

- `name`
- `manifest_tag`
- `platform`
- `dockerfile`
- optional `build_args`
- optional `test`

Canonical assets:

- schemas: `schema/ci-config.schema.json`, `schema/release-record.schema.json`
- config examples: `examples/ci/`
- wrapper examples: `examples/wrappers/`
- fixtures: `test-fixtures/ci/`
- contract workflow: `.github/workflows/test-ci.yml`

`image` must be `ghcr.io/runlix/<name>`.

## Pinning

Supported callers should pin the reusable workflow `uses:` reference to a merged full `build-workflow` commit SHA.

The reusable workflows default to `ghcr.io/runlix/build-workflow-tools:ci` for the planner image.
Regular callers should not need to override the tool image or config path.
Reusable workflows do not receive repository secrets automatically. For same-organization or same-enterprise callers, the release wrapper should set `secrets: inherit` so `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are available to `.github/workflows/release.yml`.

## Workflow Behavior

Validate:

1. validates `.ci/config.json`
2. renders the build matrix
3. builds each enabled target locally
4. runs the target test if configured
5. emits the aggregate check `validate / summary`

Release:

1. validates `.ci/config.json`
2. renders the build matrix
3. builds and tests each enabled target
4. pushes one temporary single-arch tag per target
5. creates final manifest tags
6. uploads `release-record.json` as artifact `release-record`
7. sends an optional non-blocking Telegram notification when the caller inherits `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`

Sync:

1. runs from `main` after a successful `Release` workflow on `release`
2. verifies the triggering workflow provenance
3. downloads `release-record.json` from the triggering run
4. writes `release.json`
5. commits only when the metadata changed

## Local Validation

The planner image is also the local validation entrypoint:

```bash
docker run --rm \
  -v "$PWD:/workspace" \
  -w /workspace \
  ghcr.io/runlix/build-workflow-tools:ci \
  validate-config .ci/config.json
```

Additional examples:

```bash
docker run --rm -v "$PWD:/workspace" -w /workspace \
  ghcr.io/runlix/build-workflow-tools:ci \
  plan-matrix .ci/config.json --short-sha 1234567

docker run --rm -v "$PWD:/workspace" -w /workspace \
  ghcr.io/runlix/build-workflow-tools:ci \
  validate-release-record release-record.json
```

## Design Rules

- reusable workflows are the public interface
- `tools/ci/` is the only supported implementation path for the `CI` contract
- no internal composite-action layer in the supported interface
- no legacy `docker-matrix` compatibility in the supported interface
- metadata sync is standardized on `Release`, `release`, `main`, and `release-record`
- callers should rely on the defaults unless they are maintainers validating fixtures or a new tool image
- release notifications are optional and require `secrets: inherit` on the caller release wrapper
- `publish: false` on the release workflow is for contract testing and maintainer dry runs
