# Renovate Configuration Guide

## Overview

This guide documents the Renovate configuration used across runlix projects (radarr, distroless-runtime) for automated dependency updates.

Renovate automatically:
- Monitors Docker base images for digest updates (security patches)
- Monitors Debian builder images for new versions
- Monitors application versions from GitHub releases
- Creates pull requests with grouped updates
- Auto-merges security patches after CI passes

## Configuration Files

Each project has a `renovate.json` at the repository root:
- `/Users/ohayoun/personal/runlix/radarr/renovate.json`
- `/Users/ohayoun/personal/runlix/distroless-runtime/renovate.json`

Configuration is managed through Mend's hosted Renovate service (free for open source).

---

## Production Configuration Settings

### Schedule: `"before 3am"`

```json
{
  "packageRules": [
    {
      "schedule": ["before 3am"]
    }
  ]
}
```

**What it does:**
- PRs are only created during the 00:00-03:00 UTC window
- Mend's service runs Renovate every hour, but PRs are only created if within schedule
- Batches all updates into one daily time window

**Why we use this:**
- Reduces noise during work hours
- Groups updates into daily batches
- PRs are ready for review in the morning
- Prevents unexpected PRs appearing throughout the day

**Alternative schedules:**
- `"at any time"` - PRs created any hour (use for testing)
- `["before 3am", "after 9pm"]` - Two windows per day
- `["every weekend"]` - Weekly batches

---

### PR Hourly Limit: `"prHourlyLimit": 1`

```json
{
  "prHourlyLimit": 1
}
```

**What it does:**
- Limits how many PRs Renovate can create per hour
- If multiple updates are ready, only 1 PR is created per hour
- Other updates wait for the next hour

**Why we use this:**
- Prevents flooding the repository with many PRs at once
- Spreads out updates to reduce notification fatigue
- Keeps PR creation controlled and manageable

**When to adjust:**
- Testing: Increase to `10` to see all pending PRs immediately
- High-activity repos: May want `2-3` if you can review quickly
- Production: Keep at `1` for controlled rollout

---

### PR Concurrent Limit: `"prConcurrentLimit": 3`

```json
{
  "prConcurrentLimit": 3
}
```

**What it does:**
- Maximum number of open PRs at any time
- Once a PR is merged/closed, Renovate creates the next one
- Keeps PR list manageable

**Why we use this:**
- Prevents PR list from becoming overwhelming
- Forces prioritization of reviewing and merging PRs
- Queues additional updates until capacity is available

---

### Dependency Dashboard Approval: `"dependencyDashboardApproval": false`

```json
{
  "dependencyDashboardApproval": false
}
```

**What it does:**
- Allows Renovate to create PRs automatically without manual approval
- When `true`, all updates show as "Pending Approval" in the Dependency Dashboard
- When `false`, PRs are created automatically (subject to schedule and rate limits)

**Why we use this:**
- Enables fully automated workflow
- Eliminates manual approval step
- Security digest updates can be applied automatically

**When it was added:**
- This setting was missing initially, causing "Pending Approval" status
- Added after troubleshooting why PRs weren't being created automatically

---

## Automerge Configuration

### Digest-Only Auto-merge

```json
{
  "packageRules": [
    {
      "matchFileNames": ["**/.ci/docker-matrix.json"],
      "matchUpdateTypes": ["digest"],
      "automerge": true,
      "automergeType": "pr",
      "automergeStrategy": "squash"
    }
  ]
}
```

**What gets auto-merged:**
- Digest-only updates (e.g., `sha256:abc123` → `sha256:def456`)
- Security patches to base images
- No version changes (tags remain the same)

**What does NOT get auto-merged:**
- Version updates (e.g., Debian `12.7` → `12.8`)
- Application version updates (e.g., Radarr `5.0.0` → `5.1.0`)
- Any non-digest changes require manual review

**Requirements for automerge to work:**
- CI checks must pass
- Branch protection rules must be satisfied
- PR must be in "mergeable" state

---

## The Two-Run Automerge Pattern (Critical Understanding)

### Why Automerge Takes Two Renovate Runs

Renovate's GitHub-native automerge (`platformAutomerge: true`, the default) requires **two runs** to successfully merge PRs. This is a timing race condition with GitHub's API.

#### Run 1 - Create PR and Attempt Automerge (Fails)

