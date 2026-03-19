# Maintaining Build Workflow

This repository is maintained for `runlix` image automation. The active path is the versionless `CI` contract; `v1` remains available only for legacy consumers.

## Change Types

- `CI` changes:
  - reusable workflows in `.github/workflows/pr-validation.yml`, `.github/workflows/release.yml`, `.github/workflows/sync-release-metadata.yml`
  - the CI tool image in `tools/ci/`
  - `schema/ci-config.schema.json`
  - `schema/release-metadata.schema.json`
  - `schema/releases.schema.json`
  - `examples/ci/`
  - `examples/*.yml`
  - `test-fixtures/ci/`
  - `docs/ci.md`
- `v1` changes:
  - `.github/workflows/build-images-rebuild.yml`
  - `schema/docker-matrix-schema.json`
  - `examples/v1/`
  - `test-fixtures/v1/`
  - `docs/v1/`

## Local Checks

Install the required tools once:

```bash
npm install -g ajv-cli ajv-formats
```

Useful local checks:

```bash
# Validate the active schemas, examples, and fixtures
ajv compile -s schema/ci-config.schema.json --spec=draft2020 --strict=false
ajv compile -s schema/release-metadata.schema.json --spec=draft2020 --strict=false
ajv compile -s schema/releases.schema.json --spec=draft2020 --strict=false

# Run the direct planner CLI checks
tools/ci/bin/build-workflow-ci validate-config test-fixtures/ci/service/.ci/config.json
tools/ci/bin/build-workflow-ci plan-matrix test-fixtures/ci/service/.ci/config.json --short-sha 1234567

# Build and smoke-test the local tool image
docker build -f tools/ci/Dockerfile -t build-workflow-tools:test .
docker run --rm -v "$PWD:/workspace" -w /workspace build-workflow-tools:test validate-config test-fixtures/ci/service/.ci/config.json

# Lint workflow files
actionlint .github/workflows/*.yml examples/*.yml examples/v1/*.yml

# Check for whitespace and patch-format problems
git diff --check
```

## Testing Rules

For `CI` changes:

```bash
gh workflow run test-ci.yml --ref YOUR-BRANCH
```

Also verify one real downstream canary before merging. `distroless-runtime` is the default canary:

- pin the canary wrappers to the full commit SHA you are testing
- if the branch also changes the tool image, pass `tool-image: ghcr.io/runlix/build-workflow-tools:sha-YOUR-BUILD-WORKFLOW-SHA`
- run PR validation on `release`
- if release behavior changed, run the release flow and metadata sync path too

For `v1` changes:

```bash
gh workflow run test-workflow.yml --ref YOUR-BRANCH
```

## Documentation Rules

When behavior changes, update the docs in the same branch:

- `README.md` for the supported surface
- `docs/ci.md` for the supported contract
- `docs/v1/` only if legacy behavior changed
- `examples/*.yml` and `examples/ci/*.json` if the public contract changed

Keep the docs aligned with the actual workflow contract:

- `CI` is GHCR-only for `ghcr.io/runlix/<name>`
- wrapper examples must pin the reusable workflow to a merged full SHA
- maintainers may override `tool-image` for branch validation, but regular callers should not need to
- wrapper path filters should treat `.ci/*.sh` and `.dockerignore` as build inputs
- PR aggregate check is `validate / summary`
- release uploads `release-metadata.json` as artifact `release-metadata`

## Before Pushing

- run the relevant local checks
- update fixtures/examples when the contract changes
- confirm the docs match the actual YAML and schema
- keep one concern per commit
