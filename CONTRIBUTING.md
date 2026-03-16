# Contributing to Build Workflow

## Before You Change Anything

Read the implementation surfaces in this order:

1. `.github/workflows/build-images-rebuild.yml`
2. `schema/docker-matrix-schema.json`
3. `examples/`
4. `test-fixtures/`
5. focused docs under `docs/`

When prose conflicts with the workflow or schema, update the prose.

## Development Setup

Prerequisites:

- Git
- Docker with Buildx
- Node.js 20+
- `jq`
- `gh`
- `ajv-cli` and `ajv-formats`

Install validation tools:

```bash
npm install -g ajv-cli ajv-formats
```

Clone your fork and add upstream:

```bash
git clone https://github.com/YOUR-USERNAME/build-workflow.git
cd build-workflow
git remote add upstream https://github.com/runlix/build-workflow.git
```

## Local Validation

Run these before opening a PR:

```bash
bash commands/validate-schema.sh
bash commands/inspect-workflow-surface.sh
bash commands/check-maintainer-drift.sh
```

If you touched the reusable workflow, examples, or fixtures, also dispatch the repo test workflow from your branch:

```bash
gh workflow run test-workflow.yml --ref YOUR-BRANCH -f test_type=both
```

`gh workflow run` is a GitHub Actions dispatch, not a local test runner.

## Contribution Rules

- Keep one concern per PR.
- Pin GitHub Actions to full SHAs.
- Keep schema, examples, fixtures, and docs aligned in the same change.
- Prefer raw `tag_suffix` values such as `stable` and `debug`; do not document leading-dash suffixes.
- Do not reintroduce the removed per-variant `default` field into docs or examples.
- Document any new permissions, secrets, or release-side effects in the PR description.

## Pull Requests

Use branch names like:

- `fix/...`
- `feat/...`
- `docs/...`
- `refactor/...`
- `test/...`

PRs should include:

- what changed and why
- affected workflow/schema/example/doc surfaces
- validation commands run and results
- links to any relevant workflow runs

## Reporting Problems

- Bugs and regressions: GitHub Issues
- Security issues: GitHub Security Advisories or `security@runlix.io`
- Conduct issues: `conduct@runlix.io`

## Code of Conduct

Participation in this repository is covered by [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md).