1. Renovate creates the pull request
2. Renovate immediately tries to enable GitHub's automerge feature
3. ❌ **GitHub rejects with error:** `"Pull request is in clean status"`
4. **Why it fails:** GitHub Actions workflows haven't started yet, so there are no status checks running
5. **GitHub requirement:** Automerge can only be enabled when required checks are pending/running (not in "clean" status)

#### Run 2 - Retry Automerge (1 hour later, succeeds)

1. Renovate runs again (hourly schedule)
2. GitHub Actions checks are now running on the PR
3. ✅ **GitHub accepts automerge:** Required status checks are present
4. Automerge is enabled and PR will merge automatically once checks pass

### Why This Matters for Configuration

**Hourly Renovate runs are REQUIRED** for automerge to work:
- Mend's hosted Renovate service runs automatically every hour
- The first run creates the PR but automerge fails (timing race)
- The second run (1 hour later) successfully enables automerge
- **Without hourly runs**, automerge would never be enabled

### Impact on Daily Schedule

When using `"schedule": ["before 3am"]` in production:
1. **Day 1 - 02:00 UTC:** Renovate runs during 00:00-03:00 UTC window
2. Creates PR and tries automerge → fails with "clean status"
3. **Day 2 - 02:00 UTC:** Next run is 24 hours later (next day's before 3am window)
4. Retries automerge → succeeds (checks are running)
5. PR auto-merges once CI passes

**Trade-off:**
- Daily schedule = 24-hour delay for automerge to be enabled
- More frequent schedule = faster automerge, but more noise
- **Hourly runs during the 3-hour window** would allow multiple retry attempts within the same day

**This is acceptable because:**
- Security digest updates are grouped and batched
- 24-hour delay for automerge is acceptable for non-critical security patches
- PRs are still created immediately in the scheduled window
- Manual review and merge is always available if urgent

---

## Why `platformAutomerge: false` Doesn't Work

### The Tempting But Wrong Solution

When encountering the "clean status" error, it's tempting to disable platform automerge:

```json
{
  "platformAutomerge": false  // ❌ Don't do this!
}
```

**Why this seems appealing:**
- Avoids the GitHub "clean status" timing issue
- Renovate would handle merge timing internally

**Why this DOESN'T work on protected branches:**

According to Renovate official documentation:
> "If you have configured your project to require Pull Requests before merging, it means that branch automerging is not possible, even if Renovate has rights to commit to the base branch."

- ❌ **Our `release` branch requires pull requests** (branch protection)
- ❌ **Renovate cannot bypass branch protection** to merge directly
- ❌ **Would completely break automerge functionality**

**The correct solution:**
- Keep `platformAutomerge: true` (default)
- Accept the two-run pattern with 1-hour delay (or 24-hour for daily schedules)
- Ensure Renovate runs frequently enough to retry automerge

---

## Custom Managers Configuration

### Regex-based Dependency Detection

Renovate uses custom regex managers to detect dependencies in `docker-matrix.json`:

#### Debian Builder Images

```json
{
  "customType": "regex",
  "fileMatch": ["^\\.ci/docker-matrix\\.json$"],
  "matchStrings": [
    "\"BUILDER_TAG\"\\s*:\\s*\"(?<currentValue>[^\"]+)\"[\\s\\S]*?\"BUILDER_DIGEST\"\\s*:\\s*\"(?<currentDigest>sha256:[a-f0-9]{64})\""
  ],
  "depNameTemplate": "docker.io/library/debian",
  "datasourceTemplate": "docker"
}
```

**What it detects:**
- `BUILDER_TAG`: Debian version (e.g., `12.7-slim`)
- `BUILDER_DIGEST`: SHA256 digest
- Updates both tag and digest together

#### Distroless Runtime Base Images

```json
{
  "matchStrings": [
    "\"BASE_TAG\"\\s*:\\s*\"(?<currentValue>[^\"]+)\"[\\s\\S]*?\"BASE_DIGEST\"\\s*:\\s*\"(?<currentDigest>sha256:[a-f0-9]{64})\""
  ],
  "depNameTemplate": "ghcr.io/runlix/distroless-runtime",
  "datasourceTemplate": "docker"
}
```

**What it detects:**
- `BASE_TAG`: Distroless runtime tag (e.g., `cc0-debian12`)
- `BASE_DIGEST`: SHA256 digest
- Monitors runlix's custom distroless images

#### Application Versions (radarr only)

```json
{
  "matchStrings": [
    "\"version\"\\s*:\\s*\"(?<currentValue>[^\"]+)\""
  ],
  "depNameTemplate": "Radarr/Radarr",
  "datasourceTemplate": "github-releases"
}
```

**What it detects:**
- Application version from GitHub releases
- Updates download URLs to match new versions

---

## Package Rules and Grouping

### Grouping Strategy

Updates are grouped by type to reduce PR count:

```json
{
  "packageRules": [
    {
      "matchDatasources": ["docker"],
      "matchPackageNames": ["docker.io/library/debian"],
      "groupName": "Debian builder"
    },
    {
      "matchDatasources": ["docker"],
      "matchPackageNames": ["ghcr.io/runlix/distroless-runtime"],
      "groupName": "Distroless runtime"
    },
    {
      "matchDatasources": ["github-releases"],
      "matchPackageNames": ["Radarr/Radarr"],
      "groupName": "Radarr release"
    }
  ]
}
```

**Benefits:**
- Single PR for all Debian builder updates across variants
- Single PR for all distroless runtime updates across variants
- Single PR for Radarr version + package URL updates
- Reduces PR count from 4+ to 1 per update type

---

## Testing vs Production Settings

### For Testing (Fast Feedback)

```json
{
  "packageRules": [
    {
      "schedule": ["at any time"]  // PRs created immediately
    }
  ],
  "prHourlyLimit": 10,  // Allow many PRs quickly
  "prConcurrentLimit": 5  // More open PRs allowed
}
```

**Use when:**
- Verifying Renovate configuration works
- Testing PR creation and automerge
- Debugging issues
- Want to see results immediately

**Change back after:**
- At least one successful PR created automatically
- Automerge verified working (may take 1-2 hours)
- CI passes on auto-merged PR

### For Production (Controlled Updates)

```json
{
  "packageRules": [
    {
      "schedule": ["before 3am"]  // Daily batch window
    }
  ],
  "prHourlyLimit": 1,  // Controlled rollout
  "prConcurrentLimit": 3  // Manageable PR count
}
```

**Use when:**
- Configuration is verified working
- Want to minimize notification noise
- Prefer daily batch reviews
- Production stability is priority

---

## Manual Triggering

### Method 1: Dependency Dashboard

1. Go to your repository
2. Find the "🔄 Dependency Updates Dashboard" issue
3. Check the box: "Check this box to trigger a request for Renovate to run again"
4. Renovate will run within a few minutes

**Note:** Manual triggers still respect `prHourlyLimit` and `schedule` settings!

### Method 2: Mend Developer Portal

**radarr:**
- https://developer.mend.io/github/runlix/radarr
- Click "Run Renovate Now"

**distroless-runtime:**
- https://developer.mend.io/github/runlix/distroless-runtime
- Click "Run Renovate Now"

**Note:** Requires Mend account access.

---

## Troubleshooting

### PRs Not Being Created

**Symptom:** Updates detected but marked "Pending Approval" in Dashboard

**Cause:** `dependencyDashboardApproval` not set to `false`

**Solution:**
```json
{
  "dependencyDashboardApproval": false
}
```

---

### PRs Only Created When Manually Triggered

**Symptom:** Updates detected but PRs not created automatically during scheduled time

**Cause:** Schedule restriction blocking PR creation

**Diagnosis:** Check Renovate logs for:
```
"msg":"Checking schedule(schedule=before 3am, tz=UTC, now=2026-02-02T07:40:59.858Z)"
"msg":"Package not scheduled"
"msg":"Skipping branch creation as not within schedule"
```

**Solution:** Ensure Renovate runs during schedule window, or change schedule to `"at any time"` for testing

---

### Automerge Not Enabling

**Symptom:** PR created but no "Auto-merge enabled" badge

**Cause:** First-run timing race condition

**Solution:** Wait for next Renovate run (1 hour later):
1. First run creates PR, automerge fails ("clean status")
2. Second run retries automerge, succeeds (checks running)
3. Auto-merge enabled badge appears
4. PR merges automatically once CI passes

---

### Automerge Fails with "User is not authorized for this protected branch"

**Symptom:** Error in Renovate logs about branch protection

**Cause:** Renovate bot not in branch protection bypass list

**Solution:**
1. Go to repository Settings → Branches
2. Edit branch protection rules for `release` branch
3. Add Renovate bot to bypass list or allowed merge actors

---

### Only 1 PR Created Per Hour

**Symptom:** Multiple updates ready but only 1 PR created

**Cause:** `prHourlyLimit: 1` setting

**Solution (for testing):**
```json
{
  "prHourlyLimit": 10  // Temporary increase
}
```

**Solution (for production):**
- This is intentional behavior to reduce noise
- PRs will be created in subsequent hourly runs
- Keep at `1` for production

---

### PR Created But CI Not Running

**Symptom:** PR exists but no GitHub Actions checks triggered

**Cause:** GitHub Actions workflow not configured to trigger on PRs from bots, or branch filter mismatch

**Solution:** Verify `.github/workflows/build-images-rebuild.yml`:
```yaml
on:
  pull_request:
    branches: [release]
    # No types filter needed - will trigger for all PR events
```

---

## Monitoring and Maintenance

### What to Monitor

1. **Dependency Dashboard:** Check weekly for pending updates
2. **Auto-merged PRs:** Verify they passed CI before merging
3. **Failed automerges:** Investigate if PRs stay open beyond 24 hours
4. **Renovate logs:** Available in Mend Developer Portal if issues occur

### Regular Maintenance

- **Monthly:** Review auto-merged PRs to ensure quality
- **Quarterly:** Check if `prHourlyLimit` or `prConcurrentLimit` need adjustment
- **As needed:** Update custom regex matchers if `docker-matrix.json` format changes

### Renovate Updates

Renovate itself is automatically updated by Mend:
- No configuration needed
- Breaking changes announced in Renovate release notes
- Check https://github.com/renovatebot/renovate/releases for changelog

---

## References

- Renovate Documentation: https://docs.renovatebot.com/
- Automerge Docs: https://docs.renovatebot.com/key-concepts/automerge/
- Configuration Options: https://docs.renovatebot.com/configuration-options/
- Custom Managers: https://docs.renovatebot.com/modules/manager/regex/
- GitHub Automerge: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/automatically-merging-a-pull-request

---

## Configuration Template

Use this template for new runlix projects:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "description": "Renovate configuration for docker-matrix.json updates",
  "extends": ["config:recommended"],
  "baseBranches": ["release"],
  "customManagers": [
    {
      "customType": "regex",
      "description": "Update Debian builder images",
      "fileMatch": ["^\\.ci/docker-matrix\\.json$"],
      "matchStrings": [
        "\"BUILDER_TAG\"\\s*:\\s*\"(?<currentValue>[^\"]+)\"[\\s\\S]*?\"BUILDER_DIGEST\"\\s*:\\s*\"(?<currentDigest>sha256:[a-f0-9]{64})\""
      ],
      "depNameTemplate": "docker.io/library/debian",
      "datasourceTemplate": "docker"
    },
    {
      "customType": "regex",
      "description": "Update distroless runtime base images",
      "fileMatch": ["^\\.ci/docker-matrix\\.json$"],
      "matchStrings": [
        "\"BASE_TAG\"\\s*:\\s*\"(?<currentValue>[^\"]+)\"[\\s\\S]*?\"BASE_DIGEST\"\\s*:\\s*\"(?<currentDigest>sha256:[a-f0-9]{64})\""
      ],
      "depNameTemplate": "ghcr.io/runlix/distroless-runtime",
      "datasourceTemplate": "docker"
    }
  ],
  "packageRules": [
    {
      "description": "Group all docker-matrix.json updates into daily PRs",
      "matchFileNames": ["**/.ci/docker-matrix.json"],
      "groupName": "Docker base images",
      "schedule": ["before 3am"]
    },
    {
      "description": "Auto-merge digest-only updates (security patches)",
      "matchFileNames": ["**/.ci/docker-matrix.json"],
      "matchUpdateTypes": ["digest"],
      "automerge": true,
      "automergeType": "pr",
      "automergeStrategy": "squash"
    }
  ],
  "dependencyDashboard": true,
  "dependencyDashboardTitle": "🔄 Dependency Updates Dashboard",
  "dependencyDashboardApproval": false,
  "labels": ["dependencies", "docker"],
  "timezone": "UTC",
  "prConcurrentLimit": 3,
  "prHourlyLimit": 1
}
```
