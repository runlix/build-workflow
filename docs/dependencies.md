# Dependency Surfaces

## Primary Dependencies

- GitHub Actions reusable workflow logic in `.github/workflows/build-images-rebuild.yml`
- JSON schema in `schema/docker-matrix-schema.json`
- public examples in `examples/`
- test fixtures in `test-fixtures/`

## Runtime Tooling

The workflow expects these external tools during execution:

- Docker Buildx
- QEMU
- `jq`
- `gh`
- `ajv-cli`
- Trivy

## Maintainer Checks

Use these commands when dependency or behavior changes land:

```bash
bash commands/validate-schema.sh
bash commands/inspect-workflow-surface.sh
bash commands/check-maintainer-drift.sh
```

## Contract Notes

- `tag_suffix` is preferably a raw suffix string; legacy leading-dash values are normalized.
- explicit suffixes such as `stable` and `debug` are the preferred examples.
- empty suffix remains supported, but docs and public examples should not depend on it.
- there is no supported per-variant `default` field.
