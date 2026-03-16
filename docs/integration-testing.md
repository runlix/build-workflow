# Integration Testing

## Goal

Use this when validating changes to the reusable workflow, examples, or fixture matrices against a real caller repository.

## Recommended Flow

1. Run local repo checks:

```bash
bash commands/validate-schema.sh
bash commands/inspect-workflow-surface.sh
```

2. Push your branch and dispatch the repo workflow:

```bash
gh workflow run test-workflow.yml --ref YOUR-BRANCH -f test_type=both
```

3. If the workflow change affects a real consumer repo, create a temporary caller workflow that points at your branch and run it in PR mode first.

## What To Verify

- schema validation still passes
- example and fixture matrices still validate
- versioned tags are clean: `v5.2.1-stable-amd64-abc1234`
- SHA-based tags are clean: `abc1234-stable-amd64-abc1234`
- legacy suffixes like `-debug` normalize to the same clean tag output
- empty-suffix compatibility still works without doubled or trailing hyphens
- `BASE_TAG` is normalized correctly
- PR comments and release artifacts still appear

## Example Caller Workflow

```yaml
jobs:
  validate:
    uses: YOUR-USERNAME/build-workflow/.github/workflows/build-images-rebuild.yml@YOUR-BRANCH
    with:
      pr_mode: true
    secrets: inherit
```
