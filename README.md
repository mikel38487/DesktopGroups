# DesktopGroups

Group desktop shortcuts into rectangles — and let the wallpaper draw the frames
and labels for those groups.

![DesktopGroups: group frames drawn on the wallpaper](docs/preview.png)

## Why another desktop organizer

Existing tools (Stardock Fences, DexCorral, Gridify, DeskRipple) draw their groups
as an **overlay window** on top of the desktop. That means a resident process,
hooks into Explorer, and a group that disappears when the tool is not running.

DesktopGroups does the opposite: it **bakes the group frames into the wallpaper**.
There is no background process and no overlay window; the desktop stays a normal
desktop, and the groups survive reboots because they are just icons on a grid.
Icon positions are set through the desktop list view's own `LVM_*` messages —
no code is injected into Explorer, only the item-position structures it already
understands (details in `SECURITY.md`).

The trade-off is honest: frames are static. Move an icon by hand and the frame will
no longer match — re-apply the layout and both are rebuilt from one plan.

## Features

- Scans shortcuts, folders and files on the desktop (current user + `Public`).
- Proposes groups by name heuristics (games, dev/AI, messengers, media, VPN/remote,
  hardware, installers, system, everything else).
- Create, rename, delete and reorder your own groups; move icons between groups.
- Lays icons out as exact rectangles (each block has no empty cells when possible).
- Generates a 1920×1080 wallpaper with rounded frames, per-group colors and labels.
- Keeps `config.json` next to the app and a backup of previous icon positions before
  every apply.
- Verifies the result: reads the positions back and reports any icon that did not land.

## Requirements

- Windows 10 or 11.
- Windows PowerShell 5.1 (built in). PowerShell 7 works for the engine, the GUI is
  started through `powershell.exe`.
- No administrator rights, no external packages, no network.

## Install

Nothing to compile: the program is plain PowerShell plus one C# helper that is
compiled in memory at startup by `Add-Type`.

1. Download `DesktopGroups-<version>.zip` from the [Releases](../../releases) page
   and unpack it anywhere.
2. If Windows marked the files as downloaded, right-click the ZIP →
   **Properties** → **Unblock**, or run
   `Get-ChildItem -Recurse | Unblock-File` in the unpacked folder.
3. Run **`install.cmd`**. It copies the program to
   `%LOCALAPPDATA%\Programs\DesktopGroups`, creates a Start Menu shortcut and an
   entry in *Apps & features*. No administrator rights are needed.
4. Start it from the Start Menu.

Prefer a portable setup? Skip `install.cmd` and run `DesktopGroups.cmd` from the
unpacked folder — nothing is written outside that folder except your own
`config.json` and `wallpaper.png`.

To remove it, use *Apps & features* in Windows settings, or run `uninstall.cmd`.

## Usage

