# GHCR Retention Policy Setup

This document describes how to configure GitHub Container Registry (GHCR) retention policies for images built by the workflow system.

## Table of Contents
- [Why Retention Policies Matter](#why-retention-policies-matter)
- [Image Types and Retention](#image-types-and-retention)
- [Recommended Policies](#recommended-policies)
- [Setup Instructions](#setup-instructions)
- [Automation](#automation)

## Why Retention Policies Matter

The build-workflow system creates three types of images:

1. **PR images** - Tagged `pr-{number}-{sha}{tag_suffix}-{arch}` (temporary)
2. **Platform tags** - Tagged `{version}{tag_suffix}-{arch}` (temporary, deleted by workflow)
3. **Multi-arch manifests** - Tagged `{version}{tag_suffix}` (permanent)

Without retention policies:
- PR images accumulate indefinitely (one per PR commit)
- Storage costs increase unnecessarily
- Package list becomes cluttered and hard to navigate
- Old PR images serve no purpose after PR is closed

## Image Types and Retention

### PR Images (Temporary)

**Format:** `pr-{number}-{sha}{tag_suffix}-{arch}`

**Examples:**
- `pr-123-abc1234-amd64`
- `pr-123-abc1234-debug-amd64`
- `pr-456-xyz7890-arm64`

**Purpose:**
- Validate builds before merge
- Available for testing during PR review
- Promoted to release if PR is merged

**Recommended retention:** 14 days (configurable)

**Rationale:**
- PRs are typically merged within a few days
- After merge, the image is promoted to release (or rebuilt)
- Closed PRs no longer need their images after 2 weeks
- Balance between storage costs and debugging ability

### Platform Tags (Temporary)

**Format:** `{version}{tag_suffix}-{arch}` or `{sha}{tag_suffix}-{arch}`

**Examples:**
- `v5.2.1-amd64`
- `v5.2.1-debug-arm64`
- `abc1234-amd64`

**Purpose:**
- Intermediate tags during multi-arch manifest creation
- Automatically deleted by workflow after manifest succeeds

**Retention:** N/A (deleted by workflow, typically within minutes)

**Note:** These should never accumulate. If they do, check workflow logs for deletion failures.

### Multi-Arch Manifests (Permanent)

**Format:** `{version}{tag_suffix}` or `{sha}{tag_suffix}`, plus `latest`

**Examples:**
- `v5.2.1` (default variant)
- `v5.2.1-debug` (debug variant)
- `latest` (default variant only)
- `abc1234` (base images)

**Purpose:**
- Production-ready images for deployment
- Referenced in deployment manifests
- Immutable releases

**Retention:** Keep forever (or very long, e.g., 365 days)

**Rationale:**
- These are the images users actually deploy
- Deleting them breaks deployments
- Storage cost is minimal (only manifest metadata)

## Recommended Policies

### For Service Repositories

| Image Pattern | Keep Count | Keep Days | Rationale |
|---------------|-----------|-----------|-----------|
| `pr-*` | 50 | 14 | Recent PRs + some history |
| `v*-amd64`, `v*-arm64` | 0 | 1 | Platform tags (should be deleted by workflow) |
| `v*` (semantic versions) | All | 365 | Production releases |
| `latest*` | All | Forever | Current production |

### For Base Image Repositories

| Image Pattern | Keep Count | Keep Days | Rationale |
|---------------|-----------|-----------|-----------|
| `pr-*` | 50 | 14 | Recent PRs + some history |
| `*-amd64`, `*-arm64` | 0 | 1 | Platform tags (should be deleted by workflow) |
| SHA tags (e.g., `abc1234`) | 100 | 90 | Recent releases |

## Setup Instructions

### Using GitHub Web UI

Unfortunately, GitHub does not provide a web UI for GHCR retention policies. You must use the GraphQL API or GitHub CLI.

### Using GitHub CLI with GraphQL

#### 1. Get Package ID

First, find the package ID:

```bash
# For services
gh api graphql -f query='
  query {
    organization(login: "runlix") {
      packages(first: 100, names: ["radarr"]) {
        nodes {
          id
          name
        }
      }
    }
  }
'
```

Save the `id` from the response (looks like `MDc6UGFja2FnZTEyMzQ1Njc4OQ==`).

#### 2. Create Retention Policy

```bash
# Set package ID from previous step
PACKAGE_ID="MDc6UGFja2FnZTEyMzQ1Njc4OQ=="

# Create policy for PR images
gh api graphql -f query='
  mutation {
    updatePackageSettings(input: {
      packageId: "'"$PACKAGE_ID"'"
      retentionPolicy: {
        pattern: "pr-*"
        keepNLastVersions: 50
        keepDaysCount: 14
        enabled: true
      }
    }) {
      package {
        id
        name
      }
    }
  }
'

# Create policy for platform tags (safety net)
gh api graphql -f query='
  mutation {
    updatePackageSettings(input: {
      packageId: "'"$PACKAGE_ID"'"
      retentionPolicy: {
        pattern: "*-amd64,*-arm64"
        keepNLastVersions: 0
        keepDaysCount: 1
        enabled: true
      }
    }) {
      package {
        id
        name
      }
    }
  }
'

# Create policy for release versions (keep forever)
gh api graphql -f query='
  mutation {
    updatePackageSettings(input: {
      packageId: "'"$PACKAGE_ID"'"
      retentionPolicy: {
        pattern: "v*"
        keepNLastVersions: 0
        keepDaysCount: 365
        enabled: true
      }
    }) {
      package {
        id
        name
      }
    }
  }
'
```

### Using Script

Save this script as `setup-retention.sh`:

```bash
#!/bin/bash
set -e

ORG="runlix"
PACKAGE_NAME="$1"

if [ -z "$PACKAGE_NAME" ]; then
  echo "Usage: $0 <package-name>"
  echo "Example: $0 radarr"
  exit 1
fi

echo "Setting up retention policies for $ORG/$PACKAGE_NAME..."

# Get package ID
PACKAGE_ID=$(gh api graphql -f query='
  query {
    organization(login: "'"$ORG"'") {
      packages(first: 100, names: ["'"$PACKAGE_NAME"'"]) {
        nodes {
          id
          name
        }
      }
    }
  }
' --jq '.data.organization.packages.nodes[0].id')

if [ -z "$PACKAGE_ID" ]; then
  echo "❌ Package not found: $PACKAGE_NAME"
  exit 1
fi

echo "Found package ID: $PACKAGE_ID"

# Policy 1: PR images (50 images, 14 days)
echo "Creating policy for PR images..."
gh api graphql -f query='
  mutation {
    updatePackageSettings(input: {
      packageId: "'"$PACKAGE_ID"'"
      retentionPolicy: {
        pattern: "pr-*"
        keepNLastVersions: 50
        keepDaysCount: 14
        enabled: true
      }
    }) {
      package { id }
    }
  }
' > /dev/null

echo "✅ PR images: keep 50, max 14 days"

# Policy 2: Platform tags (safety net, 1 day)
echo "Creating policy for platform tags..."
gh api graphql -f query='
  mutation {
    updatePackageSettings(input: {
      packageId: "'"$PACKAGE_ID"'"
      retentionPolicy: {
        pattern: "*-amd64,*-arm64"
        keepNLastVersions: 0
        keepDaysCount: 1
        enabled: true
      }
    }) {
      package { id }
    }
  }
' > /dev/null

echo "✅ Platform tags: max 1 day (should be deleted by workflow)"

# Policy 3: Release versions (keep 365 days)
echo "Creating policy for release versions..."
gh api graphql -f query='
  mutation {
    updatePackageSettings(input: {
      packageId: "'"$PACKAGE_ID"'"
      retentionPolicy: {
        pattern: "v*"
        keepNLastVersions: 0
        keepDaysCount: 365
        enabled: true
      }
    }) {
      package { id }
    }
  }
' > /dev/null

echo "✅ Release versions: keep 365 days"

echo ""
echo "🎉 Retention policies configured for $PACKAGE_NAME"
```

Run it:

```bash
chmod +x setup-retention.sh
./setup-retention.sh radarr
./setup-retention.sh sonarr
./setup-retention.sh distroless
```

## Automation

### Option 1: GitHub Actions Workflow

Create `.github/workflows/setup-retention.yml`:

```yaml
name: Setup Retention Policies

on:
  workflow_dispatch:
    inputs:
      package_name:
        description: 'Package name'
        required: true

jobs:
  setup:
    runs-on: ubuntu-latest
    steps:
      - name: Setup retention policies
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          ORG="runlix"
          PACKAGE_NAME="${{ inputs.package_name }}"

          # Get package ID
          PACKAGE_ID=$(gh api graphql -f query='
            query {
              organization(login: "'"$ORG"'") {
                packages(first: 100, names: ["'"$PACKAGE_NAME"'"]) {
                  nodes { id name }
                }
              }
            }
          ' --jq '.data.organization.packages.nodes[0].id')

          # Create policies (same as script above)
          # ... (copy mutation queries from script)
```

### Option 2: Terraform

If you use Terraform for GitHub management:

```hcl
# Note: As of 2024, GitHub provider doesn't support GHCR retention policies
# You'll need to use local-exec provisioner or custom provider

resource "null_resource" "ghcr_retention" {
  triggers = {
    package_name = "radarr"
  }

  provisioner "local-exec" {
    command = "./setup-retention.sh ${self.triggers.package_name}"
  }
}
```

## Verification

### Check Current Policies

```bash
# Get package ID
PACKAGE_ID=$(gh api graphql -f query='
  query {
    organization(login: "runlix") {
      packages(first: 100, names: ["radarr"]) {
        nodes { id name }
      }
    }
  }
' --jq '.data.organization.packages.nodes[0].id')

# Query retention policies
gh api graphql -f query='
  query {
    node(id: "'"$PACKAGE_ID"'") {
      ... on Package {
        name
        retentionPolicies {
          pattern
          keepNLastVersions
          keepDaysCount
          enabled
        }
      }
    }
  }
'
```

### Check Image Age

List PR images and their age:

```bash
# List all PR images with creation dates
gh api "orgs/runlix/packages/container/radarr/versions" \
  --paginate \
  --jq '.[] | select(.metadata.container.tags[] | startswith("pr-")) | {
    tags: .metadata.container.tags,
    created: .created_at
  }'
```

### Manual Cleanup

If you need to clean up old images before policies take effect:

```bash
# Delete all PR images older than 30 days
gh api "orgs/runlix/packages/container/radarr/versions" \
  --paginate \
  --jq '.[] | select(.metadata.container.tags[] | startswith("pr-")) | select(.created_at < (now - 30*86400 | todate)) | .id' \
| while read version_id; do
    echo "Deleting version $version_id"
    gh api -X DELETE "orgs/runlix/packages/container/radarr/versions/$version_id"
  done
```

**⚠️ Warning:** Be careful with manual deletion. Always verify the images you're deleting first.

## Troubleshooting

### Policy not deleting images

**Problem:** Images older than retention period still exist.

**Causes:**
1. Policy not enabled
2. Pattern doesn't match image tags
3. GitHub's cleanup runs once per day (not immediate)

**Solution:**
1. Verify policy is `enabled: true`
2. Test pattern matching (e.g., `pr-*` matches `pr-123-abc-amd64`)
3. Wait 24 hours for automatic cleanup
4. Use manual cleanup script if urgent

### Platform tags accumulating

**Problem:** Images tagged `v5.2.1-amd64` are not being deleted.

**Causes:**
1. Release workflow failed before deleting platform tags
2. Workflow doesn't have `packages: write` permission

**Solution:**
1. Check release workflow logs for deletion errors
2. Verify `packages: write` permission in workflow file
3. Manually delete old platform tags (they're not needed)

### Unable to pull old PR image

**Problem:** Trying to test old PR but image was deleted by retention policy.

**Solution:**
- If PR is still open: Re-run the PR validation workflow to rebuild
- If PR is closed: Checkout the PR branch and run validation locally
- Adjust retention policy to keep images longer

### Storage costs still high

**Problem:** Retention policies configured but storage costs remain high.

**Investigation:**
```bash
# List all images and their sizes
gh api "orgs/runlix/packages/container/radarr/versions" \
  --paginate \
  --jq '.[] | {
    tags: .metadata.container.tags,
    size_mb: (.size / 1024 / 1024 | round),
    created: .created_at
  }' \
| jq -s 'sort_by(-.size_mb) | .[:20]'
```

Check for:
- Untagged images (dangling layers) - these should be cleaned up automatically
- Very old release images - consider shorter retention for old versions
- Platform tags that weren't deleted - investigate workflow failures

## Cost Estimation

GHCR storage costs (as of 2024):
- Free tier: 500 MB
- Paid: $0.008 per GB per day (~$0.24 per GB per month)

**Example calculation:**

Assumptions:
- Service repository with 2 variants, 2 platforms
- 20 PRs per month, 3 commits per PR average
- Each image: 500 MB

Without retention policy:
- PR images: 20 PRs × 3 commits × 2 variants × 2 platforms × 500 MB = 120 GB
- Monthly cost: 120 GB × $0.24 = $28.80

With 14-day retention (50 images max):
- PR images: 50 images × 500 MB = 25 GB
- Monthly cost: 25 GB × $0.24 = $6.00
- **Savings: $22.80 per month (79%)**

For 10 service repositories: **$228/month savings**

## Next Steps

- [GitHub App Setup for API Access](./github-app-setup.md)
- [Troubleshooting Guide](./troubleshooting.md)
- [Workflow Customization Options](./customization.md)
