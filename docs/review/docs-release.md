# DesktopGroups 1.1.0 — ревью документации и готовности релиза

Независимый ревьюер документации. Дата: 2026-11-10.
Объект: `F:\AI\DesktopGroups`, коммит `c0f05a1`, `VERSION = 1.1.0`.
Код и документация **не правились**. Создан только этот файл.

## 0. Методика и оговорка о состоянии репозитория

Рабочее дерево во время ревью менялось другим процессом (в 05:46 HEAD был
`c0f05a1` и дерево чистое; к 06:27 HEAD — `ae623f0`, изменены `DesktopGroups.ps1`,
`lib\Engine.ps1`, `lib\Strings.ps1`, `docs\review\i18n.md`). Поэтому все замеры
сделаны по **неизменяемому снимку тега**, а не по рабочему дереву:

```powershell
git archive c0f05a1 -o $env:TEMP\dg-snap.zip
tar -xf $env:TEMP\dg-snap.zip -C $env:TEMP\dg-snap-c0f05a1   # 22 файла
```

Сверка «рабочее дерево = тег» для проверяемых файлов:

```powershell
git diff --name-status c0f05a1 HEAD -- README.md README.ru.md SECURITY.md SECURITY.ru.md \
    CHANGELOG.md docs/guide.md docs/guide.ru.md VERSION tools lib tests
# пусто → код и парные документы на момент ревью совпадают с тегом
```

Прочие инструменты:

- проверка ссылок и якорей — собственный скрипт (`%TEMP%\check-links.ps1`),
  слагификация по правилам GitHub (кириллица сохраняется, пунктуация вырезается,
  дубликаты получают `-1`);
- сборка пакета — `tools\build-package.ps1 -Output dist` **в копии снимка** в `%TEMP%`,
  в `dist\` репозитория ничего не собиралось;
- опубликованный артефакт скачан и разобран: `gh release download v1.1.0`.

## 1. Блокеры

### B1. README и docs/github-security обещают `SHA256SUMS.txt` и аттестацию, которых у v1.1.0 нет

**Где:** `README.md` (main, раздел «Verify what you downloaded»), `README.ru.md`
(«Проверить загруженное»), `docs/github-security.md` (строка таблицы
«SHA-256 checksums — `SHA256SUMS.txt` next to the release archive», «Build
provenance attestation — every release asset»), `SECURITY.md` (раздел SmartScreen,
«Release assets ship with `SHA256SUMS.txt` and a signed build provenance attestation»).

**Факт:**

```text
gh release view v1.1.0 --json assets
→ assets: [{"name":"DesktopGroups-1.1.0.zip","size":81525}]   # ровно один файл

