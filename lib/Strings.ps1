# Strings.ps1 — двуязычные строки интерфейса DesktopGroups.
# Ключи общие для обоих языков; тест tests\i18n.ps1 проверяет, что наборы совпадают.

$script:StringTable = @{

    ru = @{
        'app.title'              = 'DesktopGroups {0} — группы ярлыков рабочего стола'

        'btn.scan'               = 'Сканировать стол'
        'btn.propose'            = 'Предложить группы'
        'btn.new'                = 'Новая'
        'btn.rename'             = 'Переименовать'
        'btn.delete'             = 'Удалить'
        'btn.up'                 = '↑ выше'
        'btn.down'               = '↓ ниже'
        'btn.add'                = 'Добавить значки…'
        'btn.remove'             = 'Убрать из группы'
        'btn.apply'              = 'Разложить значки и обновить обои'
        'btn.saveWall'           = 'Сохранить обои в файл…'
        'btn.restore'            = 'Вернуть прошлую раскладку'
        'btn.bg'                 = 'Фоновый рисунок…'
        'btn.bgClear'            = 'Без фона'

        'grp.groups'             = 'Группы'
        'grp.items'              = 'Значки группы'
        'grp.itemsOf'            = 'Значки группы «{0}»'
        'grp.preview'            = 'Предпросмотр раскладки'
        'grp.apply'              = 'Применить'

        'lbl.lang'               = 'Язык:'
        'lbl.unassigned'         = 'Вне групп: {0}'
        'lbl.top'                = 'Значков на столе: {0}   Групп: {1}'
        'lbl.previewInfo'        = 'Блоков: {0}   Значков: {1}'
        'lbl.previewEmpty'       = 'Групп с ярлыками нет'
        'lbl.overflowNote'       = '   ВНИМАНИЕ: не влезает на экран'
        'lbl.bgNone'             = 'Фон: градиент'
        'lbl.bgSet'              = 'Фон: {0}'
        'lbl.help'               = @"
Как это работает

1. «Сканировать стол» — читает значки, папки и файлы.
2. «Предложить группы» — раскладывает значки по именам.
3. Свои группы: «Новая», «Переименовать», «Удалить»,
   стрелки меняют порядок блоков.
4. «Фоновый рисунок…» — картинка под рамками.
5. «Разложить значки и обновить обои» — расставляет
   значки и рисует рамки с подписями.
"@

        'hint.order'             = 'Порядок значков внутри группы — порядок в списке.'

        'status.ready'           = 'Готово'
        'status.scanning'        = 'Сканирую рабочий стол…'
        'status.scanned'         = 'Найдено значков: {0}. Группы сохранены, новые — в «{1}».'
        'status.proposed'        = 'Предложено групп: {0}'
        'status.created'         = 'Создана группа «{0}»'
        'status.renamed'         = 'Группа переименована в «{0}»'
        'status.deleted'         = 'Группа удалена'
        'status.added'           = 'Добавлено значков: {0}'
        'status.removed'         = 'Убрано значков: {0}'
        'status.applying'        = 'Применяю раскладку…'
        'status.applied'         = 'Расставлено: {0}, проходов: {1}'
        'status.applyMismatch'   = '; не встало: {0}'
        'status.applyUnknown'    = '; вне плана: {0}'
        'status.applyNoWall'     = '; обои применились не сразу'
        'status.restored'        = 'Возвращены позиции из {0}: значков {1}, расхождений {2}'
        'status.saved'           = 'Обои сохранены: {0}'
        'status.bgChosen'        = 'Фоновый рисунок: {0}'
        'status.bgCleared'       = 'Фоновый рисунок убран'
        'status.error'           = 'Ошибка: {0}'
        'status.restoreError'    = 'Ошибка восстановления: {0}'
        'status.overview'        = 'Значков: {0}. Сетка {1}×{2}. Версия {3}. Конфиг: {4}'
        'status.gridFallback'    = 'сетка по умолчанию: {0}'
        'status.unresolved'      = 'не найдено на столе: {0}'
        'status.langSet'         = 'Язык интерфейса: русский'
        'status.bgFailed'        = 'фон не применился: {0}'

        'msg.applyTitle'         = 'Применить'
        'msg.replaceTitle'       = 'Предложить группы'
        'msg.replaceText'        = 'Заменить текущие группы предложенными?'
        'msg.noGroups'           = 'Нет групп со значками.'
        'msg.autoArrange'        = "На рабочем столе включено автоматическое упорядочивание значков — Windows переставит их, и рамки разъедутся.`r`n`r`nВыключите его: правый клик по столу → Вид → снять «Упорядочить значки автоматически». Потом повторите."
        'msg.overflow'           = 'Блоки не влезают на экран. Продолжить?'
        'msg.noBackups'          = 'Бэкапов ещё нет: они создаются при каждом применении раскладки.'
        'msg.restoreTitle'       = 'Восстановить'
        'msg.badConfig'          = "Файл настроек повреждён и сохранён как:`r`n{0}`r`n`r`nГруппы предложены заново. Проверьте их и нажмите «Применить» — тогда новый конфиг будет записан."
        'msg.settingsTitle'      = 'Настройки'
        'msg.exists'             = 'Группа с таким названием уже есть.'
        'msg.errorTitle'         = 'Ошибка'
        'msg.startupFail'        = "Программа не смогла запуститься: {0}`r`n`r`nПодробности: {1}"
        'msg.backupRead'         = 'Не удалось прочитать бэкап: {0}'

        'dlg.newGroupTitle'      = 'Новая группа'
        'dlg.newGroupPrompt'     = 'Название новой группы'
        'dlg.newGroupDefault'    = 'Моя группа'
        'dlg.renameTitle'        = 'Переименовать'
        'dlg.renamePrompt'       = 'Новое название группы'
        'dlg.deleteTitle'        = 'Удалить'
        'dlg.deleteText'         = 'Удалить группу «{0}»? Значки вернутся в «{1}».'
        'dlg.addTitle'           = 'Добавить значки в «{0}»'
        'dlg.addButton'          = 'Добавить'
        'dlg.cancel'             = 'Отмена'
        'dlg.noFree'             = 'Свободных значков нет — все уже в группах.'
        'dlg.bgFilter'           = 'Изображения|*.png;*.jpg;*.jpeg;*.bmp;*.gif|Все файлы|*.*'
        'dlg.bgTitle'            = 'Фоновый рисунок обоев'
        'dlg.wallTitle'          = 'Куда сохранить обои'
        'dlg.wallFilter'         = 'PNG|*.png'

        'err.noView'             = 'Не найден список значков рабочего стола (SysListView32)'
        'err.openProcess'        = 'Не удалось открыть процесс explorer.exe'
        'err.alloc'              = 'Не удалось выделить память в explorer.exe'
        'err.write'              = 'WriteProcessMemory не удался'
        'err.read'               = 'ReadProcessMemory не удался'
        'err.imageTooBig'        = 'файл фона слишком большой: {0} МБ'
        'err.imageRead'          = 'не удалось прочитать изображение'
        'err.imageTooManyPixels' = 'картинка слишком большая по размерам: {0} МП'
        'err.bitness'            = 'DesktopGroups требует 64-битный PowerShell: под 32-битным хостом структура LVITEM не совпадает с explorer.exe'

        'group.other'            = 'Прочее'
    }

    en = @{
        'app.title'              = 'DesktopGroups {0} — desktop shortcut groups'

        'btn.scan'               = 'Scan desktop'
        'btn.propose'            = 'Suggest groups'
        'btn.new'                = 'New'
        'btn.rename'             = 'Rename'
        'btn.delete'             = 'Delete'
        'btn.up'                 = '↑ up'
        'btn.down'               = '↓ down'
        'btn.add'                = 'Add icons…'
        'btn.remove'             = 'Remove from group'
        'btn.apply'              = 'Lay out icons and update wallpaper'
        'btn.saveWall'           = 'Save wallpaper to file…'
        'btn.restore'            = 'Restore previous layout'
        'btn.bg'                 = 'Background image…'
        'btn.bgClear'            = 'No background'

        'grp.groups'             = 'Groups'
        'grp.items'              = 'Icons in group'
        'grp.itemsOf'            = 'Icons in «{0}»'
        'grp.preview'            = 'Layout preview'
        'grp.apply'              = 'Apply'

        'lbl.lang'               = 'Language:'
        'lbl.unassigned'         = 'Not in groups: {0}'
        'lbl.top'                = 'Icons on desktop: {0}   Groups: {1}'
        'lbl.previewInfo'        = 'Blocks: {0}   Icons: {1}'
        'lbl.previewEmpty'       = 'No groups with icons'
        'lbl.overflowNote'       = '   WARNING: does not fit the screen'
        'lbl.bgNone'             = 'Background: gradient'
        'lbl.bgSet'              = 'Background: {0}'
        'lbl.help'               = @"
How it works

1. "Scan desktop" — reads shortcuts, folders and files.
2. "Suggest groups" — sorts icons into groups by name.
3. Your own groups: "New", "Rename", "Delete";
   the arrows change block order.
4. "Background image…" — a picture under the frames.
5. "Lay out icons and update wallpaper" — places
   the icons and draws the frames with labels.
"@

        'hint.order'             = 'Icon order inside a group is the order in the list.'

        'status.ready'           = 'Ready'
        'status.scanning'        = 'Scanning the desktop…'
        'status.scanned'         = 'Icons found: {0}. Groups kept, new ones go to "{1}".'
        'status.proposed'        = 'Groups suggested: {0}'
        'status.created'         = 'Group «{0}» created'
        'status.renamed'         = 'Group renamed to «{0}»'
        'status.deleted'         = 'Group deleted'
        'status.added'           = 'Icons added: {0}'
        'status.removed'         = 'Icons removed: {0}'
        'status.applying'        = 'Applying the layout…'
        'status.applied'         = 'Placed: {0}, passes: {1}'
        'status.applyMismatch'   = '; not placed: {0}'
        'status.applyUnknown'    = '; outside the plan: {0}'
        'status.applyNoWall'     = '; wallpaper did not apply at once'
        'status.restored'        = 'Restored positions from {0}: icons {1}, mismatches {2}'
        'status.saved'           = 'Wallpaper saved: {0}'
        'status.bgChosen'        = 'Background image: {0}'
        'status.bgCleared'       = 'Background image cleared'
        'status.error'           = 'Error: {0}'
        'status.restoreError'    = 'Restore failed: {0}'
        'status.overview'        = 'Icons: {0}. Grid {1}×{2}. Version {3}. Config: {4}'
        'status.gridFallback'    = 'default grid: {0}'
        'status.unresolved'      = 'not found on the desktop: {0}'
        'status.langSet'         = 'Interface language: English'
        'status.bgFailed'        = 'background was not applied: {0}'

        'msg.applyTitle'         = 'Apply'
        'msg.replaceTitle'       = 'Suggest groups'
        'msg.replaceText'        = 'Replace the current groups with the suggested ones?'
        'msg.noGroups'           = 'No groups with icons.'
        'msg.autoArrange'        = "Auto arrange icons is turned on, so Windows will move the icons and the frames will no longer match.`r`n`r`nTurn it off: right-click the desktop → View → uncheck Auto arrange icons. Then try again."
        'msg.overflow'           = 'The blocks do not fit the screen. Continue?'
        'msg.noBackups'          = 'No backups yet: they are created on every layout apply.'
        'msg.restoreTitle'       = 'Restore'
        'msg.badConfig'          = "The settings file is damaged and saved as:`r`n{0}`r`n`r`nGroups were suggested again. Check them and press «Apply» — the new config will be written then."
        'msg.settingsTitle'      = 'Settings'
        'msg.exists'             = 'A group with this name already exists.'
        'msg.errorTitle'         = 'Error'
        'msg.startupFail'        = "The program could not start: {0}`r`n`r`nDetails: {1}"
        'msg.backupRead'         = 'Could not read the backup: {0}'

        'dlg.newGroupTitle'      = 'New group'
        'dlg.newGroupPrompt'     = 'Name of the new group'
        'dlg.newGroupDefault'    = 'My group'
        'dlg.renameTitle'        = 'Rename'
        'dlg.renamePrompt'       = 'New group name'
        'dlg.deleteTitle'        = 'Delete'
        'dlg.deleteText'         = 'Delete the group {0}? Its icons will move to {1}.'
        'dlg.addTitle'           = 'Add icons to «{0}»'
        'dlg.addButton'          = 'Add'
        'dlg.cancel'             = 'Cancel'
        'dlg.noFree'             = 'No free icons — everything is already in groups.'
        'dlg.bgFilter'           = 'Images|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files|*.*'
        'dlg.bgTitle'            = 'Wallpaper background image'
        'dlg.wallTitle'          = 'Save the wallpaper as'
        'dlg.wallFilter'         = 'PNG|*.png'

        'err.noView'             = 'Desktop icon list (SysListView32) not found'
        'err.openProcess'        = 'Could not open explorer.exe'
        'err.alloc'              = 'Could not allocate memory in explorer.exe'
        'err.write'              = 'WriteProcessMemory failed'
        'err.read'               = 'ReadProcessMemory failed'
        'err.imageTooBig'        = 'background file is too large: {0} MB'
        'err.imageRead'          = 'could not read the image'
        'err.imageTooManyPixels' = 'image is too large in pixels: {0} MP'
        'err.bitness'            = 'DesktopGroups requires 64-bit PowerShell: under a 32-bit host the LVITEM structure does not match explorer.exe'

        'group.other'            = 'Misc'
    }
}

