# Security on GitHub: what is set up here

Русская версия: [github-security.ru.md](github-security.ru.md)

This page lists the repository guards that are actually switched on, what each one
catches, and what is deliberately missing because the platform does not support it
for this kind of code.

## Enabled on this repository

| Guard | What it does | Where to look |
|---|---|---|
| **Dependabot alerts** | watches the dependency graph and reports known vulnerabilities in used versions | Security → Dependabot |
| **Dependabot security updates** | opens a PR automatically when a vulnerable dependency has a fix | Pull requests, labelled `dependabot` |
| **Dependabot version updates** | weekly PRs for GitHub Actions used in workflows (`.github/dependabot.yml`) | Pull requests |
| **Secret scanning** | scans commits for known token formats (GitHub, cloud keys, etc.) | Security → Secret scanning |
| **Push protection** | blocks a push that contains a detected secret before it reaches history | shows up as a rejected push |
| **Private vulnerability reporting** | lets a researcher open a private advisory instead of a public issue | Security → Advisories → Report |
| **OpenSSF Scorecard** | weekly supply-chain check (pinned actions, token permissions, review, branch protection), results as SARIF | Security → Code scanning; `.github/workflows/scorecard.yml` |
| **Build provenance attestation** | every release asset gets a signed statement saying which workflow and commit built it | `gh attestation verify` |
| **SHA-256 checksums** | `SHA256SUMS.txt` next to the release archive | Releases page |

### Actions are pinned by commit SHA

A tag can be moved; a commit cannot. Every `uses:` in this repository points to a
full SHA with the version in a trailing comment:

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

Dependabot still updates them: it understands the `# vX.Y.Z` comment and opens a PR
with a new SHA when a release appears. This is the check "Pinned-Dependencies" in
Scorecard.

## Verifying a release yourself

```powershell
# 1. download the archive and the checksums, then compare
Get-FileHash .\DesktopGroups-1.1.0.zip -Algorithm SHA256
Get-Content .\SHA256SUMS.txt

# 2. verify the provenance attestation (needs GitHub CLI 2.49+)
gh attestation verify .\DesktopGroups-1.1.0.zip --repo mikel38487/DesktopGroups
```

A successful check means the file was produced by this repository's release
workflow from a specific commit, not uploaded by hand.

## What is NOT enabled, and why

| Missing | Reason |
|---|---|
| **CodeQL / code scanning for PowerShell** | CodeQL has no PowerShell support. The `.cs` file is compiled at runtime by `Add-Type` and has no project file, so building it for CodeQL would mean adding a maintain-only build step for 200 lines. PSScriptAnalyzer in CI covers the PowerShell, and all C# is visible in one file. |
| **Secret scanning validity checks** | the API accepts the request but the setting stays `disabled` for this personal repository; provider patterns are still scanned. |
| **Custom (non-provider) secret patterns** | available for organizations, not for a personal repository. |
| **Branch protection with required reviews** | this is a single-maintainer project: requiring a review on your own PRs blocks work without adding a check. CI is required to pass on `main` through the release workflow's own gates (encoding, smoke, i18n). |
| **Signed commits** | would require keeping a GPG or SSH signing key; releases are covered by provenance attestation instead, which is stronger for artifacts. |

## What each guard would have caught here

- **Push protection** — would block an accidental `ghp_...` in a commit. Nothing to
  find in history (checked with a pattern scan).
- **Dependabot** — already did its job: two PRs bumped `actions/checkout` and
  `actions/upload-artifact` from v4 to v7, both merged after CI passed.
- **Scorecard** — reports posture, not bugs. It will flag things like missing
  branch protection; treat its score as a checklist, not a grade.

## Adding more later

- **Sigstore/cosign signing** of the ZIP — an alternative to attestations, keyless
  via GitHub OIDC.
- **SBOM** — `actions/dependency-submission` or a generated SPDX file for the archive;
  for a project with no package manager the SBOM is mostly the file list.
- **OpenSSF Best Practices badge** — a self-assessment form, useful as public signal.

## See also

- [SECURITY.md](../SECURITY.md) — policy, threat model, reporting
- [security-tooling.md](security-tooling.md) — scanners used on the code itself
