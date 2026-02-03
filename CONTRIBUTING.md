# Contributing to Build Workflow

Thank you for your interest in contributing to the build-workflow project! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Testing Your Changes](#testing-your-changes)
- [Submitting Changes](#submitting-changes)
- [Coding Standards](#coding-standards)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment. Please:

- Be respectful and considerate in your communication
- Welcome newcomers and help them get started
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards other community members

## How to Contribute

There are several ways you can contribute:

1. **Report bugs** - Open an issue describing the problem
2. **Suggest enhancements** - Propose new features or improvements
3. **Submit fixes** - Fix bugs or implement features via pull requests
4. **Improve documentation** - Help make our docs clearer and more comprehensive
5. **Help others** - Answer questions in issues and discussions

## Development Setup

### Prerequisites

- Git
- GitHub account
- Docker and Docker Buildx
- Node.js 20+ (for schema validation)
- `jq` for JSON processing
- `ajv-cli` for schema validation

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:

```bash
git clone https://github.com/YOUR-USERNAME/build-workflow.git
cd build-workflow
```

3. Add the upstream repository:

```bash
git remote add upstream https://github.com/runlix/build-workflow.git
```

### Install Dependencies

```bash
# Install schema validation tools
npm install -g ajv-cli ajv-formats

# Verify Docker setup
docker buildx version
```

## Testing Your Changes

### 1. Validate Schema Changes

If you modify the JSON schema:

```bash
# Validate schema syntax
ajv compile -s schema/docker-matrix-schema.json

# Test against fixtures
ajv validate -s schema/docker-matrix-schema.json -d test-fixtures/service/docker-matrix.json
ajv validate -s schema/docker-matrix-schema.json -d test-fixtures/base-image/docker-matrix.json
```

### 2. Test Workflow Changes

If you modify workflows:

```bash
# Run test workflow locally (requires GitHub CLI)
gh workflow run test-workflow.yml --ref YOUR-BRANCH

# Or test specific fixture
gh workflow run test-workflow.yml --ref YOUR-BRANCH -f test_type=service
```

### 3. Test with Real Service Repository

Create a test branch in a service repository (e.g., distroless-runtime):

```yaml
# .github/workflows/test-new-workflow.yml
name: Test Build Workflow Changes
on:
  workflow_dispatch:

jobs:
  test:
    uses: YOUR-USERNAME/build-workflow/.github/workflows/build-images-rebuild.yml@YOUR-BRANCH
    with:
      pr_mode: true
      dry_run: true
    secrets: inherit
```

### 4. Validate Documentation

Check documentation for:
- Correct Markdown syntax
- Working links
- Up-to-date examples
- Clear explanations

## Submitting Changes

### Branch Naming

Use descriptive branch names:
- `fix/issue-description` - Bug fixes
- `feat/feature-description` - New features
- `docs/documentation-description` - Documentation changes
- `refactor/refactor-description` - Code refactoring
- `test/test-description` - Test improvements

### Commit Messages

Write clear, descriptive commit messages:

```
Add concurrency control to build jobs

- Prevents multiple builds from running simultaneously
- Reduces resource contention on shared runners
- Adds per-repository concurrency groups
```

Format:
1. Summary line (50 chars or less)
2. Blank line
3. Detailed explanation (wrap at 72 chars)
4. Reference issues: `Fixes #123` or `Relates to #456`

### Pull Request Process

1. **Update your branch** with latest upstream changes:

```bash
git fetch upstream
git rebase upstream/main
```

2. **Test thoroughly** using the testing guidelines above

3. **Update documentation** if you change:
   - Workflow inputs/outputs
   - Schema structure
   - Configuration options
   - Usage patterns

4. **Open a pull request** with:
   - Clear title describing the change
   - Description of what changed and why
   - Link to related issues
   - Test results or screenshots if applicable

5. **Respond to feedback** - Address review comments promptly

### Pull Request Checklist

Before submitting, ensure:

- [ ] Code follows existing style and patterns
- [ ] All tests pass locally
- [ ] Schema changes are validated
- [ ] Documentation is updated
- [ ] Examples reflect any changes
- [ ] Commit messages are clear
- [ ] Branch is rebased on latest main
- [ ] No merge conflicts exist

## Coding Standards

### Workflow Files (.yml)

- Use 2-space indentation
- Add comments explaining complex logic
- Group related steps together
- Use descriptive step names
- Pin all actions to commit SHA hashes (not tags)
- Include inline comments showing version (e.g., `# v4`)

Example:
```yaml
- name: Checkout repository
  uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
  with:
    ref: ${{ inputs.ref }}
```

### JSON Schema

- Follow JSON Schema Draft 7 specification
- Add clear descriptions for all properties
- Include examples where helpful
- Use pattern validation for strings
- Provide informative error messages via `errorMessage`

### Documentation

- Use clear, concise language
- Include code examples
- Link to related documentation
- Keep table of contents updated
- Use proper Markdown formatting
- Test all command examples

### Bash Scripts

- Use `#!/bin/bash` shebang
- Enable error handling: `set -euo pipefail`
- Quote variables: `"$VAR"`
- Use meaningful variable names
- Add comments for complex logic

## Reporting Issues

### Bug Reports

When reporting bugs, include:

1. **Description** - What happened vs. what you expected
2. **Steps to reproduce** - Minimal steps to recreate the issue
3. **Environment** - OS, Docker version, runner type
4. **Logs** - Relevant error messages or workflow logs
5. **Configuration** - Your `docker-matrix.json` (sanitized)

Use the bug report template when creating an issue.

### Feature Requests

When suggesting features, include:

1. **Use case** - What problem does this solve?
2. **Proposed solution** - How should it work?
3. **Alternatives** - Other approaches you considered
4. **Examples** - Show how you'd use the feature

Use the feature request template when creating an issue.

## Questions?

- **Documentation**: Check [docs/](./docs/) directory
- **Issues**: Search [existing issues](https://github.com/runlix/build-workflow/issues)
- **Discussions**: Use [GitHub Discussions](https://github.com/runlix/build-workflow/discussions)

## Recognition

Contributors will be:
- Listed in release notes for significant contributions
- Credited in commit messages for their work
- Appreciated for helping make this project better!

Thank you for contributing to build-workflow! 🎉
