# Troubleshooting Guide

This guide helps diagnose and fix common issues with the build-workflow system.

## Table of Contents
- [Build Failures](#build-failures)
- [Push Failures](#push-failures)
- [Test Failures](#test-failures)
- [Schema Validation Errors](#schema-validation-errors)
- [PR Comment Not Posted](#pr-comment-not-posted)
- [Missing Platform Tags](#missing-platform-tags)
- [Image Not Found During Release](#image-not-found-during-release)
- [Rate Limit Errors](#rate-limit-errors)
- [Permission Denied Errors](#permission-denied-errors)

## Build Failures

### Error: "Dockerfile not found"

**Symptom:**
```
ERROR: Dockerfile not found: Dockerfile.amd64
```

**Causes:**
1. Path in `dockerfiles` mapping is incorrect
2. Dockerfile doesn't exist in repository
3. Wrong working directory

**Solution:**
```bash
# Check file exists
ls -la Dockerfile.amd64

# Verify path in docker-matrix.json
jq '.variants[].dockerfiles' .ci/docker-matrix.json

# Paths should be relative to repository root
```

**Fix:**
Update `.ci/docker-matrix.json`:
```json
"dockerfiles": {
  "linux/amd64": "Dockerfile.amd64",  // ✅ Relative to root
  "linux/arm64": "./Dockerfile.arm64"  // ✅ Also works
}
```

### Error: "invalid reference format"

**Symptom:**
```
ERROR: invalid reference format: repository name must be lowercase
```

**Causes:**
1. Service name contains uppercase letters
2. Tag contains invalid characters

**Solution:**
Service names in GHCR must be lowercase. This is handled automatically, but if you see this error, check your docker-matrix.json for invalid characters in `name` or `tag_suffix`:

```json
{
  "variants": [
    {
      "name": "my-service",      // ✅ lowercase, hyphens ok
      "tag_suffix": "-debug",     // ✅ starts with hyphen
      "tag_suffix": "_debug",     // ❌ underscore not recommended
      "tag_suffix": "-Debug",     // ❌ uppercase not allowed
    }
  ]
}
```

### Error: "failed to solve with frontend dockerfile.v0"

**Symptom:**
```
ERROR: failed to solve with frontend dockerfile.v0:
failed to build LLB: executor failed running [/bin/sh -c ...]: exit code 127
```

**Causes:**
1. Missing command in Dockerfile
2. Command not available in base image
3. Syntax error in Dockerfile

**Solution:**
Check Dockerfile syntax and available commands:

```dockerfile
# ❌ Distroless images don't have apt-get
RUN apt-get update

# ✅ Use multi-stage builds if you need build tools
FROM debian:12 AS builder
RUN apt-get update && apt-get install -y curl
# ... build steps ...

FROM gcr.io/distroless/base-debian12
COPY --from=builder /app/binary /app/
```

### Error: "ARG requires exactly one argument"

**Symptom:**
```
ERROR: ARG requires exactly one argument
```

**Causes:**
1. build_args values contain spaces without quotes
2. Special characters not escaped

**Solution:**
In docker-matrix.json, values with spaces need to be in quotes (JSON handles this automatically):

```json
"build_args": {
  "SIMPLE_VALUE": "123",                    // ✅
  "VALUE_WITH_SPACE": "hello world",        // ✅ JSON quotes handle it
  "COMMAND": "echo test"                    // ✅ JSON quotes handle it
}
```

In Dockerfile, use proper quoting:

```dockerfile
ARG APP_NAME
RUN echo "App: ${APP_NAME}"  # ✅ Quoted
```

## Push Failures

### Error: "unauthorized: authentication required"

**Symptom:**
```
ERROR: unauthorized: authentication required
```

**Causes:**
1. `secrets: inherit` missing in calling workflow
2. `packages: write` permission not granted
3. GITHUB_TOKEN expired or invalid

**Solution:**
Check calling workflow has proper setup:

```yaml
jobs:
  build:
    uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@main
    with:
      pr_mode: true
    secrets: inherit  # ✅ Required
    permissions:      # ✅ Alternative: set in workflow-level permissions
      packages: write
```

### Error: "denied: permission_denied: write_package"

**Symptom:**
```
ERROR: denied: permission_denied: write_package
```

**Causes:**
1. Token doesn't have `packages: write` permission
2. Package doesn't exist and token can't create it
3. Package is owned by different account

**Solution:**
1. Ensure permissions are set correctly (see above)
2. For first push, manually create package or use admin token
3. Check package ownership in GitHub organization settings

### Error: "push: max retries exceeded"

**Symptom:**
```
ERROR: push: max retries exceeded (3 attempts)
```

**Causes:**
1. Network issues
2. GHCR service degradation
3. Image too large

**Investigation:**
```bash
# Check image size
docker images | grep IMAGE_TAG

# Check GHCR status
curl -s https://www.githubstatus.com/api/v2/status.json | jq .
```

**Solution:**
- If network issue: Re-run workflow
- If image too large: Optimize Dockerfile, remove unnecessary files
- If GHCR issue: Wait and retry

## Test Failures

### Error: "test script not found"

**Symptom:**
```
ERROR: test-script.sh: No such file or directory
```

**Causes:**
1. Path in `test_script` is incorrect
2. Script not committed to repository
3. Script not executable

**Solution:**
```bash
# Check file exists
ls -la tests/test-script.sh

# Make executable
chmod +x tests/test-script.sh

# Commit changes
git add tests/test-script.sh
git commit -m "Add test script"
```

### Error: "Container exited with non-zero code"

**Symptom:**
```
ERROR: Container test-container exited with code 1
```

**Investigation:**
Check test script output in workflow logs, or run locally:

```bash
# Build image locally
docker build -t test-image .

# Run test script
export IMAGE_TAG=test-image
./tests/test-script.sh
```

**Common causes:**
- Container fails to start (missing dependencies, wrong entrypoint)
- Health check endpoint not responding
- Test assertions failing

### Test timeout

**Symptom:**
```
ERROR: The operation was canceled (timeout after 10 minutes)
```

**Causes:**
1. Container takes too long to start
2. Test script has infinite loop
3. Deadlock in application

**Solution:**
```bash
# Add timeout to individual checks
timeout 30 curl -f http://localhost:8080/health || exit 1

# Reduce wait times in test script
sleep 5  # Instead of sleep 30

# Add explicit timeout to docker commands
docker run --rm --timeout 60 test-image
```

## Schema Validation Errors

### Error: "data should NOT have additional properties"

**Symptom:**
```
ERROR: data should NOT have additional properties
additionalProperty: 'extra_field'
```

**Causes:**
1. Typo in field name
2. Using deprecated field
3. Custom field not in schema

**Solution:**
Check against schema at `schema/docker-matrix-schema.json`:

```bash
# List all valid fields
jq '.properties | keys' schema/docker-matrix-schema.json

# Compare with your config
jq 'keys' .ci/docker-matrix.json
```

**Common typos:**
- `dockerfile` instead of `dockerfiles` (plural)
- `build_arg` instead of `build_args` (plural)
- `platform` instead of `platforms` (plural)

### Error: "data should have required property 'variants'"

**Symptom:**
```
ERROR: data should have required property 'variants'
```

**Causes:**
1. Missing `variants` array
2. Empty variants array
3. JSON syntax error

**Solution:**
```bash
# Validate JSON syntax first
jq empty .ci/docker-matrix.json

# Check variants exist
jq '.variants | length' .ci/docker-matrix.json
# Should be > 0
```

### Error: "data/variants/0/tag_suffix should be string"

**Symptom:**
```
ERROR: data/variants/0/tag_suffix should be string
```

**Causes:**
1. Missing quotes around tag_suffix value
2. Using boolean/number instead of string

**Solution:**
```json
{
  "variants": [
    {
      "tag_suffix": "",      // ✅ String (empty is valid)
      "tag_suffix": "-debug" // ✅ String
      "tag_suffix": null     // ❌ Wrong type
      "tag_suffix": false    // ❌ Wrong type
    }
  ]
}
```

## PR Comment Not Posted

### Symptom
Workflow completes but no comment appears on PR.

**Causes:**
1. `pull-requests: write` permission missing
2. Not running in PR context (`pr_mode: false`)
3. GitHub API error

**Solution:**
```yaml
# Check permissions in calling workflow
permissions:
  pull-requests: write  # ✅ Required

# Check pr_mode
with:
  pr_mode: true  # ✅ Required for PR comments
```

**Debug:**
Check workflow logs for:
```
Updated existing PR comment
```
or
```
Created new PR comment
```

If neither appears, check for API errors in the "Post PR comment" step.

## Missing Platform Tags

### Symptom
Release workflow can't find platform-specific tags like `v1.0.0-amd64`.

**Causes:**
1. Platform tags were deleted too early
2. Build failed but workflow didn't fail
3. Tags never created (build was skipped)

**Investigation:**
```bash
# List all tags for package
gh api "orgs/runlix/packages/container/SERVICE_NAME/versions" \
  --jq '.[] | .metadata.container.tags[]' \
| grep -- "-amd64\|-arm64"
```

**Solution:**
- If tags don't exist: Check build-test-push job logs
- If tags were deleted: This is expected after manifest creation
- If build was skipped: Check variant `enabled` field

## Image Not Found During Release

### Symptom
Release workflow reports "PR image not found, will rebuild from scratch"

**Causes:**
1. Squash merge is enabled (see [branch-protection.md](./branch-protection.md))
2. PR images were deleted by retention policy
3. PR never built images (build was skipped or failed)

**Investigation:**
```bash
# Find PR number from merge commit
git log --oneline -1

# Check if PR images exist
gh api "orgs/runlix/packages/container/SERVICE_NAME/versions" \
  --jq '.[] | select(.metadata.container.tags[] | startswith("pr-")) | .metadata.container.tags[]'

# Expected format: pr-123-v5.2.1-stable-amd64-abc1234
```

**Solution:**
1. **Disable squash merge** (most common fix):
   ```bash
   gh repo edit --enable-merge-commit --disable-squash-merge --disable-rebase-merge
   ```

2. If images were deleted:
   - Check retention policy (see [ghcr-retention.md](./ghcr-retention.md))
   - Rebuild is acceptable (slower but works)

3. If PR build failed:
   - Fix the build issue
   - Re-run PR workflow

## Rate Limit Errors

### Error: "API rate limit exceeded"

**Symptom:**
```
ERROR: API rate limit exceeded for user
```

**Causes:**
1. Too many API calls in workflow
2. Multiple workflows running concurrently
3. Using personal access token instead of GITHUB_TOKEN

**Investigation:**
```bash
# Check current rate limit
gh api /rate_limit
```

**Solution:**
1. Use GITHUB_TOKEN (automatic, higher limits)
2. Add caching to reduce API calls
3. Use GitHub App for even higher limits (see [github-app-setup.md](./github-app-setup.md))

## Permission Denied Errors

### Error: "Resource not accessible by integration"

**Symptom:**
```
ERROR: Resource not accessible by integration
```

**Causes:**
1. Missing permission in workflow file
2. Organization settings restrict workflow permissions
3. Resource is in different repository/organization

**Solution:**
```yaml
# Add required permissions
permissions:
  contents: write       # For updating files
  packages: write       # For pushing images
  pull-requests: write  # For commenting
  actions: read         # For reading artifacts
```

Check organization settings:
1. Go to Organization Settings → Actions → General
2. Ensure "Read and write permissions" is enabled
3. Or add specific permissions in workflow file

## Getting Help

If you're still stuck after trying these solutions:

1. **Check workflow logs:** GitHub Actions → Failed workflow → Expand failed step
2. **Search existing issues:** https://github.com/runlix/build-workflow/issues
3. **Create new issue:** Include:
   - Full error message
   - Workflow run URL
   - Relevant docker-matrix.json
   - Steps already tried

## Next Steps

- [Workflow Customization Options](./customization.md)
- [Branch Protection Requirements](./branch-protection.md)
- [GHCR Retention Policy Setup](./ghcr-retention.md)
