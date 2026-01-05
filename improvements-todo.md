# GitHub Actions Workflows & Actions - Improvements TODO

> **Generated**: 2025-01-XX  
> **Purpose**: Comprehensive list of architectural improvements, security fixes, and best practices recommendations for the Runlix build-workflow repository.

---

## Executive Summary

### Overall Assessment

| Category | Score | Status |
|----------|-------|--------|
| **Overall Architecture** | 8/10 | ✅ Strong modular design |
| **Security Posture** | 6/10 | ⚠️ Needs hardening |
| **Maintainability** | 7/10 | ✅ Good, with room for improvement |
| **GitHub Best Practices** | 7/10 | ✅ Good foundation |

### Quick Reference: Priority Matrix

| Priority | Count | Focus Area |
|----------|-------|------------|
| **P1 - Critical** | 4 (2 completed) | Security fixes |
| **P2 - High** | 5 | Best practices & optimization |
| **P3 - Medium** | 4 | Maintainability & documentation |

---

## Priority 1: Security Fixes (Critical)

### 🔴 SEC-001: Credential Exposure in Git Clone URL

**Status**: ✅ **Completed**  
**Files Affected**: 
- `.github/workflows/update-digests.yml` (line 61)
- `.github/workflows/update-versions.yml` (line 60)

#### Issue Description

The workflow uses a token directly in the git clone URL, which can be logged by GitHub Actions and exposed in workflow logs.

#### Current Code (Fixed)

**Before (Insecure):**
```yaml:61:61:.github/workflows/update-digests.yml
git clone --depth 1 -b "$BRANCH" "https://x-access-token:${GH_TOKEN}@github.com/$OWNER/$REPO.git" "$DIR"
```

**After (Secure):**
```yaml:60:64:.github/workflows/update-digests.yml
gh repo clone "$OWNER/$REPO" "$DIR" -- --branch "$BRANCH" --depth 1
cd "$DIR"

# Configure git credential helper for push operations (non-persistent)
git config --global credential.helper '!f() { echo "username=x-access-token"; echo "password=${GH_TOKEN}"; }; f'
```

#### Risk Assessment

- **Impact**: High - Token could be exposed in logs
- **Likelihood**: Medium - Depends on log verbosity settings
- **Severity**: Critical

#### Recommended Fix

Use GitHub CLI (`gh repo clone`) which handles authentication securely:

```yaml
# Replace line 59-61 with:
DIR=$(mktemp -d)
gh repo clone "$OWNER/$REPO" "$DIR" -- --branch "$BRANCH" --depth 1
cd "$DIR"
```

**Alternative**: Use git credential helper with environment variable:

```yaml
# Set up credential helper
git config --global credential.helper '!f() { echo "username=x-access-token"; echo "password=${GH_TOKEN}"; }; f'
git clone --depth 1 -b "$BRANCH" "https://github.com/$OWNER/$REPO.git" "$DIR"
```

#### Implementation Steps

1. [x] Update `update-digests.yml` line 61
2. [x] Check `update-versions.yml` for similar pattern
3. [x] Test the workflow manually to ensure authentication works
4. [x] Verify no tokens appear in workflow logs

#### References

