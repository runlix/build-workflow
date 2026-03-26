# CI

The supported `build-workflow` interface is the versionless CI contract:

- `.github/workflows/pr-validation.yml`
- `.github/workflows/release.yml`
- `.github/workflows/sync-release-metadata.yml`

`v1` remains available only for legacy `docker-matrix` callers. New repositories should use this CI contract.

## Surface Map

These paths define the supported interface and its implementation:

| Path | Role | Why it exists |
| --- | --- | --- |
| `.github/workflows/pr-validation.yml` | Reusable PR validation workflow | Builds every enabled target locally and runs target tests before merge |
| `.github/workflows/release.yml` | Reusable release workflow | Builds, tests, publishes per-arch images, creates manifests, and emits release metadata |
| `.github/workflows/sync-release-metadata.yml` | Reusable metadata sync workflow | Updates `releases.json` on `main` only after a successful release run |
| `schema/ci-config.schema.json` | Caller config schema | Defines the supported `.ci/config.json` contract |
| `schema/release-metadata.schema.json` | Artifact schema | Defines `release-metadata.json` uploaded by the release workflow |
| `schema/releases.schema.json` | Metadata branch schema | Defines the committed `releases.json` shape on `main` |
| `scripts/ci/validate-config.sh` | Config validator | Enforces rules that are awkward or clearer in shell than JSON Schema alone |
| `scripts/ci/plan-matrix.sh` | Matrix renderer | Expands enabled targets into job-ready matrix entries |
| `scripts/ci/build-target.sh` | Build helper | Normalizes Docker build args, OCI labels, and tag naming for PR and release modes |
| `scripts/ci/create-manifests.sh` | Manifest publisher | Turns pushed per-arch release tags into final multi-arch manifest tags |
| `scripts/ci/render-release-metadata.sh` | Artifact renderer | Produces the release record consumed by metadata sync |
| `scripts/ci/write-releases-json.sh` | Metadata writer | Converts the artifact into the committed `releases.json` snapshot |
| `scripts/ci/validate-release-record.sh` | Metadata validator | Validates both the uploaded artifact and the committed `releases.json` |
| `examples/pr-validation.yml` | Caller wrapper example | Shows the expected trigger and path filters for `release` |
| `examples/release.yml` | Caller wrapper example | Shows the expected release wrapper and permissions |
| `examples/sync-release-metadata.yml` | Caller wrapper example | Shows the expected `workflow_run` wrapper on `main` |
| `examples/ci/*.json` | Config examples | Minimal service and base-image examples for new callers |
| `.github/workflows/test-ci.yml` | Contract test workflow | Verifies schema, examples, fixtures, PR validation, release dry-run, and metadata transform behavior |
| `test-fixtures/ci/` | Fixture caller repositories | Exercise the supported interface in realistic service and base-image layouts |

## Branch Model

The supported contract assumes a two-branch caller layout:

- `release`: runtime, build, and CI implementation
- `main`: metadata and automation configuration

This split is intentional:

- release changes build and publish images from the branch that owns Dockerfiles and `.ci/config.json`
- metadata updates land on `main` only after a successful `Release` run
- branch ownership stays clear: runtime files live on `release`, generated release metadata lives on `main`
- the sync workflow can keep `contents: write` scoped to the metadata branch instead of the release workflow

Caller repositories should keep thin wrappers on those branches and pin them to a merged full commit SHA from `runlix/build-workflow`.

## Caller Wrapper Files

Recommended wrapper layout:

```text
release branch:
  .ci/config.json
  .ci/*.sh
  linux-*.Dockerfile
  .github/workflows/pr-validation.yml
  .github/workflows/release.yml

main branch:
  .github/workflows/sync-release-metadata.yml
  releases.json
```

The example wrappers include these path filters:

- `.ci/config.json`: the build contract changed
- `.ci/*.sh`: target smoke tests or helper scripts changed
- `.dockerignore`: Docker build context changed
- `linux-*.Dockerfile`: image implementation changed
- wrapper workflow files: the caller entrypoint changed

If a caller uses additional build inputs outside those paths, its wrapper should add matching path filters.

## Workflow Inputs And Path Resolution

The reusable workflows intentionally expose a small input surface:

| Workflow | Input | Default | Meaning |
| --- | --- | --- | --- |
| PR validation | `config-path` | `.ci/config.json` | Path to the caller config file |
| PR validation | `context-dir` | `.` | Docker build context path in the caller repository |
| Release | `config-path` | `.ci/config.json` | Path to the caller config file |
| Release | `context-dir` | `.` | Docker build context path in the caller repository |
| Release | `publish` | `true` | Whether to push tags, create manifests, and upload release metadata |

