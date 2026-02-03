# Integration Testing Guide

This guide walks through integration testing the build-workflow system with real repositories.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Test 1: Base Image Repository](#test-1-base-image-repository)
- [Test 2: Service Repository](#test-2-service-repository)
- [Validation Checklist](#validation-checklist)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Access
- [ ] Admin access to test repositories
- [ ] GitHub Actions write permissions
- [ ] GHCR packages write permissions

### Required Tools
```bash
# Install required tools
brew install gh jq yq crane

# Verify installations
gh --version
jq --version
yq --version
crane version
```

### Test Repositories Setup

**Option 1: Create test repositories**
```bash
# Create test base image repo
gh repo create runlix/test-distroless --public --clone

# Create test service repo
gh repo create runlix/test-service --public --clone
```

**Option 2: Use existing repositories** (recommended)
- Base image: `runlix/distroless` (if it exists)
- Service: `runlix/radarr` or `runlix/sonarr`

---

## Test 1: Base Image Repository

### Objective
Validate the PR validation workflow with a base image repository (no version field, no base_image object).

### Step 1: Prepare Repository

```bash
# Clone repository
git clone https://github.com/runlix/test-distroless.git
cd test-distroless

# Create branch structure
git checkout -b main
git push -u origin main

# Enable branch protection later
```

### Step 2: Add Configuration

Create `.ci/docker-matrix.json`:
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
        "UPSTREAM_DIGEST": "sha256:6ae5fe659f28c6afe9cc2903aebc78a5c6ad3aaa3d9d0369760ac6aaea2529c8"
      },
      "test_script": "tests/test.sh"
    }
  ]
}
```

### Step 3: Create Dockerfiles

**Dockerfile.amd64:**
```dockerfile
ARG UPSTREAM_IMAGE
ARG UPSTREAM_TAG
ARG UPSTREAM_DIGEST

FROM ${UPSTREAM_IMAGE}:${UPSTREAM_TAG}@${UPSTREAM_DIGEST}

# Add any customizations
COPY --chmod=0644 <<EOF /etc/build-info
{"arch": "amd64", "variant": "base"}
EOF
```

**Dockerfile.arm64:**
```dockerfile
ARG UPSTREAM_IMAGE
ARG UPSTREAM_TAG
ARG UPSTREAM_DIGEST

FROM ${UPSTREAM_IMAGE}:${UPSTREAM_TAG}@${UPSTREAM_DIGEST}

# Add any customizations
COPY --chmod=0644 <<EOF /etc/build-info
{"arch": "arm64", "variant": "base"}
EOF
```

### Step 4: Create Test Script

**tests/test.sh:**
```bash
#!/bin/bash
set -e

echo "Testing base image: $IMAGE_TAG"

# Check image exists
if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
  echo "❌ Image not found"
  exit 1
fi

# Check OCI labels
REVISION=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.revision"}}' "$IMAGE_TAG")
if [ -z "$REVISION" ]; then
  echo "❌ Missing OCI label: revision"
  exit 1
fi

echo "✅ Base image test passed"
```

```bash
chmod +x tests/test.sh
```

### Step 5: Add Workflows

**`.github/workflows/pr-validation.yml`:**
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

### Step 6: Commit and Create PR

```bash
git checkout -b test-build-workflow
git add .ci/ Dockerfile.* tests/ .github/
git commit -m "Add build-workflow integration"
git push -u origin test-build-workflow

# Create PR
gh pr create \
  --title "Test: Build-workflow integration" \
  --body "Integration test for build-workflow PR validation"
```

### Step 7: Monitor and Validate

```bash
# Watch workflow
gh run watch

# After completion, check results
gh run list --limit 5

# Verify PR comment posted
gh pr view --comments

# Check GHCR for images
gh api "orgs/runlix/packages/container/test-distroless/versions" \
  --jq '.[] | .metadata.container.tags[] | select(startswith("pr-"))'
