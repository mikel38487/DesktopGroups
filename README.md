# DesktopGroups

Group desktop shortcuts into rectangles — and let the wallpaper draw the frames
and labels for those groups.

## Why another desktop organizer

Existing tools (Stardock Fences, DexCorral, Gridify, DeskRipple) draw their groups
as an **overlay window** on top of the desktop. That means a resident process,
hooks into Explorer, and a group that disappears when the tool is not running.

DesktopGroups does the opposite: it **bakes the group frames into the wallpaper**.
There is no background process, nothing is injected into Explorer, the desktop stays
a normal desktop, and the groups survive reboots because they are just icons on a grid.

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

## Usage

Run `DesktopGroups.cmd` (double click). Or:

```powershell
powershell.exe -STA -File .\DesktopGroups.ps1
```

Typical flow:

1. **Сканировать стол** — read the current desktop.
2. **Предложить группы** — fill groups from names, then adjust by hand.
3. **Новая / Переименовать / Удалить / ↑ ↓** — build your own set.
4. **Добавить значки…** — move shortcuts into the selected group.
5. **Разложить значки и обновить обои** — place icons and redraw the wallpaper.

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

## License

MIT — see [LICENSE](LICENSE).

---

# DesktopGroups (по-русски)

Программа раскладывает ярлыки рабочего стола по прямоугольным группам, а **обои
рисуют рамки и подписи** этих групп.

## Зачем ещё одна программа

Существующие решения (Stardock Fences, DexCorral, Gridify, DeskRipple) рисуют группы
**поверх** рабочего стола отдельным окном: нужен резидентный процесс, перехват
Explorer, и без запущенной программы групп нет.

DesktopGroups делает наоборот: рамки групп **впечатаны в обои**. Нет фонового
процесса, ничего не внедряется в Explorer, рабочий стол остаётся обычным, а группы
переживают перезагрузку — это просто значки на сетке.

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

## Как пользоваться

Запустить `DesktopGroups.cmd` двойным щелчком. Либо:

```powershell
powershell.exe -STA -File .\DesktopGroups.ps1
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

## Лицензия

MIT — см. [LICENSE](LICENSE).