Path handling is important:

- `config-path`, each target `dockerfile`, and each target `test` path are resolved from the caller repository root because the workflow checks out the caller repo and runs the helper scripts from that root
- `context-dir` only changes the Docker build context passed to `docker buildx build`; it does not remap `dockerfile` or `test` paths
- the workflow repository is checked out separately into `.build-workflow` so the YAML uses the exact helper scripts from `github.workflow_sha`

Checking out `.build-workflow` at `github.workflow_sha` is deliberate. It prevents a caller pinned to one reusable-workflow commit from accidentally executing helper scripts from a different branch tip.

## Permissions And Concurrency

The supported CI contract keeps permissions and concurrency narrow on purpose.

Wrapper-level permissions:

- PR validation wrapper: `contents: read`
- Release wrapper: `contents: read`, `packages: write`
- Metadata sync wrapper: `actions: read`, `contents: write`

Reusable-job permissions:

- `plan` and `summary` stay read-only
- `build` stays read-only because PR validation never pushes images
- `build-and-push` adds `packages: write` only for GHCR login and `docker push`
- `sync` adds `actions: read` to download the upstream artifact and `contents: write` to commit `releases.json`

Concurrency behavior:

- PR validation uses `pr-validation-${repository}-${ref}-${config-path}` with `cancel-in-progress: true`
- release uses `release-${repository}` with `cancel-in-progress: false`

Why it is implemented this way:

- PR reruns for the same branch/config replace older validation runs instead of consuming extra runners
- release runs are serialized per repository so two publishes cannot race while creating manifests or updating metadata
- permission scope stays aligned with the exact job that needs it rather than granting broad repository access everywhere

## Config Contract

The caller contract is one explicit file: `.ci/config.json`.

The schema is `schema/ci-config.schema.json`. The shell validator in `scripts/ci/validate-config.sh` adds the runtime checks that JSON Schema does not cover cleanly.

Top-level fields:

| Field | Required | Meaning |
| --- | --- | --- |
| `image` | yes | Final published image name. Must match `ghcr.io/runlix/<name>` |
| `version` | no | Human-facing version string used for metadata and OCI labels |
| `targets` | yes | Build units expanded into the matrix |

Per-target fields:

| Field | Required | Meaning |
| --- | --- | --- |
| `name` | yes | Stable target identifier used in the matrix and PR-local tag |
| `tag` | yes | Final manifest tag created during release |
| `arch` | yes | `amd64` or `arm64` |
| `dockerfile` | yes | Dockerfile path in the caller repository |
| `base_ref` | yes | Pinned base image reference in `image:tag@sha256:<digest>` form |
| `test` | no | Executable test script path in the caller repository |
| `enabled` | no | Defaults to `true`; disabled targets are ignored by planning and builds |
| `build_args` | no | Extra Docker build args. Keys must look like shell env var names |

## Validation Rules And Edge Cases

`validate-config.sh` enforces these rules:

- `.ci/config.json` must exist and be valid JSON
- `image` must stay inside `ghcr.io/runlix/...`; registry and namespace overrides are intentionally not part of the supported contract
- `targets` must exist and at least one target must be enabled
- target names must be unique across all targets, including disabled ones
- enabled `tag` and `arch` pairs must be unique
- reusing the same `tag` across different architectures is valid and is how callers request a multi-arch manifest
- `dockerfile` and `test` path existence is checked only for enabled targets
- `base_ref` must include both a tag and a digest; floating digests or digest-only references are rejected
- `build_args` values must be strings and keys must match `^[A-Z_][A-Z0-9_]*$`
- additional undeclared JSON properties are rejected by schema

Important behavior to account for:

- disabled targets are ignored by matrix planning, builds, manifest creation, and release metadata tag collection
- if `version` is omitted, the workflow still works; the OCI version label is skipped and the metadata record stores `version: null`
- `tag` is explicit and not derived from `version`; callers can publish versioned or non-versioned tags as long as they declare them directly

## Data Flow Between Jobs

The supported workflows pass a small set of outputs and artifacts:

| Producer | Output or artifact | Consumer | Purpose |
| --- | --- | --- | --- |
| `validate-config.sh` | `image_name`, `version`, `enabled_count`, `manifest_tags` | plan job outputs and summary rendering | Human-readable context for later jobs |
| `plan-matrix.sh` | `matrix` JSON | `build` and `build-and-push` strategies | Expands enabled targets into concrete jobs |
| `build-target.sh` | `image_tag`, `platform` | target test step and release push step | Exposes the exact image reference built in that job |
| `render-release-metadata.sh` | `release-metadata.json` | artifact upload and metadata sync workflow | Carries the release record across branches |
| `write-releases-json.sh` | `releases.json` | commit step on `main` | Publishes the current release snapshot for the caller repo |

