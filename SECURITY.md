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

Everything the program does is visible in three files: `DesktopGroups.ps1` (window),
`lib\Engine.ps1` (logic) and `lib\Strings.ps1` (interface text). There are no
external dependencies; all code is in the repository.

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

More on tooling: [docs/security-tooling.md](security-tooling.md).

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
