# Migration Guide for Service Teams

Guide for migrating existing services to the build-workflow system.

## Table of Contents
- [Overview](#overview)
- [Pre-Migration Checklist](#pre-migration-checklist)
- [Migration Steps](#migration-steps)
- [Common Patterns](#common-patterns)
- [Rollback Plan](#rollback-plan)
- [Post-Migration](#post-migration)

## Overview

This guide helps you migrate from existing CI/CD workflows to the standardized build-workflow system.

### Benefits of Migration

- **Standardization**: All services use same workflow patterns
- **Multi-architecture**: Automatic AMD64 + ARM64 builds
- **Fast PR validation**: Images built once, promoted to release
- **Centralized maintenance**: Workflow updates benefit all services
- **Vulnerability scanning**: Automatic Trivy scans
- **Consistent tagging**: Predictable image naming

### What Changes

**Before migration:**
```yaml
# .github/workflows/build.yml (custom per service)
- Custom build logic
- Manual multi-arch setup
- Inconsistent tagging
- Separate PR and release workflows
```

**After migration:**
```yaml
# .github/workflows/pr-validation.yml (standardized)
uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main

# .github/workflows/release.yml (standardized)
uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main

# .ci/docker-matrix.json (declarative configuration)
{
  "version": "v5.2.1",
  "base_image": { ... },
  "variants": [ ... ]
}
```

## Pre-Migration Checklist

### 1. Review Current Build Process

Document your current setup:

```bash
# List current workflows
ls -la .github/workflows/

# List current Dockerfiles
ls -la Dockerfile*

# Check current image tags in GHCR
gh api "orgs/runlix/packages/container/$(basename $PWD)/versions" \
  --jq '.[] | .metadata.container.tags[]' | head -20
```

### 2. Identify Build Variants

List all image variants your service currently builds:
- Standard/production build
- Debug builds
- Alpine variants
- Minimal builds
- etc.

### 3. Note Build Arguments

Document all build arguments currently used:

```bash
# Extract ARG lines from Dockerfile
grep "^ARG" Dockerfile
```

### 4. Identify Test Requirements

- Do you have existing tests?
- What needs to be tested?
- Health check endpoints?
- Required environment variables?

### 5. Check Dependencies

- Base image used (distroless, alpine, etc.)
- External dependencies
- Build tools needed
- Runtime dependencies

## Migration Steps

### Step 1: Create Branch

```bash
git checkout -b migrate-to-build-workflow
```

### Step 2: Identify Service Type

**Type A: Service with wrapped base image**
- Uses runlix distroless images
- Has semantic versioning
- Examples: radarr, sonarr, prowlarr

**Type B: Base image repository**
- Wraps upstream distroless
- No semantic versioning
- Examples: distroless, base-images

### Step 3: Create docker-matrix.json

#### For Service Repositories (Type A)

```bash
mkdir -p .ci
```

Create `.ci/docker-matrix.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/runlix/build-workflow/main/schema/docker-matrix-schema.json",
  "version": "v5.2.1",
  "base_image": {
    "image": "ghcr.io/runlix/distroless",
    "tag": "abc1234",
    "digest": "sha256:6ae5fe659f28c6afe9cc2903aebc78a5c6ad3aaa3d9d0369760ac6aaea2529c8"
  },
  "variants": [
    {
      "name": "YOURSERVICE-latest",
      "tag_suffix": "",
      "default": true,
      "platforms": ["linux/amd64", "linux/arm64"],
      "dockerfiles": {
        "linux/amd64": "Dockerfile.amd64",
        "linux/arm64": "Dockerfile.arm64"
      },
      "build_args": {
        "APP_VERSION": "5.2.1.8988",
        "APP_USER": "yourservice"
      },
      "test_script": "tests/test.sh"
    }
  ]
}
```

**Key steps:**
1. Replace `YOURSERVICE` with your service name (lowercase, no spaces)
2. Update `version` to your current version
3. Update `base_image` to current distroless version you use
4. List all build args EXCEPT `BASE_IMAGE`, `BASE_TAG`, `BASE_DIGEST` (auto-injected)
5. Add test script path if you have tests

#### For Base Image Repositories (Type B)

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

**Note:** No `version` field for base images.

### Step 4: Split Dockerfiles by Architecture

If you currently have a single Dockerfile:

```bash
# Copy to architecture-specific files
cp Dockerfile Dockerfile.amd64
cp Dockerfile Dockerfile.arm64
```

Update Dockerfiles to use correct build args:

**Dockerfile.amd64 (for services):**
```dockerfile
# Remove these if present (they're auto-injected):
# ARG TARGETPLATFORM
# ARG BUILDPLATFORM
# ARG TARGETARCH

# Add these instead:
ARG BASE_IMAGE
ARG BASE_TAG
ARG BASE_DIGEST

# Your existing args:
ARG APP_VERSION
ARG APP_USER

FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}

# Rest of your Dockerfile...
```

**Dockerfile.arm64:** Similar changes for ARM64.

### Step 5: Create Test Script (Optional)

If you have tests, create `tests/test.sh`:

```bash
#!/bin/bash
set -e

echo "Testing $IMAGE_TAG"

# Start container
docker run -d --name test-container -p 8080:8080 $IMAGE_TAG

# Wait for startup
sleep 5

# Check health
curl -f http://localhost:8080/health || {
  echo "Health check failed"
  docker logs test-container
  exit 1
}

# Cleanup
docker stop test-container
docker rm test-container

echo "Tests passed"
```

Make it executable:
```bash
chmod +x tests/test.sh
```

### Step 6: Add New Workflows

Create `.github/workflows/pr-validation.yml`:

```yaml
name: PR Validation

on:
  pull_request:
    types: [opened, synchronize, reopened]

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

### Step 7: Disable Old Workflows

**Option A: Delete old workflows**
```bash
# Backup first
mkdir -p .old-workflows
mv .github/workflows/old-build.yml .old-workflows/

git add .old-workflows/
git add .github/workflows/
git commit -m "Remove old workflows (backed up in .old-workflows/)"
```

**Option B: Disable old workflows**

Add to old workflow files:
```yaml
on:
  workflow_dispatch:  # Only manual trigger
# Remove automatic triggers
```

### Step 8: Test Locally

```bash
# Validate configuration
npm install -g ajv-cli ajv-formats
curl -o /tmp/schema.json https://raw.githubusercontent.com/runlix/build-workflow/main/schema/docker-matrix-schema.json
ajv validate -s /tmp/schema.json -d .ci/docker-matrix.json

# Build locally
docker buildx build --platform linux/amd64 -f Dockerfile.amd64 -t test:local .

# Run tests
export IMAGE_TAG=test:local
./tests/test.sh
```

### Step 9: Commit and Push

```bash
git add .ci/
git add .github/workflows/
git add Dockerfile.amd64 Dockerfile.arm64
git add tests/
git commit -m "Migrate to build-workflow system

- Add docker-matrix.json configuration
- Split Dockerfiles by architecture
- Add standardized PR and release workflows
- Add test script"

git push origin migrate-to-build-workflow
```

### Step 10: Create PR

```bash
gh pr create \
  --title "Migrate to build-workflow system" \
  --body "Migrates CI/CD to standardized runlix/build-workflow.

**Changes:**
- New docker-matrix.json configuration
- Architecture-specific Dockerfiles
- Standardized workflows for PR and release
- Automated multi-arch builds

**Testing:**
- [ ] PR validation builds pass
- [ ] Images are pushed to GHCR
- [ ] Tests pass
- [ ] PR comment is posted

**Before merge:**
- [ ] Update branch protection rules (see migration guide)
- [ ] Verify old workflows are disabled"
```

### Step 11: Monitor First Build

Watch the PR validation workflow:
1. Go to PR → Checks tab
2. Expand "validate / build-test-push"
3. Check for errors

Common first-time issues:
- Missing build args in Dockerfile
- Test script failures
- Permission issues

### Step 12: Update Branch Protection

**Critical:** Before merging, update branch protection rules.

See [branch-protection.md](./branch-protection.md) for details.

Key change:
```bash
# Disable squash merge
gh repo edit --enable-merge-commit --disable-squash-merge --disable-rebase-merge
```

### Step 13: Merge PR

```bash
# After approvals and branch protection update
gh pr merge --merge  # Use merge commit!
```

### Step 14: Test Release

```bash
# Merge main to release
git checkout main && git pull
git checkout release && git pull
git merge main
git push origin release

# Watch release workflow
gh run watch
```

## Common Patterns

### Pattern 1: Migrating from Monolithic Dockerfile

**Before:**
```dockerfile
# Dockerfile
ARG TARGETARCH
FROM busybox AS builder-${TARGETARCH}
# ... architecture-specific logic ...
```

**After:**
```dockerfile
# Dockerfile.amd64
FROM busybox AS builder
# AMD64-specific logic

# Dockerfile.arm64
FROM busybox AS builder
# ARM64-specific logic
```

**Benefit:** Clearer, easier to maintain, better caching.

### Pattern 2: Multiple Variants

**Before:** Separate workflows for standard and debug builds.

**After:** Single workflow with variants:
```json
{
  "variants": [
    {
      "name": "service-latest",
      "tag_suffix": "",
      "default": true,
      ...
    },
    {
      "name": "service-debug",
      "tag_suffix": "-debug",
      "default": false,
      ...
    }
  ]
}
```

**Benefit:** Both variants built in parallel, consistent process.

### Pattern 3: Custom Test Scripts

**Before:** Tests embedded in workflow YAML.

**After:** Separate test script:
```bash
# tests/test.sh
#!/bin/bash
set -e
# All test logic here
```

**Benefit:** Can run locally, reusable, clearer workflow.

### Pattern 4: Version Bumping

**Before:** Manual version updates in multiple places.

**After:** Single version field in docker-matrix.json:
```json
{
  "version": "v5.2.1",
  ...
}
```

Update version:
```bash
# Update version
jq '.version = "v5.3.0"' .ci/docker-matrix.json > tmp.json
mv tmp.json .ci/docker-matrix.json

git commit -am "Bump version to v5.3.0"
```

## Rollback Plan

If migration causes issues, you can quickly rollback:

### Option 1: Revert PR

```bash
# If PR not yet merged
gh pr close PRNUMBER

# Restore old branch
git checkout main
```

### Option 2: Revert Merge

```bash
# If PR already merged
git revert MERGE_COMMIT_SHA
git push origin main
```

### Option 3: Re-enable Old Workflow

```bash
# Copy back old workflow
cp .old-workflows/old-build.yml .github/workflows/
git commit -m "Rollback: Re-enable old workflow"
git push
```

## Post-Migration

### Verify Everything Works

- [ ] PR builds complete successfully
- [ ] Images are pushed to GHCR with correct tags
- [ ] Tests pass
- [ ] PR comments are posted
- [ ] Release workflow runs without errors
- [ ] Multi-arch manifests are created
- [ ] Platform tags are deleted
- [ ] Images are pullable and work

### Clean Up

After verifying migration works:

```bash
# Remove old workflows backup
rm -rf .old-workflows/
git commit -am "Clean up old workflow backups"

# Remove old Dockerfile if you had one
git rm Dockerfile
git commit -m "Remove old monolithic Dockerfile"
```

### Document Service-Specific Details

Add service-specific notes to your README:

```markdown
## Building

This service uses the runlix/build-workflow system.

### Configuration
- Base image: ghcr.io/runlix/distroless:abc1234
- Variants: standard, debug
- Platforms: linux/amd64, linux/arm64

### Local Development
See [build-workflow documentation](https://github.com/runlix/build-workflow)
```

### Update Team

Notify your team:
- New workflow patterns
- Where to find build configuration (`.ci/docker-matrix.json`)
- How to test locally
- Link to documentation

## Next Steps

- [Customization Options](./customization.md) - Advanced configuration
- [Workflow Usage](./usage.md) - Daily workflow usage
- [Troubleshooting](./troubleshooting.md) - Fix issues
- [Branch Protection](./branch-protection.md) - Required settings
