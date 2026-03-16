# Build Workflow

Reusable GitHub Actions workflow for multi-architecture container builds, PR validation, and release publication.

## What It Does

- Builds amd64 and arm64 variants from a declarative `.ci/docker-matrix.json`
- Validates PRs without pushing images to GHCR
- Rebuilds from the `release` branch for publication
- Creates multi-arch manifests and updates `releases.json`
- Scans built images with Trivy and posts PR summaries

## Quick Start

```bash
mkdir -p .ci .github/workflows

curl -o .ci/docker-matrix.json \
  https://raw.githubusercontent.com/runlix/build-workflow/main/examples/service-matrix.json

curl -o .github/workflows/pr-validation.yml \
  https://raw.githubusercontent.com/runlix/build-workflow/main/examples/pr-validation.yml

curl -o .github/workflows/release.yml \
  https://raw.githubusercontent.com/runlix/build-workflow/main/examples/release.yml
```

The remote repository does not currently publish git tags, so the examples use `@main`.
For production consumers, pin the reusable workflow to an immutable commit SHA.

## Configuration Model

The source of truth is `.ci/docker-matrix.json` validated by [`schema/docker-matrix-schema.json`](./schema/docker-matrix-schema.json).

```json
{
  "$schema": "https://raw.githubusercontent.com/runlix/build-workflow/main/schema/docker-matrix-schema.json",
  "version": "v5.2.1",
  "base_image": {
    "image": "ghcr.io/runlix/distroless-runtime",
    "tag": "abc1234",
    "digest": "sha256:abc123def456789abc123def456789abc123def456789abc123def456789abc1"
  },
  "variants": [
    {
      "name": "radarr-stable",
      "tag_suffix": "stable",
      "platforms": ["linux/amd64", "linux/arm64"],
      "dockerfiles": {
        "linux/amd64": "Dockerfile.amd64",
        "linux/arm64": "Dockerfile.arm64"
      },
      "build_args": {
        "RADARR_VERSION": "5.2.1.8988",
        "APP_USER": "radarr"
      },
      "test_script": ".ci/test-radarr.sh"
    },
    {
      "name": "radarr-debug",
      "tag_suffix": "debug",
      "platforms": ["linux/amd64", "linux/arm64"],
      "dockerfiles": {
        "linux/amd64": "Dockerfile.debug.amd64",
        "linux/arm64": "Dockerfile.debug.arm64"
      },
      "build_args": {
        "RADARR_VERSION": "5.2.1.8988",
        "APP_USER": "radarr",
        "DEBUG_MODE": "true"
      },
      "test_script": ".ci/test-radarr.sh"
    }
  ]
}
```

## Tag Contract

Prefer raw `tag_suffix` values such as `stable`, `debug`, and `minimal`.
The workflow also normalizes legacy values like `-debug`, and an empty suffix remains supported.

Generated tags omit empty segments automatically:

- PR tags, versioned repo: `pr-123-v5.2.1-stable-amd64-abc1234`
- PR tags, SHA-based repo: `pr-123-stable-amd64-abc1234`
- Release platform tags, versioned repo: `v5.2.1-stable-amd64-abc1234`
- Release platform tags, SHA-based repo: `abc1234-stable-amd64-abc1234`
- Release manifest tags, versioned repo: `v5.2.1-stable`
- Release manifest tags, SHA-based repo: `abc1234-stable`

If `base_image` is present, the workflow auto-injects:

- `BASE_IMAGE`
- `BASE_TAG`
- `BASE_DIGEST`

`BASE_TAG` follows the same normalization rules, so `abc1234` + `debug` becomes `abc1234-debug` and an empty suffix stays `abc1234`.

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
bash commands/inspect-workflow-surface.sh
bash commands/check-maintainer-drift.sh README.md CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md
```

To exercise the repo workflow in GitHub Actions:

```bash
gh workflow run test-workflow.yml --ref YOUR-BRANCH -f test_type=both
```

## Documentation

- [Usage Guide](./docs/usage.md)
- [Customization Guide](./docs/customization.md)
- [API Reference](./docs/api-reference.md)
- [Architecture](./docs/architecture.md)
- [Release Workflow](./docs/release-workflow.md)
- [Integration Testing](./docs/integration-testing.md)
- [Troubleshooting](./docs/troubleshooting.md)

## Community

- Report bugs and workflow issues with GitHub Issues
- Report vulnerabilities through GitHub Security Advisories or `security@runlix.io`
- Report code-of-conduct issues to `conduct@runlix.io`

## License

MIT. See [LICENSE](./LICENSE).
