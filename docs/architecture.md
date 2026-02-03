# Build Workflow Architecture

## Overview

**Architecture Pattern**: Service repositories own build configuration data; shared reusable workflow repository owns CI logic.

**Key Principles**:
- ✅ Per-architecture Dockerfiles for platform-specific builds
- ✅ Shared GHCR namespace with consistent naming conventions
- ✅ Idempotent workflows for safe retries
- ✅ Always rebuild from release branch for correctness
- ✅ Platform tags are temporary, multi-arch manifests are permanent
- ✅ PR validation without registry push (faster, cleaner)

---

## Core Architectural Decisions

### Repository Structure

**Service Repositories** (e.g., `runlix/radarr`, `runlix/distroless-runtime`):
- **release branch**: Contains source code, `.ci/docker-matrix.json`, per-arch Dockerfiles
  - Target for all PRs
  - Branch protection: requires PR + status checks, no direct push
  - **Squash merge disabled** (preserves commit SHA for image discovery)
- **main branch**: Contains `releases.json` metadata + documentation
  - Updated automatically by release workflow
  - Branch protection prevents accidental changes
  - Used for organizational visibility and deployment tracking

**Workflow Repository** (`runlix/build-workflow`):
- Reusable workflow: `.github/workflows/build-images-rebuild.yml`
- Called by service repos with minimal caller workflows
- Single source of truth for build logic

### Image Tagging Strategy

**PR Validation**:
```
NO images pushed to registry during PR validation.
Images are built with --load and tested in Docker daemon only.

Benefits:
- Faster PR feedback (no registry upload)
- Cleaner registry (no PR image clutter)
- Lower costs (reduced storage and bandwidth)
```

**Release Images**:

*Step 1: Temporary Platform Tags* (created → used for manifest → deleted):
```
<version>-<tag_suffix>-<arch>-<sha>

Examples (versioned service):
v5.2.1-stable-amd64-abc1234              # default variant platform tag
v5.2.1-debug-amd64-abc1234               # debug variant platform tag
v5.2.1-stable-arm64-abc1234              # arm64 platform tag

Examples (base image without version):
stable-amd64-abc1234                     # SHA becomes version
debug-arm64-abc1234                      # debug variant, arm64
```

**Why SHA in platform tags?** Ensures uniqueness and prevents tag collisions between rapid releases. Each commit gets unique platform tags.

*Step 2: Permanent Multi-Arch Manifests* (user-facing):
```
<version>-<tag_suffix>

Examples (versioned service):
v5.2.1-stable                            # default variant (tag_suffix: "stable")
v5.2.1-debug                             # debug variant (tag_suffix: "debug")

Examples (base image):
abc1234-stable                           # SHA-based versioning
abc1234-debug                            # base image debug variant
```

**Note:** Manifests intentionally **omit SHA** to provide stable, predictable tags for users. The SHA in platform tags is only for internal workflow uniqueness.

---

## Build Configuration Schema

### docker-matrix.json Location

File location: `.ci/docker-matrix.json` in service repository root

### Top-Level Fields

- **`version`** (optional): Semantic version for services (e.g., "v5.2.1"). Omit for base images (uses SHORT_SHA).
- **`base_image`** (optional): Pinned base image reference for services. Omit for base image repos.
  - `image`: Registry image name (e.g., "ghcr.io/runlix/distroless-runtime")
  - `tag`: Base image tag (e.g., "abc1234")
  - `digest`: Multi-arch manifest digest (e.g., "sha256:...")
- **`variants`** (required): Array of variant configurations

### Per-Variant Fields

- **`name`** (required): Unique identifier (e.g., "radarr-latest")
- **`tag_suffix`** (required): User-facing variant identifier (e.g., "", "-debug", "-nonroot")
- **`default`** (conditional): Required if `version` present. Exactly one variant must be default.
- **`dockerfiles`** (required): Map of platform to Dockerfile path (e.g., `{"linux/amd64": "Dockerfile.amd64"}`)
- **`platforms`** (required): Array of target platforms (e.g., `["linux/amd64", "linux/arm64"]`)
- **`build_args`** (optional): Additional Docker build arguments (literal strings only)
  - **Note**: Do NOT include `BASE_IMAGE`, `BASE_TAG`, `BASE_DIGEST` - these are auto-injected by workflow
- **`test_script`** (optional): Path to test script that receives `IMAGE_TAG` env var
- **`enabled`** (optional): Boolean to disable variant (defaults to true)

---

## Dockerfile Pattern

### Base Images (Wrap Upstream Images)

```dockerfile
ARG BASE_IMAGE
ARG BASE_TAG
ARG BASE_DIGEST

FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}

# Add common tools/configs
COPY scripts/ /usr/local/bin/
```

### Services (Use Wrapped Base Images)

```dockerfile
ARG BASE_IMAGE
ARG BASE_TAG
ARG BASE_DIGEST

FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}

# Copy application binary
COPY dist/app-amd64 /app/app
ENTRYPOINT ["/app/app"]
```

### Automatic Build Arg Injection

