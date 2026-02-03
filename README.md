# Build Workflow

Reusable GitHub Actions workflows for building multi-architecture Docker images with automated PR validation and release promotion.

## Quick Start

Add to your service repository:

```bash
# Create configuration
mkdir -p .ci
curl -o .ci/docker-matrix.json \
  https://raw.githubusercontent.com/runlix/build-workflow/main/examples/service-matrix.json

# Add workflows
mkdir -p .github/workflows
curl -o .github/workflows/pr-validation.yml \
  https://raw.githubusercontent.com/runlix/build-workflow/main/examples/pr-validation.yml
curl -o .github/workflows/release.yml \
  https://raw.githubusercontent.com/runlix/build-workflow/main/examples/release.yml

# Edit configuration for your service
vim .ci/docker-matrix.json
```

See [Usage Guide](./docs/usage.md) for complete setup instructions.

## Features

- **Multi-architecture builds**: Automatic AMD64 and ARM64 support
- **PR validation**: Build and test on every PR (no registry push)
- **Reliable releases**: Always rebuild from release branch for correctness
- **Declarative configuration**: Single JSON file defines all variants
- **Automatic tagging**: Semantic versioning and latest tags
- **Test integration**: Run custom test scripts on built images
- **Vulnerability scanning**: Trivy scans with SARIF output
- **PR comments**: Automatic build result summaries
- **OCI labels**: Standardized metadata on all images

## Architecture

### Repository Types

**Service Repositories** (e.g., radarr, sonarr):
- Use semantic versioning (`v5.2.1`)
- Build from wrapped base images
- Multiple variants (standard, debug)

**Base Image Repositories** (e.g., distroless):
- Use SHA-based versioning (`abc1234`)
- Wrap upstream images
- Foundation for service images

### Workflow Flow

```
┌─────────────┐
│  Developer  │
│   Opens PR  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────┐
│   PR Validation Workflow    │
│   - Build all variants      │
│   - Run tests               │
│   - Scan for vulnerabilities│
│   - Post PR comment         │
│   (no registry push)        │
└──────────┬──────────────────┘
           │
           │ ✅ Approved
           ▼
┌─────────────────────────────┐
│   Merge to main             │
│   (merge commit required)   │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│   Merge main → release      │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│   Release Workflow          │
│   - Rebuild from release    │
│   - Run tests               │
│   - Push platform images    │
│   - Create multi-arch tags  │
│   - Delete platform tags    │
└─────────────────────────────┘
```

## Configuration

### docker-matrix.json

Declarative configuration file at `.ci/docker-matrix.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/runlix/build-workflow/main/schema/docker-matrix-schema.json",
  "version": "v5.2.1",
  "base_image": {
    "image": "ghcr.io/runlix/distroless",
    "tag": "abc1234",
    "digest": "sha256:..."
  },
  "variants": [
    {
      "name": "radarr-latest",
      "tag_suffix": "",
      "default": true,
      "platforms": ["linux/amd64", "linux/arm64"],
      "dockerfiles": {
        "linux/amd64": "Dockerfile.amd64",
        "linux/arm64": "Dockerfile.arm64"
      },
      "build_args": {
        "RADARR_VERSION": "5.2.1.8988",
        "APP_USER": "radarr"
      },
      "test_script": "tests/test-radarr.sh"
    }
  ]
}
```

**Key features:**
- Schema validation with clear error messages
- Auto-injection of `BASE_IMAGE`, `BASE_TAG`, `BASE_DIGEST`
- Automatic `tag_suffix` appending to base image tag
- Multiple variants with independent configurations
- Per-platform Dockerfiles for architecture-specific optimizations

See [Customization Guide](./docs/customization.md) for all options.

### Dockerfiles

Per-architecture Dockerfiles with auto-injected build args:

```dockerfile
# Dockerfile.amd64
ARG BASE_IMAGE
ARG BASE_TAG
ARG BASE_DIGEST
ARG APP_VERSION
ARG APP_USER

FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}

COPY --from=builder /app/myservice /app/
USER ${APP_USER}
ENTRYPOINT ["/app/myservice"]
```

**Important:** Do NOT add `BASE_IMAGE`, `BASE_TAG`, `BASE_DIGEST` to `build_args` in docker-matrix.json - they are automatically injected.

### Workflows

**PR Validation** (`.github/workflows/pr-validation.yml`):
```yaml
name: PR Validation
on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write
  actions: read

jobs:
  validate:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: true
    secrets: inherit
```

