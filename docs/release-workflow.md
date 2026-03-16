# Release Workflow

## Trigger

Consumer repositories typically run the release caller workflow on pushes to `release`.

```yaml
jobs:
  release:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: false
    secrets: inherit
```

## Release Stages

1. `parse-matrix` validates `.ci/docker-matrix.json` and expands the matrix.
2. `promote-or-build` rebuilds each variant/platform combination from the caller repo, runs tests, scans, and pushes temporary platform tags.
3. `summary` collects artifacts and reports status.
4. `create-manifests` creates permanent multi-arch manifests, deletes temporary platform tags, and updates `releases.json`.

## Tag Outputs

Recommended `tag_suffix` values are explicit names such as `stable` and `debug`.
Legacy leading-dash values are normalized before tags are assembled.

- platform tag, versioned repo: `v5.2.1-stable-amd64-abc1234`
- platform tag, SHA-based repo: `abc1234-stable-amd64-abc1234`
- manifest tag, versioned repo: `v5.2.1-stable`
- manifest tag, SHA-based repo: `abc1234-stable`

Empty suffixes remain valid, and the workflow omits empty segments automatically.

## Requirements

- `RUNLIX_APP_ID` and `RUNLIX_PRIVATE_KEY` for `releases.json` updates
- `packages: write` and `contents: write`
- caller repo should keep workflow files, schema usage, and Dockerfiles aligned with the build matrix
