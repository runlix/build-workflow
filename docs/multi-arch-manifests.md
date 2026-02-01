# Multi-Architecture Manifest Creation

## Overview

The workflow creates **multi-architecture manifests** that allow users to pull the correct platform image automatically based on their architecture. For example, running `docker pull ghcr.io/runlix/distroless-runtime:stable` on an ARM64 machine will automatically pull the ARM64 variant, while the same command on AMD64 pulls the AMD64 variant.

## How It Works

### 1. Build Phase (PR or Release)

Each variant/architecture combination is built separately and pushed with a platform-specific tag:

**Distroless (SHA-based, no version):**
```
stable-amd64-6a29080
stable-arm64-6a29080
debug-amd64-6a29080
debug-arm64-6a29080
```

**Radarr (versioned):**
```
6.0.4.10291-stable-amd64-def5678
6.0.4.10291-stable-arm64-def5678
6.0.4.10291-debug-amd64-def5678
6.0.4.10291-debug-arm64-def5678
```

### 2. Manifest Creation Phase (Release Only)

The workflow groups platform images by their **manifest tag** (version + suffix) and creates multi-arch manifests:

**Distroless:**
- Manifest `stable` → combines `stable-amd64-6a29080` + `stable-arm64-6a29080`
- Manifest `debug` → combines `debug-amd64-6a29080` + `debug-arm64-6a29080`

**Radarr:**
- Manifest `6.0.4.10291-stable` → combines `6.0.4.10291-stable-amd64-def5678` + `6.0.4.10291-stable-arm64-def5678`
- Manifest `6.0.4.10291-debug` → combines `6.0.4.10291-debug-amd64-def5678` + `6.0.4.10291-debug-arm64-def5678`

### 3. Cleanup Phase

After manifests are created, the temporary platform-specific tags are deleted. Only the multi-arch manifests remain:

**Distroless final tags:** `stable`, `debug`
**Radarr final tags:** `6.0.4.10291-stable`, `6.0.4.10291-debug`

## Tag Format Specification

### Platform Tags (Temporary)
Built during promote-or-build job, deleted after manifest creation:
```
<version>-<suffix>-<arch>-<sha>  # Versioned services
<suffix>-<arch>-<sha>            # SHA-based services
```

Examples:
- `6.0.4.10291-stable-amd64-def5678`
- `stable-arm64-6a29080`

### Manifest Tags (Permanent)
Created by multi-arch manifest job, user-facing:
```
<version>-<suffix>  # Versioned services
<suffix>            # SHA-based services
```

Examples:
- `6.0.4.10291-stable`
- `debug`

## Implementation Details

### Grouping Logic

The workflow groups platform images by `tag_suffix` to create multi-arch manifests:

```bash
# Extract unique tag_suffix values
TAG_SUFFIXES=$(echo '${{ needs.parse-matrix.outputs.matrix }}' | \
  jq -r '[.[] | .tag_suffix] | unique | .[]')

# For each suffix, calculate manifest tag
for TAG_SUFFIX in $TAG_SUFFIXES; do
  if [ -n "$VERSION" ]; then
    MANIFEST_TAG="${VERSION}-${TAG_SUFFIX}"
  else
    MANIFEST_TAG="${TAG_SUFFIX}"
  fi

  # Collect all platform images starting with this manifest tag
  # Platform tags: stable-amd64-6a29080, stable-arm64-6a29080
  # Match pattern: ${MANIFEST_TAG}-*
done
```

### Why Not Group By variant_name?

The `variant_name` field includes the architecture (e.g., `debug-amd64`, `debug-arm64`), so grouping by it would create separate manifests per architecture instead of combining them. This was the bug that caused single-arch manifests.

**Incorrect (old behavior):**
- Group by `debug-amd64` → creates manifest with only AMD64
- Group by `debug-arm64` → creates manifest with only ARM64 (overwrites previous)

**Correct (new behavior):**
- Group by `debug` suffix → creates manifest with both AMD64 + ARM64

## Docker Matrix Configuration

In `.ci/docker-matrix.json`, variants share the same `tag_suffix` across architectures:

```json
{
  "variants": [
    {
      "name": "default-amd64",
      "tag_suffix": "stable",
      "platforms": ["linux/amd64"]
    },
    {
      "name": "default-arm64",
      "tag_suffix": "stable",
      "platforms": ["linux/arm64"]
    },
    {
      "name": "debug-amd64",
      "tag_suffix": "debug",
      "platforms": ["linux/amd64"]
    },
    {
      "name": "debug-arm64",
      "tag_suffix": "debug",
      "platforms": ["linux/arm64"]
    }
  ]
}
```

**Key Points:**
- `name` must be unique (identifies the build job)
- `tag_suffix` can be shared (identifies the manifest)
- Multiple variants with same `tag_suffix` → combined into one multi-arch manifest

## Verification

After a release, verify multi-arch manifests were created correctly:

```bash
# Inspect manifest to see all architectures
docker manifest inspect ghcr.io/runlix/distroless-runtime:stable

# Should show multiple platforms:
# {
#   "manifests": [
#     { "platform": { "architecture": "amd64", "os": "linux" } },
#     { "platform": { "architecture": "arm64", "os": "linux" } }
#   ]
# }

# Pull and verify correct architecture
docker pull ghcr.io/runlix/distroless-runtime:stable
docker inspect ghcr.io/runlix/distroless-runtime:stable | jq '.[0].Architecture'
```

## Troubleshooting

### Only One Architecture in Manifest

**Symptom:** Manifest only contains one platform (e.g., only arm64).

**Cause:** Variants are being grouped by `variant_name` instead of `tag_suffix`, causing each architecture to create a separate manifest that overwrites the previous one.

**Solution:** Ensure the workflow groups by unique `tag_suffix` values, not by `variant_name`.

### No Manifests Created

**Symptom:** Platform tags exist but manifests are not created.

**Cause:** Platform tag format doesn't match the expected pattern.

**Solution:** Platform tags must start with the manifest tag followed by a dash:
- Manifest `stable` should match platform tags `stable-*`
- Manifest `6.0.4.10291-stable` should match platform tags `6.0.4.10291-stable-*`

### Wrong Platform Pulled

**Symptom:** Docker pulls the wrong architecture for your platform.

**Cause:** The multi-arch manifest was created incorrectly or platform images have wrong architecture metadata.

**Solution:**
1. Verify the build used correct `--platform` flag
2. Check image metadata: `docker inspect <image> | jq '.[0].Architecture'`
3. Rebuild with correct platform specification

## References

- [Docker Multi-Platform Images](https://docs.docker.com/build/building/multi-platform/)
- [Docker Manifest Command](https://docs.docker.com/engine/reference/commandline/manifest/)
- [OCI Image Manifest Specification](https://github.com/opencontainers/image-spec/blob/main/manifest.md)
