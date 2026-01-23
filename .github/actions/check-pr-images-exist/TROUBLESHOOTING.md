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

### Attempt 4: Pass Directly and Handle Multiline in Action (Failed)
**What:** Pass matrix output directly and handle multiline EOF format in the action
```yaml
matrix: ${{ steps.extract.outputs.matrix }}
```
**In action:** Read the input as-is and parse with jq, which handles multiline JSON correctly
**Why it failed:** When GitHub Actions expands `${{ inputs.matrix }}` in shell commands (like `printf` or `echo`), large JSON strings get truncated due to shell command-line argument size limits.

### Attempt 5: Use Environment Variable (Current Solution)
**What:** Use `toJson(fromJson())` in workflow and write to file using environment variable
```yaml
matrix: ${{ toJson(fromJson(steps.extract.outputs.matrix)) }}
```
**In action:** Write JSON to file using environment variable instead of command-line argument
```bash
env:
  MATRIX_JSON: ${{ toJson(fromJson(inputs.matrix)) }}
run: |
  printf '%s' "${MATRIX_JSON}" | jq -c . > "${MATRIX_TMPFILE}"
```
**Why it works:**
- Environment variables can handle larger content than command-line arguments
- `toJson(fromJson())` normalizes the JSON format
- Writing via `printf` from environment variable avoids command-line truncation
- `jq` validates and compacts the JSON while writing to file

## Current Solution

### Workflow (on-merge.yml)
```yaml
matrix: ${{ toJson(fromJson(steps.extract.outputs.matrix)) }}
```

### Action (check-pr-images-exist/action.yml)
The action writes the matrix input to a file using an environment variable to avoid shell command-line truncation:

**Step 1: Write matrix to file**
```bash
env:
  MATRIX_JSON: ${{ toJson(fromJson(inputs.matrix)) }}
run: |
  MATRIX_TMPFILE=$(mktemp)
  printf '%s' "${MATRIX_JSON}" | jq -c . > "${MATRIX_TMPFILE}"
  echo "MATRIX_TMPFILE=${MATRIX_TMPFILE}" >> "$GITHUB_ENV"
```

**Step 2: Validate matrix**
```bash
# Read from file (already validated and compacted in previous step)
MATRIX_TMPFILE="${MATRIX_TMPFILE}"
if ! jq -e 'type == "array" and length > 0' < "${MATRIX_TMPFILE}" >/dev/null 2>&1; then
  echo "::error::[VALIDATION_005] matrix must be a non-empty JSON array" >&2
  exit 1
fi
```

## Key Insights

1. **Shell command-line arguments have size limits** - Expanding `${{ inputs.matrix }}` in shell commands (like `printf` or `echo`) can truncate large JSON
2. **Environment variables handle larger content** - Using `env:` to set environment variables allows larger content than command-line arguments
3. **Write to file immediately** - Write JSON to a file as soon as possible, using environment variables or direct file writing
4. **Use `toJson(fromJson())` for normalization** - This ensures proper JSON formatting before writing to file
5. **jq validates while writing** - Using `jq -c .` validates JSON and compacts it in one step

## References

- [GitHub Actions: Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub Actions: Passing data between jobs](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idoutputs)
- [GitHub Actions: Multiline strings in outputs](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#multiline-strings)

## Related Actions

- `extract-version-metadata` - Outputs matrix using multiline EOF format
- `create-manifest-lists` - Uses `toJson(fromJson())` pattern (works because it receives already-normalized JSON from workflow)
- `check-pr-images-exist` - Receives multiline EOF format directly (current fix)