function Get-SystemLanguage {
    # Порядок источников:
    # 1) PreferredUILanguages — язык отображения Windows, если задан явно;
    # 2) InstalledUICulture — язык установки (в PowerShell 5.1 CurrentUICulture
    #    всегда en-US, поэтому он не годится).
    try {
        $pref = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name PreferredUILanguages -ErrorAction Stop).PreferredUILanguages
        if ($pref) {
            $first = @($pref)[0]
            if ($first -like 'ru*') { return 'ru' }
            if ($first -like 'en*') { return 'en' }
        }
    }
    catch {
        Write-Verbose 'PreferredUILanguages недоступен — смотрим язык установки'
    }

    $c = [System.Globalization.CultureInfo]::InstalledUICulture
    if ($c -and $c.TwoLetterISOLanguageName -eq 'ru') { return 'ru' }
    return 'en'
}

function Test-StringKey {
    param([string]$Key)
    if (-not $Key) { return $false }
    $table = $script:StringTable[$script:UiLanguage]
    if ($table -and $table.ContainsKey($Key)) { return $true }
    return ($script:StringTable['en'].ContainsKey($Key))
}

function Test-LanguageCode {
    param([string]$Code)
    return ($Code -eq 'ru' -or $Code -eq 'en')
}

function Set-Language {
    param([string]$Code)
    if (Test-LanguageCode $Code) { $script:UiLanguage = $Code }
    else { $script:UiLanguage = Get-SystemLanguage }
}

function T {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [object[]]$Values
    )

    $table = $script:StringTable[$script:UiLanguage]
    if (-not $table) { $table = $script:StringTable['en'] }

    $text = $table[$Key]
    if (-not $text) { $text = $script:StringTable['en'][$Key] }
    if (-not $text) { return "[$Key]" }

    # Проверяем только на null и пустоту: массив из одного нуля (@(0))
    # в логическом контексте PowerShell считается ложью, и подстановка
    # молча пропускалась бы — тогда в подписи осталось бы «{0}».
    if ($null -ne $Values -and $Values.Count -gt 0) {
        try { return ($text -f $Values) }
        catch { return $text }
    }
    return $text
}

# Все ключи обоих языков — для теста полноты переводов
function Get-StringKeys {
    param([string]$Lang)
    return @($script:StringTable[$Lang].Keys | Sort-Object)
}

Set-Language (Get-SystemLanguage)
