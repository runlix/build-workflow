# Runlix Build Workflow

Centralized GitHub Actions workflows for building and publishing Docker images to GitHub Container Registry.

## Usage

This repository contains reusable workflows that are called by individual image repositories.

### Workflow: `build-on-call.yml`

Reusable workflow called by image repositories when building Docker images.

**Inputs**: None (workflow reads all configuration from `VERSION.json`)

**Secrets**:
- `GHCR_TOKEN`: GitHub Container Registry token (inherited from calling workflow)

**How it works**:
1. Image repository pushes to `release` or `nightly` branch
2. Repository's `call-build.yml` workflow triggers
3. Calls this reusable workflow
4. Workflow reads `VERSION.json` from the branch:
   - Extracts version, build_date, and other metadata
   - Reads `targets` array and filters to enabled targets (`enabled: true`)
   - Generates build matrix from enabled targets
5. For each enabled target in the matrix:
   - Builds Docker image using the target's specified Dockerfile
   - Uses base image digest from target's `base.digest` field
   - Pushes platform-specific image with tag: `{branch}-{version}-{target.name}`
6. Creates manifest lists per variant, combining all platforms for each variant
7. Updates `tags.json` in default branch with latest build info

**Note**: The build workflow is read-only for version management. It reads `VERSION.json` but does not modify it. See [Version Management](#version-management) below for updating versions and digests.

### Workflow: `test-on-pr.yml`

Reusable workflow for testing Docker images on pull requests. This workflow builds images without pushing them and runs smoke tests to validate containers.

**Inputs**: None (workflow reads all configuration from `VERSION.json`)

**Secrets**: None required (images are built but not pushed)

**How it works**:
1. Called from individual repository PR workflows when a pull request is opened, reopened, or synchronized
2. Workflow reads `VERSION.json` from the PR branch:
   - Extracts version, build_date, and other metadata
   - Extracts optional `test_url` field (at root level) for health endpoint testing
   - Reads `targets` array and filters to enabled targets (`enabled: true`)
   - Generates build matrix from enabled targets
3. For each enabled target in the matrix:
   - Builds Docker image using the target's specified Dockerfile (without pushing)
   - Rebuilds image in test job (uses cache, so rebuild is fast)
   - Runs smoke tests:
     - Starts container and waits for initialization
     - Captures container logs
     - Checks if container is running (fails if container exits unexpectedly)
     - Optionally tests health endpoint if `test_url` is provided in `VERSION.json`
     - Uploads test logs as artifacts
   - Cleans up containers after testing

**Test URL Handling**:
- If `test_url` exists in `VERSION.json` root: Performs curl check with retries (60 retries, 120s max time)
- If `test_url` is missing or null: Skips URL check, test still passes if container starts successfully
- Test fails if:
  - Container fails to start
  - Container exits unexpectedly
  - `test_url` is provided but endpoint check fails

**Usage in Repository**:
Create a workflow file (e.g., `.github/workflows/pr-test.yml`) in your repository:

```yaml
name: Test on PR

on:
  pull_request:
    types:
      - opened
      - reopened
      - synchronize

jobs:
  test:
    uses: runlix/build-workflow/.github/workflows/test-on-pr.yml@main
```

**VERSION.json with test_url**:
```json
{
  "version": "4.0.6",
  "build_date": "2025-12-30T16:20:07Z",
  "test_url": "http://localhost:9091/transmission/web/",
  "targets": [
    {
      "arch": "linux-amd64",
      "variant": "latest",
      "enabled": true,
      ...
    }
  ]
}
```

### Workflow: `update-digests.yml`

Automated workflow that discovers and processes all repositories with the `docker-image` topic. This workflow runs hourly and automatically executes `update-digests.sh` scripts in each repository/branch combination, creating Pull Requests when changes are detected.

**How it works**:
1. Discovers all repositories in the `runlix` organization with the `docker-image` topic
2. For each repository, lists all branches (excluding `main` and `master` branches)
3. For each branch, clones the repository and checks for `update-digests.sh` script
4. If the script exists, executes it
5. If the script makes changes, creates a Pull Request with the updates

**Triggers**:
- `workflow_dispatch`: Manual trigger
- `schedule`: Runs hourly (`0 * * * *`)

**Required Secrets**:
- `GITHUB_TOKEN`: Automatically provided by GitHub Actions (used for API calls, cloning, and creating PRs)

**Repository Requirements**:
- Repository must have the `docker-image` topic set in GitHub
- Each branch that should be processed must contain an `update-digests.sh` script
- The script should:
  - Update `VERSION.json` files with new digests
  - Exit with code 0 if changes were made
  - Exit with non-zero code if no changes are needed or if an error occurs
  - Not commit changes (the workflow handles commits and PRs)

**Branch Processing**:
- Processes all branches except `main` and `master` (to avoid conflicts with default branches)
- Creates a new branch for each PR: `update-digests-{run_id}-{timestamp}`
- PRs are created against the branch being updated

**Error Handling**:
- Continues processing other repositories if one fails
- Skips repositories/branches without `update-digests.sh` scripts
- Logs all errors for debugging
- Gracefully handles clone failures and script execution errors

**Example PR**:
When changes are detected, the workflow creates a PR with:
- Title: "Upstream image update"
- Labels: `automated`, `dependencies`
- Body: Includes repository and branch information
- Commit message: "Upstream image update" (or "Upstream image update [skip ci]" for `pr` branch)

**Concurrency**:
- Uses workflow-level concurrency to prevent duplicate runs
- Only one instance of the workflow runs at a time (`cancel-in-progress: false`)

## Version Management

The workflow uses `VERSION.json` files to define build targets, versions, and base image digests. Create a `VERSION.json` file in your `release`/`nightly` branch.

### VERSION.json Structure

The `VERSION.json` file uses a `targets` array structure where each target defines a platform-variant combination to build.

**Example for base images** (e.g., distroless-runtime):
```json
{
  "version": "2025.12.29.1",
  "build_date": "2025-12-29T08:49:05Z",
  "sbranch": "main",
  "targets": [
    {
      "arch": "linux-amd64",
      "variant": "latest",
      "enabled": true,
      "name": "linux-amd64-latest",
      "dockerfile": "linux-amd64.Dockerfile",
      "base": {
        "image": "gcr.io/distroless/base-debian12",
        "tag": "latest-amd64",
        "digest": "sha256:7aa57dbe6daf724d489941dde747932bfbba936b317b021ec7b8362ed5742987"
      },
      "builder": {
        "image": "docker.io/library/debian",
        "tag": "bookworm-slim",
        "digest": "sha256:ef5c368548841bdd8199a8606f6307402f7f2a2f8edc4acbc9c1c70c340bc023"
      },
      "tags": []
    },
    {
      "arch": "linux-arm64",
      "variant": "latest",
      "enabled": true,
      "name": "linux-arm64-latest",
      "dockerfile": "linux-arm64.Dockerfile",
      "base": {
        "image": "gcr.io/distroless/base-debian12",
        "tag": "latest-arm64",
        "digest": "sha256:e1bd9ae4515d76130ff4266a7e03ed4f18775cc4b5afb77c25acc6296be8d6bc"
      },
      "builder": {
        "image": "docker.io/library/debian",
        "tag": "bookworm-slim",
        "digest": "sha256:594f2f110240a0a9c94d6e2a1020f6a05b79f713fcacd8c122ad8ff26e31d107"
      },
      "tags": []
    }
  ]
}
```

**Key fields**:
- `version`: Version string for the image
- `build_date`: ISO 8601 timestamp (optional)
- `sbranch`: Source branch name (optional)
- `targets`: Array of build targets, each with:
  - `arch`: Architecture (e.g., `linux-amd64`, `linux-arm64`)
  - `variant`: Variant name (e.g., `latest`, `debug`)
  - `enabled`: Boolean to enable/disable this target
  - `name`: Unique target name (typically `{arch}-{variant}`)
  - `dockerfile`: Path to architecture-specific Dockerfile
  - `base`: Base image information (image, tag, digest)
  - `builder`: Builder image information (image, tag, digest) - optional
  - `tags`: Additional tags array (optional)

**For application images**, add application-specific fields:
- `url`: Download URL for application binaries (per target, if needed)
- `base_image`: Base image repository reference (e.g., `ghcr.io/runlix/distroless-runtime`)
- `base_image_version`: Version of base image to use

The workflow reads from `.targets[]` array and builds only enabled targets. Each target specifies its own Dockerfile, base image digest, and architecture.

## Multi-Platform and Multi-Variant Builds

The build system supports multi-platform builds using separate Dockerfiles per architecture (Hotio pattern), and multi-variant builds using GitHub Actions matrix strategy.

### Dockerfile Structure

Each repository should have separate Dockerfiles for each supported architecture:
- `linux-amd64.Dockerfile` - AMD64-specific Dockerfile with hardcoded values
- `linux-arm64.Dockerfile` - ARM64-specific Dockerfile with hardcoded values

**Benefits:**
- No conditionals in Dockerfiles - each is clean and simple
- No detection logic - values are hardcoded per architecture
- Better separation - changes to one architecture don't affect the other
- Easier to understand - each Dockerfile is self-contained

**Example structure:**
```
distroless-runtime/
  ├── linux-amd64.Dockerfile
  ├── linux-arm64.Dockerfile
  └── VERSION.json

sonarr/
  ├── linux-amd64.Dockerfile
  ├── linux-arm64.Dockerfile
  └── VERSION.json
```

The workflow reads enabled targets from `VERSION.json` and builds each target separately with its corresponding Dockerfile, then creates manifest lists combining all platforms for each variant.

### Variant Support

The build system supports building multiple variants of images (e.g., `latest` and `debug`). Each variant is defined as a separate target in the `targets` array with its own `variant` field. The workflow uses a matrix strategy to build all enabled targets efficiently.

### Build Matrix Generation

The workflow generates a build matrix dynamically from the `targets` array:
1. Reads `targets` array from VERSION.json
2. Filters to only enabled targets (`enabled: true`)
3. Creates a matrix entry for each enabled target
4. Each matrix entry includes: `arch`, `variant`, `name`, `dockerfile`, `base`, `builder`

Manifest lists are created per variant, only including platforms that have that variant enabled.

### Separated Concerns

- **Build workflow** (`build-on-call.yml`): Reads `VERSION.json`, builds images, updates `tags.json`. Does NOT modify `VERSION.json`.
- **Test workflow** (`test-on-pr.yml`): Builds images without pushing, runs smoke tests on pull requests. Validates containers start correctly and optionally checks health endpoints.
- **Digest update workflow** (`update-digests.yml`): Executes `update-digests.sh` scripts in repositories, creates PRs for review when digests change.

This separation:
- Prevents self-triggering workflow loops
- Ensures version changes are explicit and reviewable (GitOps)
- Eliminates race conditions on concurrent builds
- Provides better traceability

## Image Tagging Strategy

The workflow creates multiple tags for each build:

**Platform-specific images** (one per target):
- `{branch}-{version}-{target.name}` (e.g., `release-2025.12.29.1-linux-amd64-latest`)

**Manifest lists** (per variant, combining all platforms):
- `{branch}-{variant}` (e.g., `release-latest`)
- `{branch}-{version}-{variant}` (e.g., `release-2025.12.29.1-latest`)
- `{branch}-{sha}-{variant}` (e.g., `release-9e4b4f2-latest`)

Users can pull the manifest list tag and Docker will automatically select the correct platform-specific image for their architecture.

## License

GPL-3.0