The workflow automatically injects these build args from `base_image` object:
- `BASE_IMAGE` → from `base_image.image`
- `BASE_TAG` → from `base_image.tag` + variant's `tag_suffix` (automatically appended)
- `BASE_DIGEST` → from `base_image.digest`

**Example**: If `base_image.tag = "abc1234"` and variant `tag_suffix = "-debug"`, workflow injects `BASE_TAG="abc1234-debug"`.

---

## Variant-to-Base Mapping

### Automatic Tag Suffix Append

Variants automatically use base images with matching suffixes:
- Service default variant (`tag_suffix=""`) → uses base `abc1234`
- Service debug variant (`tag_suffix="-debug"`) → uses base `abc1234-debug`
- Service nonroot variant (`tag_suffix="-nonroot"`) → uses base `abc1234-nonroot`

**Requirement**: Base image repository must provide all required variant tags.

---

## Workflow Architecture

### PR Validation Flow (3 jobs)

```
PR opened/updated → Trigger build
  ↓
1. parse-matrix
   - Validate schema
   - Expand variants × platforms
   - Output matrix JSON
  ↓
2. build-and-test (matrix: parallel)
   - Setup buildx + cache
   - Build platform-specific image (--load, stays in Docker daemon)
   - Run test script (if present)
   - Vulnerability scan (informational)
   - NO registry push
  ↓
3. summary
   - Report test results
   - Report vulnerability summary
   - Post PR comment
```

**Outcome**: PR validated with test results, NO images pushed to registry

### Release Flow (3 jobs)

```
Merge to release branch → Trigger release
  ↓
1. parse-matrix
   - Same validation as PR
   - Expand variants × platforms
  ↓
2. build-and-push (matrix: parallel)
   - Setup buildx + cache
   - Build platform-specific image from release branch
   - Run test script (if present)
   - Vulnerability scan (informational)
   - Push to GHCR with platform tag
  ↓
3. create-manifests
   - Group platform tags by variant
   - Create multi-arch manifest per variant
   - Delete temporary platform tags (after ALL manifests succeed)
   - Update releases.json in main branch
```

**Outcome**: Multi-arch manifests in GHCR tagged `{version}{suffix}` or `{sha}{suffix}`

**Note**: Release always rebuilds from release branch for correctness (no promotion)

---

## releases.json Format

**Location**: `releases.json` in main branch

**Structure**:
```json
{
  "radarr": {
    "version": "v5.2.1",
    "sha": "abc1234def5678901234567890abcdef12345678",
    "short_sha": "abc1234",
    "timestamp": "2025-01-29T10:30:00Z",
    "manifests": [
      "v5.2.1",
      "v5.2.1-debug"
    ]
  },
  "sonarr": {
    "version": "v3.0.10",
    "sha": "def5678abc1234567890abcdef123456789012ab",
    "short_sha": "def5678",
    "timestamp": "2025-01-28T15:20:00Z",
    "manifests": [
      "v3.0.10",
      "v3.0.10-debug"
    ]
  },
  "distroless-runtime": {
    "version": null,
    "sha": "ghi9012jkl3456789012345678901234567890cd",
    "short_sha": "ghi9012",
    "timestamp": "2025-01-27T09:15:00Z",
    "manifests": [
      "ghi9012",
      "ghi9012-debug"
    ]
  }
}
```

---

## Operational Policies

### Workflow Triggers

**PR Validation**:
- Events: `pull_request` [opened, synchronize, reopened]
- Path filters: Trigger only on changes to:
  - `.ci/docker-matrix.json`
  - `Dockerfile*` (any Dockerfile)
- Excludes: `*.md`, `docs/`, `.github/workflows/`
- Manual: `workflow_dispatch` with `dry_run` option

**Release**:
- Event: `push` to `release` branch
- Concurrency: Per-repository (`release-${{ github.repository }}`)
- Queue behavior: Cancel in-progress runs, start new

### Branch Protection

**release branch**:
- Require pull request before merging
- Require status checks to pass: `validate`
- Allowed merge types: Merge commit, Squash, or Rebase (all supported)
- No direct pushes

**main branch**:
- Protected from direct pushes
- Only release workflow can commit (releases.json updates)
- Used for documentation and metadata visibility

### Merge Requirements

