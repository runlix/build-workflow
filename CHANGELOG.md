# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- LICENSE file (MIT License)
- CONTRIBUTING.md with comprehensive contribution guidelines
- SECURITY.md with vulnerability reporting procedures
- CODE_OF_CONDUCT.md (Contributor Covenant v2.1)
- Issue templates (bug report, feature request, service integration help)
- Pull request template with comprehensive checklist
- API reference documentation (`docs/api-reference.md`)
- CHANGELOG.md to track changes
- Schema structure validation in test workflow (validates schema before using it)
- Validation of all example files in test workflow (prevents documentation drift)

### Changed
- **SECURITY**: Pinned all GitHub Actions to commit SHA hashes (30 actions across 2 workflow files)
- **SECURITY**: Added secret masking for Telegram bot tokens in workflow logs
- Build job timeout reduced from 120 minutes to 60 minutes
- Added concurrency control to cancel outdated PR builds
- Improved retry logic with exponential backoff (30s, 60s, 120s)
- Changed fail-fast strategy to false for better visibility into failures
- Enhanced Trivy scanning to include secrets and misconfigurations
- Added secret validation at workflow start (fail fast)
- Fixed error propagation in manifest creation script
- Removed unused `default` field from schema examples and test fixtures
- Updated documentation to remove references to `latest` tag (not implemented)
- Made Telegram secrets optional in workflow definition
- Enhanced Renovate configuration with explicit digest pinning, weekly schedule, and better commit messages
- Enhanced .gitignore with comprehensive patterns for IDE, OS, and temporary files

### Fixed
- aquasecurity/trivy-action@master vulnerability (pinned to specific SHA)
- Secret exposure in Telegram notification step
- Example workflow comments that referenced outdated promotion behavior
- Documentation inconsistencies about PR image pushing
- Schema validation error: Added `$schema` as allowed property in JSON schema
- Trivy action version comment for better Renovate compatibility

### Security
- All GitHub Actions now pinned to immutable commit SHA hashes
- Secrets properly masked in workflow logs with `::add-mask::`
- Added comprehensive security policy (SECURITY.md)
- Improved secret handling in release notifications

## Previous Releases

This CHANGELOG was created on 2025-02-03. Previous changes were not tracked in this format.

For historical context, see:
- Git commit history
- GitHub releases (if any)
- Pull request history

---

## Types of Changes

- `Added` for new features
- `Changed` for changes in existing functionality
- `Deprecated` for soon-to-be removed features
- `Removed` for now removed features
- `Fixed` for any bug fixes
- `Security` for vulnerability fixes and security improvements
