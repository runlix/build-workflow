# Maintaining Build Workflow

This repository is maintained for `runlix` image automation. The active path is `v2`; `v1` remains available only for legacy consumers.

## Change Types

- `v2` changes:
  - reusable workflows in `.github/workflows/*-v2.yml`
  - `schema/ci-config-v2.schema.json`
  - `examples/ci-v2/`
  - `examples/*.yml`
  - `test-fixtures/v2/`
  - `docs/ci-v2.md`
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
bash commands/validate-schema.sh

# Inspect workflow inputs, outputs, permissions, and job surfaces
bash commands/inspect-workflow-surface.sh

# Lint workflow files
actionlint .github/workflows/*.yml examples/*.yml examples/v1/*.yml
```

## Testing Rules

For `v2` changes:

```bash
# Contract workflow for v2
gh workflow run test-workflow-v2.yml --ref YOUR-BRANCH
```

Also verify one real downstream canary before merging. `distroless-runtime` is the default canary:

- pin the canary wrappers to your branch SHA or preview tag
- run PR validation on `release`
- if release behavior changed, run the release flow and metadata sync path too

For `v1` changes:

```bash
gh workflow run test-workflow.yml --ref YOUR-BRANCH
```

## Documentation Rules

When behavior changes, update the docs in the same branch:

- `README.md` for the supported surface
- `docs/ci-v2.md` for `v2`
- `docs/v1/` only if legacy behavior changed
- `examples/*.yml` and `examples/ci-v2/*.json` if the public contract changed

Keep the docs aligned with the actual workflow contract:

- `v2` is GHCR-only for `ghcr.io/runlix/<name>`
- wrapper examples must use merged full SHAs
- wrapper path filters should treat `.ci/*.sh` as build inputs
- PR aggregate check is `validate / summary`
- release uploads `release-metadata.json` as artifact `release-metadata`

## Before Pushing

- run the relevant local checks
- update fixtures/examples when the contract changes
- confirm the docs match the actual YAML and schema
- keep one concern per commit