Each matrix row from `plan-matrix.sh` currently includes:

- `name`, `image`, `version`, `tag`, `arch`
- `platform` and `runner`
- `dockerfile`, `base_ref`, `test`, and `build_args`
- `pr_local_tag` and `release_temp_tag`

The reusable workflows currently consume `name`, `runner`, `test`, and the path/build fields directly. The tag preview fields are still part of the rendered matrix output, which makes planned PR and release tag names inspectable when running the helper script directly.

## PR Validation Flow

`examples/pr-validation.yml` is the expected caller wrapper for the `release` branch.

End-to-end behavior:

1. The caller wrapper triggers on `pull_request` to `release`.
2. The reusable workflow checks out the caller repository.
3. It resolves `github.workflow_ref` and `github.workflow_sha`, then checks out the workflow repository into `.build-workflow`.
4. `validate-config.sh` validates `.ci/config.json` and emits summary metadata.
5. `plan-matrix.sh` expands enabled targets into the job matrix.
6. One `build` job runs per enabled target on the architecture-specific runner:
   - `amd64` targets run on `ubuntu-24.04`
   - `arm64` targets run on `ubuntu-24.04-arm`
7. `build-target.sh` builds a local image tag in PR mode:
   - `ghcr.io/runlix/<name>:pr-<short_sha>-<target-name>`
8. If `test` is configured, the workflow exports `IMAGE_TAG`, `PLATFORM`, and `TEST_SCRIPT`, marks the script executable, and runs it.
9. The `summary` job always runs and fails if either planning or any target build/test failed.

Why it is implemented this way:

- planning is split from building so the reusable workflow can fail fast on config errors before scheduling matrix jobs
- PR builds stay local and never log in to GHCR, which keeps validation safer and cheaper
- the always-running summary job gives callers one stable aggregate check instead of requiring branch protection on every matrix child job

The required branch-protection check in the thin caller wrapper is `validate / summary` because the wrapper job is named `validate` and the reusable workflow job is named `summary`.

## Release Flow

`examples/release.yml` is the expected caller wrapper for the `release` branch.

End-to-end behavior:

1. The caller wrapper triggers on pushes to `release`.
2. The `plan` job repeats the same validation and matrix planning used in PR validation.
3. Each `build-and-push` matrix job:
   - checks out the caller repo and pinned workflow repo
   - logs in to GHCR when `publish: true`
   - sets up Buildx
   - builds one enabled target in release mode
   - runs the target test when configured
   - pushes the single-arch release tag when `publish: true`
4. Release-mode tags are temporary per-arch tags:
   - `ghcr.io/runlix/<name>:<manifest_tag>-<arch>-<short_sha>`
5. The `publish` job then:
   - creates final manifest tags by grouping enabled targets on `tag`
   - renders `release-metadata.json`
   - validates the metadata record
   - uploads the artifact as `release-metadata` when `publish: true`

Why it is implemented this way:

- each matrix job pushes a single-arch image independently, which makes parallel builds simple and avoids manifest coordination during the build phase
- final manifests are created only after all per-arch images exist
- release metadata is separated into an artifact instead of being committed directly so the `main` branch update can be gated by a second workflow with different permissions and provenance checks

`publish: false` is a dry-run mode for contract tests and maintainer checks:

- builds and tests still run
- `release-metadata.json` is still rendered and validated
- GHCR login, manifest creation, image pushes, and artifact upload are skipped

## Tagging, Build Args, And OCI Labels

`build-target.sh` normalizes the build inputs used by every target.

### Base Image Expansion

Each target `base_ref` is split into:

- `BASE_IMAGE`
- `BASE_TAG`
- `BASE_DIGEST`

The Dockerfiles in caller repositories are expected to consume those build args. This keeps Dockerfiles generic while still requiring a fully pinned base image for reproducibility.

### Custom Build Args

Every `build_args` entry is passed through as `--build-arg KEY=value`.

Because the schema and validator require string values, callers must stringify ports, versions, booleans, or numeric flags before putting them in JSON.

### OCI Labels

Each built image receives:

- `org.opencontainers.image.created`
- `org.opencontainers.image.revision`
- `org.opencontainers.image.source`
- `org.opencontainers.image.version` when `version` is set

The CI fixtures assert these labels so the contract does not drift silently.

