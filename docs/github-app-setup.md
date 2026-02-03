# GitHub App Setup for API Access

This document describes how to set up a GitHub App for enhanced API access in the build-workflow system.

## Table of Contents
- [Why a GitHub App](#why-a-github-app)
- [When You Need It](#when-you-need-it)
- [GITHUB_TOKEN Limitations](#github_token-limitations)
- [Creating the GitHub App](#creating-the-github-app)
- [Installation](#installation)
- [Usage in Workflows](#usage-in-workflows)
- [Alternatives](#alternatives)

## Why a GitHub App

The default `GITHUB_TOKEN` provided by GitHub Actions has limitations:
- Limited API rate limits (1,000 requests per hour per repository)
- Cannot trigger workflows in other repositories
- Limited permissions scope
- Expires after the job completes

A GitHub App provides:
- Higher rate limits (5,000 requests per hour per installation)
- Organization-wide access
- Fine-grained permissions
- Persistent authentication
- Better audit trail

## When You Need It

**REQUIRED:** The build-workflow system requires a GitHub App for:
- **Updating releases.json in the main branch** - GITHUB_TOKEN cannot trigger workflows or commit to protected branches with proper attribution
- Cross-branch commits with workflow triggers
- Proper bot attribution for automated commits
- Higher API rate limits for release operations

The `GITHUB_TOKEN` alone is sufficient for:
- Building and pushing images to GHCR
- Commenting on PRs
- Reading workflow artifacts
- Deleting package versions

**Required Secrets:**
- `RUNLIX_APP_ID` - GitHub App ID
- `RUNLIX_PRIVATE_KEY` - GitHub App private key (PEM format)

Without these secrets configured, the release workflow will fail when attempting to update releases.json.

## GITHUB_TOKEN Limitations

### Rate Limits

| Token Type | Rate Limit | Scope |
|------------|-----------|-------|
| `GITHUB_TOKEN` | 1,000 req/hr | Per repository workflow |
| GitHub App | 5,000 req/hr | Per app installation |
| Personal Access Token | 5,000 req/hr | Per user |

### Permissions

`GITHUB_TOKEN` automatically receives permissions based on workflow configuration:

```yaml
permissions:
  contents: write       # Read/write repository contents
  packages: write       # Push/delete container images
  pull-requests: write  # Comment on PRs
  actions: read         # Read workflow artifacts
```

These permissions are sufficient for the build-workflow system.

### Cross-Repository Access

`GITHUB_TOKEN` cannot:
- Trigger workflows in other repositories
- Access packages in other repositories (without `packages: write` in target repo)
- Create releases in other repositories

GitHub App can access any repository where it's installed.

## Creating the GitHub App

### Step 1: Register the App

1. Go to GitHub organization settings
2. Navigate to **Settings** → **Developer settings** → **GitHub Apps**
3. Click **New GitHub App**

### Step 2: Basic Information

| Field | Value |
|-------|-------|
| **GitHub App name** | `runlix-build-workflow` |
| **Homepage URL** | `https://github.com/runlix/build-workflow` |
| **Description** | Multi-architecture Docker image build automation |
| **Webhook** | Uncheck "Active" (not needed) |

### Step 3: Permissions

#### Repository Permissions

| Permission | Access | Reason |
|------------|--------|--------|
| **Actions** | Read | Query workflow status and artifacts |
| **Contents** | Read & Write | Checkout code, update releases.json |
| **Metadata** | Read | Required (automatically selected) |
| **Pull requests** | Read & Write | Comment on PRs, read PR metadata |

#### Organization Permissions

| Permission | Access | Reason |
|------------|--------|--------|
| **Packages** | Read & Write | Push/delete container images in GHCR |

#### Account Permissions

None needed.

### Step 4: Where can this GitHub App be installed?

- ✅ **Only on this account** (runlix organization)

### Step 5: Create the App

Click **Create GitHub App**.

### Step 6: Generate Private Key

1. After creation, scroll to **Private keys** section
2. Click **Generate a private key**
3. Save the downloaded `.pem` file securely
4. **⚠️ This key grants full access - never commit it to git**

### Step 7: Note the App ID

Find the **App ID** at the top of the app settings page (e.g., `123456`). You'll need this for workflows.

## Installation

### Install to Organization

1. Go to app settings
2. Click **Install App** in left sidebar
3. Select **runlix** organization
4. Choose repositories:
   - **All repositories** (recommended for build-workflow)
   - Or select specific repositories

### Get Installation ID

```bash
# Using GitHub CLI
gh api /orgs/runlix/installation
```

Response:
```json
{
  "id": 12345678,
  "app_id": 123456,
  ...
}
```

Save the `id` field as `INSTALLATION_ID`.

## Usage in Workflows

### Store Secrets

Add these secrets to your organization or repository:

| Secret Name | Value | Where to Get It |
|-------------|-------|-----------------|
| `RUNLIX_APP_ID` | `123456` | App settings page |
| `RUNLIX_PRIVATE_KEY` | Contents of `.pem` file | Downloaded private key |

**Note:** Installation ID is not required - the action automatically determines it using the `owner` parameter.

**Organization-level secrets** are recommended for apps used across multiple repositories.

### Generate Installation Token

Add this step to your workflow:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Generate GitHub App token
        id: app-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.RUNLIX_APP_ID }}
          private-key: ${{ secrets.RUNLIX_PRIVATE_KEY }}
          owner: ${{ github.repository_owner }}

      - name: Use token for API calls
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          # Token is available as environment variable
          gh api /user

      - name: Checkout with app token
        uses: actions/checkout@v4
        with:
          token: ${{ steps.app-token.outputs.token }}
```

### Example: Cross-Repository Workflow Trigger

```yaml
- name: Generate GitHub App token
  id: app-token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
    owner: runlix
    repositories: |
      deployment-manager
      build-workflow

- name: Trigger deployment workflow
  uses: actions/github-script@v7
  with:
    github-token: ${{ steps.app-token.outputs.token }}
    script: |
      await github.rest.actions.createWorkflowDispatch({
        owner: 'runlix',
        repo: 'deployment-manager',
        workflow_id: 'deploy.yml',
        ref: 'main',
        inputs: {
          service: 'radarr',
          version: 'v5.2.1'
        }
      })
```

### Example: Update Central releases.json

```yaml
- name: Generate GitHub App token
  id: app-token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
    owner: runlix
    repositories: build-workflow

- name: Checkout central repository
  uses: actions/checkout@v4
  with:
    repository: runlix/build-workflow
    token: ${{ steps.app-token.outputs.token }}
    path: central

- name: Update releases.json
  run: |
    cd central
    jq '.releases += [{"service": "radarr", "version": "v5.2.1"}]' releases.json > tmp.json
    mv tmp.json releases.json

- name: Commit and push
  working-directory: central
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
  run: |
    git config user.name "runlix-build-workflow[bot]"
    git config user.email "123456+runlix-build-workflow[bot]@users.noreply.github.com"
    git add releases.json
    git commit -m "Update releases.json: radarr v5.2.1"
    git push
```

## Alternatives

### Personal Access Token (PAT)

**Pros:**
- Easy to create (Settings → Developer settings → Personal access tokens)
- Works immediately without app installation
- Good for personal or small team use

**Cons:**
- Tied to a user account (breaks if user leaves)
- No fine-grained permissions
- Higher security risk (full access to user's repositories)
- No audit trail separate from user actions

**When to use:**
- Quick testing
- Personal projects
- Small teams

### GITHUB_TOKEN (Default)

**Pros:**
- Automatic (no setup required)
- Secure (automatically scoped to workflow)
- No secret management needed
- Sufficient for most CI/CD tasks

**Cons:**
- Lower rate limits
- Cannot trigger cross-repository workflows
- Limited to repository scope

**When to use:**
- Standard CI/CD workflows (like build-workflow)
- Single-repository automation
- Image building and testing

## Security Best Practices

### Private Key Storage

**✅ DO:**
- Store private key in GitHub Secrets
- Use organization-level secrets for multi-repository access
- Rotate keys periodically (every 6-12 months)
- Revoke old keys after rotation

**❌ DON'T:**
- Commit private key to git
- Share private key in Slack/email
- Store in environment variables on shared machines
- Use same key for multiple apps

### Permissions

**Principle of least privilege:**
- Only grant permissions actually needed
- Start with read-only, add write as needed
- Review permissions quarterly
- Remove unused permissions

### Monitoring

**Track app usage:**
```bash
# View app API usage
gh api /app/installations/12345678/api-usage

# View recent activity
gh api /orgs/runlix/installations/12345678/events
```

**Set up alerts:**
- Unusual API activity
- Permission changes
- New installations
- Failed authentication attempts

## Troubleshooting

### Token Generation Fails

**Error:** `Bad credentials` or `Could not create token`

**Causes:**
1. Private key is incorrect or corrupted
2. App ID is wrong
3. Installation ID is wrong
4. App is not installed on the repository/organization

**Solution:**
1. Verify app ID from app settings page
2. Re-download private key (generate new one if needed)
3. Check installation ID: `gh api /orgs/runlix/installation`
4. Ensure app is installed on target organization

### Permission Denied

**Error:** `Resource not accessible by integration`

**Causes:**
1. App doesn't have required permission
2. App is not installed on target repository
3. Token expired (tokens last 1 hour)

**Solution:**
1. Check app permissions in settings
2. Verify installation: `gh api /repos/runlix/{repo}/installation`
3. Regenerate token if expired

### Rate Limit Exceeded

**Error:** `API rate limit exceeded`

**Causes:**
1. Making too many API calls
2. Multiple workflows using same app installation

**Solution:**
1. Check current rate limit: `gh api /rate_limit`
2. Add caching to reduce API calls
3. Use conditional checks before API calls
4. Spread out API calls over time

## Cost

GitHub Apps are **free** for:
- Public repositories
- GitHub Free, Pro, and Team plans
- GitHub Enterprise

No additional cost beyond your current GitHub plan.

## Next Steps

- [Workflow Customization Options](./customization.md)
- [Branch Protection Requirements](./branch-protection.md)
- [Troubleshooting Guide](./troubleshooting.md)

## Future Enhancements

Potential uses for GitHub App in build-workflow:

1. **Central Release Registry**
   - Update `releases.json` in build-workflow repository
   - Track all service versions in one place
   - Query available versions via API

2. **Automated Rollbacks**
   - Trigger revert workflow in service repository
   - Revert to previous known-good version
   - Notify team via Slack/Discord

3. **Multi-Service Updates**
   - Update base image version across all services
   - Create PRs in all service repositories
   - Track update progress

4. **Advanced Monitoring**
   - Query build status across all services
   - Aggregate vulnerability scan results
   - Send weekly summary reports

None of these are implemented yet, but a GitHub App would enable them in the future.
