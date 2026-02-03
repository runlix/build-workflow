# Dependencies Documentation

This document maps all dependencies between files in the build-workflow system, external dependencies, and requirements for service repositories.

---

## Table of Contents

1. [System Architecture Overview](#system-architecture-overview)
2. [File Dependency Map](#file-dependency-map)
3. [External Dependencies](#external-dependencies)
4. [Service Repository Requirements](#service-repository-requirements)
5. [Runtime Dependencies](#runtime-dependencies)
6. [Version Compatibility](#version-compatibility)

---

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Service Repository                        │
│  ┌────────────────────┐         ┌──────────────────────┐   │
│  │ .ci/               │         │ .github/workflows/   │   │
│  │  docker-matrix.json├────────►│  pr-validation.yml   │   │
│  │                    │         │  release.yml         │   │
│  └────────────────────┘         └──────────┬───────────┘   │
│                                             │               │
└─────────────────────────────────────────────┼───────────────┘
                                              │
                                              │ workflow_call
                                              │
┌─────────────────────────────────────────────▼───────────────┐
│                build-workflow Repository                     │
│  ┌────────────────────────────────────────────────────┐    │
│  │ .github/workflows/build-images-rebuild.yml (Main Workflow) │    │
│  │                                                      │    │
│  │ Depends on:                                         │    │
│  │  • schema/docker-matrix-schema.json                 │    │
│  │  • GitHub Secrets (GITHUB_TOKEN, TELEGRAM_*)       │    │
│  │  • External Actions (checkout, buildx, crane, etc) │    │
│  │  • External APIs (GHCR, Telegram)                  │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ .github/workflows/test-workflow.yml                │    │
│  │                                                      │    │
│  │ Depends on:                                         │    │
│  │  • test-fixtures/**/docker-matrix.json             │    │
│  │  • test-fixtures/**/Dockerfile.*                    │    │
│  │  • test-fixtures/**/test*.sh                        │    │
│  │  • schema/docker-matrix-schema.json                 │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  Documentation Files (no runtime dependencies)              │
│  • docs/notifications.md                                    │
│  • planing/secrets.md                                       │
│  • planing/pr-flow.md                                       │
│  • planing/merge-flow.md                                    │
│  • DEPENDENCIES.md (this file)                             │
└──────────────────────────────────────────────────────────────┘
```

---

## File Dependency Map

### `.github/workflows/build-images-rebuild.yml`

**Primary workflow file** - Reusable workflow for building multi-arch Docker images.

#### Internal Dependencies

| File | Type | Purpose | Used In |
|------|------|---------|---------|
| `schema/docker-matrix-schema.json` | JSON Schema | Validate service configuration | Lines 69-84 (schema validation step) |

#### Service Repository Dependencies

| File/Directory | Required | Purpose |
|----------------|----------|---------|
| `.ci/docker-matrix.json` | ✅ Yes | Build configuration (variants, platforms, build args) |
| `Dockerfile*` | ✅ Yes | One or more Dockerfiles for each platform |
| `.ci/test*.sh` | ⚠️ Optional | Test scripts for built images |

#### GitHub Secrets Dependencies

| Secret | Required | Used In | Purpose |
|--------|----------|---------|---------|
| `GITHUB_TOKEN` | ✅ Yes (auto) | Lines 310, 437, 895 | Registry access, API calls, checkout |
| `RUNLIX_APP_ID` | ✅ Yes | Lines 1013 | GitHub App ID for releases.json commits |
| `RUNLIX_PRIVATE_KEY` | ✅ Yes | Lines 1014 | GitHub App private key for releases.json commits |
| `TELEGRAM_BOT_TOKEN` | ⚠️ Optional | Lines 1151, 1158 | Send release notifications |
| `TELEGRAM_CHAT_ID` | ⚠️ Optional | Lines 1151, 1159 | Notification recipient |

#### External GitHub Actions Dependencies

| Action | Version | Used In | Purpose |
|--------|---------|---------|---------|
| `actions/checkout@v4` | v4 | Lines 55, 254, 606, 885, 1023 | Checkout repository code |
| `actions/setup-node@v4` | v4 | Line 62 | Install Node.js for ajv-cli |
| `docker/setup-qemu-action@v3` | v3 | Lines 424-425 | Emulate non-native architectures |
| `docker/setup-buildx-action@v3` | v3 | Lines 428-429 | Enable Docker Buildx |
| `docker/login-action@v3` | v3 | Lines 432-437, 891-895 | Authenticate to GHCR |
| `actions/cache@v4` | v4 | Lines 440-446 | Cache Docker build layers |
| `nick-fields/retry@v2` | v2 | Lines 526-531 | Retry image push operations |
| `aquasecurity/trivy-action@master` | master | Lines 513-520 | Vulnerability scanning |
| `actions/github-script@v7` | v7 | Lines 552-563, 793-829 | Comment on PRs, update comments |
| `actions/upload-artifact@v4` | v4 | Lines 544-549, 567-572, 585-588, 833-837, 1103-1107 | Upload workflow artifacts |
| `actions/download-artifact@v4` | v4 | Lines 609-612, 898-903 | Download workflow artifacts |
| `imjasonh/setup-crane@v0.1` | v0.1 | Lines 257-258, 888 | Install crane CLI tool |
| `actions/create-github-app-token@v2` | v2 | Lines 1010-1016 | Generate GitHub App token for releases.json |

#### External Tool Dependencies

| Tool | Purpose | Installation | Used In |
|------|---------|--------------|---------|
| `npm` / `ajv-cli` | JSON Schema validation | `npm install -g ajv-cli ajv-formats` | Line 67 |
| `jq` | JSON parsing and manipulation | Pre-installed on ubuntu-latest | Lines 92-231 (matrix expansion), 640-650 (manifest), 688-690 (SARIF parsing), 917-971 (manifest creation), 1046-1059 (releases.json) |
| `docker` | Container operations | Pre-installed on ubuntu-latest | Lines 473-495 (build), 531 (push), 966-968 (imagetools) |
| `crane` | Registry operations (copy, delete, digest) | `imjasonh/setup-crane` action | Lines 362 (digest check), 415 (copy), 994 (delete) |
| `gh` (GitHub CLI) | Query GitHub API | Pre-installed on ubuntu-latest | Lines 269-299 (find merged PR) |
| `curl` | HTTP requests (Telegram API) | Pre-installed on ubuntu-latest | Lines 1158-1162 (send notification) |
| `git` | Version control operations | Pre-installed on ubuntu-latest | Lines 1069-1100 (commit releases.json) |

#### External API Dependencies

| API | Purpose | Authentication | Used In |
|-----|---------|----------------|---------|
| GitHub Container Registry (ghcr.io) | Store Docker images | `GITHUB_TOKEN` | Lines 437 (login), 531 (push), 895 (login) |
| GitHub API (api.github.com) | Find merged PRs, create comments | `GITHUB_TOKEN` or `APP_TOKEN` | Lines 269-299 (gh pr list), 793-829 (PR comments), 1010-1016 (app token) |
| Telegram Bot API (api.telegram.org) | Send notifications | `TELEGRAM_BOT_TOKEN` | Lines 1158-1162 (sendMessage) |

#### Runtime Environment Dependencies

| Requirement | Version | Source |
|-------------|---------|--------|
| Ubuntu Linux | latest | `runs-on: ubuntu-latest` |
| Docker | Pre-installed | GitHub Actions runner |
| Node.js | 20 | `actions/setup-node@v4` |
| jq | Pre-installed | GitHub Actions runner |
| git | Pre-installed | GitHub Actions runner |
| curl | Pre-installed | GitHub Actions runner |

---

### `.github/workflows/test-workflow.yml`

**Test workflow** - Validates build-images-rebuild.yml with test fixtures.

#### Internal Dependencies

| File/Directory | Type | Purpose | Used In |
|----------------|------|---------|---------|
| `schema/docker-matrix-schema.json` | JSON Schema | Validate test configurations | Lines 63, 138 |
| `test-fixtures/base-image/docker-matrix.json` | Test Config | Base image test configuration | Line 50 |
| `test-fixtures/base-image/Dockerfile.amd64` | Dockerfile | Base image build (AMD64) | Line 76 |
| `test-fixtures/base-image/Dockerfile.debug.amd64` | Dockerfile | Debug base image build (AMD64) | Line 97 |
| `test-fixtures/base-image/test.sh` | Test Script | Verify base image | Line 90 |
| `test-fixtures/base-image/test-debug.sh` | Test Script | Verify debug base image | Line 111 |
| `test-fixtures/service/docker-matrix.json` | Test Config | Service test configuration | Line 125 |
| `test-fixtures/service/Dockerfile.amd64` | Dockerfile | Service build (AMD64) | Line 151 |
| `test-fixtures/service/Dockerfile.debug.amd64` | Dockerfile | Debug service build (AMD64) | Line 176 |
| `test-fixtures/service/test.sh` | Test Script | Verify service image | Line 169 |
| `test-fixtures/service/test-debug.sh` | Test Script | Verify debug service image | Line 195 |

#### External GitHub Actions Dependencies

| Action | Version | Purpose | Used In |
|--------|---------|---------|---------|
| `actions/checkout@v4` | v4 | Checkout repository code | Lines 44, 119 |
| `actions/setup-node@v4` | v4 | Install Node.js for ajv-cli | Lines 53, 128 |
| `docker/setup-qemu-action@v3` | v3 | Emulate architectures | Lines 66, 141 |
| `docker/setup-buildx-action@v3` | v3 | Enable Docker Buildx | Lines 69, 144 |

#### External Tool Dependencies

| Tool | Purpose | Installation | Used In |
|------|---------|--------------|---------|
| `npm` / `ajv-cli` | JSON Schema validation | `npm install -g ajv-cli ajv-formats` | Lines 58, 133 |
| `docker` | Container operations | Pre-installed | Lines 74-85, 95-106, 149-164, 174-190 |
| `bash` | Execute test scripts | Pre-installed | Lines 90, 111, 169, 195 |

#### No External API Dependencies
Test workflow runs entirely offline (no registry push, no notifications).

---

### `schema/docker-matrix-schema.json`

**JSON Schema definition** - Validates docker-matrix.json structure.

#### Dependencies
**None** - This is a standalone JSON Schema definition file.

#### Used By

| File | Purpose |
|------|---------|
| `.github/workflows/build-images-rebuild.yml` | Validate service repository configuration |
| `.github/workflows/test-workflow.yml` | Validate test fixture configurations |
| Service repositories (via build-images-rebuild.yml) | Ensure valid configuration before build |

#### Schema Validation Tool Dependency

| Tool | Purpose |
|------|---------|
| `ajv-cli` | JSON Schema validator (installed via npm) |

---

### `test-fixtures/**/docker-matrix.json`

**Test configurations** - Example configurations for testing the workflow.

#### Dependencies
- Must conform to `schema/docker-matrix-schema.json`

#### Used By
- `.github/workflows/test-workflow.yml` (copied to `.ci/docker-matrix.json` at runtime)

---

### `test-fixtures/**/Dockerfile.*`

**Test Dockerfiles** - Minimal Dockerfiles for build testing.

#### Dependencies

| Dockerfile | Build Args Required | Base Image |
|------------|---------------------|------------|
| `base-image/Dockerfile.amd64` | `UPSTREAM_IMAGE`, `UPSTREAM_TAG`, `UPSTREAM_DIGEST` | `gcr.io/distroless/base-debian12` |
| `base-image/Dockerfile.debug.amd64` | `UPSTREAM_IMAGE`, `UPSTREAM_TAG`, `UPSTREAM_DIGEST` | `gcr.io/distroless/base-debian12` |
| `service/Dockerfile.amd64` | `BASE_IMAGE`, `BASE_TAG`, `BASE_DIGEST`, `APP_VERSION`, `APP_USER`, `APP_PORT` | Custom base image |
| `service/Dockerfile.debug.amd64` | Same as above + `DEBUG_ENABLED` | Custom base image |

#### Used By
- `.github/workflows/test-workflow.yml` (built and tested)

---

### `test-fixtures/**/test*.sh`

**Test scripts** - Verify built images work correctly.

#### Dependencies

| Script | Environment Variable | Purpose |
|--------|---------------------|---------|
| `test.sh` | `IMAGE_TAG` | Docker image to test |
| `test-debug.sh` | `IMAGE_TAG` | Docker image to test |

**External Dependencies**:
- `docker` CLI (to run containers)
- `bash` shell
- Common Linux utilities (`echo`, `sleep`, etc.)

#### Used By
- `.github/workflows/test-workflow.yml` (executed after builds)

---

### Documentation Files

These files have **no runtime dependencies** and are for human reference only.

| File | Purpose | Dependencies |
|------|---------|--------------|
| `docs/notifications.md` | Telegram notification setup guide | None |
| `planing/secrets.md` | GitHub Secrets configuration guide | None |
| `planing/pr-flow.md` | PR validation flow specification | None |
| `planing/merge-flow.md` | Merge/release flow specification | None |
| `planing/merge-flow-prd.yaml` | Implementation task list (completed) | None |
| `VALIDATION_REPORT.md` | Implementation validation results | None |
| `IMPLEMENTATION_COMPLETE.md` | Implementation summary | None |
| `DEPENDENCIES.md` | This file | None |
| `releases.json.example` | Example releases.json structure | None |

---

## External Dependencies

### GitHub Actions Marketplace

All external actions are pinned to specific versions for stability.

| Action | Repository | License | Stability |
|--------|-----------|---------|-----------|
| `actions/checkout@v4` | github.com/actions/checkout | MIT | ✅ Stable |
| `actions/setup-node@v4` | github.com/actions/setup-node | MIT | ✅ Stable |
| `docker/setup-qemu-action@v3` | github.com/docker/setup-qemu-action | Apache-2.0 | ✅ Stable |
| `docker/setup-buildx-action@v3` | github.com/docker/setup-buildx-action | Apache-2.0 | ✅ Stable |
| `docker/login-action@v3` | github.com/docker/login-action | Apache-2.0 | ✅ Stable |
| `actions/cache@v4` | github.com/actions/cache | MIT | ✅ Stable |
| `nick-fields/retry@v2` | github.com/nick-fields/retry | MIT | ✅ Stable |
| `aquasecurity/trivy-action@master` | github.com/aquasecurity/trivy-action | Apache-2.0 | ⚠️ Tracks master |
| `actions/github-script@v7` | github.com/actions/github-script | MIT | ✅ Stable |
| `actions/upload-artifact@v4` | github.com/actions/upload-artifact | MIT | ✅ Stable |
| `actions/download-artifact@v4` | github.com/actions/download-artifact | MIT | ✅ Stable |
| `imjasonh/setup-crane@v0.1` | github.com/imjasonh/setup-crane | Apache-2.0 | ✅ Stable |

**Note**: `trivy-action@master` tracks the master branch. Consider pinning to a specific commit SHA for production use.

### NPM Packages

| Package | Version | Purpose | License |
|---------|---------|---------|---------|
| `ajv-cli` | latest | JSON Schema validation CLI | MIT |
| `ajv-formats` | latest | Additional format validators for ajv | MIT |

Installed globally via: `npm install -g ajv-cli ajv-formats`

### External APIs

| API | Endpoint | Rate Limits | Authentication |
|-----|----------|-------------|----------------|
| **GitHub Container Registry** | `ghcr.io` | [GitHub Packages limits](https://docs.github.com/en/packages/learn-github-packages/about-github-packages#about-billing-for-github-packages) | `GITHUB_TOKEN` |
| **GitHub API** | `api.github.com` | [5,000 requests/hour](https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting) | `GITHUB_TOKEN` |
| **Telegram Bot API** | `api.telegram.org` | [30 messages/second](https://core.telegram.org/bots/faq#how-can-i-message-all-of-my-bot-39s-subscribers-at-once) | `TELEGRAM_BOT_TOKEN` |

### Base Container Images

Default test fixtures use:

| Image | Registry | Purpose | Digest Pinning |
|-------|----------|---------|----------------|
| `gcr.io/distroless/base-debian12:latest` | Google Container Registry | Minimal base image | ✅ Recommended |
| `gcr.io/distroless/base-debian12:debug` | Google Container Registry | Debug base with shell | ✅ Recommended |

**Note**: Service repositories can use any base image.

---

## Service Repository Requirements

To use the build-workflow system, service repositories must provide:

### Required Files

```
service-repository/
├── .ci/
│   └── docker-matrix.json          # ✅ REQUIRED: Build configuration
├── .github/
│   └── workflows/
│       ├── pr-validation.yml       # ✅ REQUIRED: Calls build-images-rebuild.yml (PR mode)
│       └── release.yml             # ✅ REQUIRED: Calls build-images-rebuild.yml (release mode)
└── Dockerfile*                     # ✅ REQUIRED: One or more Dockerfiles
```

### docker-matrix.json Structure

**Minimum required fields**:
```json
{
  "variants": [
    {
      "name": "default",
      "platforms": ["linux/amd64", "linux/arm64"],
      "dockerfiles": {
        "linux/amd64": "Dockerfile.amd64",
        "linux/arm64": "Dockerfile.arm64"
      },
      "tag_suffix": "",
      "build_args": {}
    }
  ]
}
```

**For services (with base image)**:
```json
{
  "version": "v1.2.3",
  "base_image": {
    "image": "ghcr.io/runlix/distroless",
    "tag": "abc1234",
    "digest": "sha256:..."
  },
  "variants": [...]
}
```

**Validation**: Must pass `schema/docker-matrix-schema.json` validation.

### Dockerfiles

**Requirements**:
- One Dockerfile per platform (or multi-platform Dockerfile)
- Must be referenced in `docker-matrix.json` → `variants[].dockerfiles`
- Should support standard OCI labels
- Build args will be auto-injected if `base_image` is specified

**Auto-injected build args** (if `base_image` is defined):
- `BASE_IMAGE` - From `base_image.image`
- `BASE_TAG` - From `base_image.tag` + variant's `tag_suffix`
- `BASE_DIGEST` - From `base_image.digest`

### Caller Workflows

**pr-validation.yml** (minimum):
```yaml
name: PR Validation

on:
  pull_request:
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

**release.yml** (minimum):
```yaml
name: Release

on:
  push:
    branches:
      - release

permissions:
  contents: write       # Update releases.json
  packages: write       # Push images
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

### Optional Files

```
service-repository/
├── .ci/
│   └── test*.sh                    # ⚠️ OPTIONAL: Test scripts
└── releases.json                   # ⚠️ AUTO-GENERATED: Created by workflow
```

**Test scripts**:
- Specified in `docker-matrix.json` → `variants[].test_script`
- Receives `IMAGE_TAG` environment variable
- Must exit 0 on success, non-zero on failure
- Timeout: 10 minutes

### GitHub Secrets

Service repositories must configure:

| Secret | Required | Setup |
|--------|----------|-------|
| `GITHUB_TOKEN` | ✅ Yes (automatic) | No action needed |
| `TELEGRAM_BOT_TOKEN` | ⚠️ Optional | `gh secret set TELEGRAM_BOT_TOKEN --body "TOKEN"` |
| `TELEGRAM_CHAT_ID` | ⚠️ Optional | `gh secret set TELEGRAM_CHAT_ID --body "CHAT_ID"` |

See `planing/secrets.md` for detailed setup instructions.

---

## Runtime Dependencies

### Job Execution Flow

```
┌────────────────────────────────────────────────────────────┐
│                       PR Mode                               │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  1. parse-matrix                                           │
│     ├─ Depends on: .ci/docker-matrix.json                 │
│     ├─ Validates with: schema/docker-matrix-schema.json   │
│     └─ Outputs: matrix, version                           │
│                                                             │
│  2. promote-or-build (parallel matrix)                     │
│     ├─ Depends on: parse-matrix outputs                   │
│     ├─ Builds with: Dockerfile* from matrix               │
│     ├─ Tests with: test scripts (if specified)            │
│     ├─ Scans with: trivy                                  │
│     └─ Uploads: manifest fragments, SARIF files           │
│                                                             │
│  3. summary                                                 │
│     ├─ Depends on: promote-or-build artifacts             │
│     ├─ Downloads: All manifest-* and failure-* artifacts  │
│     ├─ Generates: consolidated manifest.json              │
│     └─ Comments on: PR with results                       │
│                                                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│                     Release Mode                            │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  1. parse-matrix                                           │
│     └─ Same as PR mode                                     │
│                                                             │
│  2. promote-or-build (parallel matrix)                     │
│     ├─ Depends on: parse-matrix outputs                   │
│     ├─ Finds PR using: gh CLI + GITHUB_TOKEN              │
│     ├─ Checks PR image using: crane                       │
│     ├─ IF EXISTS: Promotes via crane copy                 │
│     ├─ IF NOT: Rebuilds from source                       │
│     └─ Uploads: platform-tag-* artifacts                  │
│                                                             │
│  3. summary                                                 │
│     └─ Same as PR mode (logs only, no PR comment)         │
│                                                             │
│  4. create-manifests                                        │
│     ├─ Depends on: promote-or-build artifacts             │
│     ├─ Downloads: All platform-tag-* artifacts            │
│     ├─ Creates: Multi-arch manifests via docker buildx    │
│     ├─ Deletes: Temporary platform tags via crane         │
│     ├─ Updates: releases.json in main branch              │
│     └─ Notifies: Telegram (if configured)                 │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

### Artifact Dependencies

**PR Mode**:
```
promote-or-build jobs → manifest-{variant}-{arch} artifacts
                     → failure-{variant}-{arch} artifacts
                     ↓
summary job ← Downloads all artifacts
          → Generates build-manifest artifact
          → Comments on PR
```

**Release Mode**:
```
promote-or-build jobs → platform-tag-{variant}-{arch} artifacts
                     ↓
create-manifests job ← Downloads all platform tags
                    → Creates multi-arch manifests
                    → Deletes platform tags
                    → Updates releases.json
                    → Sends notification
                    → Uploads manifests-created artifact
```

---

## Version Compatibility

### Workflow Compatibility

| Workflow Version | Min GitHub Actions Version | Max Tested |
|------------------|----------------------------|------------|
| build-images-rebuild.yml v1.0 | 2020 (any modern version) | 2025 |
| test-workflow.yml v1.0 | 2020 (any modern version) | 2025 |

### Action Version Compatibility

All actions use `@v3` or `@v4` tags (major version pinning).

**Recommended**: Pin to exact commit SHA for production:
```yaml
# Instead of:
uses: actions/checkout@v4

# Use:
uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

### Docker Buildx Compatibility

| Feature | Min Buildx Version | Notes |
|---------|-------------------|-------|
| Multi-platform builds | v0.8.0+ | Required for `--platform` |
| Imagetools create | v0.10.0+ | Required for manifest creation |
| OCI labels | v0.8.0+ | Standard across all versions |

### Schema Version

| docker-matrix.schema.json | Breaking Changes |
|---------------------------|------------------|
| v1.0 (current) | Initial version |

**Future versions**: Will increment major version for breaking changes.

### API Compatibility

| API | Current Version | Compatibility |
|-----|----------------|---------------|
| GitHub API | REST v3 | Stable, backward compatible |
| Docker Registry API | v2 | Stable since 2015 |
| Telegram Bot API | 7.0+ | Backward compatible, new features added |

---

## Dependency Update Strategy

### Action Updates

**Monthly review** recommended:
```bash
# Check for action updates
gh api /repos/actions/checkout/releases/latest
gh api /repos/docker/setup-buildx-action/releases/latest
```

**Breaking change monitoring**:
- Subscribe to action repositories
- Review changelogs before updating
- Test in development environment first

### Tool Updates

**Automated via GitHub Actions runner**:
- `docker`, `jq`, `git`, `curl` - Updated with runner image
- `npm` packages - Installed fresh each run (`latest`)

**Manual updates required**:
- Action version tags (`@v4` → `@v5`)
- Base container images (if pinned)

### Schema Updates

**Backward compatibility commitment**:
- Minor version: Add optional fields only
- Major version: Breaking changes allowed

**Migration path**:
- Document breaking changes in schema comments
- Provide migration guide
- Announce via GitHub Discussions

---

## Troubleshooting Dependencies

### Common Dependency Issues

#### Issue: Action version not found

**Error**: `Unable to resolve action 'actions/checkout@v5'`

**Cause**: Version tag doesn't exist yet

**Solution**: Check latest version and update:
```yaml
uses: actions/checkout@v4  # Use existing version
```

#### Issue: Schema validation fails

**Error**: `ajv validation failed`

**Cause**: `docker-matrix.json` doesn't match schema

**Solution**: Validate locally:
```bash
npx ajv-cli validate -s schema/docker-matrix-schema.json -d .ci/docker-matrix.json
```

#### Issue: Missing Dockerfile

**Error**: `Dockerfile not found: Dockerfile.amd64`

**Cause**: Dockerfile path in `docker-matrix.json` is incorrect

**Solution**: Verify file exists and path matches:
```bash
ls -la Dockerfile.amd64
# Update docker-matrix.json if path is wrong
```

#### Issue: GHCR authentication fails

**Error**: `denied: permission_denied: write_package`

**Cause**: Caller workflow missing `packages: write` permission

**Solution**: Add to caller workflow:
```yaml
permissions:
  packages: write
```

#### Issue: Telegram notification fails

**Error**: `Unauthorized` or `chat not found`

**Cause**: Invalid token or chat ID

**Solution**: Test manually:
```bash
curl -s "https://api.telegram.org/bot$TOKEN/getMe"
curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" -d "text=Test"
```

---

## Dependency Security

### Dependabot Configuration

**Recommended** `.github/dependabot.yml` for build-workflow repository:

```yaml
version: 2
updates:
  # GitHub Actions dependencies
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "github-actions"

  # Docker base images (if using Dockerfile in repo)
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "docker"
```

### Security Scanning

**Workflow includes**:
- Trivy vulnerability scanning (lines 449-457)
- SARIF output for GitHub Security tab
- PR comments with CVE counts

**Recommended additions**:
- CodeQL for workflow analysis
- Secret scanning for leaked tokens
- Dependency review action

### Supply Chain Security

**Best practices**:
- ✅ Pin action versions (`@v4`, not `@main`)
- ✅ Use official GitHub Actions when possible
- ✅ Review third-party actions before use
- ✅ Use commit SHAs for critical actions
- ✅ Enable GitHub Security features

**Action provenance**:
```yaml
# Verify action is from official source
uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
# SHA ensures exact version, prevents tag hijacking
```

---

## Summary

### Critical Dependencies (Required for Operation)

1. **Service Repository Files**:
   - `.ci/docker-matrix.json` (validated by schema)
   - `Dockerfile*` (referenced in matrix)
   - Caller workflows (pr-validation.yml, release.yml)

2. **GitHub Infrastructure**:
   - `GITHUB_TOKEN` (automatic)
   - GitHub Container Registry (ghcr.io)
   - GitHub API (api.github.com)

3. **GitHub Actions**:
   - Core actions (checkout, cache, artifacts)
   - Docker actions (buildx, login, qemu)
   - Crane setup (for release mode)

4. **External Tools**:
   - Docker (builds)
   - jq (JSON parsing)
   - ajv-cli (schema validation)

### Optional Dependencies (Enhanced Features)

1. **Telegram Notifications**:
   - `TELEGRAM_BOT_TOKEN` secret
   - `TELEGRAM_CHAT_ID` secret
   - Telegram Bot API (api.telegram.org)

2. **Testing**:
   - Test fixtures (test-workflow.yml only)
   - Test scripts (service repositories)

3. **Vulnerability Scanning**:
   - Trivy action (informational, non-blocking)

### Maintenance Requirements

- **Monthly**: Review action updates
- **Quarterly**: Update base image digests (if pinned)
- **Yearly**: Review API compatibility
- **As needed**: Update schema for new features

---

## Quick Reference

### Dependency Checklist for New Service Repository

```
Setup Checklist:
[ ] Create .ci/docker-matrix.json
[ ] Validate against schema
[ ] Create Dockerfile(s) for each platform
[ ] Create .github/workflows/pr-validation.yml
[ ] Create .github/workflows/release.yml
[ ] Set up branch protection (require PR validation)
[ ] (Optional) Configure Telegram notifications
[ ] (Optional) Create test scripts
[ ] Test PR workflow
[ ] Test release workflow
```

### Dependency Verification Commands

```bash
# Verify all dependencies present
cd service-repository/

# Check configuration exists
test -f .ci/docker-matrix.json && echo "✅ Config found"

# Validate schema
npx ajv-cli validate -s ../build-workflow/schema/docker-matrix-schema.json \
  -d .ci/docker-matrix.json && echo "✅ Schema valid"

# Check Dockerfiles exist
jq -r '.variants[].dockerfiles[]' .ci/docker-matrix.json | \
  while read df; do test -f "$df" && echo "✅ $df"; done

# Check workflows exist
test -f .github/workflows/pr-validation.yml && echo "✅ PR workflow"
test -f .github/workflows/release.yml && echo "✅ Release workflow"

# Check secrets (optional)
gh secret list | grep -E "TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID" && \
  echo "✅ Telegram configured"
```

---

**Last Updated**: 2026-01-29
**Workflow Version**: v1.0
**Schema Version**: v1.0
