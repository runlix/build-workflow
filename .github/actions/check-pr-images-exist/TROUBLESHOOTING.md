# Troubleshooting: JSON Matrix Parameter Passing

## Problem
When passing large JSON matrix data from workflow to composite action, the JSON gets truncated, causing validation errors.

## Error Messages
```
Error: [VALIDATION_004] check-pr-images-exist: matrix must be valid JSON
```

The JSON appears truncated in logs:
```bash
if [ -z "[
    {
      "arch": "linux-amd64",
      "base": {
  ]" | jq -c . > "${MATRIX_TMPFILE}" 2>/dev/null; then
```

## Root Cause
GitHub Actions has limitations when passing large JSON data:
1. **Action inputs are strings** - Complex objects must be serialized
2. **Truncation risk** - Large JSON strings can be truncated when passed through `toJson(fromJson())`
3. **Multiline EOF format** - The `extract-version-metadata` action outputs matrix using multiline EOF format to avoid truncation, but converting it with `toJson(fromJson())` collapses it back to a single line, risking truncation

## Attempted Fixes

### Attempt 1: Direct Pass (Failed)
**What:** Pass matrix output directly without normalization
```yaml
matrix: ${{ steps.extract.outputs.matrix }}
```
**Why it failed:** GitHub Actions may not properly handle multiline EOF format when passing to action inputs. The multiline format is preserved in outputs but may not work correctly as action input.

### Attempt 2: toJson(fromJson()) Normalization (Failed)
**What:** Normalize JSON using `toJson(fromJson())` pattern
```yaml
matrix: ${{ toJson(fromJson(steps.extract.outputs.matrix)) }}
```
**Why it failed:** This collapses the multiline EOF format back to a single-line string, which can get truncated for large JSON arrays. The `fromJson()` function reads the multiline EOF format correctly, but `toJson()` converts it to a single-line string that exceeds GitHub Actions' input size limits.

### Attempt 3: Using jq -c in extract-version-metadata (Partial Success)
**What:** Extract matrix as compact JSON (`jq -c`) in `extract-version-metadata`
**Status:** Already implemented - matrix is extracted as compact JSON
**Why it helps:** Compact JSON reduces size, but doesn't solve the truncation issue when passed through `toJson(fromJson())`

### Attempt 4: Pass Directly and Handle Multiline in Action (Current Solution)
**What:** Pass matrix output directly and handle multiline EOF format in the action
```yaml
matrix: ${{ steps.extract.outputs.matrix }}
```
**In action:** Read the input as-is and parse with jq, which handles multiline JSON correctly
**Why it works:** 
- Multiline EOF format is preserved when reading from step outputs
- jq can parse multiline JSON correctly
- Avoids the truncation that occurs with `toJson()` conversion

## Current Solution

### Workflow (on-merge.yml)
```yaml
matrix: ${{ steps.extract.outputs.matrix }}
```

### Action (check-pr-images-exist/action.yml)
The action reads the matrix input directly and uses jq to parse it. jq handles both single-line and multiline JSON correctly:

```bash
# Parse and compact JSON using jq -c (compact format, single line)
# jq handles multiline JSON from EOF format correctly
if ! printf '%s\n' "${{ inputs.matrix }}" | jq -c . > "${MATRIX_TMPFILE}" 2>/dev/null; then
  rm -f "${MATRIX_TMPFILE}"
  echo "::error::[VALIDATION_004] ${ACTION_NAME}: matrix must be valid JSON" >&2
  exit 1
fi
```

## Key Insights

1. **Multiline EOF format** is the correct way to output large data from actions to avoid truncation
2. **Don't use `toJson(fromJson())`** when the source is already multiline EOF format - it collapses it and risks truncation
3. **jq handles multiline JSON** - When reading multiline EOF format, jq can parse it correctly without needing normalization
4. **Action inputs preserve multiline format** - When passing multiline EOF format from step outputs to action inputs, the format is preserved

## References

- [GitHub Actions: Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub Actions: Passing data between jobs](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idoutputs)
- [GitHub Actions: Multiline strings in outputs](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#multiline-strings)

## Related Actions

- `extract-version-metadata` - Outputs matrix using multiline EOF format
- `create-manifest-lists` - Uses `toJson(fromJson())` pattern (works because it receives already-normalized JSON from workflow)
- `check-pr-images-exist` - Receives multiline EOF format directly (current fix)
