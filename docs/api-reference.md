# API Reference

## Workflow Inputs

| Input | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `pr_mode` | boolean | yes | none | `true` for PR validation, `false` for releases |
| `dry_run` | boolean | no | `false` | skip image push in release mode |

## Secrets

| Secret | Required | Description |
| --- | --- | --- |
| `RUNLIX_APP_ID` | release mode | GitHub App ID for `releases.json` updates |
| `RUNLIX_PRIVATE_KEY` | release mode | GitHub App private key |
| `TELEGRAM_BOT_TOKEN` | no | optional release notification token |
| `TELEGRAM_CHAT_ID` | no | optional release notification target |

## Permissions

The reusable workflow requires:

```yaml
permissions:
  contents: write
  packages: write
  pull-requests: write
  actions: read
```

## Jobs

### `parse-matrix`

- validates `.ci/docker-matrix.json`
- expands variants into a matrix
- exposes `matrix` and `version`

### `promote-or-build`

- builds each matrix entry
- runs `test_script` when provided
- scans with Trivy
- pushes only in release mode when `dry_run` is false

### `summary`

- downloads artifacts
- summarizes build status
- updates or creates the PR comment in PR mode

### `create-manifests`

- release mode only
- creates multi-arch manifests
- deletes temporary platform tags
- updates `releases.json`
- optionally sends Telegram notifications

## Tag Semantics

- explicit suffixes such as `stable` and `debug` are the recommended convention
- legacy suffixes such as `-debug` are normalized before tag generation
- empty suffix is supported, and empty segments are omitted from generated tags

## Example

```yaml
jobs:
  validate:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: true
    secrets: inherit
```
