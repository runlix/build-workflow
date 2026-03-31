# Contributing

The supported CI contract lives in:

- reusable workflows in `.github/workflows/validate-build.yml`, `.github/workflows/publish-release.yml`, `.github/workflows/validate-release-metadata.yml`
- internal planner tooling in `tools/ci/`
- schemas in `schema/build-config.schema.json` and `schema/release-json.schema.json`
- examples in `examples/build-config/` and `examples/wrappers/`
- fixtures in `test-fixtures/ci/`
- docs in `docs/ci-v3.md`

## Local Validation

Run these before pushing CI contract changes:

```bash
python3 -m pip install --user -r tools/ci/requirements.txt
tools/ci/bin/build-workflow-ci validate-schema-file schema/build-config.schema.json
tools/ci/bin/build-workflow-ci validate-schema-file schema/release-json.schema.json
tools/ci/bin/build-workflow-ci validate-config-payload examples/build-config/service-image.json
tools/ci/bin/build-workflow-ci validate-config test-fixtures/ci/service/.ci/build.json
tools/ci/bin/build-workflow-ci validate-release-json test-fixtures/ci/release-json/release.json
python3 -m unittest discover -s tools/ci/tests -p 'test_*.py'
```

## CI v3 Rules

- callers pin reusable workflows by merged full commit SHA
- callers also pin `ghcr.io/runlix/build-workflow-tools:sha-<same workflow sha>` and pass it as `tool-image`
- `build-workflow` ships from `main`; there is no separate supported provider `release` branch
- downstream side-branch validation requires the matching exact-commit tool image to be published before callers pin that branch SHA
- `validate-build` and `validate-release-metadata` wrappers only need `contents: read`
- publish wrappers grant `contents: read`, `packages: write`, `attestations: write`, and `id-token: write`
- callers keep wrapper workflows thin and repo-specific
- only the publish wrapper maps `RUNLIX_APP_ID` and `RUNLIX_PRIVATE_KEY`
- `main` metadata wrappers should trigger on `release.json` and their own workflow file so required checks still run when the wrapper changes
- `examples/build-config/` are schema-only examples, while `test-fixtures/ci/` are runnable contract fixtures
- `Test CI Contract` intentionally exercises both a local tool-image smoke path and a published exact-commit tool-image path