```

### Step 8: Validation Checklist

- [ ] PR workflow triggered automatically
- [ ] Schema validation passed
- [ ] Matrix expansion created 2 jobs (amd64 + arm64)
- [ ] Both platform builds succeeded
- [ ] Test scripts executed successfully
- [ ] Images pushed to GHCR with format: `pr-{number}-{sha}-{arch}`
- [ ] PR comment posted with build summary
- [ ] No version field processed (SHA-based tagging)
- [ ] No base_image auto-injection (base image scenario)

### Expected GHCR Images

After successful PR build:
```
ghcr.io/runlix/test-distroless:
  pr-1-stable-amd64-abc1234
  pr-1-stable-arm64-abc1234
```

**Note:** Tag format is `pr-{number}-{tag_suffix}-{arch}-{sha}` for base images without version.

---

## Test 2: Service Repository

### Objective
Validate the PR validation workflow with a service repository (with version field and base_image object).

### Step 1: Prepare Repository

```bash
# Clone or create service repository
git clone https://github.com/runlix/test-service.git
cd test-service

# Create branch structure
git checkout -b main
git push -u origin main
```

### Step 2: Add Configuration

Create `.ci/docker-matrix.json`:
```json
{
  "$schema": "https://raw.githubusercontent.com/runlix/build-workflow/main/schema/docker-matrix-schema.json",
  "version": "v1.0.0",
  "base_image": {
    "image": "ghcr.io/runlix/test-distroless",
    "tag": "abc1234-stable",
    "digest": "sha256:6ae5fe659f28c6afe9cc2903aebc78a5c6ad3aaa3d9d0369760ac6aaea2529c8"
  },
  "variants": [
    {
      "name": "testapp-latest",
      "tag_suffix": "",
      "default": true,
      "platforms": ["linux/amd64", "linux/arm64"],
      "dockerfiles": {
        "linux/amd64": "Dockerfile.amd64",
        "linux/arm64": "Dockerfile.arm64"
      },
      "build_args": {
        "APP_VERSION": "1.0.0",
        "APP_USER": "testapp"
      },
      "test_script": "tests/test.sh"
    },
    {
      "name": "testapp-debug",
      "tag_suffix": "-debug",
      "default": false,
      "platforms": ["linux/amd64"],
      "dockerfiles": {
        "linux/amd64": "Dockerfile.debug.amd64"
      },
      "build_args": {
        "APP_VERSION": "1.0.0",
        "APP_USER": "testapp",
        "DEBUG": "true"
      }
    }
  ]
}
```

### Step 3: Create Dockerfiles

**Dockerfile.amd64:**
```dockerfile
# Auto-injected by workflow - DO NOT add to build_args
ARG BASE_IMAGE
ARG BASE_TAG
ARG BASE_DIGEST

# Application build args (from docker-matrix.json)
ARG APP_VERSION
ARG APP_USER

FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}

# Create simple test application
COPY --chmod=0755 <<'EOF' /app/testapp
#!/bin/sh
echo "Test Application v${APP_VERSION}"
echo "User: ${APP_USER}"
echo "Arch: amd64"
while true; do sleep 3600; done
EOF

USER ${APP_USER}
ENTRYPOINT ["/app/testapp"]
```

**Dockerfile.arm64:**
```dockerfile
ARG BASE_IMAGE
ARG BASE_TAG
ARG BASE_DIGEST
ARG APP_VERSION
ARG APP_USER

FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}

COPY --chmod=0755 <<'EOF' /app/testapp
#!/bin/sh
echo "Test Application v${APP_VERSION}"
echo "User: ${APP_USER}"
echo "Arch: arm64"
while true; do sleep 3600; done
EOF

USER ${APP_USER}
ENTRYPOINT ["/app/testapp"]
```

**Dockerfile.debug.amd64:**
```dockerfile
ARG BASE_IMAGE
ARG BASE_TAG
ARG BASE_DIGEST
ARG APP_VERSION
ARG APP_USER
ARG DEBUG

FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}

COPY --chmod=0755 <<'EOF' /app/testapp
#!/bin/sh
echo "Test Application v${APP_VERSION} (DEBUG)"
echo "User: ${APP_USER}"
echo "Debug: ${DEBUG}"
while true; do sleep 3600; done
EOF

USER ${APP_USER}
ENTRYPOINT ["/app/testapp"]
```

### Step 4: Create Test Script

**tests/test.sh:**
```bash
#!/bin/bash
set -e

