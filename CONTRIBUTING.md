# Maintaining Build Workflow

This repository is maintained for `runlix` image automation. The active path is the versionless `CI` contract; `v1` remains available only for legacy consumers.

## Change Types

- `CI` changes:
  - reusable workflows in `.github/workflows/pr-validation.yml`, `.github/workflows/release.yml`, `.github/workflows/sync-release-metadata.yml`
  - `.github/actions/internal/ci/`
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
- wrapper examples must use merged full SHAs in both `uses:` and `build-workflow-ref`
- supported callers should not use branch refs or preview tags
- wrapper path filters should treat `.ci/*.sh` and `.dockerignore` as build inputs
- PR aggregate check is `validate / summary`
- release uploads `release-metadata.json` as artifact `release-metadata`

## Before Pushing

- run the relevant local checks
- update fixtures/examples when the contract changes
- confirm the docs match the actual YAML and schema
- keep one concern per commit
