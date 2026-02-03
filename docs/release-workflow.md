# Release Workflow - Detailed Implementation

## Overview

**Purpose**: Rebuild images from release branch, create multi-arch manifests, update metadata.

**Outcome**: Multi-arch manifests published to GHCR as `{version}{suffix}` or `{sha}{suffix}`, releases.json updated in main branch.

**Workflow Files**:
- Caller: `.github/workflows/release.yml` in service repository
- Reusable: `runlix/build-workflow/.github/workflows/build-images-rebuild.yml`

**Key Change**: This workflow always rebuilds from the release branch for correctness, rather than promoting PR images.

---

## Workflow Trigger

### Caller Workflow Configuration

**File**: `.github/workflows/release.yml` in service repository

```yaml
name: Release

on:
  push:
    branches:
      - release

permissions:
  contents: write       # Update releases.json in main
  packages: write       # Push images, delete platform tags
  actions: read         # Query PR status

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

### Trigger Conditions

**Automatic Trigger**:
- Push to `release` branch (typically from PR merge)
- Branch protection ensures only merged PRs can push

**Concurrency Control**:
- Group: Per-repository (`release-${{ github.repository }}`)
- Behavior: Cancel in-progress release, start new one
- Prevents: Concurrent releases from same repository racing

---

## Job 1: parse-matrix

**Purpose**: Validate schema and expand matrix (same as PR flow)

### Implementation

Identical to PR Flow Job 1 with same validation logic:
1. Validate JSON schema
2. Extract version and base_image fields
3. Expand variants × platforms with auto-injected BASE_* args
4. Validate platform-Dockerfile mapping
5. Validate variant requirements
6. Log disabled variants

### Outputs

- `version`: Version string from matrix.json or empty for SHA-based
- `matrix`: JSON array of expanded job configurations

---

## Job 2: build-and-push

**Strategy**: Matrix - one job per variant+platform combination

**Parallelization**: Fully parallel, fail-fast enabled

**Depends On**: `parse-matrix`

**Timeout**: 120 minutes per job

### Build Strategy

```
For each variant+platform:
  1. Checkout release branch code
  2. Build image from Dockerfile
  3. Run tests
  4. Push to GHCR with platform tag
  5. Save platform tag for manifest creation
```

**Always Rebuild**: This workflow always rebuilds from the release branch rather than promoting PR images, ensuring release images always match the exact release branch state.

### Step-by-Step Implementation

#### 1. Setup Environment

```yaml
- name: Checkout code
  uses: actions/checkout@v4

- name: Log in to GHCR (release mode only)
  if: ${{ !inputs.pr_mode && !inputs.dry_run }}
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

#### 2. Generate Release Tag

```bash
VERSION="${{ needs.parse-matrix.outputs.version }}"
SHORT_SHA=$(echo "${{ github.sha }}" | cut -c1-7)

# Generate release platform tag (temporary)
if [ -n "$VERSION" ]; then
  PLATFORM_TAG="${VERSION}-${{ matrix.tag_suffix }}-${{ matrix.arch }}-${SHORT_SHA}"
else
  PLATFORM_TAG="${{ matrix.tag_suffix }}-${{ matrix.arch }}-${SHORT_SHA}"
fi

echo "platform_tag=$PLATFORM_TAG" >> $GITHUB_OUTPUT
echo "Platform tag: $PLATFORM_TAG"
```

#### 3. Build Image from Release Branch

```bash
IMAGE_TAG="ghcr.io/runlix/${SERVICE_NAME}:${PLATFORM_TAG}"
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "🔨 Building: ${PLATFORM_TAG}"

# Build with OCI labels
docker buildx build \
  --platform ${{ matrix.platform }} \
  -f ${{ matrix.dockerfile }} \
  $(echo '${{ toJson(matrix.build_args) }}' | jq -r 'to_entries[] | "--build-arg \(.key)=\(.value)"' | tr '\n' ' ') \
  --label "org.opencontainers.image.revision=${{ github.sha }}" \
  --label "org.opencontainers.image.created=${BUILD_DATE}" \
  --label "org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}" \
  $([ -n "$VERSION" ] && echo "--label org.opencontainers.image.version=$VERSION" || echo "") \
  --cache-from type=local,src=/tmp/.buildx-cache \
  --cache-to type=local,dest=/tmp/.buildx-cache-new,mode=max \
  --load \
  -t $IMAGE_TAG \
  .

echo "✅ Built: $IMAGE_TAG"
```

**Benefits of Always Rebuilding**:
- **Correctness**: Release images always match release branch exactly
- **Simplicity**: No promotion logic, manifest downloading, or PR discovery
- **Reliability**: No dependency on PR image retention or workflow artifacts
- **Consistency**: Same build process for all releases

