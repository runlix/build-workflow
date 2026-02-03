## Description

<!-- Provide a clear and concise description of what this PR does -->

## Type of Change

<!-- Mark the relevant option with an 'x' -->

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring
- [ ] Dependency update
- [ ] Other (please describe):

## Related Issues

<!-- Link to related issues using keywords: Fixes #123, Relates to #456, Closes #789 -->

- Fixes #
- Relates to #

## Motivation and Context

<!-- Why is this change needed? What problem does it solve? -->

## Changes Made

<!-- List the key changes in this PR -->

-
-
-

## Testing

<!-- Describe the testing you've done -->

### Manual Testing

- [ ] Tested with base image configuration
- [ ] Tested with service configuration
- [ ] Tested in PR mode
- [ ] Tested in release mode
- [ ] Tested with dry-run mode

### Test Cases

<!-- Describe specific test scenarios -->

1. Test case 1:
   - Steps:
   - Expected:
   - Actual:

### Test Results

<!-- Paste relevant test output or link to workflow runs -->

- Workflow run: <!-- link to test run -->
- Test output:
  ```
  <!-- paste relevant output -->
  ```

## Documentation

<!-- Check all that apply -->

- [ ] Updated README.md (if needed)
- [ ] Updated relevant docs/ files
- [ ] Updated examples/ (if applicable)
- [ ] Updated schema documentation
- [ ] Updated API reference
- [ ] Added/updated code comments
- [ ] No documentation needed

## Breaking Changes

<!-- If this is a breaking change, describe: -->
<!-- 1. What breaks -->
<!-- 2. Migration path for users -->
<!-- 3. Updated migration guide -->

**Migration required?** No / Yes

If yes, describe migration steps:
1.
2.

## Backwards Compatibility

<!-- Describe how this maintains (or breaks) backwards compatibility -->

- [ ] Fully backwards compatible
- [ ] Backwards compatible with deprecation warnings
- [ ] Breaking change (documented above)

## Configuration Changes

<!-- If this changes docker-matrix.json schema or workflow inputs: -->

**Schema changes?** No / Yes

**New workflow inputs?** No / Yes

**Changed defaults?** No / Yes

Details:
-

## Security Considerations

<!-- Answer these security questions -->

- [ ] This PR doesn't introduce new security risks
- [ ] New secrets/tokens are properly masked
- [ ] Actions are pinned to SHA hashes
- [ ] No sensitive data in logs
- [ ] Permissions are minimal
- [ ] Security implications documented

Security notes:
-

## Performance Impact

<!-- Describe any performance implications -->

**Performance impact:** None / Positive / Negative / Unknown

Details:
- Build time impact:
- Resource usage:
- Optimization notes:

## Checklist

<!-- Verify all items before requesting review -->

### Code Quality

- [ ] Code follows existing style and conventions
- [ ] Comments are added where necessary
- [ ] No commented-out code or debug statements
- [ ] Error handling is appropriate
- [ ] Logging is appropriate and informative

### Testing

- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Manual testing completed
- [ ] Test fixtures updated (if applicable)
- [ ] Edge cases considered and tested

### Documentation

- [ ] Documentation is updated
- [ ] Examples are updated
- [ ] Inline comments added for complex logic
- [ ] API changes documented
- [ ] CHANGELOG.md updated (if applicable)

### Git

- [ ] Commit messages are clear and descriptive
- [ ] Branch is rebased on latest main
- [ ] No merge conflicts
- [ ] No force pushes to shared branches
- [ ] Related issues are linked

### Schema (if applicable)

- [ ] Schema validation still passes
- [ ] Schema examples updated
- [ ] Test fixtures validate against schema
- [ ] Breaking schema changes documented

### Workflows (if applicable)

- [ ] All GitHub Actions pinned to SHA hashes
- [ ] Workflow triggers are appropriate
- [ ] Permissions are minimal
- [ ] Secrets handling is secure
- [ ] Timeouts are reasonable

## Screenshots / Recordings

<!-- If applicable, add screenshots or recordings to demonstrate changes -->

## Additional Context

<!-- Add any other context about the PR here -->

## Reviewer Notes

<!-- Anything specific you want reviewers to focus on? -->

---

## For Maintainers

<!-- Maintainers: Check before merging -->

- [ ] PR title is clear and follows conventions
- [ ] Changes are well-scoped (not too large)
- [ ] Breaking changes are documented
- [ ] Security implications reviewed
- [ ] Performance impact assessed
- [ ] Documentation is complete
- [ ] Tests are comprehensive
- [ ] Ready to merge
