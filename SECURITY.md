# Security Policy

## Reporting a Vulnerability

Please do not report security issues through public GitHub issues or pull requests.

Use GitHub Private Security Advisories for this repository:

- https://github.com/runlix/build-workflow/security/advisories/new

## What To Report

Report vulnerabilities that affect the reusable workflow or the supply chain around it, including:

- compromised or untrusted GitHub Actions dependencies
- secret exposure in logs, artifacts, or release metadata
- command injection or unsafe shell handling
- permission or token escalation
- unsafe image publishing, manifest creation, or cleanup behavior

## What To Include

Include enough detail for reproduction and triage:

- affected file, job, step, or command
- reproduction steps or a minimal proof of concept
- expected behavior and observed behavior
- impact assessment
- any suggested mitigation or patch
- a contact method for follow-up

## Project-Specific Security Notes

Relevant implementation details in this repository today:

- the sync reusable workflow requires `RUNLIX_APP_ID` and `RUNLIX_PRIVATE_KEY` for protected-branch write-back
- GHCR publishing and cleanup use `GITHUB_TOKEN`
- sync write-back updates `release.json` on `main`
- optional Telegram notifications use repository secrets
- Trivy SARIF artifacts are generated during image validation

Review related documentation when reporting issues in these areas:

- [GitHub App Setup](./docs/github-app-setup.md)
- [Branch Protection](./docs/branch-protection.md)
- [API Reference](./docs/api-reference.md)

## Security Practices For Consumers

If you use this workflow in another repository:

- pin the reusable workflow to a specific commit SHA when you need immutability
- keep required secrets in GitHub Actions secrets, not in the repository
- review workflow changes carefully before updating the ref you consume
- keep branch protection enabled on branches that trigger release automation

## Disclosure

We prefer coordinated disclosure. Public details should wait until maintainers have had a reasonable chance to reproduce and mitigate the issue.

## Additional Resources

- [GitHub Actions security hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [OWASP CI/CD security guidance](https://owasp.org/www-project-devsecops-guideline/)
- [OpenSSF](https://openssf.org/)
