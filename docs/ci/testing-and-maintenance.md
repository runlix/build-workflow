# CI Testing and Maintenance

## Source of Truth Order

When supported CI docs drift, check files in this order:

1. `.github/workflows/validate.yml`
2. `.github/workflows/release.yml`
3. `.github/workflows/sync-release-record.yml`
4. `.github/workflows/validate-sync-wrapper.yml`
5. `.github/workflows/validate-release-json.yml`
6. `tools/ci/src/build_workflow_ci.py`
7. schemas in `schema/`
8. examples and fixtures
9. docs

Docs should describe those files, not the other way around.

## Provider CI

`Test CI Workflows` is the supported-CI provider contract suite.

It covers:

- schema validation
- example and fixture validation
- unit tests for the planner tool
- direct CLI smoke tests
- local tool image build and smoke tests
- sync wrapper fixture validation
- release-record fixture validation
- downstream-like runnable fixture workflows

It also verifies the provider-side tool-image publication contract through:

- local image build
- fixture wrapper checks
- published planner image assumptions used by the CI surface

## Planner Tool Responsibilities

`tools/ci/src/build_workflow_ci.py` owns the supported CI model.

Key behaviors:

- schema-backed config loading
- defaults merging
- effective test resolution
- runner mapping from platform
- PR and release tag planning
- manifest ref planning
- release-record rendering
- release-record validation
- `release.json` writing
- Telegram message rendering

If supported CI behavior changes, check whether the change belongs in:

- planner logic
- reusable workflow orchestration
- or both

## Examples vs Fixtures

`examples/ci/`:

- schema-only examples
- documentation and review aids
- not required to be runnable repositories

`test-fixtures/ci/`:

- runnable miniature caller repositories
- include real Dockerfiles and smoke tests
- used by provider CI and local end-to-end checks

Use fixtures when documenting behavior that depends on effective defaults, smoke tests, or real Docker builds.

## Wrapper Validators

`validate-sync-wrapper.yml` is the provider-owned contract for:

- trigger shape
- wrapper thinness
- permission exactness
- secret mapping
- pinned workflow SHA
- pinned tool-image digest
- required concurrency block

`validate-release-json.yml` is the provider-owned contract for:

- `release.json` file existence
- release-record schema validity

These validators are intended to be composed by a caller-managed `validate-main.yml`.

## Tool Image Publication

`Publish CI Tool Image` is part of the supported CI supply chain.

It publishes:

- immutable `:sha-<build-workflow sha>` tags
- mutable `:ci` alias
- digest refs used by callers

When CI behavior changes in `tools/ci/`, validate:

- provider `test-ci.yml`
- provider `publish-tool-image.yml`
- at least one downstream canary pinned to the new workflow SHA and tool image

## Downstream Canary

Provider CI does not fully prove caller-context reusable workflow execution.

Use a downstream canary such as `distroless-runtime` to validate:

- release-branch PR validation
- release publication
- main-side sync behavior
- main-side validator behavior

That is especially important when changes affect:

- wrapper contracts
- permissions
- artifact names
- sync PR behavior
- planner-image pins

## Documentation Maintenance

When supported CI behavior changes, update:

- `README.md`
- `docs/ci.md`
- the relevant page under `docs/ci/`
- public wrapper examples when the caller contract changed
- fixtures when runnable behavior changed

Keep `v1` docs untouched unless the legacy surface itself changed.