#### 4. Run Tests

```bash
if [ -n "${{ matrix.test_script }}" ]; then
  echo "Running tests: ${{ matrix.test_script }}"
  chmod +x ${{ matrix.test_script }}
  IMAGE_TAG=$IMAGE_TAG PLATFORM=${{ matrix.platform }} ${{ matrix.test_script }}
  echo "✅ Tests passed"
fi
```

#### 5. Push to Registry

```yaml
- name: Push image with retry
  if: |
    !inputs.dry_run && !inputs.pr_mode
  uses: nick-fields/retry@v2
  with:
    timeout_minutes: 10
    max_attempts: 3
    retry_wait_seconds: 10
    command: docker push ${{ env.IMAGE_TAG }}
```

#### 6. Save Platform Tag for Manifest Creation

```yaml
- name: Save platform tag
  run: |
    PLATFORM_TAG="${{ steps.copy.outputs.platform_tag || steps.build.outputs.platform_tag }}"
    echo "$PLATFORM_TAG" > platform-tag-${{ matrix.variant_name }}-${{ matrix.arch }}.txt

- name: Upload platform tag artifact
  uses: actions/upload-artifact@v4
  with:
    name: platform-tag-${{ matrix.variant_name }}-${{ matrix.arch }}
    path: platform-tag-${{ matrix.variant_name }}-${{ matrix.arch }}.txt
```

**Purpose**: Pass platform tag to manifest creation job via artifact

---

## Job 3: create-manifests

**Purpose**: Create multi-arch manifests, delete temporary platform tags, update releases.json

**Depends On**: `promote-or-build`

**Critical**: Only runs if ALL promote-or-build jobs succeed (fail-fast ensures this)

### Step-by-Step Implementation

#### 1. Setup Environment

```yaml
- name: Checkout code
  uses: actions/checkout@v4

- name: Setup crane
  uses: imjasonh/setup-crane@v0.1

- name: Log in to GHCR
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

#### 2. Download All Platform Tags

```yaml
- name: Download platform tags
  uses: actions/download-artifact@v4
  with:
    pattern: platform-tag-*
    path: platform-tags/
    merge-multiple: true
```

#### 3. Create Multi-Arch Manifests

```bash
VERSION="${{ needs.parse-matrix.outputs.version }}"
SHORT_SHA=$(echo "${{ github.sha }}" | cut -c1-7)

# Read unique variants from matrix
VARIANTS=$(echo '${{ needs.parse-matrix.outputs.matrix }}' | \
  jq -r '[.[] | {name: .variant_name, suffix: .tag_suffix}] | unique_by(.name)')

echo "Creating manifests for variants:"
echo "$VARIANTS" | jq -r '.[] | "  - \(.name) (suffix: \"\(.suffix)\")"'

