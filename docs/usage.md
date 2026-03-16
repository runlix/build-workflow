# Workflow Usage Guide

## Setup

Copy the example files into your service repository:

```bash
mkdir -p .ci .github/workflows

curl -o .ci/docker-matrix.json \
  https://raw.githubusercontent.com/runlix/build-workflow/main/examples/service-matrix.json

curl -o .github/workflows/pr-validation.yml \
  https://raw.githubusercontent.com/runlix/build-workflow/main/examples/pr-validation.yml

curl -o .github/workflows/release.yml \
  https://raw.githubusercontent.com/runlix/build-workflow/main/examples/release.yml
```

The reusable workflow is currently consumed from `@main` because this repo does not publish git tags.
For production use, pin a full commit SHA instead of a moving branch ref.

## docker-matrix.json

Service repositories usually define:

```json
{
  "$schema": "https://raw.githubusercontent.com/runlix/build-workflow/main/schema/docker-matrix-schema.json",
  "version": "v5.2.1",
  "base_image": {
    "image": "ghcr.io/runlix/distroless-runtime",
    "tag": "abc1234",
    "digest": "sha256:..."
  },
  "variants": [
    {
      "name": "service-stable",
      "tag_suffix": "stable",
      "platforms": ["linux/amd64", "linux/arm64"],
      "dockerfiles": {
        "linux/amd64": "Dockerfile.amd64",
        "linux/arm64": "Dockerfile.arm64"
      },
      "build_args": {
        "APP_VERSION": "5.2.1",
        "APP_USER": "service"
      },
      "test_script": ".ci/test-service.sh"
    },
    {
      "name": "service-debug",
      "tag_suffix": "debug",
      "platforms": ["linux/amd64", "linux/arm64"],
      "dockerfiles": {
        "linux/amd64": "Dockerfile.debug.amd64",
        "linux/arm64": "Dockerfile.debug.arm64"
      }
    }
  ]
}
```

Base-image repositories omit `version` and `base_image`.

## Tag Rules

- Prefer raw suffix values such as `stable`, `debug`, and `minimal`.
- Legacy values like `-debug` are normalized by the workflow.
- Empty suffix is still accepted for compatibility, but public examples in this repo use explicit suffixes.
- There is no per-variant `default` field.

Generated tags:

- PR, versioned repo: `pr-123-v5.2.1-stable-amd64-abc1234`
- PR, SHA-based repo: `pr-123-stable-amd64-abc1234`
- Release platform tag: `v5.2.1-stable-amd64-abc1234`
- Release manifest tag: `v5.2.1-stable`
- SHA-based manifest tag: `abc1234-stable`

## Dockerfiles

If `base_image` is present, the workflow injects:

- `BASE_IMAGE`
- `BASE_TAG`
- `BASE_DIGEST`

Example:

```dockerfile
ARG BASE_IMAGE
ARG BASE_TAG
ARG BASE_DIGEST
ARG APP_VERSION

FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}
```

`BASE_TAG` is normalized automatically, so `abc1234` + `debug` becomes `abc1234-debug`.

## Caller Workflows

PR validation:

```yaml
jobs:
  validate:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: true
    secrets: inherit
```

Release:

```yaml
jobs:
  release:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: false
    secrets: inherit
```

## Validation

```bash
bash commands/validate-schema.sh
gh workflow run test-workflow.yml --ref YOUR-BRANCH -f test_type=both
```
