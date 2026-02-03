# Security Policy

## Supported Versions

We release patches for security vulnerabilities in the following versions:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| release | :white_check_mark: |

**Note**: This project uses a rolling release model. The `main` branch always contains the latest stable code, and `release` branch is used for production releases.

## Reporting a Vulnerability

We take the security of build-workflow seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### What to Report

Please report any vulnerabilities related to:

- **Supply chain attacks**: Malicious dependencies, compromised actions
- **Secret exposure**: Leaked tokens, credentials in logs
- **Code injection**: Command injection, script injection
- **Privilege escalation**: Unauthorized access to resources
- **Denial of service**: Resource exhaustion attacks
- **Data leakage**: Exposure of sensitive information

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them via one of these methods:

1. **Private Security Advisory** (Preferred)
   - Go to https://github.com/runlix/build-workflow/security/advisories/new
   - Click "Report a vulnerability"
   - Fill in the details

2. **Email**
   - Send an email to: security@runlix.io
   - Include "SECURITY" in the subject line
   - Encrypt your email with our PGP key (see below)

3. **GitHub Discussions**
   - For lower-severity issues, you can use private discussions
   - Tag with `security` label

### What to Include

Please include the following information in your report:

- **Type of vulnerability** (e.g., code injection, secret exposure)
- **Affected component** (workflow file, script, documentation)
- **Steps to reproduce** the vulnerability
- **Proof of concept** (PoC) code if available
- **Impact assessment** - What could an attacker do?
- **Suggested fix** if you have one
- **Your contact information** for follow-up

### Example Report

```
Title: Potential secret exposure in Telegram notification

Component: .github/workflows/build-images-rebuild.yml (line 961)

Description:
The TELEGRAM_BOT_TOKEN is passed directly in the curl command URL,
which could be exposed in process listings or logs.

Steps to Reproduce:
1. Configure TELEGRAM_BOT_TOKEN secret
2. Trigger release workflow
3. Check workflow logs for curl command

Impact:
An attacker with access to workflow logs could extract the bot token
and send unauthorized messages.

Suggested Fix:
Pass the token via -H "Authorization: Bearer $TOKEN" header instead
of in the URL, and add ::add-mask:: directive.

Contact: your-email@example.com
```

## Response Timeline

We will acknowledge your report within **48 hours** and provide:

- Confirmation that we received your report
- Initial assessment of severity
- Estimated timeline for fix

Our security response process:

1. **Triage** (1-2 days): Verify and assess severity
2. **Investigation** (3-7 days): Understand root cause and impact
3. **Fix Development** (7-14 days): Create and test patch
4. **Disclosure** (coordinated): Public disclosure after fix is released

### Severity Levels

We use the following severity classifications:

| Severity | Response Time | Description |
|----------|---------------|-------------|
| **Critical** | 24 hours | Immediate risk of compromise (RCE, credential theft) |
| **High** | 48 hours | Significant security impact (data exposure, privilege escalation) |
| **Medium** | 1 week | Moderate risk (limited exposure, requires special conditions) |
| **Low** | 2 weeks | Minor security concern (information disclosure, weak defaults) |

## Security Best Practices

When using this workflow in your repository:

### 1. Protect Your Secrets

- Use GitHub's repository secrets (Settings → Secrets)
- Never commit secrets to code
- Rotate secrets regularly (quarterly recommended)
- Use minimal-privilege GitHub App tokens

### 2. Pin Actions to SHA Hashes

We pin all actions to commit SHA hashes (not version tags). When using this workflow:

```yaml
# Good ✅
uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@abc1234

# Better ✅✅
uses: runlix/build-workflow/.github/workflows/build-images-rebuild.yml@34e114876b0b11c390a56381ad16ebd13914f8d5
```

### 3. Branch Protection

Enable branch protection on your `main` and `release` branches:

- Require pull request reviews
- Require status checks to pass
- Restrict who can push
- See [docs/branch-protection.md](./docs/branch-protection.md)

### 4. Review Workflow Changes

Always review workflow changes carefully:
- Check for new secret usage
- Verify action sources
- Look for suspicious commands
- Test in a fork first

### 5. Monitor Dependencies

Use Renovate or Dependabot to:
- Keep base images updated
- Update action versions
- Scan for vulnerabilities

### 6. Audit Logs

Regularly review:
- GitHub Actions logs
- Container registry access logs
- Secret access logs (GitHub audit log)

## Known Security Considerations

### Container Registry Access

Images are pushed to GitHub Container Registry (GHCR) using `GITHUB_TOKEN`. This token has:
- Write access to packages
- Limited to the repository scope
- Automatically rotated by GitHub

### Cross-Branch Commits

The workflow uses a GitHub App token to commit `releases.json` to the main branch from release workflows. This is necessary for:
- Tracking release metadata
- Coordinating multi-repository deployments

**Security measures**:
- App has minimal permissions (contents: write)
- Only commits to main branch
- Commits are signed by the GitHub App
- See [docs/github-app-setup.md](./docs/github-app-setup.md)

### Multi-Architecture Builds

ARM64 builds run on `ubuntu-24.04-arm` runners. These:
- Are GitHub-hosted (secure)
- Have isolated build environments
- No persistent storage between runs

### Image Scanning

We use Trivy for vulnerability scanning:
- Scans OS packages and libraries
- Checks for secrets in image layers
- Results uploaded as SARIF artifacts
- Runs with `continue-on-error: true` (won't block builds)

## Security Updates

When we release security updates:

1. **Critical/High**: Immediate notification via GitHub Security Advisory
2. **Medium/Low**: Included in release notes
3. **All**: Documented in CHANGELOG.md

Subscribe to security advisories:
- Watch this repository → Custom → Security alerts

## Bug Bounty Program

We do not currently offer a bug bounty program. However:
- Security researchers are acknowledged in release notes
- Significant contributions may receive recognition
- We appreciate responsible disclosure

## Security Contact

- **Email**: security@runlix.io
- **Security Advisory**: https://github.com/runlix/build-workflow/security/advisories/new
- **Response Time**: 48 hours for initial acknowledgment

## PGP Key

```
-----BEGIN PGP PUBLIC KEY BLOCK-----
(PGP key would be inserted here for encrypted communications)
-----END PGP PUBLIC KEY BLOCK-----
```

## Additional Resources

- [OWASP CI/CD Security Best Practices](https://owasp.org/www-project-devsecops-guideline/)
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Supply Chain Levels for Software Artifacts (SLSA)](https://slsa.dev/)
- [Open Source Security Foundation (OpenSSF)](https://openssf.org/)

## Attribution

We believe in responsible disclosure and will:
- Acknowledge security researchers in release notes (with permission)
- Provide attribution in commit messages
- Credit your organization if applicable

Thank you for helping keep build-workflow and its users secure! 🔒
