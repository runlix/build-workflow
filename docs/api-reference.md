# Build Workflow API Reference

Complete reference for the reusable workflow inputs, outputs, and secrets.

## Table of Contents

- [Workflow Inputs](#workflow-inputs)
- [Workflow Outputs](#workflow-outputs)
- [Required Secrets](#required-secrets)
- [Environment Variables](#environment-variables)
- [Job Outputs](#job-outputs)
- [Usage Examples](#usage-examples)

## Workflow Inputs

### `pr_mode`

**Type**: `boolean`
**Required**: Yes
**Description**: Determines workflow behavior - PR validation or release mode.

**Values**:
- `true` - PR validation mode: Build, test, and validate (no registry push)
- `false` - Release mode: Build, test, push images, and create multi-arch manifests

**Example**:
```yaml
with:
  pr_mode: true
```

### `dry_run`

**Type**: `boolean`
**Required**: No
**Default**: `false`
**Description**: Skip image push to registry for testing purposes.

**Usage**: Useful for testing workflow changes without affecting the registry.

**Example**:
```yaml
with:
  pr_mode: false
  dry_run: true  # Build and test, but don't push
```

## Workflow Outputs

The workflow does not currently expose workflow-level outputs. Results are communicated via:

- **PR Comments**: Automated comments on pull requests with build results
- **Artifacts**: Uploaded artifacts containing manifests and metadata
- **Registry Images**: Tagged images in GHCR (release mode only)
- **releases.json**: Updated file in main branch (release mode only)

### Future Enhancement

Consider adding workflow outputs:

```yaml
outputs:
  image_tags:
    description: "JSON array of created image tags"
    value: ${{ jobs.create-manifests.outputs.tags }}
  version:
    description: "Version from docker-matrix.json or SHA"
    value: ${{ jobs.parse-matrix.outputs.version }}
```

## Required Secrets

### `RUNLIX_APP_ID`

**Type**: String
**Required**: Yes (release mode)
**Description**: GitHub App ID for authenticated cross-branch commits.

**Usage**: Required for updating `releases.json` in the main branch from release workflow.

**Setup**: See [GitHub App Setup](./github-app-setup.md)

### `RUNLIX_PRIVATE_KEY`

**Type**: String (PEM format)
**Required**: Yes (release mode)
**Description**: GitHub App private key for authentication.

**Format**: Multi-line PEM-encoded private key

**Example Secret Value**:
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
(key content)
...
-----END RSA PRIVATE KEY-----
```

### `TELEGRAM_BOT_TOKEN` (Optional)

**Type**: String
**Required**: No
**Description**: Telegram bot token for release notifications.

**Format**: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`

**Setup**:
1. Create bot via [@BotFather](https://t.me/BotFather) on Telegram
2. Copy the bot token
3. Add as repository secret

**Security**: Token is automatically masked in logs via `::add-mask::`

### `TELEGRAM_CHAT_ID` (Optional)

**Type**: String
**Required**: No
**Description**: Telegram chat ID where notifications will be sent.

**Format**: Numeric string (e.g., `123456789` or `-987654321` for groups)

**Setup**:
1. Message [@userinfobot](https://t.me/userinfobot) on Telegram
2. Copy your chat ID
3. Add as repository secret

**Security**: Chat ID is automatically masked in logs via `::add-mask::`

### `GITHUB_TOKEN` (Automatic)

**Type**: String
**Required**: Yes (automatically provided)
**Description**: GitHub Actions token with repository permissions.

**Usage**: Used for:
- Authenticating to GHCR
- Creating PR comments
- Downloading artifacts
- Deleting temporary images

**Permissions Required**:
```yaml
permissions:
  contents: write       # Update releases.json (release mode)
  packages: write       # Push/delete images in GHCR
  pull-requests: write  # Comment on PRs (PR mode)
  actions: read         # Read workflow artifacts
```

## Environment Variables

The following environment variables are set by the workflow:

### Workflow-Level

| Variable | Value | Description |
|----------|-------|-------------|
| `REGISTRY` | `ghcr.io` | Container registry host |
| `REGISTRY_ORG` | `runlix` | Organization name in registry |

### Job-Level

| Variable | Value | Scope | Description |
|----------|-------|-------|-------------|
| `SERVICE_NAME` | `${{ github.event.repository.name }}` | All jobs | Name of service repository |
| `IMAGE_TAG` | Generated per image | Build job | Full image tag for built image |
| `PLATFORM` | `linux/amd64` or `linux/arm64` | Build job | Target platform for build |

### Step-Level

Variables set for specific steps (via `env:`):

- `GH_TOKEN` - GitHub token for CLI commands
- `TELEGRAM_BOT_TOKEN` - Masked Telegram token
- `TELEGRAM_CHAT_ID` - Masked Telegram chat ID

## Job Outputs

### `parse-matrix` Job

**Outputs**:

| Output | Type | Description | Example |
|--------|------|-------------|---------|
| `matrix` | JSON | Expanded build matrix (variants × platforms) | `[{"variant_name":"app","arch":"amd64",...}]` |
| `version` | String | Version from docker-matrix.json | `v5.2.1` or `""` for SHA-based |

**Usage in Other Jobs**:
```yaml
needs: parse-matrix
run: |
  VERSION="${{ needs.parse-matrix.outputs.version }}"
  MATRIX='${{ needs.parse-matrix.outputs.matrix }}'
```

### `promote-or-build` Job

**Outputs**: None (uses artifacts for inter-job communication)

**Artifacts Created** (release mode):
- `platform-tag-{variant}-{arch}.txt` - Platform-specific image tag

**Matrix Strategy**: Runs in parallel for each entry in `parse-matrix.outputs.matrix`

### `summary` Job

**Outputs**: None

**Side Effects**:
- Posts PR comment (PR mode)
- Logs build summary to console

### `create-manifests` Job

**Outputs**: None (release mode only)

**Side Effects**:
- Creates multi-arch manifests in registry
- Updates `releases.json` in main branch
- Sends Telegram notification (if configured)
- Deletes temporary platform tags

**Artifacts Created**:
- `manifests-created.txt` - List of created manifest tags

## Usage Examples

### Basic PR Validation

```yaml
name: PR Validation
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  validate:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: true
    secrets: inherit
```

### Release with Notifications

```yaml
name: Release
on:
  push:
    branches: [release]

jobs:
  release:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: false
    secrets:
      RUNLIX_APP_ID: ${{ secrets.RUNLIX_APP_ID }}
      RUNLIX_PRIVATE_KEY: ${{ secrets.RUNLIX_PRIVATE_KEY }}
      TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN }}
      TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}
```

### Testing Workflow Changes

```yaml
name: Test Workflow
on:
  workflow_dispatch:

jobs:
  test:
    uses: YOUR-USERNAME/build-workflow/.github/workflows/build-images-rebuild.yml@YOUR-BRANCH
    with:
      pr_mode: false
      dry_run: true  # Don't push to registry
    secrets: inherit
```

### Conditional Secrets

If Telegram secrets are optional in your setup:

```yaml
jobs:
  release:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: false
    secrets:
      RUNLIX_APP_ID: ${{ secrets.RUNLIX_APP_ID }}
      RUNLIX_PRIVATE_KEY: ${{ secrets.RUNLIX_PRIVATE_KEY }}
      # Telegram secrets are optional - workflow continues without them
      TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN || '' }}
      TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID || '' }}
```

## Permissions Reference

### Minimal PR Mode Permissions

```yaml
permissions:
  contents: read        # Checkout code
  pull-requests: write  # Post PR comments
  actions: read         # Download artifacts
```

### Minimal Release Mode Permissions

```yaml
permissions:
  contents: write       # Update releases.json
  packages: write       # Push/delete GHCR images
  actions: read         # Download artifacts
```

### Full Permissions (Both Modes)

```yaml
permissions:
  contents: write       # Update releases.json (release)
  packages: write       # Push/delete images (release)
  pull-requests: write  # Comment on PRs (PR mode)
  actions: read         # Read artifacts (both)
```

## Error Handling

### Workflow Failures

The workflow uses `continue-on-error` for non-critical steps:

- Vulnerability scanning (Trivy)
- Platform tag cleanup (crane delete)
- Release notifications (Telegram)

Critical failures (build, test, push) will stop the workflow and report errors.

### PR Comments on Failure

Failed builds in PR mode automatically post a comment with:
- Failed variant and architecture
- Platform and Dockerfile path
- Link to workflow run logs

### Artifact Retention

| Artifact | Retention | Purpose |
|----------|-----------|---------|
| Platform tags | 1 day | Temporary coordination between jobs |
| Failure artifacts (SARIF) | 7 days | Debugging failed builds |
| Manifests list | 90 days | Release audit trail |

## Rate Limits and Timeouts

| Operation | Timeout | Retry Logic |
|-----------|---------|-------------|
| Build job | 120 min | No retry (fail-fast) |
| Manifest job | 30 min | No retry |
| Image push | 10 min | 3 attempts, 10s wait |

## See Also

- [Usage Guide](./usage.md) - Getting started
- [Customization Guide](./customization.md) - Configuration options
- [GitHub App Setup](./github-app-setup.md) - Authentication setup
- [Troubleshooting](./troubleshooting.md) - Common issues
