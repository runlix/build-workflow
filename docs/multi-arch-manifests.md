# Multi-Arch Manifests

## How It Works

Release mode creates temporary platform tags first, then merges them into permanent multi-arch manifests.

Examples:

- versioned platform tag: `v5.2.1-stable-amd64-abc1234`
- versioned manifest tag: `v5.2.1-stable`
- SHA-based platform tag: `abc1234-stable-amd64-abc1234`
- SHA-based manifest tag: `abc1234-stable`

## Grouping Rule

The workflow groups platform tags by normalized manifest tag, not by variant name.
Recommended `tag_suffix` values are explicit strings such as `stable` and `debug`.

Empty suffixes remain supported, and the manifest tag becomes just the base ref:

- versioned repo: `v5.2.1`
- SHA-based repo: `abc1234`

## Verification

```bash
docker manifest inspect ghcr.io/runlix/distroless-runtime:abc1234-stable
docker buildx imagetools inspect ghcr.io/runlix/distroless-runtime:abc1234-stable
```