echo "Testing service: $IMAGE_TAG"

# Check image exists
if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
  echo "❌ Image not found"
  exit 1
fi

# Check OCI labels
VERSION=$(docker inspect --format='{{index .Config.Labels "org.opencontainers.image.version"}}' "$IMAGE_TAG")
if [ "$VERSION" != "v1.0.0" ]; then
  echo "❌ Version label incorrect: $VERSION"
  exit 1
fi

# Start container briefly
docker run --rm -d --name test-container "$IMAGE_TAG" sleep 5
sleep 2

# Check if running
if docker ps | grep -q test-container; then
  docker stop test-container || true
  echo "✅ Service test passed"
else
  echo "❌ Container not running"
  exit 1
fi
```

```bash
chmod +x tests/test.sh
```

### Step 5: Add Workflow

Same PR validation workflow as base image test.

### Step 6: Commit and Create PR

```bash
git checkout -b test-build-workflow
git add .ci/ Dockerfile.* tests/ .github/
git commit -m "Add build-workflow integration"
git push -u origin test-build-workflow

gh pr create \
  --title "Test: Build-workflow integration (service)" \
  --body "Integration test for build-workflow with service repository"
```

### Step 7: Monitor and Validate

```bash
# Watch workflow
gh run watch

# Verify auto-injection
gh run view --log | grep "BASE_TAG"
# Should show: BASE_TAG=pr-1-abc1234 (with tag_suffix appended for debug variant)

# Check GHCR for images
gh api "orgs/runlix/packages/container/test-service/versions" \
  --jq '.[] | .metadata.container.tags[] | select(startswith("pr-"))'
```

### Step 8: Validation Checklist

- [ ] PR workflow triggered
- [ ] Schema validation passed for service config
- [ ] Version field extracted: `v1.0.0`
- [ ] base_image object extracted
- [ ] Matrix expansion created 3 jobs:
  - testapp-latest / amd64
  - testapp-latest / arm64
  - testapp-debug / amd64
- [ ] **Auto-injection verified:**
  - BASE_IMAGE = `ghcr.io/runlix/test-distroless`
  - BASE_TAG (standard) = `pr-1-abc1234` (tag + empty suffix)
  - BASE_TAG (debug) = `pr-1-abc1234-debug` (tag + "-debug" suffix)
  - BASE_DIGEST = `sha256:6ae5...`
- [ ] All builds succeeded
- [ ] Tests passed
- [ ] Images pushed with correct tags
- [ ] PR comment shows all 3 images
- [ ] OCI labels include version

### Expected GHCR Images

After successful PR build:
```
ghcr.io/runlix/test-service:
  pr-2-v1.0.0-stable-amd64-def5678      (standard variant with tag_suffix "stable")
  pr-2-v1.0.0-stable-arm64-def5678      (standard variant, ARM)
  pr-2-v1.0.0-debug-amd64-def5678       (debug variant)
