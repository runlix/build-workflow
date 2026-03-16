# Troubleshooting

## Common Problems

### Schema Validation Fails

Run:

```bash
bash commands/validate-schema.sh
```

Then check for:

- unsupported fields such as `default`
- non-string `tag_suffix` values
- missing Dockerfile mappings for declared platforms

### Tags Look Wrong

Prefer raw suffixes such as `stable` or `debug`.
Legacy values like `-debug` are normalized, but new examples should avoid them.

Expected examples:

- `v5.2.1-stable-amd64-abc1234`
- `v5.2.1-debug`
- `abc1234-stable`

If you intentionally use an empty suffix, the workflow should omit empty segments automatically.

### Base Image Args Are Wrong

Do not set `BASE_IMAGE`, `BASE_TAG`, or `BASE_DIGEST` manually when `base_image` is present.
The workflow injects them.

### Workflow Surface Drift

If docs or examples no longer match the reusable workflow, run:

```bash
bash commands/inspect-workflow-surface.sh
bash commands/check-maintainer-drift.sh
```
