# CI Testing and Maintenance

## Source of Truth Order

When supported CI docs drift, check files in this order:

1. `.github/workflows/validate.yml`
2. `.github/workflows/release.yml`
3. `.github/workflows/validate-release-json.yml`
4. `tools/ci/src/build_workflow_ci.py`
5. schemas in `schema/`
6. examples and fixtures
7. docs

Docs should describe those files, not the other way around.

## Provider CI

`Test CI Workflows` is the supported-CI provider contract suite.

It covers:

- schema validation
- example and fixture validation
- unit tests for the planner tool
- direct CLI smoke tests
- local tool image build and smoke tests
- docs navigation and supported contract-name checks
- release-json fixture validation
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
- release-json rendering
- release-json validation
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

`validate-release-json.yml` is the provider-owned contract for:

- `release.json` file existence
- release-json schema validity

Caller-managed `validate-main.yml` should stay thin and compose only that reusable validator.

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
- main-side validator behavior
- optional main-side sync behavior when GitHub App secrets are mapped

That is especially important when changes affect:

- wrapper contracts
- permissions
- release-json shape
- sync PR behavior
- planner-image pins

Prefer publishing canary images to a non-production image name when the downstream repo normally ships stable tags from release automation.

## Documentation Maintenance

When supported CI behavior changes, update:

- `README.md`
- `docs/ci.md`
- the relevant page under `docs/ci/`
- public wrapper examples when the caller contract changed
- fixtures when runnable behavior changed

Keep `v1` docs untouched unless the legacy surface itself changed.