Run `DesktopGroups.cmd` (double click). Or:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\DesktopGroups.ps1
```

Typical flow:

1. **Сканировать стол** — read the current desktop.
2. **Предложить группы** — fill groups from names, then adjust by hand.
3. **Новая / Переименовать / Удалить / ↑ ↓** — build your own set.
4. **Добавить значки…** — move shortcuts into the selected group.
5. **Разложить значки и обновить обои** — place icons and redraw the wallpaper.

## Troubleshooting

**Windows says "running scripts is disabled on this system".**
Launch through `DesktopGroups.cmd` or `install.cmd`: they pass
`-ExecutionPolicy Bypass` for that one process. The system-wide policy is not
changed. If the policy is enforced by group policy (`MachinePolicy`), `Bypass`
will not help — that is a machine restriction.

**SmartScreen or "Windows protected your PC".**
The files are not code-signed. Right-click the ZIP → **Properties** →
**Unblock** before unpacking, or run `Get-ChildItem -Recurse | Unblock-File`
in the unpacked folder.

**Antivirus flags the program.**
`lib\DesktopIcons.cs` is compiled in memory at startup and calls
`WriteProcessMemory` into `explorer.exe` — this is how icon positions are set
without an Explorer restart. Some heuristics dislike that combination. The whole
source is here; you can read exactly what is written (an `LVITEM`/`POINT`
structure, nothing else) and check it with PSScriptAnalyzer.

**Frames do not line up with the icons.**
The wallpaper is generated at the size of your current screen. If you changed
resolution or DPI after applying, press **Разложить значки и обновить обои**
again.

**Icons moved by themselves.**
"Auto arrange icons" is on. Turn it off: right-click the desktop →
**View** → uncheck **Auto arrange icons**.

## How it works

**Icon positions.** Windows 11 keeps desktop icon positions in
`HKCU\Software\Microsoft\Windows\Shell\Bags\1\Desktop\IconLayouts` — an undocumented
binary value; the old `ItemPos<W>x<H>` is gone. So DesktopGroups talks to the desktop
list view directly: `Progman` → `SHELLDLL_DefView` → `SysListView32`, then
`LVM_GETITEMTEXTW`, `LVM_GETITEMPOSITION`, `LVM_SETITEMPOSITION32` (buffers are
allocated inside `explorer.exe` with `VirtualAllocEx`). No Explorer restart needed.

**Grid.** Cell size is measured from the view itself (`LVM_GETITEMSPACING`), so DPI and
icon size changes are handled automatically.

**Layout.** Every group gets a `cols × rows` rectangle that minimizes empty cells,
blocks are packed into horizontal bands with one empty column between them, and two
top rows are kept free for the wallpaper labels.

**Wallpaper.** Drawn with `System.Drawing` from the same layout object the icons are
placed with, then applied via `SystemParametersInfo(SPI_SETDESKWALLPAPER)`. Because
both come from one plan, frames always match the grid.

## Files

| File | Purpose |
|---|---|
| `DesktopGroups.ps1` | GUI (WinForms) |
| `DesktopGroups.cmd` | launcher without a console window |
| `lib\Engine.ps1` | scanning, grouping, layout, wallpaper, apply |
| `lib\DesktopIcons.cs` | P/Invoke and desktop list-view lookup |
| `config.json` | your groups (created on first run) |
| `wallpaper.png` | generated wallpaper, referenced by the registry |
| `backups\` | icon positions before each apply |
| `tests\` | headless checks used during development |

## Limitations

- **Auto-arrange must stay off.** If "Auto arrange icons" is enabled, Windows will
  re-sort the icons; the app warns before applying.
- The wallpaper is referenced **by path** — do not delete or move `wallpaper.png`.
- Primary monitor only.
- Blocks that do not fit the screen are reported as overflow and packed anyway.
- No drag & drop on the desktop itself: groups are edited in the app.

## Development

Checks that never touch the desktop (these run in CI):

```powershell
powershell.exe -NoProfile -File .\tests\check-encoding.ps1   # BOM + parser under 5.1 and 7
powershell.exe -NoProfile -File .\tests\smoke.ps1            # grouping, layout, wallpaper
powershell.exe -NoProfile -File .\tests\fuzz-config.ps1      # junk values in config.json
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
```

Manual tests really move icons and change the wallpaper, so they stay off
unless you opt in:

```powershell
$env:DESKTOPGROUPS_MANUAL_TESTS = 1
powershell.exe -File .\tests\manual\apply-all.ps1
```

## License

MIT — see [LICENSE](LICENSE).

---

# DesktopGroups (по-русски)

Программа раскладывает ярлыки рабочего стола по прямоугольным группам, а **обои
рисуют рамки и подписи** этих групп.

![DesktopGroups: рамки групп на обоях](docs/preview.png)

## Зачем ещё одна программа

Существующие решения (Stardock Fences, DexCorral, Gridify, DeskRipple) рисуют группы
**поверх** рабочего стола отдельным окном: нужен резидентный процесс, перехват
Explorer, и без запущенной программы групп нет.

DesktopGroups делает наоборот: рамки групп **впечатаны в обои**. Нет фонового
процесса и оверлей-окна, рабочий стол остаётся обычным, а группы переживают
перезагрузку — это просто значки на сетке. Позиции значков задаются сообщениями
`LVM_*` самому списку значков: код в Explorer не внедряется, передаются только
структуры позиций, которые он и так понимает (подробности в `SECURITY.md`).

Плата честная: рамки статичны. Подвинули ярлык руками — рамка перестанет совпадать;
повторное применение раскладки перестроит и то и другое из одного плана.

## Возможности

- Сканирует ярлыки, папки и файлы рабочего стола (свой и общий `Public`).
- Предлагает группы по именам: игры, разработка/AI, мессенджеры, медиа, VPN и
  удалённый доступ, оборудование, установщики, система, остальное.
- Свои группы: создать, переименовать, удалить, менять порядок; переносить значки
  между группами.
- Раскладывает значки точными прямоугольниками — без пустых ячеек, где это возможно.
- Рисует обои 1920×1080: скруглённые рамки, цвет группы, подпись над рамкой.
- Хранит `config.json` рядом с программой и бэкап прежних позиций перед каждым
  применением.
- Проверяет результат: перечитывает позиции и сообщает, какие значки не встали.

## Требования

- Windows 10 или 11.
- Windows PowerShell 5.1 (встроен). Движок работает и в PowerShell 7, GUI
  запускается через `powershell.exe`.
- Без прав администратора, без внешних пакетов и сети.

## Установка

Компилировать ничего не нужно: программа — это PowerShell плюс один C#-файл,
который собирается в памяти при старте через `Add-Type`.

1. Скачайте `DesktopGroups-<версия>.zip` со страницы [Releases](../../releases)
   и распакуйте в любую папку.
2. Если Windows пометила файлы как скачанные — правый клик по ZIP →
   **Свойства** → **Разблокировать**, либо в распакованной папке выполните
   `Get-ChildItem -Recurse | Unblock-File`.
3. Запустите **`install.cmd`**. Он скопирует программу в
   `%LOCALAPPDATA%\Programs\DesktopGroups`, сделает ярлык в меню «Пуск» и запись
   в списке приложений. Права администратора не нужны.
4. Запускайте из меню «Пуск».

Нужен портативный вариант? Не запускайте `install.cmd`, а запустите
`DesktopGroups.cmd` прямо из распакованной папки — вне неё появятся только
ваши `config.json` и `wallpaper.png`.

Удаление — через «Приложения» в параметрах Windows или `uninstall.cmd`.

## Как пользоваться

Запустить `DesktopGroups.cmd` двойным щелчком. Либо:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\DesktopGroups.ps1
```

