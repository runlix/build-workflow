# Renovate Bot Setup for docker-matrix.json

This repository uses Renovate Bot to automatically update Docker image references in `.ci/docker-matrix.json`.

## 📋 What Gets Updated

### 1. Debian Builder Images
- **Field**: `BUILDER_TAG` + `BUILDER_DIGEST`
- **Image**: `docker.io/library/debian`
- **Current Tag**: `bookworm-slim`
- **Variants**: All 4 (amd64, arm64, default, debug)

**Example Update:**
```diff
"build_args": {
-  "BUILDER_TAG": "bookworm-slim",
-  "BUILDER_DIGEST": "sha256:09c53e50b5110eb...",
+  "BUILDER_TAG": "bookworm-20250201",
+  "BUILDER_DIGEST": "sha256:a1b2c3d4e5f6789...",
```

### 2. Distroless Base Images
- **Field**: `BASE_TAG` + `BASE_DIGEST`
- **Image**: `gcr.io/distroless/base-debian12`
- **Tags**: `latest-amd64`, `latest-arm64`, `debug-amd64`, `debug-arm64`
- **Variants**: Each variant has different tag

**Example Update:**
```diff
"build_args": {
-  "BASE_TAG": "latest-amd64",
-  "BASE_DIGEST": "sha256:eb302860a73aa69...",
+  "BASE_TAG": "latest-amd64",
+  "BASE_DIGEST": "sha256:f4e5d6c7b8a9012...",  (digest updated)
```

---

## 🔧 Configuration Explained

### File: `renovate.json`

