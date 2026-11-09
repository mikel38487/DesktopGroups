# DesktopGroups — ревью готовности к публикации

- **Объект:** коммит `64125fe` (ветка `main`), 11 файлов, 66 КБ. На момент финализации HEAD уже `1f48b23` — см. §6.
- **Среда проверки:** Windows 11, Windows PowerShell 5.1.26100, PowerShell 7.6.9, PSScriptAnalyzer 1.25.0.
- **Метод:** `git` (status/log/tag/ls-tree), парсер PowerShell, PSScriptAnalyzer, пробный запуск GUI с закрытием окна (раскладка **не** применялась), проверка ACL и арифметики раскладки.

> **Границы ревью.** Проверялся коммит `64125fe`. Во время проверки рабочее дерево менялось параллельно (появились `install.cmd`, `uninstall.cmd`, `VERSION`, `.github/`, `dist/` и правки `lib/Engine.ps1`/`README.md`). Всё ниже, если не сказано иное, относится к коммиту; дельта — в §6. Релиз нельзя тегировать из грязного дерева.
>
> **Снимок:** 2026-11-09, ~19:50 MSK. После этого в рабочем дереве продолжались правки (workflows, launchers, `tests/check-encoding.ps1`); они не проверялись и в отчёт не вошли — перед тегом сверяйтесь с `git status`.

## 1. Что мешает публикации

### Blockers

**B1. В коммите нет установки и удаления; установка в `Program Files` ломает запись данных.**

