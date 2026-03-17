# Branch Protection Requirements

This document describes the required GitHub branch protection settings for repositories using the build-workflow system.

## Table of Contents
- [Why Branch Protection Matters](#why-branch-protection-matters)
- [Required Settings for Main Branch](#required-settings-for-main-branch)
- [Required Settings for Release Branch](#required-settings-for-release-branch)
- [Critical: Squash Merge Must Be Disabled](#critical-squash-merge-must-be-disabled)
- [Setup Instructions](#setup-instructions)

## Why Branch Protection Matters

The build-workflow system relies on specific GitHub behaviors to function correctly:

1. **PR image discovery**: The release workflow needs to find PR images built from the same commit SHA. Squash merging breaks this by creating a new commit.

2. **Status checks**: Build failures must block PR merges to prevent broken images from being promoted to release.

3. **Merge commit preservation**: The release workflow uses the merge commit SHA to discover PR images. This SHA must match the PR head SHA.

## Required Settings for Main Branch

### General Rules

| Setting | Value | Reason |
|---------|-------|--------|
| Require pull request reviews | **1 approving review** | Ensure code review before merge |
| Dismiss stale reviews | **Enabled** | Re-review after new commits |
| Require review from Code Owners | **Optional** | Depends on team structure |
| Require status checks to pass | **Required** | Block merges if builds fail |
| Require branches to be up to date | **Enabled** | Prevent integration issues |

### Required Status Checks

Add these as required status checks (they come from the PR validation workflow):

- `validate / promote-or-build (variant-name, platform)` - One for each variant+platform combination

**Example for a service with 2 variants × 2 platforms:**
- `validate / promote-or-build (radarr-latest, linux/amd64)`
- `validate / promote-or-build (radarr-latest, linux/arm64)`
- `validate / promote-or-build (radarr-debug, linux/amd64)`
- `validate / promote-or-build (radarr-debug, linux/arm64)`

**Note:** The exact names depend on your `docker-matrix.json` configuration.

### Merge Settings

| Setting | Value | Reason |
|---------|-------|--------|
| Allow merge commits | **Enabled** | Creates merge commit needed for image discovery |
| Allow squash merging | **DISABLED** | ⚠️ CRITICAL: Breaks PR image discovery |
| Allow rebase merging | **Disabled** | Not compatible with PR image workflow |

### Other Protections

| Setting | Value | Reason |
|---------|-------|--------|
| Require linear history | **Disabled** | Merge commits are not linear |
| Require deployments to succeed | **Optional** | Use if you have deployment workflows |
| Lock branch | **Disabled** | Would prevent all merges |
| Do not allow bypassing settings | **Enabled** | Enforce rules for all users |

## Required Settings for Release Branch

The release branch has simpler protection since it receives merges from main:

### General Rules

| Setting | Value | Reason |
|---------|-------|--------|
| Require pull request reviews | **Disabled** | Automated merges from main |
| Require status checks to pass | **Required** | Builds must succeed before promotion |
| Require branches to be up to date | **Disabled** | Automated merges handle this |

### Required Status Checks

Add the release workflow as a required status check:

- `release / promote-or-build (variant-name, platform)` - One for each variant+platform combination
- `release / create-manifests` - Multi-arch manifest creation and releases.json update

### Merge Settings

| Setting | Value | Reason |
|---------|-------|--------|
| Allow merge commits | **Enabled** | Standard merge strategy |
| Allow squash merging | **Disabled** | Not used for release branch |
| Allow rebase merging | **Disabled** | Not used for release branch |

### Other Protections

| Setting | Value | Reason |
|---------|-------|--------|
| Require linear history | **Disabled** | Merge commits are not linear |
| Lock branch | **Disabled** | Would prevent releases |
| Restrict pushes | **Recommended** | Only CI should push to release |

## Critical: Squash Merge Must Be Disabled

### Why This Is Critical

The release workflow discovers PR images using this logic:

1. PR builds image: `pr-123-abc1234-amd64` (where `abc1234` is the PR head SHA)
2. PR is merged to main with **merge commit**
3. Main is merged to release branch, preserving the merge commit
4. Release workflow uses `git log` to find PR number and original SHA
5. Release workflow looks for image `pr-123-abc1234-amd64` to promote

**With squash merge enabled:**

1. PR builds image: `pr-123-abc1234-amd64`
2. PR is **squashed** to main creating **NEW SHA**: `xyz9876`
3. Release workflow looks for image `pr-123-xyz9876-amd64` ❌ **DOESN'T EXIST**
4. Release workflow rebuilds from scratch (slow, wastes compute)

### How to Verify

Check your repository settings:

```bash
# Using GitHub CLI
gh repo edit --enable-merge-commit --disable-squash-merge --disable-rebase-merge
```

Or via web UI:
1. Go to repository **Settings**
2. Scroll to **Pull Requests** section
3. Ensure:
   - ✅ **Allow merge commits** is checked
   - ❌ **Allow squash merging** is **unchecked**
   - ❌ **Allow rebase merging** is **unchecked**

## Setup Instructions

### Using GitHub CLI

```bash
# Set main branch protection
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field required_status_checks[strict]=true \
  --field required_status_checks[contexts][]=validate \
  --field required_pull_request_reviews[required_approving_review_count]=1 \
  --field required_pull_request_reviews[dismiss_stale_reviews]=true \
  --field enforce_admins=true \
  --field restrictions=null

# Set release branch protection
gh api repos/{owner}/{repo}/branches/release/protection \
  --method PUT \
  --field required_status_checks[strict]=false \
  --field required_status_checks[contexts][]=release \
  --field required_pull_request_reviews=null \
  --field enforce_admins=true \
  --field restrictions=null

# Disable squash merge
gh repo edit --enable-merge-commit --disable-squash-merge --disable-rebase-merge
```

### Using Web UI

#### Main Branch

1. Go to **Settings** → **Branches**
2. Click **Add branch protection rule**
3. Branch name pattern: `main`
4. Enable:
   - ✅ Require a pull request before merging
     - Require approvals: **1**
     - Dismiss stale pull request approvals when new commits are pushed
   - ✅ Require status checks to pass before merging
     - Require branches to be up to date before merging
     - Add status checks (will appear after first PR builds)
   - ✅ Do not allow bypassing the above settings
5. Click **Create** or **Save changes**

#### Release Branch

1. Go to **Settings** → **Branches**
2. Click **Add branch protection rule**
3. Branch name pattern: `release`
4. Enable:
   - ✅ Require status checks to pass before merging
     - Add release workflow status checks
   - ✅ Do not allow bypassing the above settings
5. Click **Create** or **Save changes**

#### Repository Settings

1. Go to **Settings** → **General**
2. Scroll to **Pull Requests** section
3. Configure:
   - ✅ **Allow merge commits** - checked
   - ❌ **Allow squash merging** - **unchecked**
   - ❌ **Allow rebase merging** - **unchecked**
4. Click **Save**

## Verification

### Test Main Branch Protection

```bash
# Try to push directly to main (should fail)
git checkout main
git commit --allow-empty -m "Test direct push"
git push origin main
# Expected: remote rejected (protected branch)

# Try to merge without status checks (should fail via PR)
# 1. Create PR without waiting for builds
# 2. Try to merge immediately
# Expected: Merge button disabled until builds pass
```

### Test Merge Commit Creation

```bash
# Create a test PR
git checkout -b test-merge-behavior
git commit --allow-empty -m "Test merge commit"
git push origin test-merge-behavior

# Create PR and merge via UI
# After merge, check main branch:
git checkout main
git pull
git log --oneline -3
# Expected output should show merge commit:
#   abc1234 Merge pull request #123 from test-merge-behavior
#   def5678 Test merge commit
#   ...

# Verify it's a merge commit (has 2 parents)
git rev-parse HEAD^2
# Expected: Should return a SHA (second parent exists)
```

### Test PR Image Discovery

```bash
# After merging a PR that built images:
gh run list --branch main --workflow build-images-rebuild.yml --json conclusion,databaseId --limit 1

# Check that release workflow can find PR images
gh run view {run_id} --log | grep "Found PR image"
# Expected: Should show successful discovery of pr-{number}-{sha} images
```

## Troubleshooting

### Status checks not appearing

**Problem:** Required status checks list is empty when setting up branch protection.

**Solution:** Status checks only appear after they've run at least once. Create a test PR to trigger builds, then add the status check names to branch protection.

### Merge button shows "Squash and merge"

**Problem:** Despite disabling squash merge, the button still appears.

**Solution:**
1. Check repository settings again
2. Browser cache: Hard refresh (Ctrl+F5 or Cmd+Shift+R)
3. Verify with: `gh repo view --json squashMergeAllowed`

### Release workflow rebuilding instead of promoting

**Problem:** Release workflow is rebuilding images instead of copying PR images.

**Causes:**
1. Squash merge is enabled (check repository settings)
2. PR images were not successfully pushed (check PR workflow logs)
3. PR images were deleted (check GHCR retention policy)

**Solution:**
1. Disable squash merge in repository settings
2. Verify PR workflow completes successfully
3. Check GHCR retention policy (see [ghcr-retention.md](./ghcr-retention.md))

### Unable to merge despite passing builds

**Problem:** PR builds passed but merge button is disabled.

**Causes:**
1. Branch is not up to date with main
2. Status check names don't match between workflow and branch protection
3. Required reviewers haven't approved

**Solution:**
1. Update branch: Click "Update branch" button
2. Check status check names match exactly
3. Request review from required reviewers

## Next Steps

- [GHCR Retention Policy Setup](./ghcr-retention.md)
- [GitHub App Setup for API Access](./github-app-setup.md)
- [Troubleshooting Guide](./troubleshooting.md)