**Release** (`.github/workflows/release.yml`):
```yaml
name: Release
on:
  push:
    branches: [release]

permissions:
  contents: write
  packages: write
  actions: read

concurrency:
  group: release-${{ github.repository }}
  cancel-in-progress: true

jobs:
  release:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: false
    secrets: inherit
```

## Image Tags

### PR Mode
Images are built and tested locally in the Docker daemon only.
**No images are pushed to registry during PR validation.**

This provides:
- Faster PR feedback (no registry upload time)
- Cleaner registry (no PR image clutter)
- Lower costs (reduced storage and bandwidth)

### Release Mode
**Platform tags** (temporary): `{version}{tag_suffix}-{arch}-{sha}`
- `v5.2.1-amd64-abc1234`
- `v5.2.1-debug-amd64-abc1234`

**Multi-arch manifests** (permanent): `{version}{tag_suffix}`
- `v5.2.1` (default variant)
- `v5.2.1-debug`
- `latest` (default variant only)

## Documentation

- **[Usage Guide](./docs/usage.md)** - Complete setup and daily usage
- **[Customization Guide](./docs/customization.md)** - All configuration options
- **[Migration Guide](./docs/migration.md)** - Migrate existing services
- **[Branch Protection](./docs/branch-protection.md)** - Required repository settings
- **[GHCR Retention](./docs/ghcr-retention.md)** - Image retention policies
- **[GitHub App Setup](./docs/github-app-setup.md)** - Enhanced API access (optional)
- **[Troubleshooting](./docs/troubleshooting.md)** - Fix common issues

## Examples

- **[service-matrix.json](./examples/service-matrix.json)** - Service configuration
- **[base-image-matrix.json](./examples/base-image-matrix.json)** - Base image configuration
- **[pr-validation.yml](./examples/pr-validation.yml)** - PR workflow
- **[release.yml](./examples/release.yml)** - Release workflow
- **[Dockerfiles](./examples/)** - Example Dockerfiles
- **[test-script.sh](./examples/test-script.sh)** - Test script template

## Test Fixtures

Test fixtures available in `test-fixtures/`:
- **Base image** - Distroless wrapper examples
- **Service** - Application image examples
- **Test scripts** - Testing examples

Run tests:
```bash
# Test base image builds
docker build -f test-fixtures/base-image/Dockerfile.amd64 .

# Test service builds
docker build -f test-fixtures/service/Dockerfile.amd64 .

# Run test workflow
gh workflow run test-workflow.yml
```

## Schema

JSON Schema for `docker-matrix.json` validation: [schema/docker-matrix-schema.json](./schema/docker-matrix-schema.json)

Validate locally:
```bash
npm install -g ajv-cli ajv-formats
ajv validate -s schema/docker-matrix-schema.json -d .ci/docker-matrix.json
```

## Requirements

### Repository Settings

- ✅ **Merge commits enabled** (recommended)
- ⚠️  **Squash merge** (allowed - no longer affects workflow)
- ⚠️  **Rebase merge** (allowed - no longer affects workflow)

See [Branch Protection Guide](./docs/branch-protection.md) for complete setup.

### Permissions

**PR Validation** needs:
```yaml
permissions:
  contents: read        # Checkout code
  pull-requests: write  # Comment on PRs
  actions: read         # Read artifacts
```

**Release** needs:
```yaml
permissions:
  contents: write       # Update releases.json
  packages: write       # Push/delete images
  actions: read         # Read artifacts
```

### Branch Structure

- `main` - Development branch (receives PRs)
- `release` - Release branch (triggers releases)

## Contributing

### Making Changes

1. Update workflow: `.github/workflows/build-images-rebuild.yml`
2. Update schema: `schema/docker-matrix-schema.json`
3. Update examples: `examples/`
4. Update docs: `docs/`
5. Test with fixtures: `test-fixtures/`
6. Run validation: `gh workflow run test-workflow.yml`

### Testing

```bash
# Validate schema changes
npm install -g ajv-cli ajv-formats
ajv validate -s schema/docker-matrix-schema.json -d test-fixtures/*/docker-matrix.json

# Test workflow locally (requires act or GitHub-hosted runner)
gh workflow run test-workflow.yml --ref your-branch
```

## Support

- **Issues**: https://github.com/runlix/build-workflow/issues
- **Discussions**: https://github.com/runlix/build-workflow/discussions
- **Documentation**: https://github.com/runlix/build-workflow/tree/main/docs

## License

MIT License - see [LICENSE](./LICENSE) file for details.

## Related Projects

- [runlix/distroless](https://github.com/runlix/distroless) - Base images
- [runlix/radarr](https://github.com/runlix/radarr) - Example service using this workflow
- [runlix/sonarr](https://github.com/runlix/sonarr) - Example service using this workflow
