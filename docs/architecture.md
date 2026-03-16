# Build Workflow Architecture

## Source of Truth

Use these surfaces in order:

1. `.github/workflows/build-images-rebuild.yml`
2. `schema/docker-matrix-schema.json`
3. `examples/`
4. `test-fixtures/`
5. focused docs in `docs/`

## Workflow Shape

The reusable workflow has four jobs:

1. `parse-matrix`
2. `promote-or-build`
3. `summary`
4. `create-manifests`

PR mode builds and tests locally in the runner Docker daemon.
Release mode rebuilds from the caller repo's `release` branch, pushes platform tags, creates manifests, updates `releases.json`, and may notify Telegram.

## Tagging Model

Prefer raw `tag_suffix` values such as `stable` and `debug`.
Legacy values like `-debug` are normalized before tag generation.

Generated tags omit empty segments automatically:

- versioned PR tag: `pr-123-v5.2.1-stable-amd64-abc1234`
- SHA-based PR tag: `pr-123-stable-amd64-abc1234`
- versioned platform tag: `v5.2.1-stable-amd64-abc1234`
- SHA-based platform tag: `abc1234-stable-amd64-abc1234`
- versioned manifest tag: `v5.2.1-stable`
- SHA-based manifest tag: `abc1234-stable`

## Build Argument Injection

When `base_image` is defined, the workflow injects:

- `BASE_IMAGE`
- `BASE_TAG`
- `BASE_DIGEST`

`BASE_TAG` is normalized the same way as user-facing tags.

## Schema Notes

- `version` is optional.
- `base_image` is optional.
- `variants` is required.
- `enabled` is the supported switch for disabling variants.
- There is no per-variant `default` field.