**Both must succeed to merge PR**:
1. **Build + Test**: All platform builds complete and tests pass
2. **Vulnerability Scan**: Scan completes (informational, doesn't block)

No registry push required for PR merge, simplifying the approval process.

### Image Retention

- **PR images**: N/A (no images pushed during PR validation)
- **Release manifests**: Indefinite retention
- **Platform tags**: Deleted immediately after manifest creation succeeds
- **Release builds**: Always rebuild from release branch (no dependency on PR images)

---

## Security & Access

### Registry & Permissions

- **Registry**: GitHub Container Registry (GHCR) - `ghcr.io/runlix`
- **Namespace**: Shared namespace with pattern `ghcr.io/runlix/<service-name>`
- **Target Environment**: Private repositories only
- **Authentication**:
  - `GITHUB_TOKEN` for image push/pull operations
  - **GitHub App** for releases.json commits (required)

### Required Secrets

**GitHub App Authentication** (Required):
- `RUNLIX_APP_ID`: GitHub App ID for authenticated operations
- `RUNLIX_PRIVATE_KEY`: GitHub App private key (PEM format)

**Why GitHub App?** The workflow uses a GitHub App instead of `GITHUB_TOKEN` for commits to the main branch to:
1. Generate a token with proper permissions for cross-branch commits
2. Attribute commits to the app bot user (not github-actions[bot])
3. Trigger downstream workflows that require repository_dispatch events
4. Higher rate limits for API operations

See `docs/github-app-setup.md` for setup instructions (required for workflow operation).

**Optional Secrets** (Notifications):
- `TELEGRAM_BOT_TOKEN`: Telegram bot authentication token
- `TELEGRAM_CHAT_ID`: Telegram chat/channel ID for notifications

### Token Permissions

**PR Validation Workflow**:
```yaml
permissions:
  contents: read        # Checkout code, read matrix.json
  pull-requests: write  # Comment on PR with test/scan results
  actions: read         # Query workflow artifacts
```

**Release Workflow**:
```yaml
permissions:
  contents: write       # Update releases.json in main branch
  packages: write       # Push images, delete platform tags
  actions: read         # Query PR status for image discovery
```

### Vulnerability Scanning

- **When**: PR time (parallel with tests)
- **Tool**: Trivy
- **Policy**: Informational only - reports CVEs but doesn't block merge
- **Reporting**: PR comment with high/critical CVE summary

---

## Build & Test Strategy

### Multi-Architecture Builds

- **Pattern**: Per-architecture Dockerfiles (e.g., `Dockerfile.amd64`, `Dockerfile.arm64`)
- **Parallelization**: Fully parallel - one GitHub Actions job per variant+platform combination
- **Fail-Fast**: Enabled - first platform failure cancels all other builds
- **Matrix Size**: No enforced limits

### Layer Caching

- **Strategy**: GitHub Actions cache with buildx cache backend
- **Cache Key**: `buildx-{variant_name}-{platform}-{github.sha}`
- **Restore Keys**: `buildx-{variant_name}-{platform}-`
- **Storage Limit**: 10GB per repository (GitHub Actions cache limit)
- **Eviction**: GitHub automatic LRU eviction

### Testing

- **Requirement**: Container must start successfully
- **Health Checks**: Test script handles endpoint validation if supported
- **Test Script Contract**:
  - Receives `IMAGE_TAG` environment variable
  - Must exit 0 on success, non-zero on failure
  - Can use Docker commands to test running container
- **Execution Timing**: After build, before push
- **Failure Handling**: Blocks merge, requires manual retry via workflow re-run

---

## Tools & Actions

### Required Tools

| Tool | Installation | Purpose |
|------|-------------|---------|
| `jq` | Preinstalled (GitHub runners) | Parse matrix.json, expand variants |
| `docker buildx` | `docker/setup-buildx-action@v3` | Multi-arch builds |
| `crane` | `imjasonh/setup-crane@v0.1` | Image promotion, tag deletion |
| `trivy` | `aquasecurity/trivy-action@master` | Vulnerability scanning |
| `gh` CLI | Preinstalled (GitHub runners) | Query PRs, create releases |

### Tools Summary by Workflow Stage

| Stage | Tools Used | Purpose |
|-------|-----------|---------|
| **Matrix Parsing** | `jq` | Validate and expand docker-matrix.json |
| **Build** | `docker buildx`, `qemu` | Multi-platform image builds |
| **Test** | `docker`, custom scripts | Container startup and health checks |
| **Push (PR)** | `docker push` | Upload to GHCR with retry logic |
| **Scan** | `trivy` | Vulnerability detection (informational) |
| **Promotion** | `crane` | Fast registry-to-registry image copy |
| **Manifest** | `docker buildx imagetools` | Multi-arch manifest creation |
| **Cleanup** | `crane` | Delete temporary platform tags |
| **Metadata** | `gh`, `jq`, `git` | Update releases.json, query PRs |
| **Notification** | `curl` | Telegram notifications (optional) |

---

## Key Constraints & Assumptions

### Constraints
- GitHub-hosted Ubuntu runners (not self-hosted)
- GitHub Actions cache limit: 10GB per repository
- GHCR as primary registry
- Private repositories only
- Expected scale: < 20 concurrent jobs at peak

### Assumptions
- Service teams understand Docker multi-arch concepts
- Base images are managed by platform team
- Services follow semver for version field
- Upstream versions are GitHub releases or similar APIs

### Non-Goals (Deferred)
- BuildKit secrets (implement when needed)
- SBOM generation (future)
- Image signing with Sigstore (future)
- Multi-registry support (future)
- Self-hosted runners (future)

---

## Related Documentation

- [Usage Guide](usage.md) - How to use the build workflow
- [Release Workflow](release-workflow.md) - Detailed release flow documentation
- [Multi-Arch Manifests](multi-arch-manifests.md) - Deep dive into manifest creation
- [Branch Protection](branch-protection.md) - Branch protection setup
- [Customization](customization.md) - Customizing build behavior
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
