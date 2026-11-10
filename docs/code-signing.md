# Code signing via SignPath Foundation

Русская версия: [code-signing.ru.md](code-signing.ru.md)

This page is the plan, not a statement of fact: the application has **not** been
submitted yet. It records what is required, what to prepare, and what the integration
will look like once accepted.

## What it gives, and what it does not

| Effect | Reality |
|---|---|
| PowerShell scripts run under the default `RemoteSigned` policy without `-ExecutionPolicy Bypass` | **yes** — a valid Authenticode signature is enough |
| Publisher name is shown in the properties of the signed file | yes |
| SmartScreen stops warning | **not immediately**: a valid OV signature still shows a warning until hash or publisher reputation accumulates |
| `.cmd` launchers get signed | **no** — Authenticode has no format for `.cmd`/`.bat`; they stay unsigned and must stay thin |

SignPath's own artifact reference lists `<powershell-file>` for `.ps1`, `.psm1`,
`.psd1`, `.ps1xml`, signed with `<authenticode-sign>`. Metadata restrictions
(product name and version) apply to `<pe-file>` only, so a project made of scripts
does not have to carry a version resource — which is exactly our situation.

## Eligibility (SignPath Foundation terms)

For the free OSS subscription:

- OSI-approved license, no commercial dual licensing — MIT ✓;
- no proprietary components — everything is in the repository ✓;
- actively maintained ✓;
- **already released in the form that should be signed** ✓ (v1.0.0 … v1.1.1);
- functionality documented ✓ (README, `docs/guide.md`).

For the free certificate (SignPath Foundation becomes the publisher) additionally:

- sign only your own code and artifacts;
- **privacy statement** on the project page — added to README;
- announce system changes — the program changes wallpaper and icon positions, both
  documented in README and `SECURITY.md` ✓;
- provide an uninstaller ✓ (`uninstall.cmd`);
- **MFA enabled** on the GitHub account and on SignPath;
- code review roles declared;
- **code signing policy section** on the project page with the exact phrase
  "Free code signing provided by SignPath.io, certificate by SignPath Foundation" —
  added to README.

## Application

1. Open <https://signpath.org/apply> and fill the form. Prepare:
   - repository URL and a short description of what the program does;
   - license (MIT) and confirmation there is no proprietary part;
   - the released artifact that should be signed (the ZIP from Releases);
   - the code signing policy section link (README anchor);
   - who maintains it and who approves releases.
2. Wait for manual review. Expect questions; the decision is manual and they accept
   the risk of publishing under their name, so a young project may be asked to come
   back after it has visible use. The honest weak point here is reputation: the
   project is new.
3. On approval: install the [SignPath GitHub App](https://github.com/apps/signpath)
   and link the repository.

## Setup after approval

1. **Organization** — one per maintainer. It can hold several projects: a project in
   SignPath is one product or a bundle of artifacts that belong together. So the same
   application path is reused for other open-source projects — each one is created as
   a separate project and approved separately.
2. **Project** — `DesktopGroups`.
3. **Signing policy** — certificate from SignPath Foundation, release builds only,
   **manual approval of every release**, trusted build system GitHub.com.
4. **Artifact configuration** — a versioned XML that names every file to sign:

```xml
<artifact-configuration xmlns="http://signpath.io/artifact-configuration">
  <zip-file>
    <powershell-file path="DesktopGroups.ps1">
      <authenticode-sign/>
    </powershell-file>
    <powershell-file path="lib\Engine.ps1">
      <authenticode-sign/>
    </powershell-file>
    <powershell-file path="lib\Strings.ps1">
      <authenticode-sign/>
    </powershell-file>
    <powershell-file path="tools\install.ps1">
      <authenticode-sign/>
    </powershell-file>
    <powershell-file path="tools\uninstall.ps1">
      <authenticode-sign/>
    </powershell-file>
  </zip-file>
</artifact-configuration>
```

5. **Secret** — `SIGNPATH_API_TOKEN` in the repository secrets (token with the
   "submit signing request" role only).

## Workflow change

The release job gains one stage between building the ZIP and publishing it:

```yaml
- name: Sign the archive
  uses: signpath/github-action-submit-signing-request@<sha> # v3
  with:
    api-token: ${{ secrets.SIGNPATH_API_TOKEN }}
    organization-id: <org-id>
    project-slug: desktopgroups
    signing-policy-slug: release-signing
    artifact-configuration-slug: zip-with-scripts
    github-artifact-id: ${{ steps.build.outputs.artifact-id }}
    wait-for-completion: true
    output-artifact-directory: dist-signed
```

The ZIP must be uploaded with `actions/upload-artifact` (v4 or newer) because the
action works with artifact IDs, and all jobs must run on GitHub-hosted runners.
After signing, the workflow republishes `SHA256SUMS.txt` and the attestation for the
**signed** archive.

## What changes for users

- README: drop the "unblock and bypass the execution policy" workaround, keep a note
  that SmartScreen may still warn until reputation builds up.
- `install.cmd` / `DesktopGroups.cmd`: `-ExecutionPolicy Bypass` can stay for
  compatibility, but signed scripts make it unnecessary.
- A new line in `SECURITY.md`: who signed the release and how to check it
  (`Get-AuthenticodeSignature`).

## Reusing this for other projects

- One SignPath **organization** covers all your repositories.
- Each product is a separate **project** with its own signing policy and artifact
  configuration, and each OSS project goes through its own free-subscription review.
- The certificate stays SignPath Foundation's, so the same rules apply everywhere:
  own code only, privacy statement, code review roles, manual release approval.
- Nothing in the setup is specific to PowerShell: for a C# or Go project the artifact
  configuration simply uses `<pe-file>` with metadata restrictions.

## Cost and obligations

- No fee for open-source projects.
- Manual approval of each release — you cannot publish unattended.
- The project may be paused or removed if the code of conduct is violated.

## See also

- [SignPath Foundation terms](https://signpath.org/terms.html)
- [Artifact configuration reference](https://docs.signpath.io/artifact-configuration/reference)
- [SECURITY.md](../SECURITY.md) — SmartScreen and signing options
