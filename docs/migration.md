# Migration Guide

## Move to the Current Contract

Update existing caller repositories to this model:

- use `.ci/docker-matrix.json`
- use raw `tag_suffix` values such as `stable` and `debug`
- stop documenting or relying on a per-variant `default` field
- use `ghcr.io/runlix/distroless-runtime` as the canonical runtime example when a wrapped base image is needed

## Steps

1. Replace old matrix examples with the files from `examples/`.
2. Update suffixes from `-debug` style values to raw strings.
3. Remove any `default` fields from docs or config.
4. Re-run schema validation.
5. Dispatch `test-workflow.yml` from your branch.

## Validation

```bash
bash commands/validate-schema.sh
gh workflow run test-workflow.yml --ref YOUR-BRANCH -f test_type=both
```