Порядок:

1. **Сканировать стол** — прочитать текущий рабочий стол.
2. **Предложить группы** — заполнить группы по именам, дальше править руками.
3. **Новая / Переименовать / Удалить / ↑ ↓** — собрать свой набор.
4. **Добавить значки…** — перенести ярлыки в выбранную группу.
5. **Разложить значки и обновить обои** — расставить значки и перерисовать обои.

## Как это устроено

**Позиции значков.** Windows 11 держит их в
`HKCU\Software\Microsoft\Windows\Shell\Bags\1\Desktop\IconLayouts` — двоичное значение
без документированного формата; старого `ItemPos<W>x<H>` нет. Поэтому программа
работает напрямую со списком значков: `Progman` → `SHELLDLL_DefView` →
`SysListView32`, затем `LVM_GETITEMTEXTW`, `LVM_GETITEMPOSITION`,
`LVM_SETITEMPOSITION32` (буферы выделяются внутри `explorer.exe` через
`VirtualAllocEx`). Перезапуск Explorer не нужен.

**Сетка.** Размер ячейки измеряется у самого вида (`LVM_GETITEMSPACING`), поэтому
смена DPI и размера значков учитывается сама.

**Раскладка.** Каждая группа получает прямоугольник `cols × rows` с минимумом пустых
ячеек; блоки пакуются в горизонтальные полосы с пустой колонкой между ними, два
верхних ряда оставлены под подписи обоев.

**Обои.** Рисуются `System.Drawing` из того же объекта раскладки, по которому
расставляются значки, и применяются через
`SystemParametersInfo(SPI_SETDESKWALLPAPER)`. Один план — рамки всегда по сетке.

## Файлы

| Файл | Назначение |
|---|---|
| `DesktopGroups.ps1` | окно программы (WinForms) |
| `DesktopGroups.cmd` | запуск без окна консоли |
| `lib\Engine.ps1` | скан, группы, раскладка, обои, применение |
| `lib\DesktopIcons.cs` | P/Invoke и поиск списка значков |
| `config.json` | ваши группы (создаётся при первом запуске) |
| `wallpaper.png` | сгенерированные обои, на них ссылается реестр |
| `backups\` | позиции значков перед каждым применением |
| `tests\` | headless-проверки, которыми пользовались при разработке |

## Ограничения

- **Автоупорядочивание должно быть выключено.** Если включить «Упорядочить
  автоматически», Windows переставит значки; программа предупредит перед применением.
- Обои ссылаются на файл **по пути** — не удаляйте и не переносите `wallpaper.png`.
- Только основной монитор.
- Блоки, не влезающие на экран, помечаются как переполнение, но всё равно пакуются.
- Перетаскивания мышью по рабочему столу нет: группы правятся в окне программы.

## Разработка

Проверки, которые не трогают рабочий стол (их и запускает CI):

```powershell
powershell.exe -NoProfile -File .\tests\check-encoding.ps1   # BOM и разбор под 5.1 и 7
powershell.exe -NoProfile -File .\tests\smoke.ps1            # группы, раскладка, обои
powershell.exe -NoProfile -File .\tests\fuzz-config.ps1      # мусор в config.json
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
```

Ручные тесты действительно двигают значки и меняют обои, поэтому по умолчанию
выключены:

```powershell
$env:DESKTOPGROUPS_MANUAL_TESTS = 1
powershell.exe -File .\tests\manual\apply-all.ps1
```

## Лицензия

MIT — см. [LICENSE](LICENSE).
