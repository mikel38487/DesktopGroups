# DesktopGroups — user guide

Русская версия: [guide.ru.md](guide.ru.md)

This guide covers everything the window does, what is written to disk
and to the registry, and what to do when something looks wrong.
Short overview: [README.md](../README.md).

## Contents

1. [Installation](#installation)
2. [First run](#first-run)
3. [Groups](#groups)
4. [Interface language](#interface-language)
5. [Background image](#background-image)
6. [Applying the layout](#applying-the-layout)
7. [Backups and restore](#backups-and-restore)
8. [Files and registry](#files-and-registry)
9. [Troubleshooting](#troubleshooting)
10. [FAQ](#faq)

## Installation

### Normal install (no administrator rights)

1. Download `DesktopGroups-<version>.zip` from Releases and unpack it.
2. Unblock the archive if Windows marked it as downloaded:
   right-click the ZIP → **Properties** → **Unblock**, or in the unpacked folder

   ```powershell
   Get-ChildItem -Recurse | Unblock-File
   ```

3. Run `install.cmd`. It does four things:
   - copies the program to `%LOCALAPPDATA%\Programs\DesktopGroups`;
   - creates `DesktopGroups.lnk` in the Start Menu;
   - registers an entry in *Apps & features* (`HKCU\...\Uninstall\DesktopGroups`);
   - remembers your current wallpaper in `previous-wallpaper.json`, so uninstall
     can put it back.

Everything goes into your own profile. Nothing needs elevation.

### Portable mode

Skip `install.cmd` and run `DesktopGroups.cmd` from the unpacked folder.
The program then keeps `config.json`, `wallpaper.png` and `backups\` next to itself.

Do not put the portable copy into `C:\Program Files`: a normal user cannot write
there, and the program will fail to save the config and the wallpaper.

### Removing

Use *Apps & features* in Windows settings, or run `uninstall.cmd` from the install
folder. The program is removed, the Start Menu shortcut is deleted, the
*Apps & features* entry disappears, and your previous wallpaper is restored.

## First run

The window opens with groups already suggested from the names of your icons.
Nothing is applied to the desktop until you press **Lay out icons and update wallpaper**.

On the very first start a `config.json` is created next to the program.
If that file is ever damaged, the program does not overwrite it silently:
the broken file is renamed to `config.bad-<date>-<time>.json`, and a message
tells you where it went.

## Groups

### Suggest groups

**Suggest groups** reads icon names and fills a default set: Games,
Development & AI, Chat & Internet, Media, Network & VPN, Hardware, Installers,
System, and Misc for everything unmatched. It asks for confirmation because it
replaces the current groups.

Matching works on whole words, so `Codecs` is not treated as `code` and
`Immediate` is not treated as `media`.

### Your own groups

| Button | What it does |
|---|---|
| **New** | adds a group with a name you type |
| **Rename** | changes the name of the selected group |
| **Delete** | removes the group; its icons move to Misc |
| **↑ up / ↓ down** | changes the order of the blocks on the wallpaper |
| **Add icons…** | moves free icons into the selected group |
| **Remove from group** | returns selected icons to the free pool |

Duplicate names are rejected. An empty or whitespace-only name is ignored.
The order of icons inside the group list is the order they are placed in the block.

### Scan desktop

**Scan desktop** re-reads the desktop and does **not** throw away your groups:
icons that disappeared are dropped from their groups, new icons are added to Misc,
and names that changed are matched again. This is how you refresh after adding
or deleting shortcuts.

## Interface language

The selector in the top right corner switches between **Русский** and **English**
immediately, without restart. The choice is saved in `config.json`:

```json
{ "language": "en" }
```

Precedence: `-Lang` parameter → `config.json` → the language of Windows.
If `config.json` has no `language` field, Windows' own UI language is used
(`InstalledUICulture`, so a Russian Windows gives Russian).

Force a language for a single run:

```powershell
powershell.exe -STA -ExecutionPolicy Bypass -File .\DesktopGroups.ps1 -Lang en
```

Group names are data, not interface text: switching the language does not rename
the groups you created. Only the special group named "Прочее" or "Misc" is renamed
so the two language versions of the program agree on it.

## Background image

**Background image…** opens a file dialog (PNG, JPEG, BMP, GIF, WEBP).
**No background** returns to the default dark gradient.

How the picture is used:

- scaled to fill the whole screen with **center crop** — no stretching, no bars;
- covered with a vertical dark veil (denser at the top, where the labels are);
- frames are drawn on top with a slightly stronger fill and outline so they stay
  visible over a photo;
- each label sits on its own dark plate, so it stays readable over bright areas.

The file is read into memory and released immediately: the program does not hold
a lock on your picture. You can move or delete it later — the program will simply
fall back to the gradient and say so in the status line.

Limits and safety:

- files larger than 100 MB are rejected with a message;
- a file that is not a real image is rejected and **never** written to the config;
- a path that stops existing falls back to the gradient on the next apply.

The path is stored in `config.json`:

```json
{ "background": "C:\\Pictures\\wall.png" }
```

## Applying the layout

**Lay out icons and update wallpaper** does, in order:

1. checks that *Auto arrange icons* is off and stops with an explanation if it is on;
2. builds the layout: each group becomes a `cols × rows` rectangle, blocks are
   packed into horizontal rows with one empty column between them;
3. saves the current icon positions to `backups\before-apply-<date>-<time>.json`;
4. moves the icons with `LVM_SETITEMPOSITION32`, repeating passes until nothing moves;
5. reads the positions back and reports any icon that did not land;
6. draws the wallpaper at your screen size and applies it.

If blocks do not fit the screen, the program asks for confirmation first and
marks the preview with a warning.

## Backups and restore

Every apply writes a backup of all icon positions before touching anything.
The last 20 backups are kept; older ones are deleted automatically.

**Restore previous layout** applies the most recent backup, which is useful after
an accidental re-arrangement. Backups store positions only — not which group an
icon belonged to.

## Files and registry

| What | Where |
|---|---|
| Program (installed) | `%LOCALAPPDATA%\Programs\DesktopGroups` |
| Settings | `config.json` next to the program |
| Generated wallpaper | `wallpaper.png` next to the program |
| Backups | `backups\before-apply-*.json` |
| Saved wallpaper before install | `previous-wallpaper.json` |
| Startup error log | `startup-error.log` (only if the window failed to start) |
| Wallpaper settings | `HKCU\Control Panel\Desktop` (`Wallpaper`, `WallpaperStyle`, `TileWallpaper`) |
| Uninstall entry | `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\DesktopGroups` |

`config.json` example:

```json
{
  "groups": [
    { "name": "Games", "color": "#E0A33E", "items": [ "Steam", "Deadlock+" ] }
  ],
  "language": "en",
  "background": "",
  "updated": "2026-11-10 01:40"
}
```

The file is written atomically: a temporary file is created and renamed over the
old one, so a power loss cannot leave a half-written config.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "running scripts is disabled" | ExecutionPolicy is Restricted | use `DesktopGroups.cmd` / `install.cmd`, they pass `-ExecutionPolicy Bypass` for that process only |
| SmartScreen blocks the program | files are not code-signed | unblock the archive before unpacking |
| Antivirus warning | the program writes to `explorer.exe` memory to set icon positions | expected; the source is open, only `LVITEM`/`POINT` is written |
| Frames do not match icons | resolution or DPI changed after applying | apply again |
| Icons moved by themselves | *Auto arrange icons* is on | turn it off, then apply again |
| Background not visible | file moved or deleted, or not an image | pick the file again; the status line names the current background |
| Groups disappeared | config was damaged | look for `config.bad-*.json` next to the program and restore from it |
| "Not found on the desktop: …" | an icon in a group no longer exists under that name | press **Scan desktop**, the name will be dropped |
| Window does not fit the screen | small display | the window shrinks to the working area and scrolls |

## FAQ

**Does it run in the background?**
No. It is a normal window: closed means gone. The frames are part of the wallpaper
file, so the desktop keeps looking grouped.

**Does it survive a reboot?**
Yes — the wallpaper is a normal wallpaper and the icon positions are stored by
Windows itself.

**What happens if I move one icon by hand?**
Only that icon leaves its cell; the frame stays where it was drawn. Press
**Lay out icons and update wallpaper** to rebuild everything.

**Can I use my own picture?**
Yes, see [Background image](#background-image).

**Does it work with several monitors?**
Not yet: only the primary monitor is laid out.

**Does it send anything over the network?**
No. There are no update checks and no telemetry.

**Can I edit `config.json` by hand?**
Yes. Invalid values are sanitised on load: an unknown colour becomes a palette
colour, an over-long name is cut, a missing icon name is dropped.