## Manifest Creation Rules

`create-manifests.sh` groups enabled targets by `tag`.

That means:

- two enabled targets with the same `tag` and different `arch` values become one final multi-arch manifest
- a single enabled target for one `tag` still produces a final manifest tag that points at one platform image
- if no platform tags are found for an enabled manifest tag, manifest creation fails immediately

The final published manifest tag is always exactly the configured `tag`. The architecture suffix and short SHA exist only on the temporary release tags.

## Release Metadata And Sync Flow

`render-release-metadata.sh` writes this shape:

```json
{
  "version": "1.2.3",
  "sha": "1234567890abcdef1234567890abcdef12345678",
  "short_sha": "1234567",
  "published_at": "2026-03-17T12:00:00Z",
  "tags": ["1.2.3-debug", "1.2.3-stable"]
}
```

`published_at` is generated in UTC by the release workflow at publish time, not read from the caller config.

`sync-release-metadata.yml` is the expected caller wrapper on `main`.

End-to-end behavior:

1. The wrapper triggers from `workflow_run` for the caller workflow named `Release`.
2. The reusable sync workflow exits unless the upstream run concluded with `success`.
3. It verifies:
   - triggering workflow name is exactly `Release`
   - triggering branch is exactly `release`
   - triggering repository matches the current repository
4. It checks out `main`.
5. It checks out the pinned workflow repo into `.build-workflow`.
6. It downloads artifact `release-metadata` from the triggering run ID into `artifacts/`.
7. It validates `artifacts/release-metadata.json`.
8. It verifies the metadata `sha` equals `github.event.workflow_run.head_sha`.
9. It writes `releases.json`, validates it again, and commits only when the file changed.

Why it is implemented this way:

- the provenance checks stop unrelated workflow runs, branches, or repositories from feeding metadata into `main`
- validating both the artifact and the committed `releases.json` keeps the artifact contract and the metadata-branch contract identical
- committing only on diff avoids empty metadata commits on repeated or no-op releases

The committed `releases.json` is a current-release snapshot for that caller repository, not a historical ledger.
If `releases.json` does not exist yet on `main`, the sync workflow creates it on the first successful metadata sync.
When `version` is present, the commit message is `Release: <service> <version> @ <short_sha>`. When `version` is omitted, the commit falls back to `Release: <service> @ <short_sha>`.

## Tests And Fixtures

`.github/workflows/test-ci.yml` is the contract test for the supported interface. It verifies:

- all three CI schemas compile
- example configs and fixture configs validate
- `release-metadata.json` and `releases.json` share the same record shape
- the sync workflow still contains the expected provenance guards
- both fixture repositories pass PR validation
- the service fixture passes a release dry-run
- synthetic metadata artifacts round-trip through `write-releases-json.sh`

Fixture coverage:

- `test-fixtures/ci/base-image/`: versionless base-image publishing path
- `test-fixtures/ci/service/`: versioned service-image publishing path
- `test-fixtures/ci/release-metadata/`: metadata transform contract

The fixtures are intentionally small but they exercise the important branches:

- versioned service config and versionless base-image config
- target-level smoke tests
- per-target `build_args`
- release dry-run behavior with `publish: false`
- OCI label expectations

## Failure Modes To Expect

Common failure cases and what they usually mean:

- `Config file not found`: wrapper points to the wrong `config-path`
- `Duplicate enabled tag/arch pairs detected`: two enabled targets would push the same temporary release tag
- `Target '<name>' references a missing Dockerfile` or missing test script: an enabled path is wrong relative to repository root
- `At least one target must be enabled`: the config only contains disabled targets
- `base_ref must include a digest`: the caller attempted an unpinned base image
- `No platform images discovered for manifest tag`: matrix planning and pushed per-arch tags no longer line up
- `Unexpected triggering workflow`, `Unexpected triggering branch`, or `Unexpected triggering repository`: the metadata sync wrapper is wired to the wrong event source
- `Release metadata SHA does not match triggering workflow SHA`: the downloaded artifact does not belong to the release commit that triggered sync

## Design Rules

- reusable workflows are the public interface
- shared shell logic lives under `scripts/ci/`
- reusable workflows check out the workflow repository at `github.workflow_sha` before running shared scripts
- no branch refs or preview tags in supported callers
- no legacy `docker-matrix` compatibility in the supported interface
- metadata sync is standardized on `Release`, `release`, `main`, and `release-metadata`
- callers should rely on default inputs unless they have a documented reason not to
- `publish: false` on the release workflow is for contract testing and maintainer dry runs
