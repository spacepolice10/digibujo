# Security Policy

## Supported versions

Security fixes are applied to the `main` branch.

## Reporting a vulnerability

Please **do not** open public GitHub issues for security problems.

Report vulnerabilities via [GitHub Security Advisories](https://github.com/spacepolice10/digibujo/security/advisories/new) for this repository, or email the maintainers privately if Advisories are unavailable.

Include:

- Description of the issue and impact
- Steps to reproduce
- Affected versions or commits, if known

We aim to acknowledge reports within a few business days.

## Automated checks

Pull requests and pushes to `main` run:

- `bin/brakeman` — Rails static security analysis
- `bin/bundler-audit` — known gem CVEs
- `bin/importmap audit` — JavaScript dependency audit

Run the same locally with `bin/ci`.
