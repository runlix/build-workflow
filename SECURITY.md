# Security Policy

## Supported Version

This repository currently supports the `main` branch only.
It does not currently publish git tags or maintain a separate `release` branch.

## Reporting a Vulnerability

Do not open public GitHub issues for security reports.

Use one of these channels instead:

1. GitHub Security Advisory: https://github.com/runlix/build-workflow/security/advisories/new
2. Email: `security@runlix.io`

Include:

- affected file or workflow area
- impact summary
- reproduction steps or proof of concept
- any suggested mitigation

## What to Expect

We review security reports privately and follow up through the reporting channel you used.
Please avoid public disclosure until the issue has been assessed and, when needed, fixed.

## Security Notes for Consumers

- Pin reusable workflows to immutable SHAs for production use.
- Review any permission or secret changes before adopting workflow updates.
- Keep `RUNLIX_APP_ID`, `RUNLIX_PRIVATE_KEY`, `TELEGRAM_BOT_TOKEN`, and `TELEGRAM_CHAT_ID` in GitHub Actions secrets.
- Treat GHCR publishing and cross-branch `releases.json` updates as sensitive release operations.

## Related Resources

- [GitHub App Setup](./docs/github-app-setup.md)
- [Branch Protection](./docs/branch-protection.md)
- [Release Workflow](./docs/release-workflow.md)