- [GitHub Actions Security Best Practices](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Git Credential Helper](https://git-scm.com/docs/git-credential)

---

### 🔴 SEC-002: Credential File Storage

**Status**: ✅ **Completed**  
**Files Affected**: 
- `.github/actions/update-tags-json/action.yml` (lines 76-77)

#### Issue Description

The action stores GitHub credentials in a plain text file (`~/.git-credentials`), which persists on the runner disk and could be accessed by subsequent steps or malicious code.

#### Current Code (Fixed)

**Before (Insecure):**
```yaml:77:79:.github/actions/update-tags-json/action.yml
# Configure git to use GitHub App token for authentication
git config --global credential.helper store
echo "https://${APP_BOT_NAME}:${GITHUB_TOKEN}@github.com" > ~/.git-credentials
```

**After (Secure):**
```yaml:76:77:.github/actions/update-tags-json/action.yml
# Configure git to use GitHub CLI for authentication (uses built-in flows)
gh auth setup-git
```

#### Risk Assessment

- **Impact**: High - Credentials persist on disk
- **Likelihood**: Low - But risk increases with longer-running jobs
- **Severity**: Critical

#### Recommended Fix

Use GitHub CLI's built-in authentication mechanism:

```yaml
# Configure git to use GitHub CLI for authentication (uses built-in flows)
gh auth setup-git
```

This approach:
- ✅ Uses GitHub CLI's secure authentication flows
- ✅ Automatically detects `GH_TOKEN` environment variable
- ✅ No credential file storage on disk
- ✅ Eliminates need for manual credential helper configuration

#### Implementation Steps

1. [x] Update `update-tags-json/action.yml` lines 77-79 (now 76-77)
2. [x] Test git operations still work correctly
3. [x] Verify credentials are not persisted to disk
4. [x] Check for similar patterns in other actions
5. [x] Remove unused environment variables (`GITHUB_TOKEN`, `APP_SLUG`)

#### References

- [Git Credential Storage](https://git-scm.com/docs/git-credential-store)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

---

### 🔴 SEC-003: Least-Privilege Permissions

**Status**: ✅ **Completed**  
**Files Affected**: 
- `.github/workflows/on-merge.yml` (removed workflow-level permissions, added job-level)
- `.github/workflows/on-pr.yml` (removed workflow-level permissions, added job-level)
- `.github/workflows/update-digests.yml` (removed workflow-level permissions, added job-level)
- `.github/workflows/update-versions.yml` (removed workflow-level permissions, added job-level)

#### Issue Description

Workflows request broad permissions at the workflow level, granting more access than necessary for individual jobs.

#### Current Code (Fixed)

**Before (Insecure):**
```yaml:12:14:.github/workflows/on-merge.yml
permissions:
  contents: write
  packages: write
```

**After (Secure):**
Workflow-level permissions removed. Each job now has minimal required permissions (see Permission Requirements Reference below).

#### Risk Assessment

- **Impact**: Medium - Unnecessary permissions increase attack surface
- **Likelihood**: Low - But violates principle of least privilege
- **Severity**: High

#### Recommended Fix

Move permissions to job level with minimal required permissions:

```yaml
# Remove workflow-level permissions, add per-job:

jobs:
  prepare-version:
    permissions:
      contents: read  # Only needs to read VERSION.json
    runs-on: ubuntu-latest
    # ...

  build-and-test:
    permissions:
      contents: read
      packages: write  # Only needs to push images
    runs-on: ubuntu-latest
    # ...

  publish:
    permissions:
      contents: write  # Needs to update tags.json
      packages: read   # Needs to read images for manifest lists
    runs-on: ubuntu-latest
    # ...

  create-tag:
    permissions:
      contents: write  # Only needs to create tags
    runs-on: ubuntu-latest
    # ...
```

#### Implementation Steps

1. [x] Audit each job to determine minimum required permissions
2. [x] Remove workflow-level permissions from `on-merge.yml`
3. [x] Remove workflow-level permissions from `on-pr.yml`
4. [x] Add job-level permissions to each job
5. [x] Test workflows to ensure they still function (syntax verified, no linting errors)
6. [x] Document permission requirements per job

#### Permission Requirements Reference

**on-merge.yml:**
| Job | Contents | Packages | Pull Requests | Notes |
|-----|----------|-----------|----------------|-------|
| `prepare-version` | read | - | - | Only reads VERSION.json, checks PR images |
| `re-tag` | - | write | - | Only pushes Docker images (re-tagging) |
| `build-and-test` | read | write | - | Builds and pushes images |
| `publish` | read | read | - | Creates manifest lists, updates tags.json (git ops use GitHub App token) |
| `create-tag` | write | - | - | Creates git tags (uses GITHUB_TOKEN explicitly) |

**on-pr.yml:**
| Job | Contents | Packages | Pull Requests | Notes |
|-----|----------|-----------|----------------|-------|
| `prepare-version` | read | - | - | Only reads VERSION.json |
| `test` | read | write | - | Builds PR images |
| `test-aggregate` | read | - | - | Minimal permissions for safety |
| `auto-merge` | - | - | write | Merges PRs (uses GitHub App token) |

**update-digests.yml & update-versions.yml:**
| Job | Contents | Packages | Pull Requests | Notes |
|-----|----------|-----------|----------------|-------|
| `update` | read | - | write | Clones repos, commits changes, creates PRs (git ops use GitHub App token) |

#### Implementation Notes

- **GitHub App Token vs GITHUB_TOKEN**: Most git operations (push, commit, PR creation) use GitHub App tokens generated via `actions/create-github-app-token@v2`, which have permissions configured at the app installation level. Workflow permissions only affect `GITHUB_TOKEN`, which is used by `actions/checkout` by default.
- **Why `publish` job doesn't need `contents: write`**: The `publish` job's `update-tags-json` action uses GitHub App token for all git operations (via `gh auth setup-git`), so `GITHUB_TOKEN` only needs `contents: read` for checkout operations.
- **Why `create-tag` needs `contents: write`**: The `create-tag` job explicitly uses `GITHUB_TOKEN` for checkout and tag push operations, so it requires `contents: write` permission.
- **Reduced Attack Surface**: By moving permissions to job level, jobs that only read files or push Docker images no longer have unnecessary write permissions to repository contents.

#### References

- [GitHub Actions Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)
- [Least Privilege Principle](https://en.wikipedia.org/wiki/Principle_of_least_privilege)

---

### 🔴 SEC-004: Private Key Propagation Through Action Layers

**Status**: ⚠️ **High**  
**Files Affected**: 
- `.github/workflows/on-merge.yml` (lines 201-202)
- `.github/actions/update-tags-json/action.yml` (lines 32-34, 215-216, 226-227)
- `.github/actions/auto-merge-pr/action.yml` (lines 14-16, 33-35)
- `.github/actions/delete-branch/action.yml` (if similar pattern)

#### Issue Description

Private keys are passed as inputs through multiple action layers, increasing the risk of exposure. Private keys should only be used at the workflow level to generate tokens, and tokens should be passed to actions instead.

#### Current Code

```yaml:201:202:.github/workflows/on-merge.yml
app_id: ${{ secrets.RUNLIX_APP_ID }}
private_key: ${{ secrets.RUNLIX_PRIVATE_KEY }}
```

```yaml:32:34:.github/actions/update-tags-json/action.yml
private_key:
  description: 'GitHub App private key'
  required: true
```

#### Risk Assessment

- **Impact**: High - Private keys in multiple layers increase exposure risk
- **Likelihood**: Low - But violates security best practices
- **Severity**: High

#### Recommended Fix

Generate tokens at workflow level and pass tokens to actions:

**Workflow Level** (`on-merge.yml`):
```yaml
jobs:
  publish:
    steps:
      - name: Generate GitHub App Token
        id: app-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.RUNLIX_APP_ID }}
          private-key: ${{ secrets.RUNLIX_PRIVATE_KEY }}
          owner: ${{ github.repository_owner }}

      - name: Update tags.json
        uses: ./build-workflow/.github/actions/update-tags-json
        with:
          # ... other inputs ...
          github_token: ${{ steps.app-token.outputs.token }}  # Pass token, not key
```

**Action Level** (`update-tags-json/action.yml`):
```yaml
inputs:
  github_token:  # Changed from app_id + private_key
    description: 'GitHub token (from GitHub App)'
    required: true
  # Remove app_id and private_key inputs

runs:
  using: 'composite'
  steps:
    # Remove token generation step, use provided token
    - name: Update tags.json and create PR
      env:
        GITHUB_TOKEN: ${{ inputs.github_token }}
      # ...
```

#### Implementation Steps

1. [ ] Create new action: `generate-github-app-token` (shared action)
2. [ ] Update `update-tags-json/action.yml` to accept token instead of keys
3. [ ] Update `auto-merge-pr/action.yml` to accept token instead of keys
4. [ ] Update `delete-branch/action.yml` to accept token instead of keys
5. [ ] Update all workflows to generate tokens and pass to actions
6. [ ] Test all affected workflows
7. [ ] Remove private_key inputs from action definitions

#### Architecture Diagram

**Current Flow** (Insecure):
```mermaid
graph LR
    A[Workflow Secrets] -->|private_key| B[Action Input]
    B -->|private_key| C[Token Generation]
    C -->|token| D[GitHub API]
    
    style A fill:#ff6b6b
    style B fill:#ff6b6b
```

**Proposed Flow** (Secure):
```mermaid
graph LR
    A[Workflow Secrets] -->|private_key| B[Workflow Token Gen]
    B -->|token| C[Action Input]
    C -->|token| D[GitHub API]
    
    style A fill:#51cf66
    style B fill:#51cf66
    style C fill:#51cf66
```

#### References

- [GitHub App Authentication](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app)
- [GitHub Actions Security Best Practices](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

---

## Priority 2: Best Practices Improvements

### 🟡 BP-001: Create Shared GitHub App Token Action

**Status**: 📋 **High Priority**  
**Files Affected**: 
- `.github/actions/generate-github-app-token/action.yml` (new file)
- `.github/actions/update-tags-json/action.yml` (refactor)
- `.github/actions/auto-merge-pr/action.yml` (refactor)
- `.github/actions/delete-branch/action.yml` (refactor)
- `.github/workflows/update-digests.yml` (refactor)
- `.github/workflows/update-versions.yml` (refactor)

#### Current State

GitHub App token generation is duplicated across multiple actions and workflows, with ~15-20 lines of code repeated each time.

#### Issue

- Code duplication increases maintenance burden
- Inconsistent token generation patterns
- Harder to update token generation logic
- Violates DRY (Don't Repeat Yourself) principle

#### Best Practice

Create a single, reusable action for GitHub App token generation that can be used across all workflows and actions.

#### Implementation

**Create New Action**: `.github/actions/generate-github-app-token/action.yml`

```yaml
name: 'Generate GitHub App Token'
description: 'Generate a GitHub App installation token and configure git'

inputs:
  app_id:
    description: 'GitHub App ID'
    required: true
  private_key:
    description: 'GitHub App private key'
    required: true
  owner:
    description: 'Repository owner (organization or user)'
    required: true
  configure_git:
    description: 'Whether to configure git user name and email'
    required: false
    default: 'true'

outputs:
  token:
    description: 'GitHub App installation token'
    value: ${{ steps.app-token.outputs.token }}
  app_slug:
    description: 'GitHub App slug'
    value: ${{ steps.app-token.outputs.app-slug }}
  bot_name:
    description: 'GitHub App bot name'
    value: ${{ steps.app-token.outputs.app-slug }}[bot]
  bot_email:
    description: 'GitHub App bot email'
    value: ${{ steps.get-user-id.outputs.user-id }}+${{ steps.app-token.outputs.app-slug }}[bot]@users.noreply.github.com
  user_id:
    description: 'GitHub App bot user ID'
    value: ${{ steps.get-user-id.outputs.user-id }}

runs:
  using: 'composite'
  steps:
    - name: Generate GitHub App Token
      id: app-token
      uses: actions/create-github-app-token@v2
      with:
        app-id: ${{ inputs.app_id }}
        private-key: ${{ inputs.private_key }}
        owner: ${{ inputs.owner }}

    - name: Get GitHub App Bot User ID
      id: get-user-id
      shell: bash
      run: echo "user-id=$(gh api "/users/${{ steps.app-token.outputs.app-slug }}[bot]" --jq .id)" >> "$GITHUB_OUTPUT"
      env:
        GH_TOKEN: ${{ steps.app-token.outputs.token }}

    - name: Configure Git
      if: inputs.configure_git == 'true'
      shell: bash
      run: |
        git config --global user.name '${{ steps.app-token.outputs.app-slug }}[bot]'
        git config --global user.email '${{ steps.get-user-id.outputs.user-id }}+${{ steps.app-token.outputs.app-slug }}[bot]@users.noreply.github.com'
```

**Update Workflow** (example: `update-digests.yml`):

```yaml
steps:
  - name: Generate GitHub App Token
    id: app-token
    uses: ./build-workflow/.github/actions/generate-github-app-token
    with:
      app_id: ${{ secrets.RUNLIX_APP_ID }}
      private_key: ${{ secrets.RUNLIX_PRIVATE_KEY }}
      owner: ${{ github.repository_owner }}
      configure_git: 'true'

  - name: Update digests across repositories
    env:
      OWNER: ${{ github.repository_owner }}
      GH_TOKEN: ${{ steps.app-token.outputs.token }}
    run: |
      # ... existing script ...
```

#### Files Affected

1. **New**: `.github/actions/generate-github-app-token/action.yml`
2. **Update**: `.github/workflows/update-digests.yml` (lines 21-38)
3. **Update**: `.github/workflows/update-versions.yml` (lines 21-38)
4. **Update**: `.github/actions/update-tags-json/action.yml` (lines 42-55)
5. **Update**: `.github/actions/auto-merge-pr/action.yml` (lines 29-35)
6. **Update**: `.github/actions/delete-branch/action.yml` (if similar pattern)

#### Benefits

- Reduces code duplication by ~50-70 lines per usage
- Single source of truth for token generation
- Easier to update token generation logic
- Consistent error handling
- Better testability

#### Implementation Steps

1. [ ] Create `.github/actions/generate-github-app-token/action.yml`
2. [ ] Test the new action in isolation
3. [ ] Update `update-digests.yml` to use new action
4. [ ] Update `update-versions.yml` to use new action
5. [ ] Update `update-tags-json/action.yml` to use new action
6. [ ] Update `auto-merge-pr/action.yml` to use new action
7. [ ] Update `delete-branch/action.yml` if needed
8. [ ] Test all workflows end-to-end
9. [ ] Remove duplicate token generation code

#### References

- [GitHub Actions Reusability](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [DRY Principle](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)

---

### 🟡 BP-002: Add Workflow-Level Concurrency Controls

**Status**: 📋 **High Priority**  
**Files Affected**: 
- `.github/workflows/on-merge.yml`
- `.github/workflows/on-pr.yml`

#### Current State

Workflows can run multiple instances simultaneously, potentially causing:
- Race conditions in tag creation
- Duplicate PR creation
- Resource conflicts
- Unnecessary CI costs

#### Issue

No concurrency controls at workflow level, only at job level in scheduled workflows.

#### Best Practice

GitHub recommends using concurrency groups to prevent multiple workflow runs from executing simultaneously for the same context (branch, PR, etc.).

#### Implementation

**Add to `on-merge.yml`**:

```yaml
name: On Merge Flow

on:
  workflow_call:
    inputs:
      run_smoke_test:
        description: 'Whether to run the smoke test (set false for base images)'
        type: boolean
        required: false
        default: true

# Add concurrency control
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false  # Don't cancel, wait for previous to finish

permissions:
  contents: write
  packages: write
```

**Add to `on-pr.yml`**:

```yaml
name: On PR Flow

on:
  workflow_call:
    inputs:
      run_smoke_test:
        description: 'Whether to run the smoke test (set false for base images)'
        type: boolean
        required: false
        default: true

# Add concurrency control
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true  # Cancel previous runs for same PR

permissions:
  contents: read
  pull-requests: write
  packages: write
```

#### Concurrency Strategy

| Workflow | Group Key | Cancel In Progress | Rationale |
|----------|-----------|---------------------|------------|
| `on-merge.yml` | `workflow-ref` | `false` | Don't cancel merge builds, queue them |
| `on-pr.yml` | `workflow-pr-number` | `true` | Cancel old PR builds when new commits pushed |
| `update-digests.yml` | `update-digests-automated` | `false` | Already has concurrency (keep existing) |
| `update-versions.yml` | `update-versions-automated` | `false` | Already has concurrency (keep existing) |

#### Implementation Steps

1. [ ] Add concurrency to `on-merge.yml`
2. [ ] Add concurrency to `on-pr.yml`
3. [ ] Test with multiple simultaneous triggers
4. [ ] Verify queuing behavior works correctly
5. [ ] Document concurrency strategy

#### References

- [GitHub Actions Concurrency](https://docs.github.com/en/actions/using-jobs/using-concurrency)
- [Controlling Concurrent Workflows](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#concurrency)

---

### 🟡 BP-003: Optimize Checkout Operations

**Status**: 📋 **Medium Priority**  
**Files Affected**: 
- `.github/workflows/on-merge.yml` (multiple checkout steps)
- `.github/workflows/on-pr.yml` (multiple checkout steps)
- `.github/actions/checkout-build-workflow/action.yml` (new file)

#### Current State

The `build-workflow` repository is checked out multiple times across different jobs:

- `on-merge.yml`: Checked out in 4 different jobs
- `on-pr.yml`: Checked out in 3 different jobs

#### Issue

- Redundant network operations
- Slower workflow execution
- Increased CI minutes usage
- Harder to maintain checkout configuration

#### Best Practice

Create a shared action for checking out the build-workflow repository that can be reused, or use caching to speed up checkouts.

#### Implementation

**Option 1: Shared Checkout Action** (Recommended)

Create `.github/actions/checkout-build-workflow/action.yml`:

```yaml
name: 'Checkout Build Workflow'
description: 'Checkout the build-workflow repository for actions'

inputs:
  path:
    description: 'Path to checkout build-workflow'
    required: false
    default: 'build-workflow'
  ref:
    description: 'Git ref to checkout'
    required: false
    default: 'main'

runs:
  using: 'composite'
  steps:
    - name: Checkout build-workflow for actions
      uses: actions/checkout@v6
      with:
        repository: runlix/build-workflow
        path: ${{ inputs.path }}
        ref: ${{ inputs.ref }}
```

**Usage in workflows**:

```yaml
# Replace all instances of:
- name: Checkout build-workflow for actions
  uses: actions/checkout@v6
  with:
    repository: runlix/build-workflow
    path: build-workflow

# With:
- name: Checkout build-workflow for actions
  uses: ./build-workflow/.github/actions/checkout-build-workflow
```

**Option 2: Use Caching** (Alternative)

```yaml
- name: Cache build-workflow
  uses: actions/cache@v4
  with:
    path: build-workflow
    key: build-workflow-${{ github.sha }}
    restore-keys: |
      build-workflow-

- name: Checkout build-workflow
  if: steps.cache.outputs.cache-hit != 'true'
  uses: actions/checkout@v6
  with:
    repository: runlix/build-workflow
    path: build-workflow
```

#### Files Affected

1. **New**: `.github/actions/checkout-build-workflow/action.yml`
2. **Update**: `.github/workflows/on-merge.yml` (lines 36-40, 89-93, 122-126, 157-161, 184-188, 219-223)
3. **Update**: `.github/workflows/on-pr.yml` (lines 35-39, 71-75, 121-125)

#### Benefits

- Single source of truth for checkout configuration
- Easier to update checkout logic (e.g., change branch)
- Consistent checkout behavior
- Potential for caching optimization

#### Implementation Steps

1. [ ] Create `.github/actions/checkout-build-workflow/action.yml`
2. [ ] Update all checkout steps in `on-merge.yml`
3. [ ] Update all checkout steps in `on-pr.yml`
4. [ ] Test workflows to ensure actions are found correctly
5. [ ] Consider adding caching for further optimization

#### References

- [GitHub Actions Caching](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [Checkout Action](https://github.com/actions/checkout)

---

### 🟡 BP-004: Improve Error Handling in Scheduled Workflows

**Status**: 📋 **Medium Priority**  
**Files Affected**: 
- `.github/workflows/update-digests.yml` (lines 64-65, 78-80)
- `.github/workflows/update-versions.yml` (similar pattern)

#### Current State

Error handling uses basic `|| { echo; continue; }` patterns that don't provide detailed error context or retry logic.

#### Issue

- Errors are silently swallowed with generic messages
- No retry logic for transient failures
- Difficult to debug when workflows fail
- No notification of failures

#### Best Practice

Implement comprehensive error handling with:
- Detailed error messages
- Retry logic for transient failures
- Proper error propagation
- Failure notifications

#### Implementation

**Current Code** (lines 64-65):

```yaml
[[ -x update-digests.sh ]] || { echo "⏭ No script"; cd ..; rm -rf "$DIR"; continue; }
./update-digests.sh || { echo "❌ Script failed"; cd ..; rm -rf "$DIR"; continue; }
```

**Improved Code**:

```yaml
# Function for error handling
handle_error() {
  local exit_code=$1
  local context=$2
  local repo=$3
  local branch=$4
  
  if [ $exit_code -ne 0 ]; then
    echo "::error::Failed in $context for $repo/$branch (exit code: $exit_code)"
    echo "::group::Error Details"
    echo "Repository: $repo"
    echo "Branch: $branch"
    echo "Context: $context"
    echo "Exit Code: $exit_code"
    echo "::endgroup::"
    cd ..; rm -rf "$DIR"
    return $exit_code
  fi
}

# Check script exists
if [[ ! -x update-digests.sh ]]; then
  echo "::notice::No update-digests.sh script found for $OWNER/$REPO (branch: $BRANCH)"
  cd ..; rm -rf "$DIR"
  continue
fi

# Run script with retry logic
MAX_RETRIES=3
RETRY_COUNT=0
EXIT_CODE=1

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if ./update-digests.sh; then
    EXIT_CODE=0
    break
  else
    EXIT_CODE=$?
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
      echo "::warning::Script failed, retrying ($RETRY_COUNT/$MAX_RETRIES)..."
      sleep $((RETRY_COUNT * 10))  # Exponential backoff
    fi
  fi
done

if [ $EXIT_CODE -ne 0 ]; then
  handle_error $EXIT_CODE "update-digests.sh" "$OWNER/$REPO" "$BRANCH"
  continue
fi
```

#### Files Affected

1. **Update**: `.github/workflows/update-digests.yml` (lines 45-92)
2. **Update**: `.github/workflows/update-versions.yml` (similar pattern)

#### Benefits

- Better error visibility in GitHub UI
- Automatic retry for transient failures
- Easier debugging with detailed error messages
- Proper error propagation

#### Implementation Steps

1. [ ] Add error handling functions to `update-digests.yml`
2. [ ] Add retry logic for script execution
3. [ ] Add GitHub Actions annotations (::error::, ::warning::)
4. [ ] Test error scenarios
5. [ ] Apply same pattern to `update-versions.yml`
6. [ ] Document error handling strategy

#### References

- [GitHub Actions Workflow Commands](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions)
- [Error Handling Best Practices](https://docs.github.com/en/actions/learn-github-actions/workflow-syntax-for-github-actions#jobsjob_idstepscontinue-on-error)

---

### 🟡 BP-005: Configure Matrix Strategy with fail-fast

**Status**: 📋 **Low Priority**  
**Files Affected**: 
- `.github/workflows/on-merge.yml` (lines 85-87, 113-115)
- `.github/workflows/on-pr.yml` (lines 62-64)

#### Current State

Matrix builds don't specify `fail-fast` strategy, which means all matrix jobs run even if one fails (default behavior).

#### Issue

- For independent builds (different architectures), we want all to complete even if one fails
- Current behavior may cancel other builds if one fails (depending on GitHub's default)

#### Best Practice

Explicitly configure `fail-fast` based on whether matrix jobs are independent or dependent.

#### Implementation

**For Independent Builds** (different architectures):

```yaml
strategy:
  matrix:
    target: ${{ fromJson(needs.prepare-version.outputs.matrix) }}
  fail-fast: false  # Don't cancel other builds if one fails
```

**For Dependent Builds** (if any):

```yaml
strategy:
  matrix:
    target: ${{ fromJson(needs.prepare-version.outputs.matrix) }}
  fail-fast: true  # Cancel other builds if one fails
```

#### Files Affected

1. **Update**: `.github/workflows/on-merge.yml`
   - `re-tag` job (line 85-87)
   - `build-and-test` job (line 113-115)
2. **Update**: `.github/workflows/on-pr.yml`
   - `test` job (line 62-64)

#### Recommendation

Since architecture builds are independent, set `fail-fast: false`:

```yaml
re-tag:
  needs: prepare-version
  if: needs.prepare-version.outputs.pr_images_found == 'true'
  runs-on: ubuntu-latest
  strategy:
    matrix:
      target: ${{ fromJson(needs.prepare-version.outputs.matrix) }}
    fail-fast: false  # Independent architecture builds
```

#### Implementation Steps

1. [ ] Add `fail-fast: false` to `re-tag` job in `on-merge.yml`
2. [ ] Add `fail-fast: false` to `build-and-test` job in `on-merge.yml`
3. [ ] Add `fail-fast: false` to `test` job in `on-pr.yml`
4. [ ] Test with intentional failure to verify behavior
5. [ ] Document matrix strategy decision

#### References

- [Matrix Strategy](https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs)
- [fail-fast Configuration](https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs#using-a-matrix-strategy)

---

## Priority 3: Maintainability Enhancements

### 🟢 MNT-001: Create Action Version Registry

**Status**: 📋 **Medium Priority**  
**Files Affected**: 
- `.github/action-versions.yml` (new file)
- All action files using external actions

#### Current Pattern

Action versions are hardcoded as commit SHAs scattered across multiple files:

```yaml
uses: docker/setup-buildx-action@8d2750c68a42422c14e847fe6c8ac0403b4cbd6f  # v3.12.0
uses: docker/login-action@5e57cd118135c172c3672efd75eb46360885c0ef  # v3.6.0
uses: actions/checkout@v6
```

#### Issue

- Hard to track which actions need updates
- Inconsistent versioning (some use tags, some use SHAs)
- Difficult to update versions across multiple files
- No centralized version management

#### Proposed Pattern

Create a version registry file and reference it (or use a script to update versions).

#### Implementation

**Option 1: Version Registry File** (Recommended)

Create `.github/action-versions.yml`:

```yaml
# GitHub Actions Version Registry
# Update versions here, then use script to update action files

actions:
  checkout:
    version: v6
    sha: null  # Use version tag
  
  docker-setup-buildx:
    version: v3.12.0
    sha: 8d2750c68a42422c14e847fe6c8ac0403b4cbd6f
  
  docker-login:
    version: v3.6.0
    sha: 5e57cd118135c172c3672efd75eb46360885c0ef
  
  docker-setup-qemu:
    version: v3.7.0
    sha: c7c53464625b32c7a7e944ae62b3e17d2b600130
  
  docker-build-push:
    version: v6.18.0
    sha: 263435318d21b8e681c14492fe198d362a7d2c83
  
  upload-artifact:
    version: v6.0.0
    sha: b7c566a772e6b6bfb58ed0dc250532a479d7789f
  
  create-github-app-token:
    version: v2
    sha: null
```

**Option 2: Use Dependabot** (Alternative)

Create `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

#### Files Affected

1. **New**: `.github/action-versions.yml`
2. **New**: `.github/dependabot.yml` (optional)
3. **Update**: All action files to reference versions consistently

#### Benefits

- Centralized version management
- Easier to audit and update
- Can use Dependabot for automatic updates
- Better documentation of dependencies

#### Implementation Steps

1. [ ] Create `.github/action-versions.yml` with current versions
2. [ ] Document version update process
3. [ ] Consider adding Dependabot configuration
4. [ ] Create script to update action files from registry (optional)
5. [ ] Document versioning strategy

#### References

- [Dependabot for GitHub Actions](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file#package-ecosystem)
- [GitHub Actions Versioning](https://docs.github.com/en/actions/creating-actions/about-actions#using-release-management-for-actions)

---

### 🟢 MNT-002: Add Workflow Documentation Standards

**Status**: 📋 **Low Priority**  
**Files Affected**: 
- All workflow files
- All action files

#### Current Pattern

Workflows have minimal inline documentation. Complex conditions and logic lack explanation.

#### Issue

- Hard for new contributors to understand workflows
- Complex conditions are not explained
- No documentation of "why" decisions were made
- Difficult to maintain without context

#### Proposed Pattern

Add comprehensive inline documentation following a standard format.

#### Implementation

**Documentation Template**:

```yaml
name: On Merge Flow

# Workflow Purpose:
# This workflow builds and publishes Docker images when changes are merged to the release branch.
# It optimizes builds by re-tagging PR images when available, avoiding unnecessary rebuilds.

on:
  workflow_call:
    inputs:
      run_smoke_test:
        description: 'Whether to run the smoke test (set false for base images)'
        type: boolean
        required: false
        default: true

# Concurrency: Prevent multiple instances from running simultaneously for the same branch
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false  # Queue builds rather than cancel (important for releases)

permissions:
  contents: write  # Needed for creating tags and updating tags.json
  packages: write  # Needed for pushing Docker images

jobs:
  prepare-version:
    # Purpose: Extract metadata and check if PR images exist for optimization
    runs-on: ubuntu-latest
    outputs:
      # ... outputs ...
    steps:
      # ... steps ...

  re-tag:
    # Purpose: Re-tag existing PR images to avoid rebuilding (optimization)
    # Condition: Only runs if PR images were found in prepare-version step
    needs: prepare-version
    if: needs.prepare-version.outputs.pr_images_found == 'true'
    # ... rest of job ...

  build-and-test:
    # Purpose: Build images from scratch if PR images don't exist
    # Condition: Only runs if PR images were NOT found
    needs: prepare-version
    if: needs.prepare-version.outputs.pr_images_found == 'false'
    # ... rest of job ...

  publish:
    # Purpose: Create manifest lists and update tags.json
    # Condition: Runs if EITHER re-tag OR build-and-test succeeded
    # Note: Uses always() to run even if one job failed, but checks for success
    needs: [prepare-version, re-tag, build-and-test]
    if: always() && (needs.re-tag.result == 'success' || needs.build-and-test.result == 'success')
    # ... rest of job ...
```

#### Documentation Standards

1. **Workflow Level**:
   - Purpose statement
   - Concurrency explanation
   - Permission justification

2. **Job Level**:
   - Purpose of the job
   - Condition explanations
   - Dependencies rationale

3. **Step Level** (for complex steps):
   - Why the step is needed
   - What it does
   - Any non-obvious logic

#### Files Affected

1. **Update**: `.github/workflows/on-merge.yml`
2. **Update**: `.github/workflows/on-pr.yml`
3. **Update**: `.github/workflows/update-digests.yml`
4. **Update**: `.github/workflows/update-versions.yml`
5. **Update**: Complex action files

#### Benefits

- Easier onboarding for new contributors
- Better understanding of workflow logic
- Easier maintenance
- Documents design decisions

#### Implementation Steps

1. [ ] Create documentation template
2. [ ] Add documentation to `on-merge.yml`
3. [ ] Add documentation to `on-pr.yml`
4. [ ] Add documentation to `update-digests.yml`
5. [ ] Add documentation to `update-versions.yml`
6. [ ] Document complex action logic
7. [ ] Create documentation standards guide

#### References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Code Documentation Best Practices](https://www.writethedocs.org/guide/writing/beginners-guide-to-docs/)

---

### 🟢 MNT-003: Standardize Error Messages

**Status**: 📋 **Low Priority**  
**Files Affected**: 
- All action files with error handling

#### Current Pattern

Error messages vary in format and detail:

```bash
echo "ERROR: password input is required"
echo "ERROR: builder_digest is required but was not provided or is empty"
echo "Failed to create PR. Response: ${PR_RESPONSE}"
```

#### Issue

- Inconsistent error message format
- Some errors lack context
- Difficult to search logs for specific errors
- No standardized error codes

#### Proposed Pattern

Create a standard error message format with consistent structure.

#### Implementation

**Error Message Template**:

```bash
# Format: [ERROR_CODE] Component: Description (Context)
# Example: [VALIDATION_001] docker-setup-login: Password input is required

# Standard error function
error_exit() {
  local code=$1
  local component=$2
  local message=$3
  local context=${4:-""}
  
  if [ -n "$context" ]; then
    echo "::error::[$code] $component: $message (Context: $context)" >&2
  else
    echo "::error::[$code] $component: $message" >&2
  fi
  exit 1
}

# Usage examples
error_exit "VALIDATION_001" "docker-setup-login" "Password input is required"
error_exit "VALIDATION_002" "prepare-build-args" "Builder digest is required" "Target: ${TARGET_NAME}"
```

**Error Code Registry** (`.github/error-codes.yml`):

```yaml
error_codes:
  VALIDATION_001: "Required input is missing"
  VALIDATION_002: "Required digest is missing or invalid"
  VALIDATION_003: "Invalid input format"
  GIT_001: "Git operation failed"
  GIT_002: "Branch creation failed"
  GIT_003: "Push operation failed"
  DOCKER_001: "Docker build failed"
  DOCKER_002: "Docker push failed"
  GITHUB_API_001: "GitHub API request failed"
  GITHUB_API_002: "PR creation failed"
```

#### Files Affected

1. **New**: `.github/error-codes.yml`
2. **Update**: All action files with error handling
3. **New**: Shared error handling script (optional)

#### Benefits

- Consistent error format
- Easier log searching
- Better error tracking
- Improved debugging

#### Implementation Steps

1. [ ] Create error code registry
2. [ ] Create standard error function
3. [ ] Update action files to use standard format
4. [ ] Document error codes
5. [ ] Test error messages in workflows

#### References

- [GitHub Actions Workflow Commands](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-error-message)

---

### 🟢 MNT-004: Extract Magic Strings to Constants

**Status**: 📋 **Low Priority**  
**Files Affected**: 
- `.github/actions/auto-merge-pr/action.yml` (lines 87-89)
- `.github/workflows/update-digests.yml` (line 84)
- Other files with hardcoded strings

#### Current Pattern

Magic strings are hardcoded throughout workflows and actions:

```yaml
# auto-merge-pr/action.yml
if [[ ! "${PR_TITLE}" =~ ^update-digests ]] && \
   [[ ! "${PR_TITLE}" =~ ^update-version- ]] && \
   [[ ! "${PR_TITLE}" =~ ^update-tags-json- ]]; then

# update-digests.yml
--title "update-digests"
--label "automated,dependencies"
```

#### Issue

- Hard to maintain (change in multiple places)
- Risk of typos
- No single source of truth
- Difficult to update consistently

#### Proposed Pattern

Extract magic strings to constants or inputs.

#### Implementation

**Option 1: Constants File** (`.github/constants.yml`):

```yaml
pr_titles:
  update_digests: "update-digests"
  update_versions: "update-version-"
  update_tags_json: "update-tags-json-"

pr_labels:
  automated: "automated"
  dependencies: "dependencies"
  default: "automated,dependencies"

commit_messages:
  upstream_update: "Upstream image update"
  upstream_update_skip_ci: "Upstream image update [skip ci]"
  tags_json_update: "Update tags.json for {branch} branch variants (version: {version}) [skip ci]"
```

**Option 2: Action Inputs** (for actions):

```yaml
inputs:
  pr_title_prefixes:
    description: 'Comma-separated list of PR title prefixes to auto-merge'
    required: false
    default: 'update-digests,update-version-,update-tags-json-'
```

**Usage in Actions**:

```yaml
# Instead of hardcoded strings
PR_TITLE_PREFIXES=("update-digests" "update-version-" "update-tags-json-")

# Check if PR title matches any prefix
MATCHED=false
for prefix in "${PR_TITLE_PREFIXES[@]}"; do
  if [[ "${PR_TITLE}" =~ ^${prefix} ]]; then
    MATCHED=true
    break
  fi
done

if [ "$MATCHED" = "false" ]; then
  echo "PR title does not match any auto-merge prefix"
  exit 0
fi
```

#### Files Affected

1. **New**: `.github/constants.yml` (optional)
2. **Update**: `.github/actions/auto-merge-pr/action.yml`
3. **Update**: `.github/workflows/update-digests.yml`
4. **Update**: `.github/workflows/update-versions.yml`
5. **Update**: `.github/actions/update-tags-json/action.yml`

#### Benefits

- Single source of truth
- Easier to maintain
- Reduced risk of typos
- Better testability

#### Implementation Steps

1. [ ] Identify all magic strings across workflows/actions
2. [ ] Create constants file or use inputs
3. [ ] Update actions to use constants/inputs
4. [ ] Update workflows to use constants
5. [ ] Test all affected workflows
6. [ ] Document constants

---

## Implementation Roadmap

### Phase 1: Critical Security Fixes (Week 1)

**Priority**: Must complete before any other changes

1. **SEC-001**: Fix credential exposure in git clone URL
   - Effort: 2 hours
   - Risk: Low (isolated change)
   - Dependencies: None

2. **SEC-002**: Remove credential file storage ✅ **Completed**
   - Effort: 2 hours
   - Risk: Low (isolated change)
   - Dependencies: None

3. **SEC-003**: Implement least-privilege permissions
   - Effort: 4 hours
   - Risk: Medium (requires testing)
   - Dependencies: None

4. **SEC-004**: Refactor private key propagation
   - Effort: 8 hours
   - Risk: Medium (touches multiple files)
   - Dependencies: BP-001 (shared token action)

### Phase 2: Best Practices (Week 2-3)

**Priority**: High, improves maintainability and security

1. **BP-001**: Create shared GitHub App token action
   - Effort: 4 hours
   - Risk: Low
   - Dependencies: None
   - **Note**: Required for SEC-004

2. **BP-002**: Add workflow-level concurrency
   - Effort: 2 hours
   - Risk: Low
   - Dependencies: None

3. **BP-003**: Optimize checkout operations
   - Effort: 4 hours
   - Risk: Low
   - Dependencies: None

4. **BP-004**: Improve error handling
   - Effort: 6 hours
   - Risk: Medium
   - Dependencies: None

5. **BP-005**: Configure matrix fail-fast
   - Effort: 1 hour
   - Risk: Low
   - Dependencies: None

### Phase 3: Maintainability (Week 4+)

**Priority**: Medium, improves long-term maintainability

1. **MNT-001**: Create action version registry
   - Effort: 3 hours
   - Risk: Low
   - Dependencies: None

2. **MNT-002**: Add workflow documentation
   - Effort: 8 hours
   - Risk: Low
   - Dependencies: None

3. **MNT-003**: Standardize error messages
   - Effort: 6 hours
   - Risk: Low
   - Dependencies: None

4. **MNT-004**: Extract magic strings
   - Effort: 4 hours
   - Risk: Low
   - Dependencies: None

### Testing Strategy

For each phase:

1. **Unit Testing**: Test individual actions in isolation
2. **Integration Testing**: Test workflows end-to-end
3. **Regression Testing**: Verify existing functionality still works
4. **Security Testing**: Verify no secrets are exposed in logs

### Rollout Plan

1. **Create Feature Branch**: `improvements/security-fixes`
2. **Implement Phase 1**: Critical security fixes
3. **Test Thoroughly**: Run all workflows multiple times
4. **Code Review**: Get team review
5. **Merge to Main**: Deploy to production
6. **Repeat for Phase 2 & 3**: Follow same process

### Success Metrics

- [ ] All security issues resolved (SEC-001 through SEC-004)
- [ ] No credentials exposed in workflow logs
- [ ] All workflows pass with new permissions
- [ ] Reduced code duplication by 30%+
- [ ] Improved workflow documentation coverage to 80%+
- [ ] All actions use standardized error messages

---

## Appendix: File Change Summary

### New Files to Create

1. `.github/actions/generate-github-app-token/action.yml`
2. `.github/actions/checkout-build-workflow/action.yml`
3. `.github/action-versions.yml`
4. `.github/error-codes.yml`
5. `.github/constants.yml` (optional)
6. `.github/dependabot.yml` (optional)

### Files to Modify

1. `.github/workflows/on-merge.yml`
2. `.github/workflows/on-pr.yml`
3. `.github/workflows/update-digests.yml`
4. `.github/workflows/update-versions.yml`
5. `.github/actions/update-tags-json/action.yml`
6. `.github/actions/auto-merge-pr/action.yml`
7. `.github/actions/delete-branch/action.yml` (if exists)
8. `.github/actions/docker-build-test-push/action.yml`
9. `.github/actions/docker-setup-login/action.yml`
10. All other action files using external actions

### Estimated Total Effort

- **Phase 1 (Security)**: 16 hours
- **Phase 2 (Best Practices)**: 17 hours
- **Phase 3 (Maintainability)**: 21 hours
- **Total**: ~54 hours (approximately 1.5 weeks for one developer)

---

## References

### GitHub Documentation

- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [GitHub Actions Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)
- [GitHub Actions Concurrency](https://docs.github.com/en/actions/using-jobs/using-concurrency)
- [Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Composite Actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)

### Security Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Principle of Least Privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege)
- [Git Credential Storage](https://git-scm.com/docs/git-credential-store)

### Best Practices

- [GitHub Actions Best Practices](https://docs.github.com/en/actions/learn-github-actions/best-practices)
- [DRY Principle](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)
- [Code Documentation](https://www.writethedocs.org/guide/writing/beginners-guide-to-docs/)

---

**Last Updated**: 2025-01-XX  
**Next Review**: After Phase 1 completion  
**Maintained By**: Runlix Team

