# Workflow Customization Options

This document describes all available customization options for the build-workflow reusable workflows.

## Table of Contents
- [Workflow Inputs](#workflow-inputs)
- [Environment Variables](#environment-variables)
- [docker-matrix.json Configuration](#docker-matrixjson-configuration)
- [Build Arguments](#build-arguments)
- [Test Scripts](#test-scripts)

## Workflow Inputs

### PR Validation Workflow

```yaml
uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
with:
  pr_mode: true
  dry_run: false  # optional
secrets: inherit
```

**Inputs:**

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `pr_mode` | Yes | - | Set to `true` for PR validation, `false` for release builds |
| `dry_run` | No | `false` | Skip image push to registry (for testing workflow changes) |

### Release Workflow

```yaml
uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
with:
  pr_mode: false
secrets: inherit
```

**Note:** Always use `secrets: inherit` to pass GitHub token for GHCR authentication.

## Environment Variables

The workflow sets these environment variables automatically:

| Variable | Scope | Description |
|----------|-------|-------------|
| `REGISTRY` | Workflow-level | Container registry URL (`ghcr.io`) |
| `REGISTRY_ORG` | Workflow-level | Organization name (`runlix`) |
| `SERVICE_NAME` | Job-level | Extracted from `github.event.repository.name` |
| `IMAGE_TAG` | Step-level | Generated image tag (varies by mode and variant) |

## docker-matrix.json Configuration

Place this file at `.ci/docker-matrix.json` in your service repository.

### Top-Level Fields

```json
{
  "version": "v5.2.1",         // Optional: semantic version for services
  "base_image": { ... },        // Optional: for services using wrapped base images
  "variants": [ ... ]           // Required: at least one variant
}
```

#### version (optional)

- **Type:** String
- **When to use:** Service repositories with semantic versioning
- **When to omit:** Base image repositories (use SHA-based versioning)
- **Requirements:** If present, exactly one variant must have `default: true`

**Example:**
```json
"version": "v5.2.1"
```

#### base_image (optional)

- **Type:** Object
- **When to use:** Service repositories that use a wrapped base image
- **When to omit:** Base image repositories

**Required fields:**
```json
"base_image": {
  "image": "ghcr.io/runlix/distroless",
  "tag": "abc1234",
  "digest": "sha256:abc123def456..."
}
```

**Auto-injection behavior:**
- `BASE_IMAGE` is automatically injected into build_args
- `BASE_TAG` is automatically set to `base_image.tag + variant.tag_suffix`
- `BASE_DIGEST` is automatically injected into build_args
- **Do NOT** manually add these to variant `build_args`

### Variants

Each variant defines a different build configuration (e.g., standard, debug, alpine).

```json
"variants": [
  {
    "name": "radarr-latest",
    "tag_suffix": "",
    "default": true,
    "enabled": true,
    "platforms": ["linux/amd64", "linux/arm64"],
    "dockerfiles": {
      "linux/amd64": "Dockerfile.amd64",
      "linux/arm64": "Dockerfile.arm64"
    },
    "build_args": {
      "RADARR_VERSION": "5.2.1.8988",
      "APP_USER": "radarr"
    },
    "test_script": "./tests/test-radarr.sh"
  }
]
```

#### Variant Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `name` | Yes | String | Unique identifier for this variant |
| `tag_suffix` | Yes | String | Appended to version/SHA (e.g., `""`, `"-debug"`, `"-alpine"`) |
| `default` | Conditional | Boolean | Exactly one variant must be `true` if `version` field is present |
| `enabled` | No | Boolean | Set to `false` to skip building this variant (default: `true`) |
| `platforms` | Yes | Array | List of platforms to build (e.g., `["linux/amd64", "linux/arm64"]`) |
| `dockerfiles` | Yes | Object | Platform-to-Dockerfile mapping |
| `build_args` | No | Object | Build-time variables passed to Docker |
| `test_script` | No | String | Path to test script (receives `IMAGE_TAG` env var) |

#### Tag Suffix Rules

- Must be unique across variants when combined with version/SHA
- Starts with `-` for non-default variants (e.g., `"-debug"`)
- Empty string `""` for default variant
- Automatically appended to `base_image.tag` when injecting `BASE_TAG`

**Example collision (invalid):**
```json
{
  "version": "v1.0.0",
  "variants": [
    { "name": "standard", "tag_suffix": "" },      // v1.0.0
    { "name": "other", "tag_suffix": "" }          // v1.0.0 - COLLISION!
  ]
}
```

## Build Arguments

### For Base Image Repositories

Manually specify upstream image details:

```json
"build_args": {
  "UPSTREAM_IMAGE": "gcr.io/distroless/base-debian12",
  "UPSTREAM_TAG": "latest",
  "UPSTREAM_DIGEST": "sha256:..."
}
```

### For Service Repositories

**DO NOT** manually specify `BASE_IMAGE`, `BASE_TAG`, or `BASE_DIGEST`. These are auto-injected from the `base_image` object.

Only specify application-specific arguments:

```json
"build_args": {
  "APP_VERSION": "5.2.1.8988",
  "APP_USER": "myapp",
  "PORT": "8080"
}
```

**Incorrect:**
```json
"build_args": {
  "BASE_IMAGE": "ghcr.io/runlix/distroless",    // ❌ Don't do this
  "BASE_TAG": "abc1234",                         // ❌ Don't do this
  "BASE_DIGEST": "sha256:...",                   // ❌ Don't do this
  "APP_VERSION": "5.2.1.8988"
}
```

## Test Scripts

Test scripts receive the built image tag via the `IMAGE_TAG` environment variable.

### Basic Template

```bash
#!/bin/bash
set -e

echo "Testing image: $IMAGE_TAG"

# Start container
docker run -d --name test-container $IMAGE_TAG

# Wait for startup
sleep 5

# Check container is running
if ! docker ps | grep -q test-container; then
  echo "❌ Container failed to start"
  docker logs test-container
  exit 1
fi

# Cleanup
docker stop test-container
docker rm test-container

echo "✅ Tests passed"
```

### Health Check Example

```bash
#!/bin/bash
set -e

docker run -d --name test-container -p 8080:8080 $IMAGE_TAG
sleep 10

# Check health endpoint
if ! curl -f http://localhost:8080/health; then
  echo "❌ Health check failed"
  docker logs test-container
  exit 1
fi

docker stop test-container && docker rm test-container
echo "✅ Health check passed"
```

### Test Script Requirements

- Must be executable (`chmod +x test-script.sh`)
- Must exit with code 0 on success, non-zero on failure
- Must clean up containers on exit
- Timeout: 10 minutes (enforced by workflow)
- Available commands: docker, curl, jq, standard Unix utilities

## Image Tag Formats

Tags are generated automatically based on mode and configuration:

### PR Mode

**With version (services):**
Format: `pr-{number}-{version}-{tag_suffix}-{arch}-{sha}`

**Examples:**
- `pr-123-v5.2.1-stable-amd64-abc1234` (default variant with tag_suffix "stable")
- `pr-123-v5.2.1-debug-amd64-abc1234` (debug variant)
- `pr-123-v5.2.1-stable-arm64-abc1234` (ARM architecture)

**Without version (base images):**
Format: `pr-{number}-{tag_suffix}-{arch}-{sha}`

**Examples:**
- `pr-456-stable-amd64-abc1234` (default variant)
- `pr-456-debug-arm64-abc1234` (debug variant, ARM)

### Release Mode - Platform Tags (temporary)

**With version (services):**
Format: `{version}-{tag_suffix}-{arch}-{sha}`

**Examples:**
- `v5.2.1-stable-amd64-abc1234` (default variant with tag_suffix "stable")
- `v5.2.1-debug-amd64-abc1234` (debug variant, amd64)
- `v5.2.1-stable-arm64-abc1234` (default variant, ARM)

**Without version (base images):**
Format: `{tag_suffix}-{arch}-{sha}`

**Examples:**
- `stable-amd64-abc1234`
- `debug-arm64-abc1234`

**Note:** Platform tags include SHA suffix for uniqueness and are deleted after multi-arch manifest creation.

### Release Mode - Multi-Arch Manifests (permanent)

**With version (services):**
Format: `{version}-{tag_suffix}`

**Examples:**
- `v5.2.1-stable` (default variant with tag_suffix "stable")
- `v5.2.1-debug` (debug variant with tag_suffix "debug")

**Without version (base images):**
Format: `{sha}-{tag_suffix}`

**Examples:**
- `abc1234-stable` (commit SHA with tag_suffix "stable")
- `abc1234-debug` (commit SHA with debug variant)

**Note:** Manifests intentionally omit SHA suffix to provide stable, predictable tags for users.

## OCI Labels

All images automatically include these OCI labels:

| Label | Description | Example |
|-------|-------------|---------|
| `org.opencontainers.image.revision` | Git commit SHA | `abc123def456...` |
| `org.opencontainers.image.created` | Build timestamp (ISO 8601) | `2024-01-29T10:30:00Z` |
| `org.opencontainers.image.source` | Source repository URL | `https://github.com/runlix/radarr` |
| `org.opencontainers.image.version` | Version (if present) | `v5.2.1` |

## Dry Run Mode

For testing workflow changes without pushing images:

```yaml
uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
with:
  pr_mode: true
  dry_run: true  # Skip image push
secrets: inherit
```

**Behavior in dry run:**
- Builds complete normally
- Tests run normally
- Vulnerability scans run normally
- Images are NOT pushed to GHCR
- PR comments still posted (if pr_mode: true)

**Use cases:**
- Testing workflow YAML changes
- Testing new variant configurations
- Validating Dockerfile changes locally
- Debugging build issues

## Disabling Variants

Temporarily disable a variant without removing it:

```json
"variants": [
  {
    "name": "experimental",
    "enabled": false,  // This variant will be skipped
    "tag_suffix": "-experimental",
    ...
  }
]
```

**Note:** At least one variant must have `enabled: true` (or omit the field).

## Caching

Docker layer caching is automatic:

- Cache key: `buildx-{variant_name}-{platform}-{sha}`
- Cache restore: Falls back to latest cache for same variant+platform
- Cache location: GitHub Actions cache (`/tmp/.buildx-cache`)
- Cache mode: `mode=max` (cache all layers)

No configuration needed.

## Permissions

The calling workflow must grant these permissions:

```yaml
permissions:
  contents: write       # Update releases.json (release mode only)
  packages: write       # Push images to GHCR, delete platform tags
  pull-requests: write  # Comment on PR (PR mode only)
  actions: read         # Query workflow artifacts
```

## Concurrency

For release workflows, prevent concurrent builds:

```yaml
concurrency:
  group: release-${{ github.repository }}
  cancel-in-progress: true
```

This prevents race conditions when pushing manifests and updating releases.json.

## Timeout

Default timeout: 60 minutes per build job

To customize (in your calling workflow):

```yaml
jobs:
  build:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: true
    secrets: inherit
    timeout-minutes: 120  # Custom timeout
```

## Next Steps

- [Branch Protection Requirements](./branch-protection.md)
- [GHCR Retention Policy Setup](./ghcr-retention.md)
- [GitHub App Setup](./github-app-setup.md)
- [Troubleshooting Guide](./troubleshooting.md)