gh attestation verify .\DesktopGroups-1.1.0.zip --repo mikel38487/DesktopGroups
→ Error: HTTP 404: Not Found (.../attestations/sha256:25ef3c28...)
```

`SHA256SUMS.txt` в релизе отсутствует, аттестации нет: релиз опубликован
2026-11-10T00:22Z, а шаги «Аттестация происхождения» и «Контрольная сумма SHA-256»
появились в `release.yml` позже (коммит `3baa7cd`). Важно: **в ZIP лежит README из
тега, и там этого обещания нет** — ложным становится README на GitHub, по которому
и идут пользователи.

**Действие:** либо выпустить `v1.1.1` через обновлённый `release.yml` (он уже пишет
`SHA256SUMS.txt` и аттестацию) и проверить `gh attestation verify`, либо до
перевыпуска убрать обещание из README/README.ru/SECURITY/docs/github-security.

### B2. Удаление: недокументированная потеря данных и подмена обоев

Документация говорит только о восстановлении обоев:

- `README.md`: «To remove it, use *Apps & features* … Your previous wallpaper is restored on uninstall.»
- `docs/guide.md`, «Removing»: «The program is removed, the Start Menu shortcut is deleted, the *Apps & features* entry disappears, and your previous wallpaper is restored.»

Код удаляет **весь каталог программы**, то есть `config.json` (ваши группы),
`wallpaper.png` и `backups\`:

```text
tools\uninstall.ps1:68-72
'Start-Sleep -Seconds 2; Remove-Item -LiteralPath $env:DESKTOPGROUPS_UNINSTALL_DIR -Recurse -Force …'
```

Восстановление обоев условное и об этом ни слова:

```text
tools\uninstall.ps1:29-33   if (Test-Path $prevFile) { … if ($wall -and (Test-Path -LiteralPath $wall)) {…} }
tools\uninstall.ps1:47-55   if (-not $restored) { $fallback = …\web\wallpaper\Windows\img0.jpg ; … }
```

Если `previous-wallpaper.json` нет (портативный режим — он не создаётся, его пишет
только `tools\install.ps1:43`) или сохранённый файл обоев удалён, скрипт **ставит
стандартные обои Windows**, а не «восстанавливает прежние». При этом `uninstall.cmd`
лежит в корне архива и в портативной установке удалит саму распакованную папку
вместе с конфигом — README подаёт его как безопасный способ удаления.

**Действие:** в README (оба языка) и в `docs/guide.md`/`guide.ru.md` прямо написать:
удаление стирает `config.json`, `wallpaper.png` и `backups\`; обои восстанавливаются
только если их файл ещё существует, иначе ставится стандартные обои Windows.
Для портативного режима — отдельное предупреждение.

### B3. `SECURITY.md`: заявлен «полный список», но он неполон; «три файла» — ошибка

Оба языка, раздел «What the program does to your system» / «Что программа делает
в системе» начинается словами «Risk assessment needs the full list» и содержит
таблицу. В ней нет трёх вещей, которые код делает:

1. **Чтение реестра** `HKCU\Software\Microsoft\Windows\Shell\Bags\1\Desktop`
   (`lib\Engine.ps1:680`, функция `Test-AutoArrange`, значение `FFlags`). В таблице
   только две записи в реестр — обе про запись.
2. **Перебор файлов рабочего стола на диске** — `%USERPROFILE%\Desktop` и
   `%PUBLIC%\Desktop` (`lib\Engine.ps1:109-115`, `Get-ChildItem -Force`). Таблица
   говорит только про чтение имён и позиций через `explorer.exe`.
3. **Четвёртый файл кода.** «Verifying the code yourself»: «Everything the program
   does is visible in **three files**: `DesktopGroups.ps1`, `lib\Engine.ps1` and
   `lib\Strings.ps1`». P/Invoke и самая чувствительная часть лежат в
   `lib\DesktopIcons.cs`, который подключается в `lib\Engine.ps1:5-7`
   (`Add-Type -Path … DesktopIcons.cs`) и вызывает `VirtualAllocEx`/`WriteProcessMemory`.

**Действие:** добавить строку «чтение `HKCU\…\Shell\Bags\1\Desktop` (признак
«Упорядочить автоматически»)» и строку про перебор папок рабочего стола; в тексте
заменить «three files» на четыре, назвав `lib\DesktopIcons.cs`.

## 2. Мажоры

### M1. В README нет раздела «Ограничения»

Витрина (оба языка) не сообщает главного ограничения — **только основной монитор**.
Оно есть в `docs/guide.md` (FAQ: «Not yet: only the primary monitor is laid out»),
в CHANGELOG 1.0.0 («Primary monitor only») и больше нигде. Также в README нет
«нет drag & drop» и «`wallpaper.png` нельзя удалять, пока он применён».

**Действие:** короткий раздел `## Limitations` / `## Ограничения` из трёх пунктов
после «Requirements»/«Требования».

### M2. Кнопка «Сохранить обои в файл…» не описана нигде

`lib\Strings.ps1:19` — `'btn.saveWall' = 'Сохранить обои в файл…'`, `:122` —
`'Save wallpaper to file…'`; обработчик `DesktopGroups.ps1:849-857`
(`SaveFileDialog` + `Save-Wallpaper`), статус `status.saved`. В README (оба) и в
руководстве (оба) кнопки нет, при этом `docs/guide.md` начинается словами «This
guide covers everything the window does». В таблице кнопок руководства 6 строк,
в окне 14 кнопок (`btn.*` в `lib\Strings.ps1:9-22`).

Там же: не описан параметр `-ConfigPath` (`DesktopGroups.ps1:7, 25-35`) — а он меняет
место хранения конфига, тогда как руководство утверждает, что конфиг всегда лежит
рядом с программой.

**Действие:** добавить кнопку в таблицу «Your own groups»/«Свои группы» (или отдельный
абзац в «Applying the layout»), описать `-ConfigPath` рядом с `-Lang` или убрать
фразу «covers everything».

