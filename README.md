# Runlix Build Workflow

Centralized GitHub Actions workflows for building and publishing Docker images to GitHub Container Registry.

## Usage

This repository contains reusable workflows that are called by individual image repositories.

### Workflow: `build-on-call.yml`

Called by image repositories when building Docker images.

**Inputs**:
- `image_name`: Docker image name (e.g., `sonarr-distroless`)
- `dockerfile_path`: Path to Dockerfile (default: `Dockerfile`)
- `build_context`: Build context path (default: `.`)
- `version`: Application version (optional, extracted from VERSION.json or Dockerfile if not provided)

**Secrets**:
- `GHCR_TOKEN`: GitHub Container Registry token (inherited from calling workflow)

## How It Works

1. Image repository pushes to `release` or `nightly` branch
2. Repository's `call-build.yml` workflow triggers
3. Calls this reusable workflow
4. Workflow reads version from `VERSION.json` (hotio pattern) or falls back to Dockerfile parsing
5. Builds Docker image and pushes to `ghcr.io/runlix/<image-name>`
6. Updates `tags.json` in main branch (default branch) with latest build info

**Note**: The build workflow is now read-only for version management. It reads `VERSION.json` but does not modify it. See [Version Management](#version-management) below for updating versions and digests.

### Workflow: `update-digests.yml`

Reusable workflow for updating base image digests in `VERSION.json` files. This workflow is separate from the build process to prevent self-triggering loops and follows GitOps best practices.

**Inputs**:
- `repository` (required): Repository to update (e.g., `runlix/distroless-runtime`)
- `branch` (required): Branch to update (e.g., `release`)
- `version_file_path` (optional, default: `VERSION.json`): Path to version file
- `auto_merge` (optional, default: `false`): Enable auto-merge for created PRs

**How to use**:

Create a workflow in your repository (e.g., `.github/workflows/update-digests.yml`):

```yaml
name: Update Digests

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight UTC

jobs:
  update:
    permissions:
      contents: write
      pull-requests: write
    concurrency:
      group: update-digests-release
      cancel-in-progress: false
    uses: runlix/build-workflow/.github/workflows/update-digests.yml@main
    with:
      repository: ${{ github.repository }}
      branch: release
      version_file_path: VERSION.json
      auto_merge: false  # Set to true when ready to enable auto-merge
```

**What it does**:
1. Checks out the specified branch
2. Extracts current digests from Docker registries
3. Compares with digests in `VERSION.json`
4. If digests changed:
   - Updates digests in `VERSION.json`
   - Bumps patch version (e.g., 1.0.0 → 1.0.1)
   - Creates a PR with the changes
   - Optionally enables auto-merge if `auto_merge: true`

**Auto-merge**:
- Defaults to `false` (PRs require manual review)
- Can be enabled per-repository by setting `auto_merge: true`
- Requires repository settings: Settings → General → Pull Requests → Allow auto-merge
- PRs will be automatically merged when status checks pass (if configured)

## Version Management

The workflow supports two version management approaches:

1. **VERSION.json pattern (recommended)**: Create a `VERSION.json` file in your `release`/`nightly` branch:
   ```json
   {
     "VERSION": "4.0.16.2944",
     "SBRANCH": "main",
     "AMD64_URL": "https://services.sonarr.tv/v1/download/main/4.0.16.2944?version=linux"
   }
   ```

   For base images (like `distroless-runtime`), include digest fields:
   ```json
   {
     "VERSION": "1.0.0",
     "DEBIAN_DIGEST_AMD64": "sha256:...",
     "DEBIAN_DIGEST_ARM64": "sha256:...",
     "DISTROLESS_DIGEST_AMD64": "sha256:...",
     "DISTROLESS_DIGEST_ARM64": "sha256:..."
   }
   ```

2. **Dockerfile ARG pattern**: Use `ARG VERSION=...` or `ARG APP_VERSION=...` in your Dockerfile (fallback)

The build workflow will automatically detect and use VERSION.json if present, otherwise it will parse the Dockerfile.

### Separated Concerns

- **Build workflow** (`build-on-call.yml`): Reads `VERSION.json`, builds images, updates `tags.json`. Does NOT modify `VERSION.json`.
- **Digest update workflow** (`update-digests.yml`): Updates base image digests and versions in `VERSION.json`, creates PRs for review.

This separation:
- Prevents self-triggering workflow loops
- Ensures version changes are explicit and reviewable (GitOps)
- Eliminates race conditions on concurrent builds
- Provides better traceability

## Image Tagging Strategy

Images are tagged with:
- Branch name (e.g., `release`, `nightly`)
- Branch-version (e.g., `release-4.0.16.2944`)
- Branch-commit (e.g., `release-9e4b4f2`)

## License

GPL-3.0