```

**Note:** Tag format is `pr-{number}-{version}-{tag_suffix}-{arch}-{sha}` for versioned services.

---

## Validation Checklist

### Critical Features to Test

#### 1. Schema Validation
- [ ] Valid configs pass validation
- [ ] Invalid configs fail with clear errors
- [ ] Schema downloaded from correct URL

#### 2. Auto-Injection (Services Only)
- [ ] BASE_IMAGE injected correctly
- [ ] BASE_TAG has tag_suffix appended
- [ ] BASE_DIGEST injected correctly
- [ ] Original build_args preserved
- [ ] No manual BASE_* in docker-matrix.json

#### 3. Tag Generation
- [ ] PR tags format: `pr-{number}-{sha}{tag_suffix}-{arch}`
- [ ] SHA is 7-character short SHA
- [ ] tag_suffix correctly appended
- [ ] Architecture correctly appended

#### 4. Matrix Expansion
- [ ] Correct number of jobs created
- [ ] Each variant × platform combination present
- [ ] Disabled variants skipped
- [ ] Platform-Dockerfile mapping correct

#### 5. Build Process
- [ ] QEMU setup for cross-platform builds
- [ ] BuildKit caching works
- [ ] OCI labels applied
- [ ] Build args passed correctly

#### 6. Test Execution
- [ ] Test scripts receive IMAGE_TAG env var
- [ ] 10-minute timeout enforced
- [ ] Test failures block PR
- [ ] Test success allows merge

#### 7. Image Push
- [ ] Images pushed to correct registry
- [ ] Retry logic works (3 attempts)
- [ ] Push failures block PR
- [ ] Dry run mode skips push

#### 8. PR Comments
- [ ] Comment posted on PR
- [ ] Shows all built images
- [ ] Updates on subsequent pushes
- [ ] Includes build status
- [ ] Links to workflow run

#### 9. Vulnerability Scanning
- [ ] Trivy scan runs
- [ ] SARIF output created
- [ ] Scan failures don't block (continue-on-error)
- [ ] Results available in artifacts

#### 10. Summary Job
- [ ] Runs even if builds fail
- [ ] Downloads all artifacts
- [ ] Generates manifest.json
- [ ] Reports overall status

---

## Troubleshooting

### Issue: Schema Validation Fails

**Symptom:** Schema validation step fails with "data should have required property"

**Solution:**
```bash
# Validate locally first
npm install -g ajv-cli ajv-formats
curl -o /tmp/schema.json https://raw.githubusercontent.com/runlix/build-workflow/main/schema/docker-matrix-schema.json
ajv validate -s /tmp/schema.json -d .ci/docker-matrix.json
```

### Issue: Build Fails with Missing BASE_IMAGE

**Symptom:** Build fails: "BASE_IMAGE: unset variable"

**Cause:** Dockerfile references BASE_IMAGE but it's not in build_args

**Solution:** Remove BASE_IMAGE, BASE_TAG, BASE_DIGEST from build_args in docker-matrix.json. They're auto-injected.

### Issue: PR Comment Not Posted

**Symptom:** Build succeeds but no comment on PR

**Solution:**
1. Check permissions: `pull-requests: write` required
2. Check workflow logs for API errors
3. Verify `secrets: inherit` in caller workflow

### Issue: Images Not Pushed

**Symptom:** Build succeeds but images not in GHCR

**Solution:**
1. Check `dry_run: false` in workflow
2. Verify `packages: write` permission
3. Check GHCR authentication
4. Review push step logs for errors

### Issue: Auto-Injection Not Working

**Symptom:** Build fails: "BASE_TAG: no such build arg"

**Diagnostic:**
```bash
# Check matrix expansion in workflow logs
# Look for: "Expanding matrix with auto-injection"
# Verify build_args includes BASE_IMAGE, BASE_TAG, BASE_DIGEST
```

**Solution:** Ensure base_image object is present and correctly formatted in docker-matrix.json

---

## Success Criteria

Integration testing is successful when:

### Base Image Repository
✅ PR builds complete in <10 minutes
✅ Both platforms (amd64, arm64) build successfully
✅ Tests pass
✅ Images pushed to GHCR with correct tags
✅ PR comment shows build results
✅ No version-specific logic applied

### Service Repository
✅ PR builds complete in <15 minutes
✅ All variants × platforms build successfully
✅ Auto-injection works correctly (verify in logs)
✅ tag_suffix appended to BASE_TAG
✅ Tests pass for all variants
✅ Images pushed with version in OCI labels
✅ PR comment shows all images
✅ Default variant marked correctly

### Overall System
✅ Schema validation catches errors
✅ Fail-fast stops all builds on first failure
✅ Vulnerability scans don't block builds
✅ Retry logic handles transient push failures
✅ Documentation matches implementation
✅ No manual intervention required

---

## Next Steps

After successful integration testing:

1. **Document learnings** - Add any discovered issues to troubleshooting guide
2. **Update examples** - Refine examples based on real-world usage
3. **Performance baseline** - Record build times for future optimization
4. **Rollout plan** - Begin migrating production services
5. **Monitoring setup** - Add alerts for build failures

## Support

If integration tests fail:
1. Review troubleshooting section above
2. Check [docs/troubleshooting.md](./troubleshooting.md)
3. Search [issues](https://github.com/runlix/build-workflow/issues)
4. Create new issue with:
   - Repository name
   - Workflow run URL
   - docker-matrix.json content
   - Error logs