### M3. В архив попадает `docs/security-tooling.md` — русскоязычная служебная заметка со стёртыми ссылками

Файл есть в ZIP (8066 байт, см. §5) и содержит:

- `dist/DesktopGroups-1.0.0.zip` — пример `curl` для VirusTotal с прошлой версией
  (`docs/security-tooling.md:66`), единственное место, где `1.0.0` выглядит как текущая;
- «с отчётами в `docs/review/`» — каталога в архиве нет (его вырезает и
  `gitattributes export-ignore`, и сам `build-package.ps1`).

В англоязычном пакете («English first») этот документ ещё и единственный
одноязычный. **Действие:** либо исключить из `$include` в `build-package.ps1`,
либо обновить пример на `<version>` и убрать упоминание `docs/review/`.

### M4. Документация на main разошлась с документацией в релизе

`git diff --name-status c0f05a1 HEAD` → изменены `README.md`, `README.ru.md`,
`SECURITY.md`, `SECURITY.ru.md`, добавлены `docs/github-security.md`,
`docs/github-security.ru.md` и отчёты ревью. Пользователь скачивает ZIP (там
документы тега) и читает README на GitHub (там уже другие тексты: SHA256,
SmartScreen, ссылки на `docs/github-security.md`). Для релиза это значит: любой
вывод «документация готова» верен только для тега, а витрина живёт своей жизнью.

**Действие:** либо перевыпуск (v1.1.1) с этими документами, либо явно решить, что
main-документация — «следующая версия», и не ссылаться из неё на артефакты v1.1.0
(см. B1).

### M5. README описывает состав `docs\`, которого в архиве нет

`README.md` / `README.ru.md`, таблица «Project layout» / «Состав проекта»:
«`docs\` — user guide, security notes, **review reports**». В ZIP каталога
`docs\review\` нет (проверено разбором архива). Текущее описание верно для
репозитория, но не для пакета.

**Действие:** убрать «review reports» из описания (или оговорить «в репозитории»).

### M6. В git закоммичен посторонний артефакт сборки

```text
git ls-tree -r --name-only c0f05a1 | Select-String 'tmp-pkg'
→ tmp-pkg-review/DesktopGroups-1.1.0.zip     (80 646 байт, в самом теге v1.1.0)
```

`.gitignore` его не покрывает, `tools\install.ps1:15` (`$skipDirs`) — тоже, то есть
при установке из рабочей копии папка скопируется в `%LOCALAPPDATA%\Programs\DesktopGroups`.
**Действие:** `git rm -r --cached tmp-pkg-review`, добавить в `.gitignore` и `$skipDirs`.

### M7. Точечные расхождения EN/RU

См. §3 — их четыре, все мелкие по объёму, но два меняют смысл (область действия
в SECURITY и рекомендация PSScriptAnalyzer).

## 3. Таблица расхождений EN / RU

Структура пар совпадает: 12 заголовков README, 18 у руководства, 7 у SECURITY;
числа в парах идентичны (100 МБ, 20 бэкапов, 32-бит, 4 КБ, 3/7 дней, 3–7 дней
поддержки версий). Размеры разделов относятся как 0,83–1,14 — систематических
пропусков нет. Реальные расхождения:

| # | Тема | English | Русский | Кто шире | Действие |
|---|---|---|---|---|---|
| 1 | SECURITY, «Scope» / «Область действия» | «code…, the installer, wallpaper generation, registry work and the desktop window handling» | то же + «**фоновые изображения**» | RU | добавить «background images» в EN (или убрать из RU) |
| 2 | README, «Antivirus flags the program» / «Антивирус ругается» | «…you can read exactly what is written (an `LVITEM`/`POINT` structure, nothing else) **and check it with PSScriptAnalyzer**» | предложения про PSScriptAnalyzer нет | EN | добавить фразу в RU |
| 3 | README, «Development» — комментарий к smoke | «# grouping, layout, wallpaper» | «# группы, раскладка, обои, **фон**» | RU | добавить «background» в EN |
| 4 | README, «Background image» — про битые файлы | «Broken images are **reported** and never stored» | «Битые картинки не сохраняются в настройки» (нет «с сообщением») | EN | добавить «с сообщением» в RU |
| 5 | README (уже после тега), «Verify what you downloaded» / «Проверить загруженное» | имя файла зашито: `DesktopGroups-1.1.0.zip` | то же | паритет, но обе версии устареют на 1.1.1 | заменить на `DesktopGroups-<version>.zip` |
| 6 | CHANGELOG 1.1.0 | Added 5 / Fixed 4 | Добавлено 5 / Исправлено 4 | паритет | — |
| 7 | Кнопки в руководстве | «↑ up / ↓ down», «Add icons…», «Remove from group» | «↑ выше / ↓ ниже», «Добавить значки…», «Убрать из группы» | паритет с UI (`Strings.ps1:14-17`, `117-120`) | — |
| 8 | `docs/github-security.md` / `.ru.md` (после тега) | 9 + 5 строк таблиц, 3 + 3 пункта | то же | паритет | — |

## 4. Ссылки и якоря

Скрипт прогнан по снимку тега (8 файлов, 46 ссылок) и по рабочему дереву
(17 файлов, 60 ссылок, включая `docs/review/` и `docs/github-security.*`):

```text
файлов: 17, ссылок: 60
[ФАЙЛ НЕ НАЙДЕН] README.md:55 -> ../../releases
[ФАЙЛ НЕ НАЙДЕН] README.ru.md:55 -> ../../releases
ПРОБЛЕМ: 2
```

**Якоря: битых нет.** Проверены оглавления руководства с кириллицей
(`#установка`, `#язык-интерфейса`, `#фоновый-рисунок`, `#файлы-и-реестр`,
`#вопросы-и-ответы`), английские (`#installation`, `#files-and-registry`,
`#faq`) и новый якорь `SECURITY.md#smartscreen-code-signing-and-why-you-see-a-warning`
с парным `SECURITY.ru.md#smartscreen-подпись-кода-и-почему-появляется-предупреждение`.

