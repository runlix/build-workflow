# Maintaining Build Workflow

This repository is maintained for `runlix` image automation. The active path is the versionless `CI` contract; `v1` remains available only for legacy consumers.

## Change Types

- `CI` changes:
  - reusable workflows in `.github/workflows/validate.yml`, `.github/workflows/release.yml`, `.github/workflows/sync-release-record.yml`
  - the CI tool image in `tools/ci/`
  - `schema/ci-config.schema.json`
  - `schema/release-record.schema.json`
  - `examples/ci/`
  - `examples/wrappers/`
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
python3 -m pip install -r tools/ci/requirements.txt
```

Useful local checks:

```bash
ajv compile -s schema/ci-config.schema.json --spec=draft2020 --strict=false
ajv compile -s schema/release-record.schema.json --spec=draft2020 --strict=false

python3 -m unittest discover -s tools/ci/tests -p 'test_*.py'

tools/ci/bin/build-workflow-ci validate-config test-fixtures/ci/service/.ci/config.json
tools/ci/bin/build-workflow-ci plan-matrix test-fixtures/ci/service/.ci/config.json --short-sha 1234567

docker build -f tools/ci/Dockerfile -t build-workflow-tools:test .
docker run --rm -v "$PWD:/workspace" -w /workspace build-workflow-tools:test validate-config test-fixtures/ci/service/.ci/config.json

actionlint .github/workflows/*.yml examples/wrappers/*.yml examples/v1/*.yml
git diff --check
```

## Testing Rules

For `CI` changes:

```bash
gh workflow run test-ci.yml --ref YOUR-BRANCH
```

Also verify one real downstream canary before merging. `distroless-runtime` is the default canary:

- pin the canary wrappers to the full commit SHA you are testing
- use `secrets: inherit` on the release wrapper if release notifications are in scope
- only use `config-path` or `tool-image` overrides for maintainer validation
- run validate on `release`
- if release behavior changed, run the release flow and record sync path too

For `v1` changes:

```bash
gh workflow run test-workflow.yml --ref YOUR-BRANCH
```

## Documentation Rules

When behavior changes, update the docs in the same branch:

- `README.md` for the supported surface
- `docs/ci.md` for the supported contract
- `docs/v1/` only if legacy behavior changed
- `examples/wrappers/*.yml` and `examples/ci/*.json` if the public contract changed

Keep the docs aligned with the actual workflow contract:

- `CI` is GHCR-only for `ghcr.io/runlix/<name>`
- wrapper examples must pin the reusable workflow to a merged full SHA
- regular callers should not need to set `config-path` or `tool-image`
- release wrappers should use `secrets: inherit` when Telegram notifications are desired
- validate uploads no artifacts
- release uploads `release-record.json` as artifact `release-record`
- sync writes `release.json`

## Before Pushing

- run the relevant local checks
- update fixtures and examples when the contract changes
- confirm the docs match the actual YAML and schema
- keep one concern per commit
