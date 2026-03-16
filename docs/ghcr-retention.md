# GHCR Retention Guidance

## Image Types

The workflow produces three tag classes:

1. PR tags, for example `pr-123-v5.2.1-stable-amd64-abc1234`
2. Temporary platform tags, for example `v5.2.1-stable-amd64-abc1234`
3. Permanent manifests, for example `v5.2.1-stable`

For SHA-based repos, the version-like prefix is the short Git SHA, for example `abc1234-stable`.

## Retention Recommendations

- `pr-*`: short retention window
- `*-amd64-*` and `*-arm64-*`: short retention window as a safety net, even though the workflow deletes them
- manifest tags: keep long-term

Avoid writing retention rules around `latest`; this workflow does not treat `latest` as a built-in manifest contract.
