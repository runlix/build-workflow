# Legacy `v1`

`v1` is the legacy `docker-matrix` workflow surface.

It remains in this repository for existing consumers, but it is no longer the recommended starting point for new repositories.

Core `v1` entrypoints:

- reusable workflow: `../../.github/workflows/build-images-rebuild.yml`
- schema: `../../schema/docker-matrix-schema.json`
- examples: `../../examples/v1/`
- fixtures: `../../test-fixtures/v1/`

Primary legacy guides:

- [usage.md](./usage.md)
- [customization.md](./customization.md)
- [migration.md](./migration.md)
- [branch-protection.md](./branch-protection.md)
- [troubleshooting.md](./troubleshooting.md)
- [integration-testing.md](./integration-testing.md)
- [release-workflow.md](./release-workflow.md)
- [renovate.md](./renovate.md)

For new repositories, use `../ci-v2.md` instead.
