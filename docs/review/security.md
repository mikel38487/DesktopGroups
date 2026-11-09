# Отчёт по безопасности: DesktopGroups

| | |
|---|---|
| Дата ревью | 2026-11-09 |
| Ветка | `main`, HEAD `64125fe` |
| Ревизия кода | рабочее дерево, снимок 19:41 MSK (см. ниже) |
| Ревьюер | независимый агент (не автор кода) |
| Объём | `DesktopGroups.ps1`, `lib\Engine.ps1`, `lib\DesktopIcons.cs`, `*.cmd`, `tools\*`, `.github\workflows\*`, `tests\*` |

## Как читать отчёт

Репозиторий правился **во время ревью** (в 19:39–19:43 менялись `lib\Engine.ps1` и `README.md`,
появились `tools\`, `install.cmd`, `SECURITY.md`, `.github\`). Чтобы выводы не расплывались,
все находки привязаны к снимку рабочего дерева, снятому в 19:41 MSK:

| Файл | SHA-256 (12) | Байт |
|---|---|---|
| `DesktopGroups.ps1` | `559F0DC30CA6` | 25288 |
| `lib\Engine.ps1` | `179C1207F5B7` | 21408 |
| `lib\DesktopIcons.cs` | `3C9630AF8B89` | 4088 |
| `tools\install.ps1` | `B83218CC0858` | 3511 |
| `tools\uninstall.ps1` | `9898505F853E` | 1642 |
| `DesktopGroups.cmd` | `7DE9F7A24FFD` | 191 |
| `install.cmd` / `uninstall.cmd` | `22490DEC51B2` / `73CE033CEC6D` | 505 / 381 |
| `.github\workflows\ci.yml` | `767C42F49FE5` | 2521 |
| `.github\workflows\release.yml` | `70A0C309553C` | 1288 |

Номера строк — по этим версиям. Если файл уже изменился, сверяйтесь по цитате, а не по номеру.

**Ограничения ревью.** Раскладка к живому рабочему столу не применялась: `Invoke-DesktopLayout`
и кнопка «Разложить значки и обновить обои» не вызывались, обои в реестр не записывались.
Разрешённые операции выполнялись: `Read-ViewItems`, `New-Layout`, `New-ProposedGroups`,
`Save-Wallpaper` во временный каталог, разбор `config.json`, чтение реестра. Всё, что касается
`LVM_SETITEMPOSITION32`, проверено чтением кода и чтением позиций, но не записью.

**Метод.** Не «на глаз»: функции `Load-Config`/`Save-Config` брались из файла через AST
(`Parser::ParseFile` → `FunctionDefinitionAst.Extent.Text` → `[scriptblock]::Create`) и исполнялись
в Windows PowerShell 5.1 — то есть проверялся фактический текст программы, а не его пересказ.

## Статус на момент сдачи (19:48 MSK)

Репозиторий продолжал меняться после снятия снимка. Что важно знать, прежде чем читать находки:

1. **Рабочая копия сейчас не запускается под Windows PowerShell 5.1.** `DesktopGroups.ps1`
   и `lib\Engine.ps1` на 19:47 записаны **без BOM** (30221 и 22062 байта, BOM=False), поэтому
   5.1 читает их как cp1251 и отказывается разбирать:

   ```
   At F:\AI\DesktopGroups\lib\Engine.ps1:19 char:22
   + ...  @{ name = 'РЈСЃС‚Р°РЅРѕРІС‰РёРєРё'; color = '#B7B26A'; words = @() }
   Unexpected token ...
   ```

   `tests\smoke.ps1` (он запускается через `powershell.exe`) падает на этом же месте.
   Это не отдельная уязвимость, а текущее состояние рабочего дерева; лечится возвратом BOM
   (см. SEC-09). Но если сдавать в таком виде — программа не стартует у всех, у кого ANSI-
   кодовая страница не UTF-8.

2. **Часть находок уже правится** (мной не ревьюилось, снимок их не содержит):
   - SEC-03: `Load-Config` переименован в `Import-Config`, повреждённый файл откладывается
     в `config.bad-<дата>.json`, пользователю показывается сообщение (строки 36–56, 654–660).
     Осталось: `Save-Config` по-прежнему пишет неатомарно и не валидирует значения.
   - SEC-08: добавлена ротация бэкапов (не больше 20, `lib\Engine.ps1:494-499`) и кнопка
     «Вернуть прошлую раскладку».
   - Ни SEC-01, ни SEC-02, ни SEC-04, ни SEC-05, ни SEC-06, ни SEC-10 на 19:48 не исправлены —
   проверено поиском по коду (`Is64BitProcess` — нет, полного пути в `.cmd` — нет, склейки
   команды в `uninstall.ps1` — есть, валидации цвета — нет).

3. Номера строк ниже — по снимку из таблицы. В живом дереве они уже сдвинулись: цитируйте
   код, а не номер.

---

## Сводка

| ID | Severity | Где | Суть |
|---|---|---|---|
| SEC-01 | major | `tools\uninstall.ps1:28-29` | Команда PowerShell собирается конкатенацией из пути установки → инъекция кода |
| SEC-02 | major | `lib\DesktopIcons.cs:51-68`, `lib\Engine.ps1:356-368` | Нет проверки разрядности: 32-битный хост пишет в 64-битный explorer структуру другого размера |
| SEC-03 | major | `DesktopGroups.ps1:33-53, 592-596` | Ошибка разбора `config.json` молча уничтожает конфиг пользователя |
| SEC-04 | major | `DesktopGroups.ps1:39-45, 318`; `lib\Engine.ps1:262-271` | Нет валидации значений из `config.json` → исключение в отрисовке, применить раскладку нельзя |
| SEC-05 | minor | `DesktopGroups.cmd:3`, `install.cmd:6`, `uninstall.cmd:5` | `powershell.exe` без полного пути — подхват из текущего каталога (воспроизведено) |
| SEC-06 | minor | `lib\Engine.ps1:345-352`; `tools\uninstall.ps1` | Прежние `Wallpaper`/`WallpaperStyle`/`TileWallpaper` не сохраняются и не восстанавливаются |
| SEC-07 | minor | `lib\Engine.ps1:365-366` | Утечка хендла процесса, если `VirtualAllocEx` не удался |
| SEC-08 | minor | `lib\Engine.ps1:479-492` | Бэкап позиций: коллизии по имени, нет ротации, нет восстановления, накапливает инвентарь стола |
| SEC-09 | minor | `.github\workflows\ci.yml` | GUI-файл в CI только парсится под pwsh; потеря BOM не ловится |
| SEC-10 | minor | `tools\uninstall.ps1:7, 28` | Рекурсивное удаление `$dest` без проверки, что это каталог программы |
| SEC-11 | nit | `.github\workflows\release.yml:34-40` | `${{ inputs.tag }}` подставляется в тело скрипта |
| SEC-12 | nit | `ci.yml`, `release.yml` | Зависимости CI не закреплены (`@v4`, `Install-Module` без версии, PSGallery → Trusted) |
| SEC-13 | nit | `DesktopGroups.ps1:4, 15` | `-ConfigPath` не валидируется: запись JSON по любому пути |
| SEC-14 | nit | `README.md`, `SECURITY.md` | «Ничего не внедряется в Explorer» — неточно, есть `OpenProcess`+`VirtualAllocEx`+`WriteProcessMemory` |

---

## SEC-01 — Инъекция кода через путь установки в деинсталляторе

**Severity:** major
**Файл:** `tools\uninstall.ps1:28-29`

```powershell
$dest = Split-Path -Parent $PSScriptRoot
$cleanup = 'Start-Sleep -Seconds 2; Remove-Item -LiteralPath ''' + $dest + ''' -Recurse -Force -ErrorAction SilentlyContinue'
Start-Process -FilePath $psExe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-Command', $cleanup) | Out-Null
```

**Суть.** Путь каталога программы склеивается в **текст команды PowerShell**, которая затем
исполняется в отдельном скрытом процессе. Путь берётся из `$PSScriptRoot`, то есть из места,
куда пользователь распаковал или установил программу. Апостроф в пути закрывает строковый
литерал и превращает остаток пути в код.

**Воспроизведение.** Строка команды собрана ровно как в файле и разобрана парсером
(исполнение не требовалось):

```powershell
$cleanup = 'Start-Sleep -Seconds 2; Remove-Item -LiteralPath ''' + $dest + ''' -Recurse -Force -ErrorAction SilentlyContinue'
[System.Management.Automation.Language.Parser]::ParseInput($cleanup, [ref]$null, [ref]$err).EndBlock.Statements
```

| `$dest` | Что получилось |
|---|---|
| `C:\Users\User\AppData\Local\Programs\DesktopGroups` | 2 оператора, всё нормально |
| `C:\Tools\it's here\DesktopGroups` | ошибка разбора: «В строке отсутствует завершающий символ: '» → удаление молча не выполнится |
| `C:\Tools\x'; New-Item -Path C:\Windows\Temp\dg-pwned.txt -ItemType File; '` | **5 операторов**: `Start-Sleep`, `Remove-Item`, `New-Item -Path C:\Windows\Temp\dg-pwned.txt`, … |

**Последствие.** Любой, кто может повлиять на путь установки (имя профиля с апострофом,
распаковка в каталог с апострофом, каталог, созданный другой программой), получает выполнение
произвольного PowerShell-кода в контексте пользователя **без единого видимого окна**
(`-WindowStyle Hidden`). В обычном случае с апострофом в пути — просто не удаляется каталог,
и пользователь об этом не узнает.

**Исправление.** Не подставлять значение в текст команды. Передать его переменной окружения
(она наследуется дочерним процессом и не парсится как код):

```powershell
$dest = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $dest 'DesktopGroups.ps1'))) {
    throw "Каталог $dest не похож на установку DesktopGroups — удаление отменено."
}
$env:DESKTOPGROUPS_UNINSTALL_DIR = $dest
Start-Process -FilePath $psExe -WindowStyle Hidden -ArgumentList @(
    '-NoProfile',
    '-Command',
    'Start-Sleep -Seconds 2; Remove-Item -LiteralPath $env:DESKTOPGROUPS_UNINSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue'
) | Out-Null
```

Альтернатива — `-EncodedCommand` с `$args[0]`, но вариант с переменной окружения короче
и не требует кодирования.

---

## SEC-02 — 32-битный хост портит память 64-битного explorer

**Severity:** major (предусловие: запуск под 32-битным PowerShell; через штатные `.cmd` не достигается)
**Файл:** `lib\DesktopIcons.cs:50-68`, `lib\Engine.ps1:356-368`, `415-449`

**Суть.** `LVITEM` описан как обычная структура, её размер и смещения зависят от разрядности
**хост-процесса**. `Add-Type` компилирует C# в процессе PowerShell, значит под 32-битным
PowerShell структура будет 32-битной, а `explorer.exe` на 64-битной Windows ждёт 64-битную.
Программа пишет 60-байтную структуру туда, где explorer читает 88-байтную.

**Воспроизведение** (замер, без записи в explorer):

```
64-бит: LVITEM size = 88, pszText@24, cchTextMax@32, lParam@40
32-бит: LVITEM size = 60, pszText@20, cchTextMax@24, lParam@32
```

**Последствие.** В 32-битной раскладке на месте `pszText` (смещение 24) лежат `cchTextMax`
(260 = `0x104`) и `iImage` (0). 64-битный explorer прочитает указатель `0x0000000000000104`
и попытается записать по нему текст элемента → нарушение доступа в `explorer.exe`, то есть
падение и перезапуск рабочего стола. Это не «теоретически неверный тип»: адрес получается
детерминированно ненулевой и невалидный.

**Почему не blocker.** Штатный `DesktopGroups.cmd` вызывает `powershell.exe` из PATH, а это
`System32` → 64-бит. Но README обещает работу и под PowerShell 7 (у которого есть x86-сборка),
а `%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe` — обычный способ запуска
«как в старые времена». Проверки нет ни одной.

**Исправление.** Явный отказ на несовместимой разрядности — до первого `OpenProcess`:

```powershell
# lib/Engine.ps1, в начале файла (после Add-Type)
if (-not [Environment]::Is64BitProcess -and [Environment]::Is64BitOperatingSystem) {
    throw 'DesktopGroups требует 64-битный PowerShell: под 32-битным хостом структура LVITEM не совпадает с explorer.exe.'
}
```

И в `.cmd` — полный путь к 64-битному хосту (см. SEC-05):

```bat
start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0DesktopGroups.ps1"
```

---

## SEC-03 — Ошибка в `config.json` молча уничтожает конфиг

**Severity:** major
**Файл:** `DesktopGroups.ps1:33-53` (`Load-Config`), `592-596` (ветка старта), `24-31` (`Save-Config`)

**Суть.** `Load-Config` при любой ошибке разбора возвращает `$false`, а старт в этом случае
не сообщает пользователю ничего: предлагает группы заново и **тут же перезаписывает файл**.
Резервной копии конфига нет. Запись при этом неатомарная (`[IO.File]::WriteAllText` поверх
файла), поэтому обрыв питания в момент сохранения даёт тот же сценарий.

**Воспроизведение** (функции взяты из файла через AST, исполнены в PowerShell 5.1):

```powershell
# обрезанный JSON — как после ручной правки с опечаткой
[IO.File]::WriteAllText($p, '{"groups":[{"name":"Моя группа","color":"#111111","items":["Steam"]', [Text.UTF8Encoding]::new($true))
Load-Config                      # => False
# дальше — ровно ветка Add_Shown:
$script:Groups.Clear(); $proposed = New-ProposedGroups (Get-DesktopItems); ...; Save-Config
```

Результат:

```
Load-Config => False ; размер файла до: 67
размер файла после старта: 4526
содержимое до : {"groups":[{"name":"Моя группа","color":"#111111","items":["Steam"]
восстановить прежние группы из файла можно? False
```

Дополнительно проверены «валидные, но бессмысленные» конфиги — они дают `Load-Config => True`
с нулём групп, и конфиг так же затирается при закрытии окна (`Add_FormClosing` → `Save-Config`):

| Конфиг | `Load-Config` | Групп |
|---|---|---|
| `[1,2,3]` (корень — массив) | True | 0 |
| `{"groups":null}` | True | 0 |
| `{"groups":"abc"}` | True | 1 (пустое имя, пустой цвет) |
| обрезанный JSON | False | — |
| JSON с комментарием `//` | False | — |

**Последствие.** Потеря пользовательской работы без предупреждения и без возможности отката.
Для программы, которая хранит единственный файл настроек рядом с собой и предлагает править
его руками, это основной риск, а не косметика.

**Исправление.** 1) Не перезаписывать то, что не прочиталось; 2) сохранить копию и сказать
пользователю; 3) считать «структурно неверный» конфиг ошибкой, а не пустым; 4) писать атомарно.

```powershell
function Load-Config {
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) { return $false }
    try {
        $raw = [IO.File]::ReadAllText($script:ConfigPath, [Text.UTF8Encoding]::new($true))
        $data = $raw | ConvertFrom-Json
        if ($null -eq $data -or $null -eq $data.groups) { throw 'в конфиге нет поля groups' }
        if ($data.groups -isnot [System.Array] -and $data.groups -isnot [pscustomobject]) { throw 'groups — не список' }
        ...
    }
    catch {
        $broken = Join-Path $script:AppDir ('config.broken-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        try { Copy-Item -LiteralPath $script:ConfigPath -Destination $broken -Force } catch { }
        [System.Windows.Forms.MessageBox]::Show(
            ("config.json не читается: {0}`r`nФайл сохранён как {1}. Группы предложены заново." -f $_.Exception.Message, $broken),
            'Конфиг', 'OK', 'Warning') | Out-Null
        return $false
    }
}
```

Атомарная запись:

```powershell
function Save-Config {
    ...
    $tmp = $script:ConfigPath + '.tmp'
    [IO.File]::WriteAllText($tmp, $json, [Text.UTF8Encoding]::new($true))
    if (Test-Path -LiteralPath $script:ConfigPath) {
        [IO.File]::Replace($tmp, $script:ConfigPath, $null)   # атомарно в пределах тома
    } else {
        Move-Item -LiteralPath $tmp -Destination $script:ConfigPath
    }
}
```

---

## SEC-04 — Нет валидации значений из `config.json`: исключение в отрисовке

**Severity:** major
**Файл:** `DesktopGroups.ps1:39-45` (загрузка), `308-332` (`Paint`), `318`; `lib\Engine.ps1:262-271` (`Convert-HexColor`), `285-343` (`Save-Wallpaper`)

**Суть.** Из конфига берутся `name`, `color`, `items` как есть, без проверки типа и формата.
`Convert-HexColor` слепо режет строку: `Substring(0,2)`, `Substring(2,2)`, `Substring(4,2)`
и `[Convert]::ToInt32(...,16)`. Любое отклонение — исключение.

**Воспроизведение** (PowerShell 5.1, значения взяты из конфига и переданы в реальные функции):

```
OK   color=[#B7B26A]     -> FFB7B26A
FAIL color=[#ZZZZZZ]     -> ToInt32: "Could not find any recognizable digits."
FAIL color=[12345]       -> Substring: "Index and length must refer to a location within the string."
FAIL color=[]            -> Substring: то же
FAIL color=[red]         -> ToInt32: то же
FAIL color=[System.Collections.Hashtable] -> ToInt32: то же
```

Те же значения, прогнанные через `New-Layout` + `Save-Wallpaper` (как в кнопке «Разложить»):

```
FAIL Save-Wallpaper color=#ZZZZZZ -> MethodInvocationException: ToInt32 ...
FAIL Save-Wallpaper color=$null   -> MethodInvocationException: Substring ...
FAIL Save-Wallpaper color=12345   -> MethodInvocationException: Substring ...
```

При этом `Load-Config` на всех этих конфигах возвращает `True` — то есть мусор доходит
до отрисовки.

**Последствие.** Два разных исхода:

- кнопка «Разложить значки и обновить обои»: исключение ловится в `catch` (`DesktopGroups.ps1:556`),
  пользователь видит диалог ошибки, обои не создаются, раскладка не применяется;
- предпросмотр (`$preview.Add_Paint`, строка 308): `Convert-HexColor` вызывается прямо в
  обработчике события, `try/catch` там нет. Исключение выходит из обработчика в механизм
  WinForms (`Application.ThreadException`, в приложении свой обработчик не установлен) —
  предпросмотр перестаёт рисоваться, а пользователь получает ошибку .NET при каждой
  перерисовке панели.

Починка руками требует редактирования JSON — то есть ровно того действия, которое привело
к поломке.

**Исправление.** Валидировать при загрузке, а не при отрисовке; `Convert-HexColor` сделать
неубиваемым.

```powershell
# lib/Engine.ps1
function Convert-HexColor {
    param([string]$Hex)
    if ($Hex -notmatch '^#?[0-9A-Fa-f]{6}$') {
        return [System.Drawing.Color]::FromArgb(255, 140, 140, 140)   # серый вместо исключения
    }
    $h = $Hex.TrimStart('#')
    return [System.Drawing.Color]::FromArgb(255,
        [Convert]::ToInt32($h.Substring(0, 2), 16),
        [Convert]::ToInt32($h.Substring(2, 2), 16),
        [Convert]::ToInt32($h.Substring(4, 2), 16))
}
```

```powershell
# DesktopGroups.ps1, в Load-Config
foreach ($g in @($data.groups)) {
    $name = [string]$g.name
    if ($name.Length -gt 200) { $name = $name.Substring(0, 200) }        # предел для подписи
    $color = [string]$g.color
    if ($color -notmatch '^#[0-9A-Fa-f]{6}$') { $color = Get-NextColor $script:Groups }
    $items = @(@($g.items) | ForEach-Object { [string]$_ } | Where-Object { $_ })
    [void]$script:Groups.Add([pscustomobject]@{ name = $name; color = $color; items = $items })
}
```

---

## SEC-05 — `powershell.exe` без полного пути: подхват из текущего каталога

**Severity:** minor
**Файл:** `DesktopGroups.cmd:3`, `install.cmd:6`, `uninstall.cmd:5`

```bat
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0DesktopGroups.ps1"
```

**Суть.** `powershell.exe` без пути разрешается по порядку поиска `CreateProcess`, в котором
**текущий каталог идёт раньше PATH**. При двойном клике по `.cmd` текущим каталогом становится
папка с программой.

**Воспроизведение.** Собран безобидный `powershell.exe` (только пишет файл-маркер), положен
в каталог рядом с копией строки запуска:

```
подложен powershell.exe: True (3584 байт)
маркер до: False
маркер после: True
СОДЕРЖИМОЕ: hijacked
```

То есть запустился подложенный файл, а не `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`.

**Последствие.** Портретный (portable) запуск из распакованного архива исполняет `powershell.exe`
из папки программы. Само по себе это **не даёт повышения прав**: кто может положить файл
в папку программы, тот может заменить и `DesktopGroups.ps1`, который всё равно исполняется.
Реальный вес — два сценария: (1) папка лежит на сетевом ресурсе или в синхронизируемом
каталоге, куда пишет кто-то ещё; (2) эвристики AV/EDR справедливо считают запуск
`powershell.exe` из пользовательского каталога подозрительным. Правка стоит одной строки.

Заодно: `-ExecutionPolicy Bypass` во всех трёх `.cmd`, в ярлыке (`tools\install.ps1:45`)
и в `UninstallString` (`tools\install.ps1:73`). Для неподписанного скрипта это единственный
способ гарантировать запуск, но пока подписи нет — это ещё и способ обойти политику
для любого подменённого `.ps1` в том же каталоге.

**Исправление.**

```bat
rem DesktopGroups.cmd
start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0DesktopGroups.ps1"
```

То же для `install.cmd` и `uninstall.cmd`. `-ExecutionPolicy Bypass` убрать после подписи
кода (`Set-AuthenticodeSignature`), до тех пор — оставить и упомянуть в README явно.

---

## SEC-06 — Обои: прежние настройки не сохраняются и не восстанавливаются

**Severity:** minor
**Файл:** `lib\Engine.ps1:345-352`; `tools\uninstall.ps1` (не трогает эти значения)

```powershell
$key = 'HKCU:\Control Panel\Desktop'
Set-ItemProperty -Path $key -Name Wallpaper -Value $Path
Set-ItemProperty -Path $key -Name WallpaperStyle -Value '10'
Set-ItemProperty -Path $key -Name TileWallpaper -Value '0'
```

**Суть.** Три значения перезаписываются безусловно, прежние нигде не сохраняются.
Деинсталлятор удаляет программу и ярлыки, но не эти значения.

**Воспроизведение** (чтение реестра на машине после работы программы):

```
Wallpaper      = F:\AI\DesktopGroups\wallpaper.png
WallpaperStyle = 10
TileWallpaper  = 0
файл существует: True
Uninstall-ключ: False
```

**Последствие.** Обои пользователя и режим «Заполнить» заменены безвозвратно (прежний путь
нигде не записан). После удаления программы или переноса папки `Wallpaper` указывает на
несуществующий файл — рабочий стол остаётся чёрным до ручной смены обоев. Следы в реестре
после «удаления» остаются.

**Исправление.** Запомнить прежние значения при первом применении и вернуть их при удалении:

```powershell
# lib/Engine.ps1 — перед первой записью
$script:WallpaperBackup = @{
    Wallpaper      = (Get-ItemProperty -Path $key -Name Wallpaper      -ErrorAction SilentlyContinue).Wallpaper
    WallpaperStyle = (Get-ItemProperty -Path $key -Name WallpaperStyle -ErrorAction SilentlyContinue).WallpaperStyle
    TileWallpaper  = (Get-ItemProperty -Path $key -Name TileWallpaper  -ErrorAction SilentlyContinue).TileWallpaper
}
# сохранить в config.json (поле wallpaperBackup) — переживёт перезапуск

# tools/uninstall.ps1 — перед удалением каталога
$cfg = Join-Path $dest 'config.json'
if (Test-Path -LiteralPath $cfg) {
    $b = (Get-Content -LiteralPath $cfg -Raw | ConvertFrom-Json).wallpaperBackup
    if ($b -and $b.Wallpaper) {
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper      -Value $b.Wallpaper
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value $b.WallpaperStyle
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper  -Value $b.TileWallpaper
    }
}
```

---

## SEC-07 — Утечка хендла процесса при сбое `VirtualAllocEx`

**Severity:** minor (по коду; сбой выделения памяти воспроизвести не удалось)
**Файл:** `lib\Engine.ps1:365-366`

```powershell
$proc = [DesktopIconsNative]::OpenProcess(0x438, $false, $procId)
if ($proc -eq [IntPtr]::Zero) { throw 'Не удалось открыть процесс explorer.exe' }

$remote = [DesktopIconsNative]::VirtualAllocEx(...)
if ($remote -eq [IntPtr]::Zero) { throw 'Не удалось выделить память в explorer.exe' }
```

**Суть.** Между `OpenProcess` и `VirtualAllocEx` нет `try/finally`. Если выделение памяти
не удалось, хендл процесса уже открыт и не закрывается — исключение уходит наверх, а
`Close-DesktopView` вызывать не на чем (функция не вернула объект).

**Воспроизведение.** Сбой `VirtualAllocEx` вызвать не удалось (нужны исчерпание адресного
пространства или отзыв прав), поэтому находка — из чтения кода, а не из запуска. Обратный
случай проверен: при закрытом хендле `WriteProcessMemory` возвращает `false` и программа
бросает исключение, а `finally` в `Invoke-DesktopLayout` хендл закрывает.

**Последствие.** Один потерянный хендл на неудачную попытку. Практически безвредно, но
в цикле (повторные нажатия при нехватке памяти) хендлы копятся.

**Исправление.**

```powershell
$proc = [DesktopIconsNative]::OpenProcess(0x438, $false, $procId)
if ($proc -eq [IntPtr]::Zero) { throw 'Не удалось открыть процесс explorer.exe' }
try {
    $remote = [DesktopIconsNative]::VirtualAllocEx($proc, [IntPtr]::Zero, [UIntPtr]::new(4096), 0x3000, 0x04)
    if ($remote -eq [IntPtr]::Zero) { throw 'Не удалось выделить память в explorer.exe' }
}
catch {
    [void][DesktopIconsNative]::CloseHandle($proc)
    throw
}
```

---

## SEC-08 — Бэкап позиций: коллизии, рост без предела, нет восстановления

**Severity:** minor
**Файл:** `lib\Engine.ps1:479-492`

```powershell
$file = Join-Path $BackupDir ('before-apply-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$obj = @{}
foreach ($it in $before) { $obj[$it.name] = @{ x = $it.x; y = $it.y } }
```

**Суть.** Три отдельные проблемы:

1. **Ключ — имя значка.** Одноимённые объекты (ярлык `X.lnk` и папка `X`) схлопываются
   в одну запись: бэкап неполный, восстановить вторую позицию нечем. Та же коллизия
   в плане раскладки (`New-Layout`, `$plan[$g.items[$i]]`) — два значка получают одну цель.
2. **Нет ротации.** Файлы не удаляются никогда. При каждом применении — новый файл.
3. **Нет восстановления.** Программа бэкап пишет, но применить его не умеет; в README
   об этом не сказано. Пользователь считает, что «бэкап есть», а откатить нечем.

**Воспроизведение.** Каталог `backups\` в рабочем дереве: три файла по ~6 КБ, накопление
за один вечер. Кода, который их удаляет или читает, в проекте нет (`Select-String` по
`backups` даёт только `Join-Path` и `New-Item`).

**Последствие.** Приватность: в бэкап попадают имена **всех** объектов рабочего стола,
включая те, что не входят ни в одну группу (`tdata`, личные документы). Каталог растёт
без предела. Коллизия имён делает восстановление неполным.

**Исправление.**

```powershell
# ключ — индекс + имя, чтобы не терять одноимённые
foreach ($it in $before) { $obj["$($it.index)|$($it.name)"] = @{ x = $it.x; y = $it.y; name = $it.name } }

# ротация: держим 10 последних
Get-ChildItem -LiteralPath $BackupDir -Filter 'before-apply-*.json' |
    Sort-Object LastWriteTime -Descending | Select-Object -Skip 10 |
    Remove-Item -Force
```

Плюс либо добавить `Restore-DesktopLayout`, либо честно написать в README, что файл —
для ручного разбора.

---

## SEC-09 — CI проверяет GUI-файл только под PowerShell 7

**Severity:** minor
**Файл:** `.github\workflows\ci.yml:14-30`; `.gitattributes`

**Суть.** Продукт запускается `powershell.exe` (5.1), который читает `.ps1` без BOM как
ANSI (на русской Windows — cp1251). CI же проверяет синтаксис через `shell: pwsh` (7.x),
который читает UTF-8 без BOM нормально. `tests\smoke.ps1` действительно запускается через
`powershell.exe` и косвенно поймает потерю BOM в `lib\Engine.ps1`, но `DesktopGroups.ps1`
(GUI) в CI **не исполняется вообще** — только парсится под pwsh.

**Воспроизведение.** Это не гипотеза: во время ревью `lib\Engine.ps1` на минуту оказался
без BOM (правка в 19:42:25, 21646 байт, BOM=False), и PowerShell 5.1 отказался его разбирать:

```
At F:\AI\DesktopGroups\lib\Engine.ps1:19 char:22
+ ...  @{ name = 'РЈСЃС‚Р°РЅРѕРІС‰РёРєРё'; color = '#B7B26A'; words = @() }
Unexpected token ...
```

Через минуту BOM вернулся (19:43:13, BOM=True) и `tests\smoke.ps1` снова прошёл 21/21.
К 19:47 BOM потерян снова, и уже в обоих файлах — то есть риск не гипотетический,
а воспроизводится в этом же дереве несколько раз за час.

**Последствие.** Коммит без BOM проходит статический анализ и уезжает в релиз; у пользователя
с cp1251-локалью программа не стартует (или стартует с искажёнными подписями групп).

**Исправление.** Добавить в CI явную проверку кодировки и разбор под 5.1:

```yaml
      - name: Кодировка .ps1/.cs — UTF-8 с BOM (требование Windows PowerShell 5.1)
        shell: pwsh
        run: |
          $bad = Get-ChildItem -Recurse -Include *.ps1,*.cs | Where-Object {
            $b = [IO.File]::ReadAllBytes($_.FullName)
            -not ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
          }
          if ($bad) { throw "Без BOM: $($bad.FullName -join ', ')" }

      - name: Синтаксис под Windows PowerShell 5.1
        shell: cmd
        run: powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$e=$null; foreach ($f in Get-ChildItem -Recurse -Include *.ps1) { [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$null,[ref]$e) }; if ($e) { $e; exit 1 }"
```

---

## SEC-10 — Деинсталлятор удаляет каталог рекурсивно без проверки, что это каталог программы

**Severity:** minor
**Файл:** `tools\uninstall.ps1:7, 28`

**Суть.** `$dest = Split-Path -Parent $PSScriptRoot`, дальше `Remove-Item -LiteralPath $dest
-Recurse -Force`. Ни проверки, что в каталоге лежит программа, ни подтверждения, ни `-WhatIf`.
Если скрипт оказался в `C:\tools\uninstall.ps1`, то `$dest` = `C:\`, и команда пытается
удалить корень диска.

**Воспроизведение.** Не запускалось (деструктивно). Логика проверена вычислением:
`Split-Path -Parent 'C:\tools'` → `C:\`.

**Последствие.** Вероятность мала (нужно распаковать только `tools\` в корень диска), но
цена ошибки несоизмерима: рекурсивное удаление без единой проверки. Плюс нет подтверждения —
`uninstall.cmd` удаляет сразу, только с `pause` в конце.

**Исправление.** Проверка «это похоже на установку» + подтверждение (см. код в SEC-01).
Дополнительно — не удалять каталог, если в нём есть файлы, которых программа не создавала
(`config.json` пользователя стоит сохранить или спросить).

---

## SEC-11 — `${{ inputs.tag }}` подставляется в тело скрипта релиза

**Severity:** nit
**Файл:** `.github\workflows\release.yml:34-40`

```yaml
run: |
  $tag = if ($env:GITHUB_REF_TYPE -eq 'tag') { $env:GITHUB_REF_NAME } else { '${{ inputs.tag }}' }
```

**Суть.** GitHub подставляет значение входа в текст скрипта до исполнения. Значение вида
`'; <команда>; '` даст инъекцию. Плюс `gh release create $tag ...` — `$tag`, начинающийся
с `--`, будет прочитан как опция `gh`.

**Воспроизведение.** Не запускалось: нужен `workflow_dispatch` с правом записи в репозиторий.
Риск ограничен кругом мейнтейнеров, поэтому nit, а не выше.

**Последствие.** Выполнение команд в контексте раннера с `GITHUB_TOKEN` (`contents: write`).

**Исправление.**

```yaml
      - name: Публикация релиза
        shell: pwsh
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          INPUT_TAG: ${{ inputs.tag }}
        run: |
          $tag = if ($env:GITHUB_REF_TYPE -eq 'tag') { $env:GITHUB_REF_NAME } else { $env:INPUT_TAG }
          if ($tag -notmatch '^v\d+\.\d+\.\d+$') { throw "некорректный тег: $tag" }
          gh release create -- "$tag" $zip.FullName --title "$tag" --generate-notes
```

---

## SEC-12 — Зависимости CI не закреплены

**Severity:** nit
**Файл:** `ci.yml:12, 32-36`; `release.yml:21`

- `actions/checkout@v4`, `actions/upload-artifact@v4` — теги, а не SHA: тег можно перевесить.
- `Set-PSRepository -Name PSGallery -InstallationPolicy Trusted` + `Install-Module PSScriptAnalyzer`
  без версии: в CI ставится и исполняется произвольная свежая версия модуля.

**Воспроизведение.** Не воспроизводится на этом репозитории (нужен компромисс PSGallery или
перевешенный тег). Это гигиена цепочки поставок, не дефект кода.

**Исправление.** `uses: actions/checkout@<40-символьный SHA> # v4.x.y`,
`Install-Module PSScriptAnalyzer -RequiredVersion 1.22.0 -Scope CurrentUser -Force`,
`Set-PSRepository` без `Trusted` (или `-InstallationPolicy Trusted` только на время шага).

---

## SEC-13 — `-ConfigPath` не валидируется

**Severity:** nit
**Файл:** `DesktopGroups.ps1:4, 15, 30`

**Суть.** `param([string]$ConfigPath)` → `$script:ConfigPath = $ConfigPath`; дальше
`[IO.File]::WriteAllText($script:ConfigPath, ...)`. Путь не проверяется: программа перезапишет
любой указанный файл JSON-ом групп. Относительный путь резолвится от текущего каталога
процесса, а не от каталога программы.

**Воспроизведение.** Не эксплуатируется: параметр задаёт сам пользователь при запуске.
Проверено чтением кода; запись по произвольному пути — следствие, а не отдельный тест.

**Последствие.** Пользователь может случайно затереть чужой файл (`-ConfigPath C:\...\settings.json`)
или получить неожиданное расположение конфига. Повышения прав нет — пишет от своего имени.

**Исправление.** Привести к абсолютному пути и предупредить, если расширение не `.json`
или файл не похож на конфиг DesktopGroups; при старте без параметра — как сейчас, рядом
с программой.

---

## SEC-14 — «Ничего не внедряется в Explorer» — неточная формулировка

**Severity:** nit
**Файл:** `README.md` (раздел «Why another desktop organizer»), `SECURITY.md` (таблица действий)

**Суть.** README: «There is no background process, nothing is injected into Explorer».
Фактически программа делает `OpenProcess(0x438)`, `VirtualAllocEx` и `WriteProcessMemory`
в `explorer.exe` — не внедряет код (нет `CreateRemoteThread`, только данные для `LVM_*`),
но пишет в чужой процесс. `SECURITY.md` это описывает корректно, README — нет.

**Воспроизведение.** Код: `lib\Engine.ps1:362-368` (`OpenProcess` + `VirtualAllocEx`),
`391` (`WriteProcessMemory`), `lib\DesktopIcons.cs:33-45`.

**Последствие.** Пользователь и ревьюер ожидают одного, видят другое; эвристики AV на
`WriteProcessMemory` в explorer срабатывают законно (`docs/security-tooling.md` это уже
признаёт). Честная формулировка снижает и риск ложных обвинений, и поток вопросов.

**Исправление.** Заменить на: «нет резидентного процесса и внедрения кода; позиции значков
читаются и записываются через сообщения списку рабочего стола, буфер для структур выделяется
в `explorer.exe` на время операции и освобождается сразу после».

---

## Проверено, риск не подтвердился

Это важно не меньше находок: перечисленное ниже выглядит опасно, но при проверке запуском
не воспроизвелось.

**1. Имена групп и ярлыков из `config.json` как вектор инъекции — нет.**
Проверены: `"` `'` `\n` `\r\n` табуляция, эмодзи, NUL (`\u0000`), 10 000 символов,
10 000 000 символов, 10 000 эмодзи, `$()`, `%TEMP%`, `|`, `&`, `;`, `<`, `>`.
`ConvertFrom-Json` всё принимает, `New-Layout` и `Save-Wallpaper` отрабатывают без исключений,
PNG пишется 1920×1080:

```
OK   NUL внутри имени        155 мс  1920x1080
OK   только перевод строки    41 мс  1920x1080
OK   10000 эмодзи            112 мс  1920x1080
OK   управляющие символы      46 мс  1920x1080
```

Инъекции нет по конструкции: в проекте нет `Invoke-Expression`, `iex`, `& $x`, `Start-Process`,
`cmd /c` с подстановкой; имя группы уходит только в `Graphics.DrawString`/`MeasureString`
и в `Text` WinForms-контролов. `-f` с именем, содержащим `{0}`, рекурсии не даёт (значение
подставляется как данные). Длинное имя просто вылезает за рамку и обрезается краем битмапа.

**2. Буферы в explorer.exe не пересекаются.** `LVITEM` пишется в смещение 0 (88 байт),
текст читается из 128 (520 байт = 260 UTF-16), `POINT` — в 2048 (8 байт). Всё внутри
одного выделения 4096 байт, перекрытий нет; `cchTextMax=260` соответствует читаемым 520 байтам.

**3. Утечки хендлов на нормальном пути нет.** 50 циклов `Get-DesktopView` → `Read-ViewItems`
→ `Close-DesktopView`: хендлов 599 → 598. Освобождение памяти и закрытие хендла — в `finally`.

**4. Права администратора не нужны и не запрашиваются.** Процесс без прав администратора
успешно прочитал 47 значков (`OpenProcess(0x438)` к своему `explorer.exe`). В коде и
установщике нет `runas`, манифеста с `requireAdministrator`, `ScheduledTask`, ключа `Run`,
записи в `HKLM`. Установка пишет только в `%LOCALAPPDATA%`, `HKCU` и меню «Пуск» пользователя.

**5. Реестр — только HKCU.** `HKCU\Control Panel\Desktop` (три значения) и
`HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\DesktopGroups`. Чужих ключей нет.
`Test-AutoArrange` читает `HKCU\...\Bags\1\Desktop` только на чтение.

**6. Сети и загрузки нет.** Ни `Invoke-WebRequest`, ни `WebClient`, ни `DownloadString`,
ни `Start-BitsTransfer`, ни `Add-Type` из интернета. `Add-Type -AssemblyName` берёт сборки
из GAC, `Add-Type -Path` компилирует локальный `lib\DesktopIcons.cs`. Автозапуска нет.

**7. Секретов нет.** Ни токенов, ни ключей, ни паролей — ни в коде, ни в `config.json`,
ни в бэкапах. В `config.json` только имена ярлыков, цвета и метка времени.
`config.json`, `wallpaper.png`, `backups/`, `build/` — в `.gitignore` и не входят
в релизный архив (`tools\build-package.ps1` их не копирует), то есть инвентарь рабочего
стола в публичный репозиторий не попадает.

**8. Огромные группы больше не уводят раскладку за экран.** В проверенной версии `New-Layout`
ограничивает блок экраном: 10 000 значков → 24×417, `overflow = true`, PNG рисуется,
исключения нет. (В версии до правки 19:39 получалось `cols=2500`, `w=190000` — правка
с `$maxCols/$maxRows` это закрыла.)

**9. Перезапуск explorer между вызовами не даёт тихой порчи.** При закрытом хендле
`WriteProcessMemory` возвращает `false`, программа бросает исключение, `finally` закрывает
хендл; на экране — сообщение об ошибке, а не «расставлено N». Остаточный теоретический
риск: `HWND` списка значков может быть переиспользован другим окном после перезапуска
explorer, и `LVM_*` уйдёт не туда. Воспроизвести не удалось (нужен захват того же HWND),
поэтому как находку не заявляю.

**10. Дубли ключей в JSON не ломают загрузку.** PowerShell 5.1 молча берёт последнее
значение (`{"name":"A","name":"B"}` → `B`), исключения нет, потери данных нет.

**11. Размеры и типы P/Invoke на x64 корректны.** `LVITEM` 88 байт и смещения
`pszText@24`, `cchTextMax@32`, `lParam@40` совпадают с нативной раскладкой; `UIntPtr`
для размеров использован правильно; `Marshal.AllocHGlobal` освобождается в `finally`.

---

## Итог

| Severity | Количество |
|---|---|
| blocker | 0 |
| major | 4 |
| minor | 6 |
| nit | 4 |
| **всего** | **14** |

### Вердикт

**В текущем виде публиковать нельзя.** Блокеров нет, но четыре находки уровня major
относятся к тому, что пользователь заметит сразу или не заметит вовсе, пока не потеряет данные:

1. **SEC-01** — единственная настоящая дыра исполнения кода (деинсталлятор). Правится
   тремя строками, но до правки выпускать нельзя.
2. **SEC-03** — программа молча стирает конфиг пользователя при любой опечатке в JSON.
   Для утилиты, где `config.json` предлагается править руками, это недопустимо.
3. **SEC-04** — мусорный цвет в конфиге делает предпросмотр и кнопку «Разложить»
   неработоспособными без внятного объяснения.
4. **SEC-02** — дешёвый guard (5 строк) против порчи памяти чужого процесса; без него
   обещание «работает и под PowerShell 7» опасно.

После закрытия SEC-01…SEC-04 (и, желательно, SEC-05, SEC-06, SEC-10 — это по несколько
строк каждая) программа выглядит пригодной для публикации: остальные находки — гигиена
и качество, а не риски. Отдельно стоит поправить формулировку про Explorer (SEC-14):
при таком коде вопросы от AV и от читателей будут гарантированно, и лучше ответить на них
в README заранее.

Что в проекте сделано хорошо и переделывать не надо: доступ к процессу с минимально
достаточными правами (`0x438`, без `PROCESS_ALL_ACCESS`), один буфер на все операции,
освобождение в `finally`, отказ от `Invoke-Expression` и любых внешних загрузок,
отсутствие прав администратора, `HKCU` вместо `HKLM`, `.gitignore` для пользовательских
данных и `Unblock-File` в инструкции по установке.