| Ссылка | Оценка | Комментарий |
|---|---|---|
| `README.md:55`, `README.ru.md:55` → `../../releases` | не проверяемо локально | относительный путь, файла нет; на GitHub разрешается от blob-пути (`/owner/repo/releases`) и работает. Проверить в браузере не удалось: github.com в песочнице резолвится в приватный адрес (SSRF blocked). Надёжнее — `/releases` |
| `docs/security-tooling.md` → «`docs/review/`» (текстом) | битая для получателя архива | каталога в ZIP нет |
| `docs/security-tooling.md` → `dist/DesktopGroups-1.0.0.zip` (текстом) | устаревшая | версия 1.0.0 |
| `README.md` → `docs/preview.png` | ок | есть в архиве (31224 б) |
| `SECURITY.md` → `docs/security-tooling.md` | ок | есть в архиве |
| `SECURITY.md` → `docs/github-security.md` (после тега) | ок в репозитории | в ZIP v1.1.0 файла нет — но и ссылки в ZIP нет |

## 5. Состав архива

Сборка из снимка тега во временную папку:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-package.ps1 -Output dist
→ DesktopGroups-1.1.0.zip (79 КБ), 20 записей
```

Разбор архива и сверка с опубликованным ассетом:

| Требование | В сборке из тега | В релизе v1.1.0 |
|---|---|---|
| `README.ru.md` | ✔ 11 963 б | ✔ 11 963 б |
| `SECURITY.ru.md` | ✔ 6 605 б | ✔ 6 605 б |
| `docs\guide.md` | ✔ 9 680 б | ✔ 9 680 б |
| `docs\guide.ru.md` | ✔ 15 677 б | ✔ 15 677 б |
| `lib\Strings.ps1` | ✔ 15 632 б | ✔ 15 632 б |
| `config.json` | ✔ отсутствует | ✔ отсутствует |
| `wallpaper.png` | ✔ отсутствует | ✔ отсутствует |
| `backups\` | ✔ отсутствует | ✔ отсутствует |
| `docs\review\` | ✔ отсутствует | ✔ отсутствует |
| `tools\build-package.ps1` | ✔ отсутствует (вырезается) | ✔ отсутствует |

Полный состав (20 файлов): `CHANGELOG.md`, `DesktopGroups.cmd`, `DesktopGroups.ps1`,
`docs/guide.md`, `docs/guide.ru.md`, `docs/preview.png`, `docs/security-tooling.md`,
`install.cmd`, `lib/DesktopIcons.cs`, `lib/Engine.ps1`, `lib/Strings.ps1`, `LICENSE`,
`README.md`, `README.ru.md`, `SECURITY.md`, `SECURITY.ru.md`, `tools/install.ps1`,
`tools/uninstall.ps1`, `uninstall.cmd`, `VERSION`.

Опубликованный ассет **совпадает по составу и размерам** с локальной сборкой
(`gh release download v1.1.0` → те же 20 записей, те же длины). Хеши не совпадают
(локально `sha256:70f85118…`, в релизе `sha256:25ef3c28…`) — это ожидаемо:
`Compress-Archive` не детерминирован (метки времени/порядок), поэтому
воспроизводимость по хешу подтвердить нельзя; именно поэтому `SHA256SUMS.txt`
и нужен — см. B1.

## 6. Версия

| Проверка | Результат | Доказательство |
|---|---|---|
| `VERSION` = 1.1.0 | ✔ | байты `49,46,49,46,48` (+ перевод строки) |
| Заголовок окна берёт версию из `VERSION` | ✔ | `DesktopGroups.ps1:41-43` читает файл, `:358` `T 'app.title' @($script:Version)`; `Strings.ps1:7/110` — шаблон «DesktopGroups {0} …» |
| CHANGELOG 1.1.0 | ✔ 2026-11-10, Added 5 / Fixed 4 в каждом языке | `CHANGELOG.md` |
| CHANGELOG 1.0.0 | ✔ 2026-11-09, Added 5 / Known limitations 3 в каждом языке | `CHANGELOG.md` |
| Тег `v1.1.0` | ✔ annotated, локально и на remote указывает на `c0f05a1` | `git ls-remote --tags origin` → `refs/tags/v1.1.0^{} = c0f05a11f3b…` |
| Тег `v1.0.0` | ✔ есть | там же |
| Релиз опубликован | ✔ `v1.1.0`, Latest, 2026-11-10T00:22Z, ассет 81 525 б | `gh release list/view` |
| `1.0.0` как текущая | ✘ одно место | `docs/security-tooling.md:66` — `… --form file=@dist/DesktopGroups-1.0.0.zip` |
| HEAD = тег | ✘ | на момент ревью HEAD `ae623f0` (плюс незакоммиченные правки кода) — см. M4 |

## 7. Инструкции против кода

Каждое утверждение документации сверено с кодом (`tools\install.ps1`,
`tools\uninstall.ps1`, `lib\Engine.ps1`, `DesktopGroups.ps1`).

| Утверждение документации | Код | Вердикт |
|---|---|---|
| Ставится в `%LOCALAPPDATA%\Programs\DesktopGroups` | `install.ps1:13` | ✔ |
| «Копирует программу» | `install.ps1:30-36`, пропускает `.git/.github/tests/dist/backups/build`, `config.json`, `wallpaper.png`, `*.zip` | ✔ (но `tmp-pkg-review` не пропускается — M6) |
| Ярлык `DesktopGroups.lnk` в меню «Пуск» | `install.ps1:67-69` | ✔ |
| Запись в «Приложения и возможности» | `install.ps1:77-88`, ключ `HKCU\…\Uninstall\DesktopGroups` | ✔ |
| «Запоминает текущие обои в `previous-wallpaper.json`» | `install.ps1:41-52`, повторно не перезаписывает | ✔ |
| «Четыре вещи» (ровно 4) | те же четыре шага | ✔ |
| Ярлык на рабочем столе — только по флагу | `install.ps1:71-75` (`-DesktopShortcut`); SECURITY: «desktop (opt-in)» | ✔; README флаг не упоминает |
| Права администратора не нужны | ни `-Verb RunAs`, ни `#Requires -RunAsAdministrator`; пишутся только `HKCU` | ✔ |
| «Разблокировать» ZIP в свойствах / `Unblock-File` | `install.ps1` файлы не разблокирует — это делает пользователь | ✔ (инструкция честная) |
| Лимит фона 100 МБ | `Engine.ps1:395` `MaxBytes = 104857600`, `:402` сообщение с МБ | ✔ |
| Ротация 20 бэкапов | `Engine.ps1:721-725` `Sort-Object LastWriteTime -Descending | Select-Object -Skip 20` | ✔ (20 включая только что созданный) |
| Бэкап перед каждым применением | `Engine.ps1:706-719` внутри `Invoke-DesktopLayout`, до записи позиций | ✔ |
| `config.bad-<дата>-<время>.json` | `DesktopGroups.ps1:97` `'config.bad-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss')` | ✔ |
| `WallpaperStyle` в реестре | `Engine.ps1:556-563`: `WallpaperStyle='10'`, `TileWallpaper='0'`, `Wallpaper=<путь>` + `SystemParametersInfo` | ✔ (документация значение 10 не называет — расхождения нет) |
| Обои рисуются в размере экрана | `DesktopGroups.ps1:823` передаёт `$script:Screen.width/height`; дефолты `1920/1080` в `Engine.ps1:420-421` недостижимы | ✔ |
| Проверка «Упорядочить автоматически» с остановкой | `DesktopGroups.ps1:807-810` `Test-AutoArrange` → сообщение и `return` | ✔ |
| «Вернуть прошлую раскладку» — самый свежий бэкап | `DesktopGroups.ps1:862-888`, сортировка + сообщение `msg.noBackups` | ✔ |
| Удаление группы → значки в «Прочее» | `DesktopGroups.ps1:646-654`, `dlg.deleteText` «…вернутся в „Прочее“» | ✔ |
| Дубли имён отклоняются | `DesktopGroups.ps1:609/634`, `msg.exists` | ✔ |
| Конфиг пишется атомарно | `DesktopGroups.ps1:71-79` (tmp + `Move-Item -Force`) | ✔ |
| Битый конфиг не перезаписывается, а переименовывается | `DesktopGroups.ps1:94-101` | ✔ |
| Битые картинки не попадают в конфиг | `DesktopGroups.ps1:768-778` (проверка `Get-BackgroundImage` до `Save-Config`) | ✔ |
| «Нет прав администратора, нет сети» | нет `Invoke-WebRequest/RestMethod/WebClient/HttpClient` | ✔ |
| Отказ под 32-битным PowerShell | `Engine.ps1:13-17` | ✔ (SECURITY это утверждает, README — нет) |
| Только основной монитор | `Get-ScreenInfo` работает с primary; в README не сказано | ✔ код, ✘ витрина (M1) |
| «Удаление восстанавливает прежние обои» | `uninstall.ps1:29-55` — условно, иначе стандартные обои; каталог удаляется целиком | ✘ (B2) |
| «`docs\` — guide, security notes, review reports» | в архиве `docs\review\` нет | ✘ (M5) |
| «Руководство покрывает всё, что делает окно» | кнопка «Сохранить обои в файл…», параметр `-ConfigPath` не описаны | ✘ (M2) |
| «Всё видно в трёх файлах» | четвёртый — `lib\DesktopIcons.cs` | ✘ (B3) |

Отдельно: русский текст сообщения в самом окне (`Strings.ps1:81`) советует
«правый клик по столу → **Упорядочить значки** → снять „Упорядочить автоматически“»,
а документация — «**Вид** → снять» (правильный путь в Windows). Расхождение
в пользу документации: править нужно строку интерфейса, не документ.

## 8. CI

`.github/workflows/ci.yml`, порядок шагов (windows-latest):

| # | Шаг | Что запускает | Обязательный по задаче |
|---|---|---|---|
| 1 | Кодировка и разбор (PowerShell 5.1) | `powershell.exe … tests\check-encoding.ps1` | ✔ |
| 2 | Кодировка и разбор (PowerShell 7) | `.\tests\check-encoding.ps1` | ✔ (тот же тест под 7) |
| 3 | Установка PSScriptAnalyzer 1.25.0 | `Install-Module` | — |
| 4 | Статический анализ | `Invoke-ScriptAnalyzer … -Severity Error, Warning`, падение только на Error | — |
| 5 | Smoke-тесты | `tests\smoke.ps1` | ✔ |
| 6 | Полнота переводов | `tests\i18n.ps1` | ✔ (новый тест 1.1.0) |
| 7 | Фаззинг config.json | `tests\fuzz-config.ps1` | ✔ (новый тест 1.1.0) |
| 8 | Сборка релизного архива | `tools\build-package.ps1 -Output dist` | ✔ |
| 9 | Архив как артефакт | `upload-artifact`, `if-no-files-found: error` | — |

Все пять требуемых проверок есть, новые (`i18n.ps1`, `fuzz-config.ps1`) на месте,
сборка идёт после тестов. Замечания:

- `release.yml` перед публикацией запускает только `check-encoding`, `smoke`, `i18n` —
  **`fuzz-config` в релизных воротах нет** (в CI есть). Логично добавить.
- CI не проверяет состав архива (что `README.ru.md`/`SECURITY.ru.md`/`guide.ru.md`
  внутри). Косвенно закрыто: `build-package.ps1` бросает исключение, если файла нет.
- Последний запуск workflow `Release` (`workflow_dispatch`, 03:07) — **failure**;
  следующий коммит `ae623f0` как раз чинит проверку кода возврата `gh`.
- README-утверждение «these run in CI» для четырёх скриптов — верно.

## 9. Чек-лист релиза

| Пункт | Статус | Чем подтверждено |
|---|---|---|
| `VERSION` = 1.1.0, единственный источник версии | ✔ | `VERSION`, `DesktopGroups.ps1:41-43` |
| Заголовок окна показывает 1.1.0 | ✔ | `:358` |
| CHANGELOG: запись 1.1.0 двуязычная и полная | ✔ | 5 Added / 4 Fixed в обоих языках |
| CHANGELOG: предыдущая 1.0.0 на месте | ✔ | раздел от 2026-11-09 |
| Тег `v1.1.0` существует и указывает на релизный коммит | ✔ | `c0f05a1`, локально и на remote |
| Пакет собирается из тега одной командой | ✔ | `build-package.ps1 -Output dist` → 20 файлов |
| В пакете есть `README.ru.md`, `SECURITY.ru.md`, оба guide, `lib\Strings.ps1` | ✔ | разбор ZIP |
| В пакете нет `config.json`, `wallpaper.png`, `backups\`, `docs\review\` | ✔ | разбор ZIP |
| Опубликованный ассет совпадает с локальной сборкой | ✔ по составу | 20 записей, те же размеры |
| `SHA256SUMS.txt` рядом с релизом | ✘ | в релизе только ZIP |
| Аттестация происхождения | ✘ | `gh attestation verify` → 404 |
| Документация описывает удаление без потери данных | ✘ | B2 |
| SECURITY-«полный список» соответствует коду | ✘ | B3 |
| README содержит ограничения | ✘ | M1 |
| Опубликованные документы = документы в репозитории | ✘ | M4 (main ушёл вперёд) |
| В репозитории нет артефактов сборки | ✘ | `tmp-pkg-review/DesktopGroups-1.1.0.zip` в теге |
| CI зелёный на релизном коммите | ⚠ не проверялось | нужен доступ к Actions API по `c0f05a1`; последний `Release` run — failure |
| Парность EN/RU по структуре и числам | ✔ | §3: заголовки и числа совпадают |
| Якоря и относительные ссылки | ✔ (кроме `../../releases`, см. §4) | скрипт проверки |

## 10. Оценка

**Почти готово.** Документация — сильная часть релиза: пары EN/RU совпадают по
структуре и числам, кириллические якоря и оглавления живые, архив собран правильно
и совпадает с опубликованным ассетом, версия берётся из одного места, CHANGELOG
двуязычный и симметричный, CI покрывает все пять требуемых проверок.

«Готово» не позволяет сказать три блокера: обещание `SHA256SUMS.txt`/аттестации,
которого у v1.1.0 нет; молчаливое удаление `config.json` и `backups\` при
деинсталляции вместе с подменой обоев на стандартные; и SECURITY, который
заявляет полноту списка, но не упоминает чтение `Shell\Bags`, перебор папок
рабочего стола и целый файл с `WriteProcessMemory`.

Порядок действий:

1. `SECURITY.md` + `.ru.md`: две строки в таблицу и «четыре файла» (правка текста, ~15 минут).
2. README + guide (оба языка): раздел «Ограничения» и предупреждение об удалении.
3. Руководство: кнопка «Сохранить обои в файл…», `-ConfigPath`, фраза «covers everything».
4. `docs/security-tooling.md`: `<version>` вместо 1.0.0, убрать `docs/review/` или исключить файл из архива.
5. `git rm --cached tmp-pkg-review` + `.gitignore` + `$skipDirs`.
6. Перевыпуск `v1.1.1` из обновлённого `release.yml`, затем
   `gh attestation verify` и `Get-FileHash` против `SHA256SUMS.txt` — это закрывает B1 и M4 разом.
