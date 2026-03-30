# Maintaining Build Workflow

This repository is maintained for `runlix` image automation. The active path is the versionless `CI` contract; `v1` remains available only for legacy consumers.

## Change Types

- `CI` changes:
  - reusable workflows in `.github/workflows/validate.yml`, `.github/workflows/release.yml`, `.github/workflows/validate-release-json.yml`
  - the CI tool image in `tools/ci/`
  - `schema/ci-config.schema.json`
  - `schema/release-json.schema.json`
  - `examples/ci/`
  - `examples/wrappers/`
  - `test-fixtures/ci/`
  - `docs/ci.md`
  - `docs/ci/`
- `v1` changes:
  - `.github/workflows/build-images-rebuild.yml`
  - `schema/docker-matrix-schema.json`
  - `examples/v1/`
  - `test-fixtures/v1/`
  - `docs/v1/`

## Local Checks

Install the required tools once:

```bash
python3 -m pip install -r tools/ci/requirements.txt
```

Useful local checks:

```bash
tools/ci/bin/build-workflow-ci validate-schema-file schema/ci-config.schema.json
tools/ci/bin/build-workflow-ci validate-schema-file schema/release-json.schema.json

python3 -m unittest discover -s tools/ci/tests -p 'test_*.py'

tools/ci/bin/build-workflow-ci validate-config-payload examples/ci/service-config.json
tools/ci/bin/build-workflow-ci validate-config test-fixtures/ci/service/.ci/config.json
tools/ci/bin/build-workflow-ci plan-matrix test-fixtures/ci/service/.ci/config.json --short-sha 1234567
tools/ci/bin/build-workflow-ci render-release-json test-fixtures/ci/service/.ci/config.json --source-sha 1234567890abcdef1234567890abcdef12345678 --published-at 2026-03-17T12:00:00Z --manifests-path test-fixtures/ci/release-json/manifests.json
tools/ci/bin/build-workflow-ci validate-release-json test-fixtures/ci/release-json/release.json

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

`test-ci.yml` validates the provider surface only: schemas, CLI behavior, runnable fixtures, `release.json` contracts, the published planner image, and the release/main wrapper examples.
Also verify one real downstream canary before merging. `distroless-runtime` is the default reusable-workflow canary:

- pin the canary wrappers to the full commit SHA you are testing
- pass `tool-image` pinned by digest or `:sha-<build-workflow git sha>`
- map only `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` on the release wrapper if release notifications are in scope
- map only `RUNLIX_APP_ID` and `RUNLIX_PRIVATE_KEY` on the release wrapper if `main` sync is in scope
- only use `config-path` as a maintainer override
- run validate on `release`
- if release behavior changed, run the full publish path and confirm the `release.json` PR flow

For `v1` changes:

```bash
gh workflow run test-workflow.yml --ref YOUR-BRANCH
```

## Documentation Rules

When behavior changes, update the docs in the same branch:

- `README.md` for the supported surface
- `docs/ci.md` for the supported contract landing page
- `docs/ci/` for focused supported-CI guides
- `docs/v1/` only if legacy behavior changed
- `examples/wrappers/*.yml` and `examples/ci/*.json` if the public contract changed

Keep the docs aligned with the actual workflow contract:

- `CI` is GHCR-only for `ghcr.io/runlix/<name>`
- wrapper examples must pin the reusable workflow to a merged full SHA
- wrapper examples must also pass `tool-image` pinned by digest
- `examples/ci/` are schema-only examples, while `test-fixtures/ci/` are runnable contract fixtures
- release wrappers should map only the Telegram and GitHub App secrets they need
- validate uploads no artifacts
- release owns manifest publication, attestation, and optional `main` sync
- caller-managed `validate-main.yml` should validate only `release.json`

## Before Pushing

- run the relevant local checks
- update fixtures and examples when the contract changes
- confirm the docs match the actual YAML and schema
- keep one concern per commit