# For each variant, create manifest
echo "$VARIANTS" | jq -c '.[]' | while read variant; do
  VARIANT_NAME=$(echo "$variant" | jq -r '.name')
  TAG_SUFFIX=$(echo "$variant" | jq -r '.suffix')

  # Determine manifest tag
  if [ -n "$VERSION" ]; then
    MANIFEST_TAG="${VERSION}${TAG_SUFFIX}"
  else
    MANIFEST_TAG="${SHORT_SHA}${TAG_SUFFIX}"
  fi

  echo "🔨 Creating manifest: ${MANIFEST_TAG}"

  # Collect all platform images for this variant
  PLATFORM_IMAGES=()
  for tag_file in platform-tags/platform-tag-${VARIANT_NAME}-*.txt; do
    if [ -f "$tag_file" ]; then
      PLATFORM_TAG=$(cat "$tag_file")
      PLATFORM_IMAGES+=("ghcr.io/runlix/${SERVICE_NAME}:${PLATFORM_TAG}")
      echo "  + Platform: ${PLATFORM_TAG}"
    fi
  done

  if [ ${#PLATFORM_IMAGES[@]} -eq 0 ]; then
    echo "❌ Error: No platform images found for ${VARIANT_NAME}"
    exit 1
  fi

  # Create multi-arch manifest
  docker buildx imagetools create \
    -t "ghcr.io/runlix/${SERVICE_NAME}:${MANIFEST_TAG}" \
    "${PLATFORM_IMAGES[@]}"

  echo "✅ Created: ${MANIFEST_TAG}"
  echo "${MANIFEST_TAG}" >> manifests-created.txt
done
```

**Key Points**:
- Groups platform tags by variant (using artifact naming pattern)
- Creates one multi-arch manifest per variant
- Uses `docker buildx imagetools create` (supports manifest lists)
- Fails if any variant is missing platform images
- Only runs if ALL platform builds succeeded

#### 4. Delete Temporary Platform Tags

```bash
echo "🧹 Cleaning up temporary platform tags..."

SUCCESS_COUNT=0
FAIL_COUNT=0

for tag_file in platform-tags/platform-tag-*.txt; do
  if [ -f "$tag_file" ]; then
    PLATFORM_TAG=$(cat "$tag_file")
    echo "Deleting: ${PLATFORM_TAG}"

    if crane delete "ghcr.io/runlix/${SERVICE_NAME}:${PLATFORM_TAG}"; then
      ((SUCCESS_COUNT++))
    else
      echo "⚠️ Failed to delete ${PLATFORM_TAG} (continuing)"
      ((FAIL_COUNT++))
    fi
  fi
done

echo "✅ Cleanup complete: $SUCCESS_COUNT deleted, $FAIL_COUNT failed"

# Don't fail workflow on cleanup errors
exit 0
```

**Cleanup Strategy**:
- Deletes ALL platform tags after manifests created
- Failures logged but don't fail workflow
- Platform tags are temporary by design
- Manifests reference images by digest (immutable)

**Why Delete?**:
- Reduces registry clutter
- Platform tags are implementation detail (not user-facing)
- Users should only pull multi-arch manifests

#### 5. Update releases.json in Main Branch

```bash
# Checkout main branch
git clone --branch main --single-branch --depth 1 \
  https://x-access-token:${{ secrets.GITHUB_TOKEN }}@github.com/${{ github.repository }} main-branch
cd main-branch

VERSION="${{ needs.parse-matrix.outputs.version }}"
SHORT_SHA=$(echo "${{ github.sha }}" | cut -c1-7)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MANIFESTS=$(cat ../manifests-created.txt | jq -R -s 'split("\n") | map(select(length > 0))')

# Read current releases.json or create empty object
if [ -f releases.json ]; then
  RELEASES=$(cat releases.json)
else
  RELEASES='{}'
fi

# Update entry for this service
RELEASES=$(echo "$RELEASES" | jq \
  --arg service "${SERVICE_NAME}" \
  --arg version "$VERSION" \
  --arg sha "${{ github.sha }}" \
  --arg timestamp "$TIMESTAMP" \
  --argjson manifests "$MANIFESTS" \
  '.[$service] = {
    version: (if $version != "" then $version else null end),
    sha: $sha,
    timestamp: $timestamp,
    manifests: $manifests
  }')

# Write updated releases.json
echo "$RELEASES" | jq '.' > releases.json

# Commit and push
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add releases.json
git commit -m "Release: ${SERVICE_NAME} @ ${{ github.sha }}"
git push
```

**releases.json Structure**:
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
  "distroless-runtime": {
    "version": null,
    "sha": "def5678abc1234567890abcdef123456789012ab",
    "short_sha": "def5678",
    "timestamp": "2025-01-28T15:20:00Z",
    "manifests": [
      "def5678",
      "def5678-debug"
    ]
  }
}
```

#### 6. Send Notification (Optional)

```yaml
- name: Notify release completion
  if: always()
  run: |
    VERSION="${{ needs.parse-matrix.outputs.version }}"

    # Only notify for versioned releases
    if [ -n "$VERSION" ]; then
      if [ -n "${{ secrets.TELEGRAM_BOT_TOKEN }}" ] && [ -n "${{ secrets.TELEGRAM_CHAT_ID }}" ]; then
        MESSAGE="🚀 *Release Complete*%0A%0A"
        MESSAGE+="Service: ${SERVICE_NAME}%0A"
        MESSAGE+="Version: ${VERSION}%0A"
        MESSAGE+="SHA: ${SHORT_SHA}%0A"
        MESSAGE+="Manifests: $(cat manifests-created.txt | tr '\n' ', ')%0A"

        curl -s -X POST \
          "https://api.telegram.org/bot${{ secrets.TELEGRAM_BOT_TOKEN }}/sendMessage" \
          -d "chat_id=${{ secrets.TELEGRAM_CHAT_ID }}" \
          -d "text=${MESSAGE}" \
          -d "parse_mode=Markdown"
      fi
    fi
```

---

## Tag Lifecycle Visualization

```
PR Flow:
  Build → Test
  ↓
  Images built with --load (Docker daemon only)
  NO registry push

Merge to release:
  ↓
Release Flow:
  Checkout release branch
  ↓
  Build from Dockerfile
  ↓
  v5.2.1-stable-amd64-abc1234 (temporary platform tag)
  v5.2.1-stable-arm64-abc1234 (temporary platform tag)
  ↓
  Create manifest
  ↓
  v5.2.1-stable (permanent multi-arch manifest)
  ↓
  Delete temporary tags
  ❌ v5.2.1-stable-amd64-abc1234 (deleted)
  ❌ v5.2.1-stable-arm64-abc1234 (deleted)

Final State:
  ✅ v5.2.1-stable (manifest)
```

---

## Success Criteria

**Release succeeds when**:
1. ✅ All variants × platforms promoted or rebuilt successfully
2. ✅ All multi-arch manifests created
3. ✅ releases.json updated in main branch
4. ❌ Platform tag cleanup failures don't block (best effort)

**Release fails when**:
- ❌ Any platform promotion/build fails
- ❌ Any manifest creation fails
- ❌ releases.json commit fails

---

## Expected Outcomes

### GHCR Registry State After Release

**Services (with version)**:
```
ghcr.io/runlix/radarr:
  v5.2.1-stable                       ← multi-arch manifest (permanent)
  v5.2.1-debug                        ← multi-arch manifest (permanent)
```

**Base Images (SHA-based)**:
```
ghcr.io/runlix/distroless-runtime:
  abc1234-stable                    ← multi-arch manifest (permanent)
  abc1234-debug                     ← multi-arch manifest (permanent)
```

**Note**: No PR images are pushed to the registry - PR validation builds images locally only.

**Platform Tags Deleted**:
```
❌ v5.2.1-stable-amd64-abc1234    (deleted after manifest)
❌ v5.2.1-stable-arm64-abc1234    (deleted after manifest)
❌ v5.2.1-debug-amd64-abc1234     (deleted after manifest)
```

---

## Performance Characteristics

### Build Time
- **Duration**: 2-10 minutes per variant+platform (depends on image size and complexity)
- **Operation**: Full Docker build + test + push from release branch
- **Network**: Moderate to high (layer uploads, uses BuildKit cache)
- **Cost**: Standard compute and bandwidth costs

### Build Optimizations
- **Layer Caching**: GitHub Actions cache with buildx backend
- **Native Builds**: arm64 images built on native ARM runners (faster)
- **Parallel Execution**: All variant+platform combinations build concurrently
- **Fail-Fast**: First failure cancels remaining builds

### Expected Release Time
- **Simple Images** (distroless base): ~3-5 minutes total
- **Service Images** (with dependencies): ~8-15 minutes total
- **Complex Images** (large apps): ~15-30 minutes total

**Trade-off**: ~2 minutes slower than promotion but guarantees correctness

---

## Troubleshooting

### Common Issues

**Build Failed**:
- Check build logs for compilation or dependency errors
- Verify Dockerfile syntax and build args are correct
- Check if base image is available and accessible
- Ensure sufficient runner resources

**Manifest Creation Failed**:
- Verify all platform builds succeeded
- Check platform tag artifacts were uploaded
- Ensure docker buildx imagetools has registry access
- Platform tags NOT deleted on failure (safe recovery)

**releases.json Update Failed**:
- Check main branch protection allows workflow commits
- Verify `contents: write` permission
- Check for merge conflicts (if multiple services release simultaneously)

**Platform Tag Deletion Warnings**:
- Non-critical - manifests already created
- May indicate GHCR rate limiting
- Tags will be cleaned up by retention policy eventually

### Recovery Procedures

**Failed Release (Platform Build)**:
1. Fix the issue (code, Dockerfile, dependencies)
2. Push fix to release branch
3. Workflow automatically retries full release

**Failed Manifest Creation**:
1. Platform tags preserved (not deleted on failure)
2. Re-run workflow via GitHub Actions UI
3. Uses existing platform tags (idempotent)

**Failed releases.json Update**:
1. Manifests already created and published
2. Manually update releases.json if needed
3. Or re-run workflow (idempotent manifest creation)

### Debug Commands

**Check if platform image exists**:
```bash
crane digest ghcr.io/runlix/radarr:v5.2.1-stable-amd64-abc1234
```

**Inspect manifest**:
```bash
crane manifest ghcr.io/runlix/radarr:v5.2.1-stable | jq
```

**List platform images in manifest**:
```bash
docker buildx imagetools inspect ghcr.io/runlix/radarr:v5.2.1-stable
```

---

## Related Documentation

- [Architecture](architecture.md) - Overall system design
- [Usage Guide](usage.md) - How to trigger releases
- [Multi-Arch Manifests](multi-arch-manifests.md) - Deep dive into manifests
- [Branch Protection](branch-protection.md) - Required branch rules
- [Troubleshooting](troubleshooting.md) - More debugging help