Based on official Renovate documentation:
- [Regex Manager Docs](https://docs.renovatebot.com/modules/manager/regex/)
- [Docker Datasource Docs](https://docs.renovatebot.com/modules/datasource/docker/)
- [Configuration Options](https://docs.renovatebot.com/configuration-options/)
- [Base Branches](https://docs.renovatebot.com/configuration-options/#basebranches)

#### Base Branch Configuration

```json
{
  "baseBranches": ["release"]
}
```

**Important:** Since `docker-matrix.json` exists in the `release` branch (not `main`), we configure Renovate to scan the `release` branch. All PRs will target the `release` branch.

#### Custom Managers (Regex-based)

```json
{
  "customManagers": [
    {
      "customType": "regex",
      "fileMatch": ["^\\.ci/docker-matrix\\.json$"],
      "matchStrings": ["..."],
      "depNameTemplate": "docker.io/library/debian",
      "datasourceTemplate": "docker"
    }
  ]
}
```

**How it works:**
1. `fileMatch`: Finds `.ci/docker-matrix.json` file
2. `matchStrings`: Regex extracts `BUILDER_TAG` and `BUILDER_DIGEST`
3. `depNameTemplate`: Specifies Docker image name
4. `datasourceTemplate`: Tells Renovate to query Docker registries

**Named Capture Groups** (required by Renovate):
- `(?<currentValue>...)` - Captures current tag (e.g., "bookworm-slim")
- `(?<currentDigest>...)` - Captures current digest (e.g., "sha256:abc123...")

#### Package Rules

```json
{
  "packageRules": [
    {
      "matchFileNames": ["**/.ci/docker-matrix.json"],
      "groupName": "Docker base images",
      "schedule": ["before 3am on monday"]
    }
  ]
}
```

**Features:**
- **Grouping**: All updates combined into one PR per image type
- **Scheduling**: Updates run weekly (Monday at 3 AM UTC)
- **Auto-merge**: Digest-only updates (security patches) merge automatically
- **Separate PRs**: Major updates get individual PRs for review

---

## 🚀 Setup Instructions

### Step 1: Enable Renovate Bot (5 minutes)

**Option A: GitHub App (Recommended)**

1. Go to https://github.com/apps/renovate
2. Click **"Install"**
3. Select **"Only select repositories"**
4. Choose `runlix/distroless-runtime`
5. Click **"Install"**

**Option B: Self-Hosted**

```bash
docker run --rm \
  -e RENOVATE_TOKEN=$GITHUB_TOKEN \
  -e LOG_LEVEL=info \
  renovate/renovate:latest \
  runlix/distroless-runtime
```

### Step 2: Wait for Initial Scan (10 minutes)

Renovate will:
1. Create issue: **"🔄 Dependency Updates Dashboard"**
2. Scan `.ci/docker-matrix.json`
3. Detect all Docker images
4. Create PRs if updates available

### Step 3: Review First PRs

Check that PRs include:
- ✅ Updated `*_TAG` field
- ✅ Updated `*_DIGEST` field (matching new tag)
- ✅ Changelog and release notes
- ✅ All variants updated (if same tag)

---

## 🧪 Testing Configuration Locally

### Validate Configuration

```bash
# Install Renovate CLI
npm install -g renovate

# Validate renovate.json
renovate-config-validator

# Expected output:
# ✔ Validating renovate.json
# ✔ Config validated successfully
```

### Test Regex Patterns

**Pattern 1: BUILDER_TAG + BUILDER_DIGEST**

```javascript
const pattern = /"BUILDER_TAG"\s*:\s*"(?<currentValue>[^"]+)"[\s\S]*?"BUILDER_DIGEST"\s*:\s*"(?<currentDigest>sha256:[a-f0-9]{64})"/g;

// Test against your file
const content = require('fs').readFileSync('.ci/docker-matrix.json', 'utf8');
const matches = [...content.matchAll(pattern)];

console.log(`Found ${matches.length} BUILDER image references`);
// Expected: 4 matches (one per variant)
```

**Pattern 2: BASE_TAG + BASE_DIGEST**

```javascript
const pattern = /"BASE_TAG"\s*:\s*"(?<currentValue>[^"]+)"[\s\S]*?"BASE_DIGEST"\s*:\s*"(?<currentDigest>sha256:[a-f0-9]{64})"/g;

const content = require('fs').readFileSync('.ci/docker-matrix.json', 'utf8');
const matches = [...content.matchAll(pattern)];

console.log(`Found ${matches.length} BASE image references`);
// Expected: 4 matches (latest-amd64, latest-arm64, debug-amd64, debug-arm64)
```

### Dry Run (See what would happen)

```bash
# Set debug logging
export LOG_LEVEL=debug
export RENOVATE_TOKEN=your_github_token

# Dry run (no changes made)
renovate --dry-run=full --print-config runlix/distroless-runtime

# Check output for:
# - Detected dependencies
# - Proposed updates
# - Would-be PRs
```

---

## 📊 Expected Behavior

### Week 1: Initial Setup

```
✅ Renovate creates issue: "🔄 Dependency Updates Dashboard"
✅ Initial scan detects:
   - debian:bookworm-slim (BUILDER_TAG/DIGEST)
   - gcr.io/distroless/base-debian12:latest-amd64 (BASE_TAG/DIGEST)
   - gcr.io/distroless/base-debian12:latest-arm64
   - gcr.io/distroless/base-debian12:debug-amd64
   - gcr.io/distroless/base-debian12:debug-arm64

✅ Creates PRs if updates available
```

### Weekly Updates (Every Monday 3 AM UTC)

**Example PR: Debian Update**
```
Title: chore(deps): update Debian builder image to bookworm-20250201

Body:
This PR updates docker.io/library/debian from bookworm-slim to bookworm-20250201

Changes:
- BUILDER_TAG: bookworm-slim → bookworm-20250201
- BUILDER_DIGEST: sha256:09c53e... → sha256:a1b2c3...
- Affects all 4 variants (amd64, arm64, default, debug)

Files changed:
- .ci/docker-matrix.json

Changelog: [link to Debian changelog]
```

**Example PR: Distroless Digest Update**
```
Title: chore(deps): update Distroless base image digest

Body:
This PR updates the digest for gcr.io/distroless/base-debian12:latest-amd64

Changes:
- BASE_DIGEST: sha256:eb3028... → sha256:f4e5d6...
- Security patches included

Auto-merge: ✅ (digest-only update)
```

### Auto-Merge Behavior

**Will auto-merge:**
- ✅ Digest-only updates (security patches)
- ✅ After CI passes
- ✅ Uses squash merge strategy

**Requires manual review:**
- ⚠️ Tag changes (e.g., bookworm-slim → bookworm-20250201)
- ⚠️ Major version updates
- ⚠️ CI failures

---

## 🔍 Monitoring

### Dependency Dashboard

Renovate creates a GitHub issue titled **"🔄 Dependency Updates Dashboard"**

**Shows:**
- ✅ Detected dependencies
- ✅ Available updates
- ✅ Rate-limited updates
- ✅ Pending approvals
- ✅ Error logs

**Location:** `https://github.com/runlix/distroless-runtime/issues`

### PR Labels

All Renovate PRs are labeled:
- `dependencies` - Dependency update
- `docker` - Docker image update

### Logs

Detailed logs are included in each PR description:
- Changelog links
- Release notes
- Affected files
- Update reasoning

---

## ⚙️ Customization

### Change Update Schedule

```json
{
  "packageRules": [
    {
      "schedule": ["every weekend"]  // Or "after 10pm every weekday"
    }
  ]
}
```

**Schedule Syntax:** https://docs.renovatebot.com/configuration-options/#schedule

### Disable Auto-Merge

```json
{
  "packageRules": [
    {
      "matchUpdateTypes": ["digest"],
      "automerge": false  // Require manual review for all updates
    }
  ]
}
```

### Pin Specific Image Versions

```json
{
  "packageRules": [
    {
      "matchPackageNames": ["docker.io/library/debian"],
      "allowedVersions": "bookworm-*",  // Only allow bookworm variants
      "enabled": true
    }
  ]
}
```

### Enable Manual Approval

```json
{
  "dependencyDashboardApproval": true  // Require clicking "approve" in dashboard
}
```

---

## 🐛 Troubleshooting

### Issue: Renovate doesn't detect images

**Check:**
1. File path matches: `.ci/docker-matrix.json`
2. JSON is valid: `jq . .ci/docker-matrix.json`
3. Fields exist: `BUILDER_TAG`, `BUILDER_DIGEST`, etc.
4. Regex patterns match: Run test script above

### Issue: Digest updates don't work

**Cause:** Architecture-specific digests are different

**Expected Behavior:**
- `bookworm-slim` amd64: `sha256:09c53e...`
- `bookworm-slim` arm64: `sha256:79abd3...`

Each variant gets correct digest for its architecture.

### Issue: Too many PRs created

**Solution:**
```json
{
  "prConcurrentLimit": 2,  // Max 2 PRs open at once
  "prHourlyLimit": 1       // Max 1 PR created per hour
}
```

### Issue: Want to test image before merging

**Solution:**
```json
{
  "dependencyDashboardApproval": true,
  "packageRules": [
    {
      "matchUpdateTypes": ["major", "minor"],
      "automerge": false
    }
  ]
}
```

---

## 📚 Additional Resources

### Official Documentation
- Main Docs: https://docs.renovatebot.com
- Regex Manager: https://docs.renovatebot.com/modules/manager/regex/
- Docker Datasource: https://docs.renovatebot.com/modules/datasource/docker/
- Docker Guide: https://docs.renovatebot.com/docker/
- Digest Pinning: https://docs.renovatebot.com/docker/#digest-pinning
- Auto-merge: https://docs.renovatebot.com/key-concepts/automerge/

### Testing Tools
- Regex Testing: https://regex101.com (use RE2 flavor)
- Config Validator: `npx renovate-config-validator`
- JSON Schema: https://docs.renovatebot.com/renovate-schema.json

### Community Support
- GitHub Discussions: https://github.com/renovatebot/renovate/discussions
- Discord: https://discord.gg/renovate
- Stack Overflow: `[renovate]` tag

### Example Configurations
- Kubernetes: https://github.com/kubernetes/kubernetes/blob/master/renovate.json
- Helm: https://github.com/helm/helm/blob/main/renovate.json
- Home Assistant: https://github.com/home-assistant/core/blob/dev/renovate.json

---

## 🔐 Security Notes

### Digest Pinning

Renovate follows Docker best practices for digest pinning:
> "By pinning to a digest you make your Docker builds immutable"

Our configuration maintains both:
- **Tag** (human-readable, e.g., `bookworm-slim`)
- **Digest** (immutable, e.g., `sha256:abc123...`)

This ensures:
- Build reproducibility
- Security (tags can be mutated, digests cannot)
- Readability (tags are easier to understand than digests)

### Vulnerability Alerts

Renovate can detect known vulnerabilities and create urgent PRs:

```json
{
  "vulnerabilityAlerts": {
    "enabled": true,
    "labels": ["security"]
  }
}
```

**Documentation:** https://docs.renovatebot.com/configuration-options/#vulnerabilityalerts

---

## ✅ Quick Checklist

Setup complete when:
- [ ] `renovate.json` exists in repository root
- [ ] Renovate Bot installed on repository
- [ ] Dependency Dashboard issue created
- [ ] First PR created and reviewed
- [ ] CI passes on first PR
- [ ] Auto-merge tested (if enabled)
- [ ] Team understands PR format

---

**Last Updated:** 2025-02-01
**Renovate Version:** Latest (auto-updated)
**Configuration Version:** 1.0
