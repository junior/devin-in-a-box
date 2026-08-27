# Security policy

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for security issues. Do
not open a public issue containing credentials, tokens, private source code,
internal hostnames, or CI logs with sensitive data.

For non-sensitive hardening suggestions, a regular GitHub issue is welcome.

## Credential model

Devin credentials are mounted at runtime and copied into the ephemeral
container with mode `0600`. They must never be added to the build context,
committed to Git, embedded in an image layer, or printed in logs.

Use a dedicated, least-privileged Devin identity when your organization permits
it. Protect GitLab file variables and GitHub Actions secrets, and rotate any
credential immediately if exposure is suspected.

## Supported versions

Security fixes are applied to the latest published image and the default
branch. Pin a digest when deployment reproducibility matters.