- В `64125fe` есть только `DesktopGroups.cmd`; README (§Usage) говорит «Run DesktopGroups.cmd». Нет `install.cmd`/`uninstall.cmd`, ярлыка в меню «Пуск», записи в «Приложениях».
- Программа пишет данные **рядом со скриптом**: `config.json` (`DesktopGroups.ps1:30`), `wallpaper.png` (`DesktopGroups.ps1:538`), `backups\` (`lib/Engine.ps1:477`).
- `C:\Program Files` для обычного пользователя — только чтение: ACL `BUILTIN\Пользователи: ReadAndExecute, Synchronize` (проверено `Get-Acl`). Первое сохранение конфига/обоев упадёт с `UnauthorizedAccessException`; в GUI это выглядит как ошибка или молчаливое отсутствие сохранения.
- Удаления нет: `HKCU\Control Panel\Desktop\Wallpaper` указывает на `...\wallpaper.png` (`lib/Engine.ps1:338`). Удалили папку — обои битые/чёрные.

**Действие:** добавить `install.cmd`/`uninstall.cmd`, ставить в `%LOCALAPPDATA%\Programs\DesktopGroups` (проверено: путь существует и доступен на запись), делать ярлык в «Пуск», при удалении восстанавливать обои. Черновик — §2.

**B2. Команда запуска из README не работает при ExecutionPolicy `Restricted`.**

- README:43 предлагает `powershell.exe -STA -File .\DesktopGroups.ps1`.
- Проверено: `powershell.exe -NoProfile -ExecutionPolicy Restricted -File DesktopGroups.ps1` → `cannot be loaded because running scripts is disabled on this system`, exit 1.
- `.cmd` спасает только потому, что передаёт `-ExecutionPolicy Bypass` (`DesktopGroups.cmd:3`). На этой машине политика `RemoteSigned`, но на клиентских Windows нередко `Restricted`; после скачивания ZIP файлы получают Mark-of-the-Web.
- README не упоминает ни `Bypass`, ни «Разблокировать» архив.

**Действие:** сделать `.cmd` единственным документированным входом; в ручной команде добавить `-ExecutionPolicy Bypass`; добавить шаг «Свойства ZIP → Разблокировать»; явно написать, что политика не меняется глобально. Если политика задана GPO (`MachinePolicy`), `Bypass` не поможет — это ограничение.

**B3. Обои всегда 1920×1080, а раскладка считается от реального экрана. На любом другом разрешении рамки не совпадают.**

- `Save-Wallpaper` по умолчанию `1920×1080` (`lib/Engine.ps1:276`), GUI вызывает без размеров (`DesktopGroups.ps1:539`).
- `Get-ScreenInfo` берёт реальный экран (`lib/Engine.ps1:241`), `New-Layout` считает координаты в его пикселях.
- Проверено на 1366×768: блок `x=14, y=202`, рамка рисуется в `y=190`, после `WallpaperStyle=10` (Fill, `lib/Engine.ps1:339`) масштаб 0,711 → рамка на `y≈135`, значок на `y=202`. Сдвиг ≈67 px.
- Проверено на 2560×1440: 4-й блок `right=2066` при ширине картинки 1920 — часть рамки обрезана; Fill растянет 1920→2560, координаты разъедутся.
- Корректно работает только при точном 1920×1080. README:26 называет 1920×1080, но в Limitations (`README.md:87-94`) ограничения по разрешению нет.

**Действие:** рисовать обои в размере экрана (`Save-Wallpaper $layout $png $screen.width $screen.height`) или масштабировать координаты; добавить тесты для 1366×768 и 2560×1440; до исправления — явное ограничение в README.

**B4. Нет версии, тега и релизных артефактов.**

- `git tag -l` пуст; в файлах нет версии; нет `VERSION`, `CHANGELOG.md`; `git log` — один коммит.
- Нет GitHub Release, ZIP, release notes.

**Действие:** зафиксировать `0.1.0` (или `1.0.0`, если осознанно фиксируете формат конфига), добавить `VERSION`, `CHANGELOG.md` (Keep a Changelog), аннотированный тег `v0.1.0`, Release с ZIP из `git archive`, SHA256.

**B5. Тесты нельзя запускать в CI, и они опасны для пользователя.**

- Все 4 файла в `tests/` содержат абсолютные `F:\AI\DesktopGroups` (9 вхождений) и лезут в живой рабочий стол: `Get-DesktopView`, `Read-ViewItems`, `Get-ViewGridStep`.
- `tests/apply-all.ps1` реально применяет раскладку, пишет `wallpaper.png` и меняет обои через реестр (`:20`, `:36`, `:39-47`); `tests/test-engine.ps1` пишет в `build\` (`:26`); `tests/verify-apply.ps1` читает реестр (`:24`).
- На `windows-latest` нет интерактивного рабочего стола (`Progman`/`SHELLDLL_DefView`), тесты упадут; в худшем случае изменят стол раннера.
- Headless-тестов нет вообще.

**Действие:** перенести в `tests/manual/` с guard по переменной окружения; заменить `F:\...` на `$PSScriptRoot\..`; добавить `tests/headless.tests.ps1` на Pester для `New-ProposedGroups`, `New-Layout`, `Convert-HexColor`, `Get-DefaultGrid`; CI — §3.

**B6. Рабочее дерево грязное относительно коммита — тегировать нельзя.**

- На момент отчёта: `M README.md`, `M lib/Engine.ps1`; untracked `install.cmd`, `uninstall.cmd`, `VERSION`, `CHANGELOG.md`, `SECURITY.md`, `.gitattributes`, `.github/`, `dist/`, `docs/`, `tools/`, `tests/smoke.ps1`, `PSScriptAnalyzerSettings.psd1`.
- Это не входит в `64125fe`; релиз из такого дерева либо потеряет правки, либо попадёт в тег непроверенным. Позже эти файлы вошли в `1f48b23` (см. §6), но в коммит попал и `dist/*.zip`.

**Действие:** закоммитить и проверить, затем тег с чистого дерева (`git status --short` пусто).

### Major

**M1. Битый конфиг молча перезаписывается.** `Load-Config` ловит любую ошибку и возвращает `$false` (`DesktopGroups.ps1:33-53`); `Add_Shown` тогда предлагает группы и сразу вызывает `Save-Config` (`DesktopGroups.ps1:592-596`). Повреждённый/нечитаемый `config.json` → группы пользователя теряются без предупреждения. Действие: переименовать в `config.bad-<дата>.json`, показать MessageBox, не сохранять автоматически.

**M2. Переполнение по ширине не обнаруживается (в коммите).** `New-Layout` проверяет только высоту (`lib/Engine.ps1:199-201`); при 200 значках в группе `cols=50`, `right=3814` при экране 1920, `overflow=False`. Группа уезжает за экран молча; README:93 обещает «blocks that do not fit are reported». Действие: проверять ширину, переносить/ограничивать колонки, тест. В рабочем дереве уже появились `maxCols/maxRows` — проверить и закоммитить.

**M3. Мусор в рабочем дереве может утечь.** В git не попал (`.gitignore`), но лежит рядом: `config.json` (47 имён ярлыков, 9 групп), `wallpaper.png`, `backups/*.json` (3 файла), `build/test-wallpaper.png`. Если собирать ZIP «как есть» или загружать папку через веб-интерфейс GitHub, имена и обои уедут в публикацию. Действие: удалить артефакты, ZIP — только `git archive`, добавить `dist/` в `.gitignore`.

**M4. В коммите нет документации, которую ждут на GitHub.** Нет `CHANGELOG.md`, `SECURITY.md`, `CONTRIBUTING.md`, шаблонов issue, `.gitattributes`, скриншотов; README без разделов Install/Uninstall/Troubleshooting (в рабочем дереве уже добавляется). Действие — §3.

**M5. Удаление не восстанавливает обои.** Даже в рабочем `uninstall.cmd` написано «обои не восстанавливаются». После удаления папки реестр указывает на несуществующий файл. Действие: сохранять `Wallpaper`, `WallpaperStyle`, `TileWallpaper` при установке и восстанавливать при удалении; fallback — `%SystemRoot%\web\wallpaper\Windows\img0.jpg` (проверено: существует).

**M6. Бэкапы растут без ограничения и нет восстановления.** `backups/before-apply-*.json` на каждый apply (`lib/Engine.ps1:477-481`), UI восстановления нет. Действие: ротация (например, 20 последних) + кнопка «Восстановить».

**M7. Мелочи UX/надёжности.** Окно `1140×760` при рабочей высоте 728 на 1366×768 может не влезть; `-WindowStyle Hidden` скрывает ошибки старта (нет MessageBox); интерфейс только русский при английском README; `Add-Type` компилирует C# в рантайме и пишет в память `explorer.exe` — некоторые AV/EDR могут ругаться, в README нет troubleshooting; 21 предупреждение PSScriptAnalyzer (0 ошибок): `Load-Config` — неодобренный глагол, 4 пустых `catch`, остальное — ложные срабатывания ShouldProcess/множественного числа.

## 2. Чего не хватает для удобной установки

### Целевая структура

```text
DesktopGroups/
├─ DesktopGroups.cmd
├─ DesktopGroups.ps1
├─ install.cmd
├─ uninstall.cmd
├─ VERSION
├─ README.md
├─ CHANGELOG.md
├─ SECURITY.md
├─ CONTRIBUTING.md
├─ LICENSE
├─ .gitattributes
├─ .github/
│  ├─ workflows/ci.yml
│  └─ ISSUE_TEMPLATE/bug_report.yml
├─ lib/
│  ├─ Engine.ps1
│  └─ DesktopIcons.cs
├─ tools/
│  ├─ install.ps1
│  └─ uninstall.ps1
├─ docs/
│  └─ screenshots/
│     ├─ main.png
│     └─ wallpaper.png
└─ tests/
   ├─ headless.tests.ps1
   └─ manual/
      ├─ apply-all.ps1
      ├─ test-engine.ps1
      ├─ verify-apply.ps1
      └─ diff-names.ps1
```

### `install.cmd` — тонкая обёртка

```bat
@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\install.ps1"
if errorlevel 1 pause
```

`tools/install.ps1` — ключевое:

```powershell
$src = Split-Path -Parent $PSScriptRoot
$dst = Join-Path $env:LOCALAPPDATA 'Programs\DesktopGroups'
New-Item -ItemType Directory -Force -Path (Join-Path $dst 'lib') | Out-Null

# только код; config.json / wallpaper.png / backups при обновлении не трогаем
Copy-Item "$src\DesktopGroups.ps1","$src\DesktopGroups.cmd","$src\README.md","$src\LICENSE" $dst -Force
Copy-Item "$src\lib\Engine.ps1","$src\lib\DesktopIcons.cs" (Join-Path $dst 'lib') -Force

# сохранить текущие обои для удаления
$k = Get-ItemProperty 'HKCU:\Control Panel\Desktop'
@{ Wallpaper = $k.Wallpaper; WallpaperStyle = $k.WallpaperStyle; TileWallpaper = $k.TileWallpaper } |
    ConvertTo-Json | Set-Content (Join-Path $dst 'previous-wallpaper.json') -Encoding UTF8

# ярлык в «Пуск»
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Programs')) 'DesktopGroups.lnk'))
$lnk.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$lnk.Arguments = '-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f (Join-Path $dst 'DesktopGroups.ps1')
$lnk.WorkingDirectory = $dst
$lnk.IconLocation = "$env:SystemRoot\System32\shell32.dll,21"
$lnk.Save()

Start-Process (Join-Path $dst 'DesktopGroups.cmd')
```

### `uninstall.cmd` / `tools/uninstall.ps1`

- закрыть окно, если открыто (процесса-резидента нет — достаточно попросить закрыть или найти процесс по командной строке);
- удалить ярлык `%APPDATA%\Microsoft\Windows\Start Menu\Programs\DesktopGroups.lnk`;
- восстановить обои из `previous-wallpaper.json` (проверить, что файл ещё существует; иначе `%SystemRoot%\web\wallpaper\Windows\img0.jpg`) и вызвать `SystemParametersInfo(SPI_SETDESKWALLPAPER)`;
- удалить `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DesktopGroups`, если делали запись в «Приложения»;
- спросить, удалять ли настройки: если да — `Remove-Item $dst -Recurse -Force`, иначе удалить только код, оставить `config.json`/`wallpaper.png`/`backups`.

### Минимальный путь «скачал → запустил → работает»

1. GitHub Release → `DesktopGroups-0.1.0.zip`.
2. Свойства ZIP → «Разблокировать» (если кнопка есть) → распаковать.
3. Запустить `install.cmd` (без администратора). Он копирует в `%LOCALAPPDATA%\Programs\DesktopGroups`, делает ярлык и открывает программу.
4. Портативный вариант: не запускать `install.cmd`, а запустить `DesktopGroups.cmd` из распакованной папки; данные будут рядом.

Отдельного шага сборки нет: C# компилируется `Add-Type` при первом запуске (нужен только встроенный .NET Framework, он есть на Win10/11). Админ не нужен. Политика не меняется: `Bypass` действует только на процесс.

### Где данные

- Программа: `%LOCALAPPDATA%\Programs\DesktopGroups`.
- Данные: рядом (`config.json`, `wallpaper.png`, `backups/`) — этого требует текущий код. Поэтому `Program Files` не подходит; если хотите `%APPDATA%`, это отдельная правка кода.
- Обновление: перезаписать только код, `config.json` и `wallpaper.png` сохранить.
- Удаление: `uninstall.cmd`, обои восстановить.

### Консоль и права

- `.cmd` запускает `powershell.exe` с `-WindowStyle Hidden`; проверено: видно только окно формы, консоли нет. При двойном клике по `.cmd` возможна короткая вспышка консоли — ярлык из `install.cmd` это убирает.
- Ошибки старта (например, `Add-Type` не скомпилировал C#) при скрытой консоли не видны; обернуть запуск в try/catch с MessageBox.
- Админ не нужен: запись только в HKCU и профиль.

## 3. Чек-лист релиза

1. **Заморозить код.** По `1f48b23` осталось: B3 (масштаб обоев), M1 (битый конфиг), M5 (обои при удалении); M2 уже закрыт — прогнать smoke.
2. **Убрать артефакты:** `git rm --cached dist/DesktopGroups-1.0.0.zip`, добавить `dist/` в `.gitignore`, удалить `config.json`, `wallpaper.png`, `backups/`, `build/`.
3. **Проверить файлы (в `1f48b23` уже есть):** `install.cmd`, `uninstall.cmd`, `tools/install.ps1`, `tools/uninstall.ps1`, `VERSION`, `CHANGELOG.md`, `SECURITY.md`, `.gitattributes`, `.github/workflows/ci.yml`; добавить `CONTRIBUTING.md`, шаблон issue, скриншоты.
4. **Версия:** `VERSION` = `0.1.0` (или `1.0.0`), та же строка в окне/«О программе», `CHANGELOG` с датой, тег `v0.1.0`.
5. **Локальные проверки:**

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tests\headless.tests.ps1
   pwsh -File tests\headless.tests.ps1
   Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error   # должно быть 0
   ```

   Парсер: 0 ошибок в 6 файлах (проверено для HEAD).

6. **Прогон на чистой машине/профиле:** распаковать ZIP → `install.cmd` → скан → предложить → применить → закрыть → `uninstall.cmd`; проверить 1366×768 и 2560×1440; проверить, что обои восстановились.
7. **CI:** parser + PSScriptAnalyzer (Error) + Pester headless на `windows-latest`; PS 5.1 и 7. Пример:

   ```yaml
   name: CI
   on: [push, pull_request]
   jobs:
     test:
       runs-on: windows-latest
       steps:
         - uses: actions/checkout@v4
         - shell: pwsh
           run: Install-Module PSScriptAnalyzer,Pester -Scope CurrentUser -Force
         - shell: pwsh
           run: |
             Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object {
               $e=$null; $t=$null
               [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$t,[ref]$e) | Out-Null
               if ($e) { $e | ForEach-Object { Write-Error "$($_.Extent.File):$($_.Extent.StartLineNumber): $($_.Message)" } }
             }
         - shell: pwsh
           run: |
             $r = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
             if ($r) { $r | Format-Table; exit 1 }
         - shell: pwsh
           run: Invoke-Pester ./tests/headless.tests.ps1 -CI
   ```

   `tests/manual/*` в CI не запускать.

8. **Коммит и тег:**

   ```powershell
   git status --short          # пусто
   git add -A
   git commit -m "Release 0.1.0: install/uninstall, CI, docs, wallpaper scaling"
   git tag -a v0.1.0 -m "DesktopGroups 0.1.0"
   git push origin main --tags
   ```

9. **ZIP:**

   ```powershell
   git archive --format=zip --prefix=DesktopGroups-0.1.0/ -o dist/DesktopGroups-0.1.0.zip v0.1.0
   Get-FileHash dist\DesktopGroups-0.1.0.zip -Algorithm SHA256
   ```

   Содержимое: `DesktopGroups.cmd`, `DesktopGroups.ps1`, `install.cmd`, `uninstall.cmd`, `VERSION`, `README.md`, `CHANGELOG.md`, `LICENSE`, `lib/*`. Без `config.json`, `wallpaper.png`, `backups/`, `build/`, `tests/`, `docs/`, `.github/`, `dist/`. Для этого — `export-ignore` в `.gitattributes`.

10. **GitHub Release:** заголовок `DesktopGroups 0.1.0`, notes из `CHANGELOG`, приложить ZIP + SHA256; включить Issues; заполнить описание репозитория и topics.
11. **Проверка после публикации:** скачать Release ZIP в чистый профиль, повторить шаг 6; проверить, что в ZIP нет `F:\AI` и личных имён (`tar -tf`, `Select-String`).

### `.gitattributes`

```gitattributes
* text=auto eol=lf
*.cmd text eol=crlf
*.ps1 text eol=crlf
*.png binary
tests/manual export-ignore
docs/review export-ignore
.github export-ignore
dist export-ignore
```

## 4. Первое впечатление

- **Название.** `DesktopGroups` — понятное, но родовое: пересекается с «Desktop Groups» и Fences-подобными утилитами. Перед публикацией проверить, что имя свободно на GitHub и не теряется в поиске; в описании сразу дать отличие — «рамки впечатаны в обои, фонового процесса нет».
- **Описание репозитория.** Локально `git remote -v` пуст, поэтому описание/топики/социальный preview проверить нельзя — их ещё нет. Рекомендация: описание «Bake desktop shortcut groups into your wallpaper — no background process, no Explorer hooks.»; topics: `windows`, `powershell`, `winforms`, `desktop`, `wallpaper`, `shortcuts`, `icon-layout`, `fences-alternative`.
- **Лицензия.** MIT, `LICENSE:3` — `Copyright (c) 2026 mikel38487`; совпадает с git-email `mikel38487@users.noreply.github.com`. GitHub определит лицензию как MIT.
- **Секреты.** По типовым шаблонам (`ghp_`, `github_pat_`, `api_key`, `secret`, `password`, `token`, `Bearer`) — 0 совпадений в tracked-файлах. Ключей, токенов и `.env` нет.
- **Размер.** В `64125fe` — 66 КБ, 11 файлов, бинарников нет; `.git` маленький. В `1f48b23` уже 28 файлов и бинарный ZIP 24 КБ — это перебор, артефакту в git не место.
- **`.gitattributes` / переносы строк.** Файла нет; `core.autocrlf=true` (проверено), git предупреждает «LF will be replaced by CRLF». В блобах LF, включая `.cmd`; `.cmd` с LF в тесте запустился, но для предсказуемости и ZIP нужен `.gitattributes` (§3).
- **Скриншоты.** В коммите нет ни одного изображения; первый экран README — только текст. Для «первого впечатления» нужен скриншот окна и пример обоев (без личных имён).
- **История.** Один коммит, сообщение по-русски, ветка `main`, тегов нет — история для релиза ещё не оформлена.

## 5. Оценка

**Не готово** по коммиту `64125fe`; по `1f48b23` — **почти готово**, а в рабочем дереве уже исправляются B2/B3/M1/M5/M6/M7 (не проверены запуском). Итог — см. §6.

Почему: пользователь, скачавший ZIP завтра, получает папку без установщика и без ответа «куда класть»; если кладёт в `Program Files` — программа не сохраняет конфиг/обои; команда из README на политике `Restricted` не запускается; на экране, отличном от 1920×1080, рамки не совпадают со значками; версии/тега/Release нет; тесты не проверяются в CI и опасны. Это не косметика — это первый запуск и основной сценарий.

Что уже хорошо: ядро работает (GUI под 5.1 открывается и закрывается, 47 значков/9 групп сохраняются), парсер — 0 ошибок, PSScriptAnalyzer — 0 ошибок (21 warning), секретов нет, MIT, 66 КБ / 11 файлов, `.gitignore` закрывает артефакты, README EN+RU, BOM у `.ps1` корректный (5.1 не ломает кириллицу), `.cmd` с LF работает.

Чтобы стало «готово»: закрыть B1–B5, прогнать чек-лист §3 на чистой машине. После этого — «почти готово» → «готово»; B3 (обои) и B1 (установка) обязательны.

## 6. Коммит `1f48b23`: что изменилось после ревью

Пока шло ревью, поверх `64125fe` появился коммит `1f48b23` «Инфраструктура релиза: установка без компиляции, CI, тесты, безопасность». В нём: `install.cmd`/`uninstall.cmd`/`tools/*`, `VERSION` 1.0.0, `CHANGELOG.md`, `SECURITY.md`, `.github/workflows/{ci,release}.yml`, `tests/smoke.ps1`, `tests/fuzz-config.ps1`, `.gitattributes`, правки `Engine.ps1`/`DesktopGroups.ps1`/`README.md` — **и этот отчёт, и `dist/DesktopGroups-1.0.0.zip`**. Полного прогона нового коммита не было; ниже — что проверено по файлам.

На финальной проверке (уже после `1f48b23`) в рабочем дереве снова появились незакоммиченные правки `DesktopGroups.ps1`/`lib/Engine.ps1`: `Save-Wallpaper` теперь получает `$script:Screen.width/height` (B3), битый конфиг откладывается в `config.bad-*` (M1), добавлена кнопка «Вернуть прошлую раскладку» (M6), окно подстраивается под рабочую область (M7). Также изменены `README.md` (ручная команда уже с `-ExecutionPolicy Bypass` — B2) и `tools/install.ps1`/`tools/uninstall.ps1` (сохранение и восстановление обоев — M5). Эти правки не входят в `1f48b23` и **не проверялись запуском**; перед тегом их нужно закоммитить и прогнать smoke + GUI.

| Замечание | Статус в `1f48b23` | Что осталось |
|---|---|---|
| B1 установка/удаление | закрыто частично | install в `%LOCALAPPDATA%`, ярлык «Пуск», запись в «Приложения»; **uninstall не восстанавливает обои** (M5); install копирует `PSScriptAnalyzerSettings.psd1` в папку пользователя |
| B2 ExecutionPolicy | не закрыто в `1f48b23` | ручная команда `powershell.exe -STA -File` (`README.md:64`, `:187`) без `Bypass`; в рабочем дереве уже `-ExecutionPolicy Bypass` (L64/L216) — проверить |
| B3 обои 1920×1080 | **не закрыто в `1f48b23`** | GUI вызывает `Save-Wallpaper $layout $png` без размеров (`DesktopGroups.ps1:564`), сигнатура `1920×1080` (`lib/Engine.ps1:288`); в рабочем дереве уже передаётся размер экрана — проверить запуском |
| B4 версия/релиз | закрыто частично | `VERSION` 1.0.0, `CHANGELOG.md`, `release.yml`; **тега нет** (`git tag -l` пуст), Release не создан |
| B5 тесты/CI | закрыто частично | `smoke.ps1` headless, CI его запускает; **`tests/apply-all.ps1` и др. остаются с `F:\AI` и без guard**; `fuzz-config.ps1` в CI не запускается |
| B6 грязное дерево | закрыто | всё закоммичено; но в коммит попали `dist/*.zip` и `docs/review/release.md` |
| M1 битый конфиг | не закрыто в `1f48b23` | `Import-Config` проверяет `$null`, но при ошибке `Add_Shown` всё равно предлагает группы и `Save-Config` перезаписывает файл; в рабочем дереве файл уже откладывается в `config.bad-*` — проверить |
| M2 ширина | закрыто | `maxCols/maxRows` + fallback; smoke проверяет 150 и 400 значков |
| M3 мусор | **ухудшилось** | `dist/DesktopGroups-1.0.0.zip` (24 773 Б) tracked; `.gitignore` без `dist/` |
| M5 обои при удалении | не закрыто в `1f48b23` | `uninstall.cmd` прямо пишет «обои не восстанавливаются»; в рабочем дереве install сохраняет `previous-wallpaper.json`, uninstall восстанавливает — проверить |
| M6 бэкапы | не закрыто в `1f48b23` | без ротации и восстановления; в рабочем дереве добавлена кнопка «Вернуть прошлую раскладку» — проверить |
| M7 мелочи | частично | версия в заголовке, `catch` с warning; warning в скрытой консоли не виден; в рабочем дереве окно подстраивается под экран — проверить |

Новые находки по `1f48b23`:

1. **ZIP в git устарел.** `dist/DesktopGroups-1.0.0.zip` (24 773 Б) содержит `PSScriptAnalyzerSettings.psd1`, но **не содержит** `CHANGELOG.md` и `SECURITY.md`, хотя `tools/build-package.ps1` их включает. Артефакт не соответствует сборщику; в git ему не место.
2. **`build-package.ps1` кладёт в пользовательский ZIP `PSScriptAnalyzerSettings.psd1`** — dev-конфиг, не нужен.
3. **`tools/install.ps1` копирует `PSScriptAnalyzerSettings.psd1`** в `%LOCALAPPDATA%\Programs\DesktopGroups` (`skipFiles` его не исключает).
4. **`docs/review/release.md` опубликован в коммите** — внутренний отчёт с оценкой «не готово»; решить, публиковать ли.
5. **`git tag -l` пуст** — `release.yml` сработает только после тега; тега нет.
6. **`tests/smoke.ps1` по-прежнему проверяет 1920×1080** и не поймает регрессию масштаба; после фикса B3 добавить проверку 1366×768/2560×1440.

Порядок действий сейчас: закоммитить и прогнать правки B2/B3/M1/M5/M6/M7 из рабочего дерева → убрать `dist/` из git и добавить в `.gitignore` → исключить `PSScriptAnalyzerSettings.psd1` из `build-package.ps1` и `install.ps1` → перенести `tests/apply-all.ps1` и др. в `tests/manual/` с guard → тег `v1.0.0` (или `v0.1.0`) и Release. После этого — «готово».

## Приложение: доказательства

| Проверка | Команда/метод | Результат |
|---|---|---|
| Состояние git | `git status --short --branch` | на старте `## main`, чисто, HEAD `64125fe`; на финализации HEAD `1f48b23` |
| Состав | `git ls-files` | `64125fe` — 11 файлов, 66 КБ; `1f48b23` — 28 файлов + ZIP 24 КБ |
| Парсер | `[Parser]::ParseFile` | 0 ошибок в 6 `.ps1` |
| PSScriptAnalyzer | `Invoke-ScriptAnalyzer` | 0 Error, 21 Warning, 7 Information |
| Restricted | `powershell.exe -ExecutionPolicy Restricted -File ...` | exit 1, «running scripts is disabled» |
| GUI | `DesktopGroups.cmd`, закрытие окна | окно `DesktopGroups — группы ярлыков рабочего стола`, консоли нет; 9 групп/47 значков сохранены |
| Program Files | `Get-Acl 'C:\Program Files'` | `BUILTIN\Пользователи: ReadAndExecute, Synchronize` |
| Раскладка n=200 | `New-Layout` из `HEAD:lib/Engine.ps1` | `cols=50`, `right=3814`, `overflow=False` |
| 1366×768 | `New-Layout` + арифметика Fill | рамка `y≈135`, значок `y=202` |
| 2560×1440 | 4 блока по 24 | 4-й `right=2066` > 1920 |
| Секреты | `Select-String` по tracked | 0 совпадений (типовые шаблоны) |
| Тесты | `git grep 'F:\\AI' HEAD -- tests` | 9 вхождений (в `64125fe`; в `1f48b23` старые файлы не менялись) |
| Теги | `git tag -l` | пусто и в `64125fe`, и в `1f48b23` |
| ZIP в git | `git ls-tree -r -l HEAD dist` | `dist/DesktopGroups-1.0.0.zip`, 24 773 Б |
| Содержимое ZIP | `ZipFile.OpenRead` | нет `CHANGELOG.md`/`SECURITY.md`, есть `PSScriptAnalyzerSettings.psd1` |
| Ручной запуск | `README.md` | в `1f48b23` L64/:187 без `Bypass`; в рабочем дереве L64/L216 уже с `-ExecutionPolicy Bypass` |
| Рабочее дерево на финализации | `git status --short` | `M DesktopGroups.ps1`, `M lib/Engine.ps1`, `M docs/review/release.md`, `?? docs/review/security.md` |
