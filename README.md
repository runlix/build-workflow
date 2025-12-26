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

2. **Dockerfile ARG pattern**: Use `ARG VERSION=...` or `ARG APP_VERSION=...` in your Dockerfile (fallback)

The workflow will automatically detect and use VERSION.json if present, otherwise it will parse the Dockerfile.

## Image Tagging Strategy

Images are tagged with:
- Branch name (e.g., `release`, `nightly`)
- Branch-version (e.g., `release-4.0.16.2944`)
- Branch-commit (e.g., `release-9e4b4f2`)

## License

GPL-3.0
