# Workflow Usage Guide

Complete guide to using the build-workflow system in your service repository.

## Table of Contents
- [Quick Start](#quick-start)
- [Initial Setup](#initial-setup)
- [Creating docker-matrix.json](#creating-docker-matrixjson)
- [Creating Dockerfiles](#creating-dockerfiles)
- [Adding Workflows](#adding-workflows)
- [Testing Locally](#testing-locally)
- [First PR](#first-pr)
- [First Release](#first-release)

## Quick Start

For the impatient - minimal steps to get started:

```bash
# 1. Create configuration directory
mkdir -p .ci

# 2. Copy example configuration
curl -o .ci/docker-matrix.json \
  https://raw.githubusercontent.com/runlix/build-workflow/main/examples/service-matrix.json

# 3. Copy example workflows
mkdir -p .github/workflows
curl -o .github/workflows/pr-validation.yml \
  https://raw.githubusercontent.com/runlix/build-workflow/main/examples/pr-validation.yml
curl -o .github/workflows/release.yml \
  https://raw.githubusercontent.com/runlix/build-workflow/main/examples/release.yml

# 4. Edit configuration
vim .ci/docker-matrix.json  # Update for your service

# 5. Create Dockerfiles
touch Dockerfile.amd64 Dockerfile.arm64

# 6. Commit and push
git add .ci .github Dockerfile.*
git commit -m "Add build-workflow integration"
git push
```

## Initial Setup

### Prerequisites

- Service repository in `runlix` organization
- Admin access to repository settings
- Docker knowledge (Dockerfile creation)
- Basic understanding of GitHub Actions

### Repository Structure

After setup, your repository should have:

```
your-service/
├── .ci/
│   └── docker-matrix.json          # Build configuration
├── .github/
│   └── workflows/
│       ├── pr-validation.yml       # PR builds
│       └── release.yml             # Release builds
├── Dockerfile.amd64                # AMD64 Dockerfile
├── Dockerfile.arm64                # ARM64 Dockerfile
├── tests/                          # Optional
│   └── test-service.sh            # Test script
└── src/                            # Your application code
    └── ...
```

## Creating docker-matrix.json

### For Service Repositories

Services use versioned releases and wrapped base images:

```json
{
  "$schema": "https://raw.githubusercontent.com/runlix/build-workflow/main/schema/docker-matrix-schema.json",
  "version": "v5.2.1",
  "base_image": {
    "image": "ghcr.io/runlix/distroless",
    "tag": "abc1234",
    "digest": "sha256:abc123..."
  },
  "variants": [
    {
      "name": "my-service-latest",
      "tag_suffix": "",
      "default": true,
      "platforms": ["linux/amd64", "linux/arm64"],
      "dockerfiles": {
        "linux/amd64": "Dockerfile.amd64",
        "linux/arm64": "Dockerfile.arm64"
      },
      "build_args": {
        "APP_VERSION": "5.2.1.8988",
        "APP_USER": "myservice"
      },
      "test_script": "tests/test-service.sh"
    }
  ]
}
```

**Key points:**
- `version`: Your semantic version (required for services)
- `base_image`: The wrapped base image to use
- `base_image.tag`: Will have variant's `tag_suffix` appended automatically
- `build_args`: DO NOT include `BASE_IMAGE`, `BASE_TAG`, `BASE_DIGEST` (auto-injected)
- `default: true`: Required for exactly one variant when version is present

### For Base Image Repositories

Base images use SHA-based versioning and no base_image object:

```json
{
  "$schema": "https://raw.githubusercontent.com/runlix/build-workflow/main/schema/docker-matrix-schema.json",
  "variants": [
    {
      "name": "distroless-base",
      "tag_suffix": "",
      "platforms": ["linux/amd64", "linux/arm64"],
      "dockerfiles": {
        "linux/amd64": "Dockerfile.amd64",
        "linux/arm64": "Dockerfile.arm64"
      },
      "build_args": {
        "UPSTREAM_IMAGE": "gcr.io/distroless/base-debian12",
        "UPSTREAM_TAG": "latest",
        "UPSTREAM_DIGEST": "sha256:..."
      }
    }
  ]
}
```

**Key differences:**
- NO `version` field
- NO `base_image` object
- Uses commit SHA for tags (e.g., `abc1234`)

### Adding Variants

Add multiple variants for different build configurations:

```json
{
  "version": "v5.2.1",
  "base_image": { ... },
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
      }
    },
    {
      "name": "radarr-debug",
      "tag_suffix": "-debug",
      "default": false,
      "platforms": ["linux/amd64", "linux/arm64"],
      "dockerfiles": {
        "linux/amd64": "Dockerfile.debug.amd64",
        "linux/arm64": "Dockerfile.debug.arm64"
      },
      "build_args": {
        "RADARR_VERSION": "5.2.1.8988",
        "APP_USER": "radarr",
        "DEBUG": "true"
      }
    }
  ]
}
```

**Results:**
- Default variant: `ghcr.io/runlix/radarr:v5.2.1` and `ghcr.io/runlix/radarr:latest`
- Debug variant: `ghcr.io/runlix/radarr:v5.2.1-debug`

### Validation

Validate your configuration:

```bash
# Install ajv-cli
npm install -g ajv-cli ajv-formats

# Download schema
curl -o /tmp/schema.json \
  https://raw.githubusercontent.com/runlix/build-workflow/main/schema/docker-matrix-schema.json

# Validate
ajv validate -s /tmp/schema.json -d .ci/docker-matrix.json
```

## Creating Dockerfiles

### For Service Repositories

Use auto-injected `BASE_IMAGE`, `BASE_TAG`, `BASE_DIGEST`:

**Dockerfile.amd64:**
```dockerfile
# These are auto-injected - DO NOT add to build_args in docker-matrix.json
ARG BASE_IMAGE
ARG BASE_TAG
ARG BASE_DIGEST

# Your custom build args (defined in docker-matrix.json)
ARG APP_VERSION
ARG APP_USER

# Use the base image
FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}

# Copy your application
COPY --from=builder /app/myservice /app/

# Set up user
USER ${APP_USER}

ENTRYPOINT ["/app/myservice"]
```

**Key points:**
- Use `ARG` for `BASE_IMAGE`, `BASE_TAG`, `BASE_DIGEST`
- These values come from `base_image` object in docker-matrix.json
- `BASE_TAG` already has variant's `tag_suffix` appended
- Use pinned digest for reproducible builds

### For Base Image Repositories

Wrap upstream images:

**Dockerfile.amd64:**
```dockerfile
ARG UPSTREAM_IMAGE
ARG UPSTREAM_TAG
ARG UPSTREAM_DIGEST

FROM ${UPSTREAM_IMAGE}:${UPSTREAM_TAG}@${UPSTREAM_DIGEST}

# Add customizations (certificates, timezone data, etc.)
COPY certs/ /etc/ssl/certs/
```

### Multi-Architecture Considerations

**Separate Dockerfiles per architecture:**
- `Dockerfile.amd64` - AMD64-specific build
- `Dockerfile.arm64` - ARM64-specific build

**Why not multi-stage?**
- Per-arch Dockerfiles allow architecture-specific optimizations
- Clearer build logs (one build per file)
- Better caching (separate cache per architecture)
- Consistent with project patterns

**Example differences:**

```dockerfile
# Dockerfile.amd64
FROM golang:1.21-alpine AS builder
RUN go build -o /app/myservice .

FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}
COPY --from=builder /app/myservice /app/

# Dockerfile.arm64 might need different compiler flags
FROM golang:1.21-alpine AS builder
RUN GOARCH=arm64 go build -o /app/myservice .

FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}
COPY --from=builder /app/myservice /app/
```

## Adding Workflows

### PR Validation Workflow

Create `.github/workflows/pr-validation.yml`:

```yaml
name: PR Validation

on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - '.ci/docker-matrix.json'
      - 'Dockerfile*'

permissions:
  contents: read
  packages: write
  pull-requests: write
  actions: read

jobs:
  validate:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: true
    secrets: inherit
```

**Triggers:**
- When PR is opened, updated, or reopened
- Only when build files change (optional optimization)

**Permissions:**
- `contents: read` - Checkout code
- `packages: write` - Push to GHCR
- `pull-requests: write` - Post comments
- `actions: read` - Read artifacts

### Release Workflow

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    branches:
      - release

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

**Triggers:**
- Push to `release` branch (typically from merged main)

**Concurrency:**
- Prevents multiple releases from running simultaneously
- Important for avoiding race conditions

## Testing Locally

### Validate Configuration

```bash
# Check JSON syntax
jq empty .ci/docker-matrix.json

# Validate against schema
ajv validate -s /tmp/schema.json -d .ci/docker-matrix.json
```

### Build Images Locally

```bash
# Source values from docker-matrix.json
BASE_IMAGE=$(jq -r '.base_image.image' .ci/docker-matrix.json)
BASE_TAG=$(jq -r '.base_image.tag' .ci/docker-matrix.json)
BASE_DIGEST=$(jq -r '.base_image.digest' .ci/docker-matrix.json)
APP_VERSION=$(jq -r '.variants[0].build_args.APP_VERSION' .ci/docker-matrix.json)

# Build AMD64
docker buildx build \
  --platform linux/amd64 \
  -f Dockerfile.amd64 \
  --build-arg BASE_IMAGE=$BASE_IMAGE \
  --build-arg BASE_TAG=$BASE_TAG \
  --build-arg BASE_DIGEST=$BASE_DIGEST \
  --build-arg APP_VERSION=$APP_VERSION \
  -t my-service:test-amd64 \
  .

# Build ARM64 (requires QEMU)
docker buildx build \
  --platform linux/arm64 \
  -f Dockerfile.arm64 \
  --build-arg BASE_IMAGE=$BASE_IMAGE \
  --build-arg BASE_TAG=$BASE_TAG \
  --build-arg BASE_DIGEST=$BASE_DIGEST \
  --build-arg APP_VERSION=$APP_VERSION \
  -t my-service:test-arm64 \
  .
```

### Run Tests Locally

```bash
# Set IMAGE_TAG environment variable
export IMAGE_TAG=my-service:test-amd64

# Run test script
./tests/test-service.sh
```

### Dry Run Workflow

Test the full workflow without pushing:

```yaml
# In pr-validation.yml, add dry_run parameter
jobs:
  validate:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: true
      dry_run: true  # Skip push to GHCR
    secrets: inherit
```

## First PR

### Step 1: Create Feature Branch

```bash
git checkout -b add-build-workflow
```

### Step 2: Add All Files

```bash
git add .ci/docker-matrix.json
git add .github/workflows/pr-validation.yml
git add .github/workflows/release.yml
git add Dockerfile.amd64 Dockerfile.arm64
git add tests/*.sh  # If you have tests
git commit -m "Add build-workflow integration"
```

### Step 3: Push and Create PR

```bash
git push origin add-build-workflow
gh pr create --title "Add build-workflow integration" --body "Integrates with runlix/build-workflow for multi-arch builds"
```

### Step 4: Monitor Build

Watch the PR validation workflow:
- Go to your PR on GitHub
- Click "Checks" tab
- Expand "validate / build-test-push"

Expected output:
- ✅ Schema validation passed
- ✅ Building images (one job per variant × platform)
- ✅ Tests passed
- ✅ Images pushed to GHCR
- 💬 Comment posted on PR with results

### Step 5: Fix Issues

If builds fail:
1. Check error message in workflow logs
2. Fix the issue locally
3. Push new commit
4. Workflow runs automatically

## First Release

### Step 1: Merge PR to Main

```bash
# After PR is approved
gh pr merge --merge  # Use merge commit (NOT squash!)
```

**Critical:** Must use merge commit (see [branch-protection.md](../docs/branch-protection.md))

### Step 2: Merge Main to Release

```bash
git checkout main
git pull
git checkout release
git pull
git merge main
git push origin release
```

Or use GitHub UI:
1. Create PR from `main` to `release`
2. Merge with merge commit

### Step 3: Monitor Release

Watch the release workflow:
- Go to Actions → Release workflow
- Check progress

Expected behavior:
- Looks for PR images (if found, copies them - fast)
- If not found, rebuilds from scratch (slower)
- Creates multi-arch manifests
- Deletes temporary platform tags
- Posts summary

### Step 4: Verify Images

```bash
# List all tags
gh api "orgs/runlix/packages/container/YOUR_SERVICE/versions" \
  --jq '.[] | .metadata.container.tags[]'

# Expected tags (for v5.2.1):
# v5.2.1 (multi-arch manifest)
# v5.2.1-debug (if you have debug variant)
# latest (only for default variant)
```

### Step 5: Test Deployed Image

```bash
# Pull multi-arch image (automatically selects correct architecture)
docker pull ghcr.io/runlix/your-service:v5.2.1

# Run locally
docker run --rm ghcr.io/runlix/your-service:v5.2.1
```

## Next Steps

- [Customization Options](./customization.md) - Advanced configuration
- [Branch Protection](./branch-protection.md) - Required repository settings
- [Troubleshooting](./troubleshooting.md) - Fix common issues
- [Migration Guide](./migration.md) - Migrate existing services
