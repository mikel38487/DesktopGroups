# Changelog

Format — [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning — [Semantic Versioning](https://semver.org/).
Each release is written twice: English first, then Russian.

## [1.1.1] — 2026-11-10

### Fixed (English)

- **WEBP was promised but never worked.** GDI+ has no WebP decoder, so the file was
  always rejected. Removed from the file filter and from all documentation;
  README, guide and this changelog no longer mention it.
- **Phone photos no longer land sideways.** The EXIF orientation tag is applied
  before scaling, so portrait shots are not rotated 90°.
- **Decompression bombs are rejected.** A small PNG can unpack into gigabytes:
  images above 100 megapixels are refused before any allocation.
- **Transparent PNGs no longer show black areas.** The gradient is painted first and
  the photo goes on top, so transparent regions reveal the background.
- **Broken or truncated images are rejected when picked**, not later during drawing.
- **A background that cannot be read no longer leaves a lying label.** The path is
  validated on load and cleared with an explanation.
- **If the background fails during apply, the status line says so** instead of
  silently falling back to the gradient.
- **Preview matches the wallpaper**: same veil, and the image is cached instead of
  being decoded on every repaint.
- **Uninstall no longer throws away your groups.** `config.json` is copied to
  `%APPDATA%\DesktopGroups` before the folder is deleted; a portable copy requires
  `-Force`, because the whole unpacked folder is removed. Documented.
- **Localized engine errors.** Messages from the engine are taken from the string
  table, so an English interface no longer shows Russian text.
- **Wrong menu path in the Russian hint** for turning off auto-arrange: it is
  *View → «Упорядочить значки автоматически»*, not *«Упорядочить значки»*.
- **The special "Misc" group follows the interface language** whichever way the
  language arrived: the selector, `-Lang`, or `config.json`.
- **The help block no longer clips its last line**; the label height is measured.
- **The wallpaper save dialog** has a translated title and filter.

### Added (English)

- Verified release artifacts: `SHA256SUMS.txt` and a signed build-provenance
  attestation (`gh attestation verify`).
- Repository guards: Dependabot alerts and security updates, private vulnerability
  reporting, OpenSSF Scorecard, a `main` ruleset blocking deletion and force-push,
  and all GitHub Actions pinned to commit SHAs.
- `docs/github-security.md` — what is enabled, what cannot be, and how to verify.
- `SECURITY.md` — a section on SmartScreen, signing options and why the warning appears.

---

### Исправлено (русский)

- **WEBP обещался, но не работал.** В GDI+ нет декодера WebP, файл всегда
  отклонялся. Убран из фильтра и из всей документации.
- **Снимки с телефона больше не ложатся боком.** EXIF-ориентация применяется
  до масштабирования.
- **«Декомпрессионные бомбы» отклоняются.** Маленький PNG может развернуться
  в гигабайты: картинки больше 100 МП отсекаются до выделения памяти.
- **Прозрачные PNG больше не дают чёрных областей.** Сначала рисуется градиент,
  фото ложится поверх, и прозрачность показывает фон.
- **Битые и обрезанные картинки отклоняются при выборе**, а не при отрисовке.
- **Нечитаемый фон больше не оставляет врущую подпись**: путь проверяется
  при загрузке и очищается с объяснением.
- **Если фон не применился при раскладке, это видно в строке состояния**,
  а не молчаливый откат к градиенту.
- **Предпросмотр совпадает с обоями**: та же вуаль, картинка кешируется вместо
  повторного декодирования на каждой перерисовке.
- **Удаление больше не теряет группы.** `config.json` копируется в
  `%APPDATA%\DesktopGroups` до удаления каталога; для портативной копии нужен
  `-Force`, потому что удаляется вся папка. Описано в документации.
- **Ошибки движка переведены.** Сообщения берутся из таблицы строк, и в
  английском интерфейсе больше нет русского текста.
- **Исправлен путь в русской подсказке** про автоупорядочивание: это
  *Вид → «Упорядочить значки автоматически»*, а не *«Упорядочить значки»*.
- **Служебная группа «Прочее»/«Misc» следует языку интерфейса** независимо от
  источника: комбобокс, `-Lang` или `config.json`.
- **Справка больше не обрезает последнюю строку** — высота считается по тексту.
- **Диалог сохранения обоев** получил переведённые заголовок и фильтр.

### Добавлено (русский)

- Проверяемые артефакты релиза: `SHA256SUMS.txt` и подписанная аттестация
  происхождения (`gh attestation verify`).
- Защиты репозитория: Dependabot-алерты и автоисправления, приватные отчёты
  об уязвимостях, OpenSSF Scorecard, ruleset на `main` с запретом удаления и
  force-push, все GitHub Actions закреплены по SHA коммита.
- `docs/github-security.ru.md` — что включено, чего не бывает и как проверить.
- `SECURITY.ru.md` — раздел про SmartScreen, варианты подписи и причины
  предупреждения.

## [1.1.0] — 2026-11-10

### Added (English)

- **Two interface languages**: Russian and English, switched in the window and
  remembered in `config.json`. The default follows the language of Windows.
  Suggested group names and the special "Misc" group are localised too.
- **Custom background image**: any PNG, JPEG, BMP or GIF picture can be placed
  under the frames. It is scaled to fill the screen with a centre crop, dimmed with
  a vertical veil for readability, and the frames and labels are drawn on top.
  A "No background" button returns to the default gradient.
- New `lib\Strings.ps1` with the full string table for both languages.
- `tests\i18n.ps1` — checks that both languages have the same keys, that no string
  is empty, that every key used in the code exists, and that parameter substitution
  works (including the zero case).
- Bilingual documentation: `README.md` / `README.ru.md`,
  `docs/guide.md` / `docs/guide.ru.md`, `SECURITY.md` / `SECURITY.ru.md`.

### Fixed (English)

- Empty counters showed `{0}` instead of `0` — an array containing a single zero is
  falsy in PowerShell, so substitution was silently skipped.
- The interface language could fall back to the system one at startup because
  WinForms delivers `SelectedIndexChanged` asynchronously; pending events are now
  drained while the guard is still active.
- The `-Lang` parameter was overwritten by the dot-sourced string table: the state
  variable used to share a name with the script parameter. Renamed to `UiLanguage`.
- Background image files are read into memory instead of opening the file, so the
  picture is never locked and can be moved or deleted later.

---

### Добавлено (русский)

- **Два языка интерфейса**: русский и английский, переключаются в окне и
  запоминаются в `config.json`. По умолчанию берётся язык Windows.
  Предлагаемые названия групп и служебная группа «Прочее» тоже локализованы.
- **Свой фоновый рисунок**: любая картинка PNG, JPEG, BMP или GIF ложится
  под рамки. Она растягивается на экран с обрезкой по центру, затемняется
  вертикальной вуалью для читаемости, а рамки и подписи рисуются поверх.
  Кнопка «Без фона» возвращает градиент по умолчанию.
- Новый `lib\Strings.ps1` с полной таблицей строк для обоих языков.
- `tests\i18n.ps1` — проверяет, что в обоих языках одинаковый набор ключей, нет
  пустых строк, все ключи из кода существуют и подстановка параметров работает
  (включая случай нуля).
- Документация на двух языках: `README.md` / `README.ru.md`,
  `docs/guide.md` / `docs/guide.ru.md`, `SECURITY.md` / `SECURITY.ru.md`.

### Исправлено (русский)

- Пустые счётчики показывали `{0}` вместо `0`: массив из одного нуля ложен
  в PowerShell, и подстановка молча пропускалась.
- Язык интерфейса мог откатиться на системный при старте, потому что WinForms
  доставляет `SelectedIndexChanged` отложенно; теперь очередь сообщений
  прокручивается, пока защита ещё включена.
- Параметр `-Lang` затирался подключённой таблицей строк: переменная состояния
  называлась так же, как параметр скрипта. Переименована в `UiLanguage`.
- Файлы фоновых картинок читаются в память, а не открываются как файл, поэтому
  картинка не блокируется и её можно потом перенести или удалить.

## [1.0.0] — 2026-11-09

### Added (English)

- Scanning of desktop shortcuts, internet links, folders and files (own desktop
  and the shared `Public` one).
- Automatic group suggestions by name: games, development & AI, chat & internet,
  media, network & VPN, hardware, installers, system, everything else.
- Custom groups: create, rename, delete, reorder, move icons between groups.
- Rectangle layout with block-shape selection (fewest empty cells) and band packing.
- Wallpaper generation at screen size with rounded frames, per-group colour and labels.
- Icon placement through the desktop list view's `LVM_*` messages inside
  `explorer.exe`, with no Explorer restart.
- Backups of icon positions before every apply, verification afterwards, and a
  one-click restore of the previous layout.
- Guard against "Auto arrange icons", which would move icons and break the frames.
- Install without compilation: `install.cmd` copies the program to the user profile,
  creates a Start Menu shortcut and an entry in *Apps & features*; `uninstall.cmd`
  removes it and restores the previous wallpaper.
- Smoke tests that never touch the desktop, config fuzzing, and PSScriptAnalyzer
  settings for CI.

### Known limitations (English)

- Primary monitor only.
- No drag & drop on the desktop itself: groups are edited in the window.
- The wallpaper is referenced by path, so `wallpaper.png` must not be deleted.

---

### Добавлено (русский)

- Сканирование ярлыков, интернет-ссылок, папок и файлов рабочего стола
  (своего и общего `Public`).
- Автоматическое предложение групп по именам: игры, разработка и AI,
  связь и интернет, медиа, сеть и VPN, оборудование, установщики, система, прочее.
- Свои группы: создание, переименование, удаление, изменение порядка,
  перенос значков между группами.
- Раскладка прямоугольниками с подбором формы блока (минимум пустых ячеек)
  и паковкой в полосы.
- Генерация обоев в размере экрана: скруглённые рамки, цвет группы, подписи.
- Расстановка значков через сообщения `LVM_*` списку значков внутри
  `explorer.exe`, без перезапуска Explorer.
- Бэкап позиций перед каждым применением, проверка после, восстановление
  прошлой раскладки одной кнопкой.
- Защита от «Упорядочить автоматически»: иначе Windows переставит значки
  и рамки разъедутся.
- Установка без компиляции: `install.cmd` копирует программу в профиль,
  создаёт ярлык в «Пуске» и запись в списке приложений; `uninstall.cmd` удаляет
  и возвращает прежние обои.
- Smoke-тесты без рабочего стола, фаззинг конфига и настройки PSScriptAnalyzer
  для CI.

### Известные ограничения (русский)

- Только основной монитор.
- Перетаскивания мышью по рабочему столу нет: группы правятся в окне.
- Обои ссылаются на файл по пути, поэтому `wallpaper.png` нельзя удалять.
