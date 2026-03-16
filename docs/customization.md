# Workflow Customization

## Inputs

The reusable workflow exposes two inputs:

| Input | Required | Default | Purpose |
| --- | --- | --- | --- |
| `pr_mode` | yes | none | `true` for PR validation, `false` for releases |
| `dry_run` | no | `false` | Skip registry push during release-mode testing |

Example:

```yaml
uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
with:
  pr_mode: false
  dry_run: true
secrets: inherit
```

## docker-matrix.json

Supported top-level fields:

- `version`: semantic version for service repos
- `base_image`: pinned runtime image for service repos
- `variants`: required build definitions

Supported per-variant fields:

| Field | Required | Notes |
| --- | --- | --- |
| `name` | yes | unique identifier |
| `tag_suffix` | yes | raw suffix such as `stable` or `debug` |
| `dockerfiles` | yes | map of platform to Dockerfile |
| `platforms` | yes | supported platforms |
| `build_args` | no | literal string args only |
| `test_script` | no | executable script path |
| `enabled` | no | defaults to `true` |

There is no supported `default` field.

## Tag Behavior

- Docs and examples in this repo use explicit suffixes such as `stable` and `debug`.
- Empty suffix remains valid, but generated tags omit empty segments automatically.
- `BASE_TAG` uses the same normalization rule.

Examples:

- `v5.2.1-stable-amd64-abc1234`
- `v5.2.1-debug`
- `abc1234-stable`
- `abc1234-debug`

## Build Args

Do not define these manually when `base_image` is present:

- `BASE_IMAGE`
- `BASE_TAG`
- `BASE_DIGEST`

Define only application-specific args:

```json
{
  "build_args": {
    "APP_VERSION": "5.2.1",
    "APP_USER": "service"
  }
}
```

## Test Scripts

`test_script` receives:

- `IMAGE_TAG`
- `PLATFORM`

Scripts should exit non-zero on failure and clean up any containers they create.
