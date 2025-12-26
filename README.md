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
- `version`: Application version (optional, extracted from Dockerfile if not provided)

**Secrets**:
- `GHCR_TOKEN`: GitHub Container Registry token (inherited from calling workflow)

## How It Works

1. Image repository pushes to `release` or `nightly` branch
2. Repository's `call-build.yml` workflow triggers
3. Calls this reusable workflow
4. Builds Docker image and pushes to `ghcr.io/runlix/<image-name>`
5. Updates `tags.json` in master branch with latest build info

## Image Tagging Strategy

Images are tagged with:
- Branch name (e.g., `release`, `nightly`)
- Branch-version (e.g., `release-4.0.16.2944`)
- Branch-commit (e.g., `release-9e4b4f2`)

## License

GPL-3.0
