# Security policy

Русская версия: [SECURITY.ru.md](SECURITY.ru.md)

## Supported versions

| Version | Supported |
|---|---|
| 1.1.x | yes |
| 1.0.x | security fixes only |
| < 1.0 | no |

## What the program does to your system

Risk assessment needs the full list:

| Action | Where | Why |
|---|---|---|
| Read icon names and positions | `explorer.exe` process, `SysListView32` window | learn what is on the desktop and where |
| Enumerate desktop folders | `%USERPROFILE%\Desktop` and `%PUBLIC%\Desktop` | find shortcuts, folders and files to group |
| Read registry | `HKCU\Software\Microsoft\Windows\Shell\Bags\1\Desktop` (`FFlags`) | check whether "Auto arrange icons" is on, and refuse to apply if so |
| Write icon positions | same window, `LVM_SETITEMPOSITION32` | place icons into blocks |
| Read a background image | the file you pick in the dialog | use it as the wallpaper base |
| Write registry | `HKCU\Control Panel\Desktop` (`Wallpaper`, `WallpaperStyle`, `TileWallpaper`) | apply the generated wallpaper |
| Write registry | `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\DesktopGroups` | entry in *Apps & features* (install only) |
| Files | program folder: `config.json`, `wallpaper.png`, `backups\` | settings, wallpaper, position backups |
| Files | `%LOCALAPPDATA%\Programs\DesktopGroups` | install location |
| Shortcuts | Start Menu, desktop (opt-in) | launch and removal |

What it does **not** do:

- no network access — no update checks, no telemetry;
- no administrator rights, never asks for elevation;
- no services, drivers, scheduled tasks or autostart entries;
- does not read files outside the desktop and its own folder
  (plus the one image you explicitly pick);
- stores and requests no passwords, tokens or keys;
- runs no external programs.

## Threat model

| Asset | Threat | Mitigation |
|---|---|---|
| Icon positions | the program mangles the layout | backup before apply, verification after, repeated passes |
| Registry | writing to foreign keys | only two `HKCU` keys, listed above |
| `explorer.exe` memory | corrupting another process | a single 4 KB buffer via `VirtualAllocEx`, freed in `finally`; only `LVITEM`/`POINT` are written; the program refuses to run under 32-bit PowerShell, where the structure size would not match |
| `config.json` | tampering, junk in group names | values are used as labels and item names, never as code or paths; names are matched against real desktop icons, unknown ones dropped; colours and lengths validated |
| Background image | malicious or malformed file | the file is parsed by `System.Drawing`, capped at 100 MB, read into memory and released; a broken file is rejected and never stored |
| Wallpaper | swapped file | the picture is generated locally from the layout plan |

## Verifying the code yourself

Everything the program does is visible in four files: `DesktopGroups.ps1` (window),
`lib\Engine.ps1` (logic), `lib\Strings.ps1` (interface text) and
`lib\DesktopIcons.cs` (the P/Invoke layer, compiled at startup by `Add-Type`).
There are no external dependencies; all code is in the repository.

```powershell
# static analysis
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1

# checks that never touch the desktop
powershell.exe -NoProfile -File .\tests\check-encoding.ps1
powershell.exe -NoProfile -File .\tests\smoke.ps1
powershell.exe -NoProfile -File .\tests\i18n.ps1

# secret scan over history
git log -p | Select-String -Pattern 'ghp_|api[_-]?key|password\s*=' -CaseSensitive:$false
```

More on tooling: [docs/security-tooling.md](docs/security-tooling.md).

## SmartScreen, code signing and why you see a warning

Microsoft Defender SmartScreen looks at two signals when a file is downloaded and run:
**publisher reputation** (is it signed, by whom) and **file hash reputation**
(has this exact file been downloaded by many people without reports).

Current behaviour, per Microsoft's own documentation
([SmartScreen reputation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation)):

| Distribution | First download |
|---|---|
| Microsoft Store | no warning — Microsoft re-signs the app |
| Signed with a valid OV/EV certificate | **still a warning** until reputation accumulates; the verified publisher name is shown |
| Unsigned or self-signed | warning: "Windows protected your PC" |

Two facts worth knowing:

- **An EV certificate no longer skips SmartScreen.** That stopped being true some
  years ago; paying extra for EV only to avoid warnings is not justified any more.
- **Unsigned files rebuild reputation from zero on every new version.** A signing
  certificate is the only identity that carries reputation between releases.

For this project specifically: the download is a ZIP with `.ps1`, `.cmd` and `.cs`
files — **there is no `.exe`**. SmartScreen's program-reputation flow therefore rarely
applies. What actually interrupts the first run is different:

1. the ZIP gets a *Mark of the Web*, so Windows may ask you to unblock it;
2. PowerShell refuses to run unsigned scripts under the default `RemoteSigned`
   policy for downloaded files;
3. on Windows 11 with **Smart App Control** enabled, unsigned scripts can be blocked
   outright, and only turning the feature off changes that.

### What this project does about it

- `install.cmd` and `DesktopGroups.cmd` pass `-ExecutionPolicy Bypass` **for that one
  process**; the system-wide policy is never changed.
- The README documents the **Unblock** step and the `Unblock-File` command.
- Release assets ship with `SHA256SUMS.txt` and a **signed build provenance
  attestation**, so a user can verify the download came from this repository:

  ```powershell
  gh attestation verify .\DesktopGroups-1.1.0.zip --repo mikel38487/DesktopGroups
  ```

### What would remove the warning

| Option | Cost | Fits this project? |
|---|---|---|
| **SignPath Foundation** — free OV-level signing for open source | free, requires the build to be reproducible from public sources | best fit; application needed |
| **OV code-signing certificate** (Sectigo, Certum, …) | roughly €200–400 per year, hardware token or cloud HSM | works, but reputation still starts at zero |
| **Azure Artifact Signing** (formerly Trusted Signing) | from $9.99/month, CI-friendly | needs 3+ years of verifiable business history; not available to individuals |
| **Microsoft Store** | free | not applicable: this is a script tool, not a packaged app |
| **EV certificate** | most expensive | no SmartScreen benefit any more |

Concrete plan for this repository: [docs/code-signing.md](docs/code-signing.md).

There is **no manual submission** that grants consumer reputation; it builds
organically from download volume. Enterprise administrators can submit a file through
the [Microsoft Security Intelligence portal](https://www.microsoft.com/en-us/wdsi/filesubmission)
to speed up trust in a managed fleet.

## Reporting a vulnerability

- Do not open a public issue. Use the **Security** tab →
  **Report a vulnerability** (GitHub Security Advisories).
- If that is impossible, contact the address in the GitHub profile without
  exploit details in the open.
- Please include: version (`VERSION`), Windows version, reproduction steps,
  expected and actual behaviour.

Timeline: acknowledgement within 3 days, assessment within 7 days, fix by
agreement depending on severity.

## Scope

In scope: code in this repository, the installer, wallpaper generation,
registry work and the desktop window handling.

Out of scope: vulnerabilities in Windows and Explorer, third-party themes,
desktop behaviour when icons are dragged by hand.
