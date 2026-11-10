# DesktopGroups — группировка ярлыков рабочего стола с подписями на обоях.
# Интерфейс на русском и английском: язык берётся из config.json, из параметра
# -Lang или из локали Windows, и переключается в окне.
# Запуск: DesktopGroups.cmd (или powershell.exe -STA -File DesktopGroups.ps1)

param(
    [string]$ConfigPath,
    [string]$Lang
)



Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# Строки подключаем раньше движка: движок при загрузке проверяет разрядность
# и берёт текст ошибки из таблицы.
. (Join-Path $PSScriptRoot 'lib\Strings.ps1')
. (Join-Path $PSScriptRoot 'lib\Engine.ps1')


[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppDir = $PSScriptRoot
$script:ConfigNote = ''
if ($ConfigPath) {
    $full = [IO.Path]::GetFullPath($ConfigPath)
    if ([IO.Path]::GetExtension($full) -eq '.json') {
        $script:ConfigPath = $full
    }
    else {
        # не даём писать JSON куда угодно: параметр принимаем только для .json
        $script:ConfigPath = Join-Path $script:AppDir 'config.json'
        $script:ConfigNote = 'config-path-ignored'
    }
}
else {
    $script:ConfigPath = Join-Path $script:AppDir 'config.json'
}

$script:BackupDir = Join-Path $script:AppDir 'backups'
$script:Version = '0.0.0'
$verFile = Join-Path $script:AppDir 'VERSION'
if (Test-Path -LiteralPath $verFile) { $script:Version = (Get-Content -LiteralPath $verFile -Raw).Trim() }

$script:Groups = New-Object System.Collections.ArrayList
$script:Items = @()
$script:Screen = Get-ScreenInfo
$script:Grid = Get-DefaultGrid
$script:BackgroundImage = ''
# кеш фона для предпросмотра: файл перечитывается только при смене пути
# или времени изменения, а не на каждой перерисовке
$script:PreviewBgImage = $null
$script:PreviewBgPath = ''
$script:PreviewBgStamp = 0
$script:SuppressLanguageEvent = $false

# язык: параметр важнее локали, файл настроек важнее параметра
if ($Lang -and (Test-LanguageCode $Lang)) { Set-Language $Lang }

# ---------------------------------------------------------------- конфиг

function Save-Config {
    $data = @{
        groups     = @()
        language   = $script:UiLanguage
        background = $script:BackgroundImage
        updated    = (Get-Date -Format 'yyyy-MM-dd HH:mm')
    }
    foreach ($g in $script:Groups) {
        $data.groups += @{ name = $g.name; color = $g.color; items = @($g.items) }
    }
    $json = $data | ConvertTo-Json -Depth 5
    # атомарная запись: пишем во временный файл и переименовываем поверх.
    # File.Replace здесь не годится: PowerShell подставляет пустую строку
    # вместо $null в третий аргумент, и вызов падает.
    $tmp = $script:ConfigPath + '.tmp'
    [IO.File]::WriteAllText($tmp, $json, [Text.UTF8Encoding]::new($true))
    try {
        Move-Item -LiteralPath $tmp -Destination $script:ConfigPath -Force
    }
    catch {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Import-Config {
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) { return $false }

    $data = $null
    try {
        $raw = [IO.File]::ReadAllText($script:ConfigPath, [Text.UTF8Encoding]::new($true))
        $data = $raw | ConvertFrom-Json
    }
    catch {
        $data = $null
    }

    # пустой файл и мусор разбираются в $null без исключения — проверяем явно
    if ($null -eq $data -or $null -eq $data.groups) {
        # не теряем файл пользователя: откладываем рядом с отметкой времени
        $bad = Join-Path $script:AppDir ('config.bad-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        try { Move-Item -LiteralPath $script:ConfigPath -Destination $bad -Force }
        catch { $bad = $script:ConfigPath }
        $script:ConfigBroken = $bad
        return $false
    }

    # язык из файла перекрывает локаль, но не явный параметр -Lang
    if (-not $Lang -and $data.language -and (Test-LanguageCode ([string]$data.language))) {
        Set-Language ([string]$data.language)
    }

    if ($data.background) {
        $bg = [string]$data.background
        $ok = $false
        if (Test-Path -LiteralPath $bg -PathType Leaf) {
            # файл может существовать и не быть картинкой: проверяем чтением,
            # иначе подпись «Фон: …» обещает то, чего не будет
            $probe = $null
            try {
                $probe = Get-BackgroundImage -Path $bg
                $ok = ($null -ne $probe)
            }
            catch {
                $script:BackgroundNote = $_.Exception.Message
            }
            finally {
                if ($probe) { $probe.Image.Dispose(); $probe.Stream.Dispose() }
            }
        }
        else {
            $script:BackgroundNote = $bg
        }
        if ($ok) { $script:BackgroundImage = $bg } else { $script:BackgroundImage = '' }
    }

    $script:Groups.Clear()
    foreach ($g in @($data.groups)) {
        # значения из файла — недоверенный ввод: приводим типы и отбрасываем мусор
        $name = [string]$g.name
        if ($name.Length -gt 200) { $name = $name.Substring(0, 200) }
        if (-not $name.Trim()) { continue }

        $color = [string]$g.color
        if ($color -notmatch '^#[0-9A-Fa-f]{6}$') { $color = Get-NextColor $script:Groups }

        $items = @(@($g.items) | ForEach-Object { [string]$_ } | Where-Object { $_ })

        [void]$script:Groups.Add([pscustomobject]@{
            name  = $name
            color = $color
            items = $items
        })
    }
    # имена в конфиге могли разойтись с реальными — сопоставляем по базовому имени
    $null = Resolve-GroupItems $script:Groups $script:Items
    return $true
}

# ---------------------------------------------------------------- группы

function Get-OrCreateGroup {
    param([string]$Name, [string]$Color)
    foreach ($g in $script:Groups) { if ($g.name -eq $Name) { return $g } }
    if (-not $Color) { $Color = Get-NextColor $script:Groups }
    $ng = [pscustomobject]@{ name = $Name; color = $Color; items = @() }
    [void]$script:Groups.Add($ng)
    return $ng
}

function Get-OtherGroupName { return (T 'group.other') }

# Имя служебной группы должно соответствовать языку интерфейса, откуда бы
# язык ни пришёл: комбобокс, -Lang или config.json.
function Sync-OtherGroupName {
    $ru = Get-GroupName -Id 'other' -Lang 'ru'
    $en = Get-GroupName -Id 'other' -Lang 'en'
    $target = T 'group.other'
    foreach ($g in $script:Groups) {
        if ($g.name -eq $ru -or $g.name -eq $en) { $g.name = $target }
    }
}

function Remove-ItemFromAllGroups {
    param([string]$ItemName)
    foreach ($g in $script:Groups) {
        if (@($g.items) -contains $ItemName) {
            $g.items = @($g.items | Where-Object { $_ -ne $ItemName })
        }
    }
}

function Get-UnassignedItems {
    $assigned = @{}
    foreach ($g in $script:Groups) { foreach ($i in @($g.items)) { $assigned[$i] = $true } }
    return @($script:Items | Where-Object { -not $assigned.ContainsKey($_.name) } | ForEach-Object { $_.name })
}

# ---------------------------------------------------------------- окно

$form = New-Object System.Windows.Forms.Form
$form.Text = 'DesktopGroups ' + $script:Version
# на маленьких экранах окно не должно вылезать за рабочую область
$work = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$winW = [Math]::Min(1140, $work.Width - 20)
$winH = [Math]::Min(760, $work.Height - 20)
$form.Size = New-Object System.Drawing.Size($winW, $winH)
$form.AutoScroll = $true
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(900, 600)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$status = New-Object System.Windows.Forms.Label
$status.AutoSize = $false
$status.Location = New-Object System.Drawing.Point(12, 690)
$status.Size = New-Object System.Drawing.Size(1100, 22)
$form.Controls.Add($status)

# --- верхняя панель
$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Location = New-Object System.Drawing.Point(12, 12)
$btnScan.Size = New-Object System.Drawing.Size(150, 30)
$form.Controls.Add($btnScan)

$btnPropose = New-Object System.Windows.Forms.Button
$btnPropose.Location = New-Object System.Drawing.Point(170, 12)
$btnPropose.Size = New-Object System.Drawing.Size(160, 30)
$form.Controls.Add($btnPropose)

$lblTop = New-Object System.Windows.Forms.Label
$lblTop.Location = New-Object System.Drawing.Point(345, 19)
$lblTop.Size = New-Object System.Drawing.Size(430, 20)
$lblTop.Text = ''
$form.Controls.Add($lblTop)

$lblLang = New-Object System.Windows.Forms.Label
# ширина с запасом: «Language:» шире, чем «Язык:»
$lblLang.Location = New-Object System.Drawing.Point(772, 19)
$lblLang.Size = New-Object System.Drawing.Size(72, 20)
$lblLang.TextAlign = 'MiddleRight'
$form.Controls.Add($lblLang)

$cmbLang = New-Object System.Windows.Forms.ComboBox
$cmbLang.Location = New-Object System.Drawing.Point(848, 15)
$cmbLang.Size = New-Object System.Drawing.Size(120, 24)
$cmbLang.DropDownStyle = 'DropDownList'
[void]$cmbLang.Items.Add('Русский')
[void]$cmbLang.Items.Add('English')
$form.Controls.Add($cmbLang)

# --- группы
$grpGroups = New-Object System.Windows.Forms.GroupBox
$grpGroups.Location = New-Object System.Drawing.Point(12, 52)
$grpGroups.Size = New-Object System.Drawing.Size(300, 625)
$form.Controls.Add($grpGroups)

$lstGroups = New-Object System.Windows.Forms.ListBox
$lstGroups.Location = New-Object System.Drawing.Point(10, 22)
$lstGroups.Size = New-Object System.Drawing.Size(280, 500)
$lstGroups.IntegralHeight = $false
$grpGroups.Controls.Add($lstGroups)

$btnNew = New-Object System.Windows.Forms.Button
$btnNew.Location = New-Object System.Drawing.Point(10, 530)
$btnNew.Size = New-Object System.Drawing.Size(85, 28)
$grpGroups.Controls.Add($btnNew)

$btnRename = New-Object System.Windows.Forms.Button
$btnRename.Location = New-Object System.Drawing.Point(100, 530)
$btnRename.Size = New-Object System.Drawing.Size(115, 28)
$grpGroups.Controls.Add($btnRename)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Location = New-Object System.Drawing.Point(220, 530)
$btnDelete.Size = New-Object System.Drawing.Size(70, 28)
$grpGroups.Controls.Add($btnDelete)

$btnUp = New-Object System.Windows.Forms.Button
$btnUp.Location = New-Object System.Drawing.Point(10, 564)
$btnUp.Size = New-Object System.Drawing.Size(100, 28)
$grpGroups.Controls.Add($btnUp)

$btnDown = New-Object System.Windows.Forms.Button
$btnDown.Location = New-Object System.Drawing.Point(115, 564)
$btnDown.Size = New-Object System.Drawing.Size(100, 28)
$grpGroups.Controls.Add($btnDown)

$lblUnassigned = New-Object System.Windows.Forms.Label
$lblUnassigned.Location = New-Object System.Drawing.Point(10, 596)
$lblUnassigned.Size = New-Object System.Drawing.Size(280, 20)
$lblUnassigned.Text = ''
$grpGroups.Controls.Add($lblUnassigned)

# --- значки выбранной группы
$grpItems = New-Object System.Windows.Forms.GroupBox
$grpItems.Location = New-Object System.Drawing.Point(322, 52)
$grpItems.Size = New-Object System.Drawing.Size(360, 625)
$form.Controls.Add($grpItems)

$lstItems = New-Object System.Windows.Forms.ListBox
$lstItems.Location = New-Object System.Drawing.Point(10, 22)
$lstItems.Size = New-Object System.Drawing.Size(340, 500)
$lstItems.IntegralHeight = $false
$lstItems.SelectionMode = 'MultiExtended'
$grpItems.Controls.Add($lstItems)

$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Location = New-Object System.Drawing.Point(10, 530)
$btnAdd.Size = New-Object System.Drawing.Size(165, 28)
$grpItems.Controls.Add($btnAdd)

$btnRemove = New-Object System.Windows.Forms.Button
$btnRemove.Location = New-Object System.Drawing.Point(180, 530)
$btnRemove.Size = New-Object System.Drawing.Size(170, 28)
$grpItems.Controls.Add($btnRemove)

$lblItemsHint = New-Object System.Windows.Forms.Label
$lblItemsHint.Location = New-Object System.Drawing.Point(10, 564)
$lblItemsHint.Size = New-Object System.Drawing.Size(340, 40)
$grpItems.Controls.Add($lblItemsHint)

# --- предпросмотр
$grpPreview = New-Object System.Windows.Forms.GroupBox
$grpPreview.Location = New-Object System.Drawing.Point(692, 52)
$grpPreview.Size = New-Object System.Drawing.Size(420, 300)
$form.Controls.Add($grpPreview)

$preview = New-Object System.Windows.Forms.Panel
$preview.Location = New-Object System.Drawing.Point(12, 22)
$preview.Size = New-Object System.Drawing.Size(396, 223)
$preview.BackColor = [System.Drawing.Color]::FromArgb(18, 22, 30)
$preview.BorderStyle = 'FixedSingle'
$grpPreview.Controls.Add($preview)

$lblPreviewInfo = New-Object System.Windows.Forms.Label
$lblPreviewInfo.Location = New-Object System.Drawing.Point(12, 252)
$lblPreviewInfo.Size = New-Object System.Drawing.Size(396, 20)
$lblPreviewInfo.Text = ''
$grpPreview.Controls.Add($lblPreviewInfo)

# --- действия
$grpActions = New-Object System.Windows.Forms.GroupBox
$grpActions.Location = New-Object System.Drawing.Point(692, 362)
$grpActions.Size = New-Object System.Drawing.Size(420, 315)
$form.Controls.Add($grpActions)

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Location = New-Object System.Drawing.Point(12, 22)
$btnApply.Size = New-Object System.Drawing.Size(396, 38)
$btnApply.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$grpActions.Controls.Add($btnApply)

$btnSaveWall = New-Object System.Windows.Forms.Button
$btnSaveWall.Location = New-Object System.Drawing.Point(12, 64)
$btnSaveWall.Size = New-Object System.Drawing.Size(396, 28)
$grpActions.Controls.Add($btnSaveWall)

$btnRestore = New-Object System.Windows.Forms.Button
$btnRestore.Location = New-Object System.Drawing.Point(12, 96)
$btnRestore.Size = New-Object System.Drawing.Size(396, 26)
$grpActions.Controls.Add($btnRestore)

$btnBg = New-Object System.Windows.Forms.Button
$btnBg.Location = New-Object System.Drawing.Point(12, 128)
$btnBg.Size = New-Object System.Drawing.Size(252, 28)
$grpActions.Controls.Add($btnBg)

$btnBgClear = New-Object System.Windows.Forms.Button
$btnBgClear.Location = New-Object System.Drawing.Point(272, 128)
$btnBgClear.Size = New-Object System.Drawing.Size(136, 28)
$grpActions.Controls.Add($btnBgClear)

$lblBg = New-Object System.Windows.Forms.Label
$lblBg.Location = New-Object System.Drawing.Point(12, 160)
$lblBg.Size = New-Object System.Drawing.Size(396, 18)
$lblBg.Text = ''
$grpActions.Controls.Add($lblBg)

$lblHelp = New-Object System.Windows.Forms.Label
$lblHelp.Location = New-Object System.Drawing.Point(12, 182)
$lblHelp.Size = New-Object System.Drawing.Size(396, 122)
$lblHelp.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$grpActions.Controls.Add($lblHelp)

# ---------------------------------------------------------------- язык

# Все подписи окна ставятся здесь: при смене языка достаточно вызвать снова.
function Update-Language {
    param([switch]$SkipLists)

    $form.Text = (T 'app.title' @($script:Version))

    $btnScan.Text = T 'btn.scan'
    $btnPropose.Text = T 'btn.propose'
    $btnNew.Text = T 'btn.new'
    $btnRename.Text = T 'btn.rename'
    $btnDelete.Text = T 'btn.delete'
    $btnUp.Text = T 'btn.up'
    $btnDown.Text = T 'btn.down'
    $btnAdd.Text = T 'btn.add'
    $btnRemove.Text = T 'btn.remove'
    $btnApply.Text = T 'btn.apply'
    $btnSaveWall.Text = T 'btn.saveWall'
    $btnRestore.Text = T 'btn.restore'
    $btnBg.Text = T 'btn.bg'
    $btnBgClear.Text = T 'btn.bgClear'

    $grpGroups.Text = T 'grp.groups'
    $grpItems.Text = T 'grp.items'
    $grpPreview.Text = T 'grp.preview'
    $grpActions.Text = T 'grp.apply'

    $lblLang.Text = T 'lbl.lang'
    $lblItemsHint.Text = T 'hint.order'
    $lblHelp.Text = (T 'lbl.help').Trim()
    # высоту считаем по тексту: в русском строк больше, и фиксированная
    # высота срезала последнюю строку
    $helpSize = [System.Windows.Forms.TextRenderer]::MeasureText($lblHelp.Text, $lblHelp.Font)
    $need = $helpSize.Height + 6
    if ($need -gt $lblHelp.Height) { $lblHelp.Height = $need }

    Update-BackgroundLabel

    if (-not $SkipLists) {
        Update-GroupList
        Update-ItemList
        Update-Preview
    }
}

function Update-BackgroundLabel {
    if ($script:BackgroundImage) {
        $lblBg.Text = (T 'lbl.bgSet' @([IO.Path]::GetFileName($script:BackgroundImage)))
    }
    else {
        $lblBg.Text = T 'lbl.bgNone'
    }
}

function Set-InterfaceLanguage {
    param([string]$Code)

    if (-not (Test-LanguageCode $Code)) { return }
    if ($Code -eq $script:UiLanguage) { return }

    Set-Language $Code
    # служебная группа переименовывается вместе с интерфейсом
    Sync-OtherGroupName

    Update-Language
    Save-Config
    $status.Text = T 'status.langSet'
}

$cmbLang.Add_SelectedIndexChanged({
        if ($script:SuppressLanguageEvent) { return }
        $code = 'ru'
        if ($cmbLang.SelectedIndex -eq 1) { $code = 'en' }
        # событие может прийти повторно с тем же значением — не дёргаем интерфейс
        if ($code -eq $script:UiLanguage) { return }
        Set-InterfaceLanguage $code
    })

# ---------------------------------------------------------------- обновление

function Update-GroupList {
    $sel = $lstGroups.SelectedIndex
    $lstGroups.BeginUpdate()
    $lstGroups.Items.Clear()
    foreach ($g in $script:Groups) {
        $n = @($g.items).Count
        [void]$lstGroups.Items.Add(('{0}  ({1})' -f $g.name, $n))
    }
    $lstGroups.EndUpdate()
    if ($sel -ge 0 -and $sel -lt $lstGroups.Items.Count) { $lstGroups.SelectedIndex = $sel }
    elseif ($lstGroups.Items.Count -gt 0) { $lstGroups.SelectedIndex = 0 }

    $un = @(Get-UnassignedItems)
    $lblUnassigned.Text = (T 'lbl.unassigned' @($un.Count))
    $lblTop.Text = (T 'lbl.top' @($script:Items.Count, $script:Groups.Count))
}

function Update-ItemList {
    $lstItems.BeginUpdate()
    $lstItems.Items.Clear()
    $g = Get-SelectedGroup
    if ($g) {
        foreach ($i in @($g.items)) { [void]$lstItems.Items.Add($i) }
        $shown = $g.name
        if ($shown.Length -gt 40) { $shown = $shown.Substring(0, 40) + '…' }
        $grpItems.Text = (T 'grp.itemsOf' @($shown))
    }
    else {
        $grpItems.Text = T 'grp.items'
    }
    $lstItems.EndUpdate()
}

function Get-SelectedGroup {
    $idx = $lstGroups.SelectedIndex
    if ($idx -ge 0 -and $idx -lt $script:Groups.Count) { return $script:Groups[$idx] }
    return $null
}

function Get-PreviewBackground {
    if (-not $script:BackgroundImage) { return $null }

    $stamp = 0
    try { $stamp = (Get-Item -LiteralPath $script:BackgroundImage -ErrorAction Stop).LastWriteTimeUtc.Ticks }
    catch { return $null }

    if ($script:PreviewBgImage -and $script:PreviewBgPath -eq $script:BackgroundImage -and $script:PreviewBgStamp -eq $stamp) {
        return $script:PreviewBgImage
    }

    if ($script:PreviewBgImage) {
        $script:PreviewBgImage.Dispose()
        $script:PreviewBgImage = $null
    }

    $loaded = $null
    try {
        $loaded = Get-BackgroundImage -Path $script:BackgroundImage
        if ($loaded) {
            # поток освобождаем, картинку оставляем в кеше
            $loaded.Stream.Dispose()
            $script:PreviewBgImage = $loaded.Image
            $script:PreviewBgPath = $script:BackgroundImage
            $script:PreviewBgStamp = $stamp
            return $script:PreviewBgImage
        }
    }
    catch {
        Write-Verbose 'фон в предпросмотре не отрисован: не удалось прочитать файл'
    }
    finally {
        if ($loaded -and $loaded.Stream) { $loaded.Stream.Dispose() }
    }
    return $null
}

function Clear-PreviewBackground {
    if ($script:PreviewBgImage) {
        $script:PreviewBgImage.Dispose()
        $script:PreviewBgImage = $null
    }
    $script:PreviewBgPath = ''
    $script:PreviewBgStamp = 0
}

function Update-Preview {
    $preview.Invalidate()
    $groups = @($script:Groups | Where-Object { @($_.items).Count -gt 0 })
    if ($groups.Count -eq 0) {
        $lblPreviewInfo.Text = T 'lbl.previewEmpty'
        return
    }
    $layout = New-Layout $groups $script:Screen $script:Grid
    $count = 0
    foreach ($b in $layout.blocks) { $count += @($b.items).Count }
    $lblPreviewInfo.Text = (T 'lbl.previewInfo' @($layout.blocks.Count, $count))
    if ($layout.overflow) { $lblPreviewInfo.Text += (T 'lbl.overflowNote') }
}

$preview.Add_Paint({
        param($s, $e)
        # исключение из обработчика Paint уходит в WinForms и ломает окно,
        # поэтому предпросмотр рисуем «мягко»: не вышло — просто пусто
        try {
            $gfx = $e.Graphics
            $gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $scaleX = $s.Width / [double]$script:Screen.width
            $scaleY = $s.Height / [double]$script:Screen.height
            $scale = [Math]::Min($scaleX, $scaleY)

            $dstW = [int]($script:Screen.width * $scale)
            $dstH = [int]($script:Screen.height * $scale)
            if ($dstW -lt 1) { $dstW = 1 }
            if ($dstH -lt 1) { $dstH = 1 }

            # Подложка повторяет итог: сначала градиент, потом фото поверх.
            # Так прозрачные PNG не дают чёрных областей, а предпросмотр
            # совпадает с готовыми обоями по цвету вуали.
            $bgRect = New-Object System.Drawing.Rectangle(0, 0, $dstW, $dstH)
            $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                $bgRect,
                [System.Drawing.Color]::FromArgb(13, 16, 22),
                [System.Drawing.Color]::FromArgb(24, 29, 41),
                90)
            $gfx.FillRectangle($bgBrush, $bgRect)
            $bgBrush.Dispose()

            $bgImg = Get-PreviewBackground
            if ($bgImg) {
                $k = [Math]::Max($dstW / [double]$bgImg.Width, $dstH / [double]$bgImg.Height)
                $dw = [int][Math]::Ceiling($bgImg.Width * $k)
                $dh = [int][Math]::Ceiling($bgImg.Height * $k)
                $dx = [int](($dstW - $dw) / 2)
                $dy = [int](($dstH - $dh) / 2)
                $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $gfx.DrawImage($bgImg, (New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)))

                $scrim = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                    $bgRect,
                    [System.Drawing.Color]::FromArgb(120, 0, 0, 0),
                    [System.Drawing.Color]::FromArgb(70, 0, 0, 0),
                    90)
                $gfx.FillRectangle($scrim, $bgRect)
                $scrim.Dispose()
            }

            $groups = @($script:Groups | Where-Object { @($_.items).Count -gt 0 })
            if ($groups.Count -eq 0) { return }
            $layout = New-Layout $groups $script:Screen $script:Grid
            $dot = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 200, 210, 230))
            foreach ($b in $layout.blocks) {
                $c = Convert-HexColor $b.color
                $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(170, $c.R, $c.G, $c.B), 1)
                $gfx.DrawRectangle($pen, [int]($b.x * $scale), [int]($b.y * $scale), [int]($b.w * $scale), [int]($b.h * $scale))
                $pen.Dispose()
                foreach ($it in $b.items) {
                    $gfx.FillRectangle($dot, [single]($it.x * $scale), [single]($it.y * $scale), 6, 6)
                }
                $f = New-Object System.Drawing.Font('Segoe UI', 6.5)
                $br = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, $c.R, $c.G, $c.B))
                $gfx.DrawString($b.name, $f, $br, [single]($b.x * $scale), [single]($b.y * $scale - 11))
                $br.Dispose()
                $f.Dispose()
            }
            $dot.Dispose()
        }
        catch {
            Write-Verbose 'предпросмотр не отрисован: ' + $_.Exception.Message
        }
    })

# ---------------------------------------------------------------- действия

$lstGroups.Add_SelectedIndexChanged({ Update-ItemList })

$btnScan.Add_Click({
        $status.Text = T 'status.scanning'
        $script:Items = Get-DesktopItems -AlignWithView

        # группы не сбрасываем: только убираем исчезнувшие значки
        # и складываем новые в «Прочее» — иначе скан уничтожает работу
        $known = @{}
        foreach ($it in $script:Items) { $known[$it.name] = $true }
        foreach ($g in $script:Groups) {
            $g.items = @(@($g.items) | Where-Object { $known.ContainsKey($_) })
        }
        $null = Resolve-GroupItems $script:Groups $script:Items

        $unassigned = @(Get-UnassignedItems)
        if ($unassigned.Count -gt 0) {
            $target = Get-OrCreateGroup (Get-OtherGroupName) '#8C8C8C'
            foreach ($u in $unassigned) {
                if (@($target.items) -notcontains $u) { $target.items = @($target.items) + $u }
            }
        }

        Save-Config
        Update-GroupList
        Update-ItemList
        Update-Preview
        $status.Text = (T 'status.scanned' @($script:Items.Count, (Get-OtherGroupName)))
    })

$btnPropose.Add_Click({
        if ($script:Items.Count -eq 0) { $script:Items = Get-DesktopItems -AlignWithView }
        $ans = [System.Windows.Forms.MessageBox]::Show(
            (T 'msg.replaceText'),
            (T 'msg.replaceTitle'),
            'YesNo', 'Question')
        if ($ans -ne 'Yes') { return }
        $script:Groups.Clear()
        $proposed = New-ProposedGroups $script:Items $script:UiLanguage
        foreach ($g in $proposed) { [void]$script:Groups.Add($g) }
        Save-Config
        Update-GroupList
        Update-ItemList
        Update-Preview
        $status.Text = (T 'status.proposed' @($script:Groups.Count))
    })

$btnNew.Add_Click({
        $name = [Microsoft.VisualBasic.Interaction]::InputBox(
            (T 'dlg.newGroupPrompt'),
            (T 'dlg.newGroupTitle'),
            (T 'dlg.newGroupDefault'))
        if (-not $name) { return }
        $name = $name.Trim()
        if (-not $name) { return }
        foreach ($g in $script:Groups) {
            if ($g.name -eq $name) {
                [System.Windows.Forms.MessageBox]::Show((T 'msg.exists'), (T 'dlg.newGroupTitle'), 'OK', 'Warning')
                return
            }
        }
        $null = Get-OrCreateGroup $name $null
        Save-Config
        Update-GroupList
        $lstGroups.SelectedIndex = $lstGroups.Items.Count - 1
        Update-ItemList
        Update-Preview
        $status.Text = (T 'status.created' @($name))
    })

$btnRename.Add_Click({
        $g = Get-SelectedGroup
        if (-not $g) { return }
        $name = [Microsoft.VisualBasic.Interaction]::InputBox(
            (T 'dlg.renamePrompt'),
            (T 'dlg.renameTitle'),
            $g.name)
        if (-not $name) { return }
        $name = $name.Trim()
        if (-not $name) { return }
        foreach ($o in $script:Groups) {
            if ($o -ne $g -and $o.name -eq $name) {
                [System.Windows.Forms.MessageBox]::Show((T 'msg.exists'), (T 'dlg.renameTitle'), 'OK', 'Warning')
                return
            }
        }
        $g.name = $name
        Save-Config
        Update-GroupList
        Update-ItemList
        Update-Preview
        $status.Text = (T 'status.renamed' @($name))
    })

$btnDelete.Add_Click({
        $g = Get-SelectedGroup
        if (-not $g) { return }
        $ans = [System.Windows.Forms.MessageBox]::Show(
            (T 'dlg.deleteText' @($g.name, (Get-OtherGroupName))),
            (T 'dlg.deleteTitle'),
            'YesNo', 'Question')
        if ($ans -ne 'Yes') { return }
        $target = Get-OrCreateGroup (Get-OtherGroupName) '#8C8C8C'
        foreach ($i in @($g.items)) {
            if (@($target.items) -notcontains $i) { $target.items = @($target.items) + $i }
        }
        [void]$script:Groups.Remove($g)
        Save-Config
        Update-GroupList
        Update-ItemList
        Update-Preview
        $status.Text = T 'status.deleted'
    })

$btnUp.Add_Click({
        $idx = $lstGroups.SelectedIndex
        if ($idx -le 0) { return }
        $g = $script:Groups[$idx]
        $script:Groups.RemoveAt($idx)
        $script:Groups.Insert($idx - 1, $g)
        Save-Config
        Update-GroupList
        $lstGroups.SelectedIndex = $idx - 1
        Update-Preview
    })

$btnDown.Add_Click({
        $idx = $lstGroups.SelectedIndex
        if ($idx -lt 0 -or $idx -ge ($script:Groups.Count - 1)) { return }
        $g = $script:Groups[$idx]
        $script:Groups.RemoveAt($idx)
        $script:Groups.Insert($idx + 1, $g)
        Save-Config
        Update-GroupList
        $lstGroups.SelectedIndex = $idx + 1
        Update-Preview
    })

$btnAdd.Add_Click({
        $g = Get-SelectedGroup
        if (-not $g) { return }
        $candidates = @(Get-UnassignedItems)
        if ($candidates.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show((T 'dlg.noFree'), (T 'btn.add').TrimEnd([char]0x2026), 'OK', 'Information')
            return
        }

        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text = (T 'dlg.addTitle' @($g.name))
        $dlg.Size = New-Object System.Drawing.Size(380, 500)
        $dlg.StartPosition = 'CenterParent'
        $dlg.FormBorderStyle = 'FixedDialog'
        $dlg.MaximizeBox = $false
        $dlg.MinimizeBox = $false
        $dlg.Font = $form.Font

        $clb = New-Object System.Windows.Forms.CheckedListBox
        $clb.Location = New-Object System.Drawing.Point(12, 12)
        $clb.Size = New-Object System.Drawing.Size(340, 390)
        $clb.CheckOnClick = $true
        foreach ($c in $candidates) { [void]$clb.Items.Add($c) }
        $dlg.Controls.Add($clb)

        $ok = New-Object System.Windows.Forms.Button
        $ok.Text = T 'dlg.addButton'
        $ok.DialogResult = 'OK'
        $ok.Location = New-Object System.Drawing.Point(180, 415)
        $ok.Size = New-Object System.Drawing.Size(80, 28)
        $dlg.Controls.Add($ok)

        $cancel = New-Object System.Windows.Forms.Button
        $cancel.Text = T 'dlg.cancel'
        $cancel.DialogResult = 'Cancel'
        $cancel.Location = New-Object System.Drawing.Point(270, 415)
        $cancel.Size = New-Object System.Drawing.Size(80, 28)
        $dlg.Controls.Add($cancel)

        $dlg.AcceptButton = $ok
        $dlg.CancelButton = $cancel

        if ($dlg.ShowDialog() -eq 'OK') {
            $chosen = @($clb.CheckedItems)
            foreach ($c in $chosen) {
                Remove-ItemFromAllGroups $c
                if (@($g.items) -notcontains $c) { $g.items = @($g.items) + $c }
            }
            Save-Config
            Update-GroupList
            Update-ItemList
            Update-Preview
            $status.Text = (T 'status.added' @($chosen.Count))
        }
        $dlg.Dispose()
    })

$btnRemove.Add_Click({
        $g = Get-SelectedGroup
        if (-not $g) { return }
        $sel = @($lstItems.SelectedItems)
        if ($sel.Count -eq 0) { return }
        foreach ($s in $sel) {
            $g.items = @($g.items | Where-Object { $_ -ne $s })
        }
        Save-Config
        Update-GroupList
        Update-ItemList
        Update-Preview
        $status.Text = (T 'status.removed' @($sel.Count))
    })

$btnBg.Add_Click({
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title = T 'dlg.bgTitle'
        $dlg.Filter = T 'dlg.bgFilter'
        if ($dlg.ShowDialog() -ne 'OK') { return }

        # проверяем файл до сохранения: битый не должен попасть в настройки
        $loaded = $null
        try {
            $loaded = Get-BackgroundImage -Path $dlg.FileName
            if (-not $loaded) { throw (T 'err.imageRead') }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message, (T 'msg.errorTitle'), 'OK', 'Error')
            return
        }
        finally {
            if ($loaded) {
                $loaded.Image.Dispose()
                $loaded.Stream.Dispose()
            }
        }

        $script:BackgroundImage = $dlg.FileName
        Clear-PreviewBackground
        Save-Config
        Update-BackgroundLabel
        Update-Preview
        $status.Text = (T 'status.bgChosen' @([IO.Path]::GetFileName($dlg.FileName)))
    })

$btnBgClear.Add_Click({
        $script:BackgroundImage = ''
        Clear-PreviewBackground
        Save-Config
        Update-BackgroundLabel
        Update-Preview
        $status.Text = T 'status.bgCleared'
    })

$btnApply.Add_Click({
        $groups = @($script:Groups | Where-Object { @($_.items).Count -gt 0 })
        if ($groups.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show((T 'msg.noGroups'), (T 'msg.applyTitle'), 'OK', 'Warning')
            return
        }
        if (Test-AutoArrange) {
            [System.Windows.Forms.MessageBox]::Show((T 'msg.autoArrange'), (T 'msg.applyTitle'), 'OK', 'Warning')
            return
        }
        $status.Text = T 'status.applying'
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        try {
            $layout = New-Layout $groups $script:Screen $script:Grid
            if ($layout.overflow) {
                $ans = [System.Windows.Forms.MessageBox]::Show((T 'msg.overflow'), (T 'msg.applyTitle'), 'YesNo', 'Warning')
                if ($ans -ne 'Yes') { return }
            }
            $res = Invoke-DesktopLayout $layout $script:BackupDir
            $png = Join-Path $script:AppDir 'wallpaper.png'
            # обои рисуем ровно в размере экрана: иначе на другом разрешении
            # Windows растянет картинку и рамки разъедутся со значками
            $null = Save-Wallpaper $layout $png $script:Screen.width $script:Screen.height 12 $script:BackgroundImage
            if ($script:LastWallpaperError) {
                $bgFail = $script:LastWallpaperError
            }
            $ok = Set-DesktopWallpaper $png

            $msg = (T 'status.applied' @($res.placed, $res.passes))
            if ($res.mismatches.Count -gt 0) {
                $msg += (T 'status.applyMismatch' @($res.mismatches.Count))
                $details = ($res.mismatches | ForEach-Object { '{0}: {1} -> {2}' -f $_.name, $_.expected, $_.actual }) -join '; '
                $msg += ' (' + $details + ')'
            }
            if ($res.unknown.Count -gt 0) {
                $msg += (T 'status.applyUnknown' @($res.unknown -join ', '))
            }
            if ($bgFail) { $msg += '; ' + (T 'status.bgFailed' @($bgFail)) }
            if (-not $ok) { $msg += (T 'status.applyNoWall') }
            $status.Text = $msg
            Save-Config
            Update-Preview
        }
        catch {
            $status.Text = (T 'status.error' @($_.Exception.Message))
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, (T 'msg.errorTitle'), 'OK', 'Error')
        }
        finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    })

$btnSaveWall.Add_Click({
        $groups = @($script:Groups | Where-Object { @($_.items).Count -gt 0 })
        if ($groups.Count -eq 0) { return }
        $dlg = New-Object System.Windows.Forms.SaveFileDialog
        $dlg.Title = T 'dlg.wallTitle'
        $dlg.Filter = T 'dlg.wallFilter'
        $dlg.FileName = 'desktop-groups.png'
        if ($dlg.ShowDialog() -eq 'OK') {
            $layout = New-Layout $groups $script:Screen $script:Grid
            $null = Save-Wallpaper $layout $dlg.FileName $script:Screen.width $script:Screen.height 12 $script:BackgroundImage
            $status.Text = (T 'status.saved' @($dlg.FileName))
        }
    })

$btnRestore.Add_Click({
        $files = @(Get-ChildItem -LiteralPath $script:BackupDir -Filter 'before-apply-*.json' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending)
        if ($files.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show((T 'msg.noBackups'), (T 'msg.restoreTitle'), 'OK', 'Information')
            return
        }
        $file = $files[0]
        $plan = @{}
        try {
            $data = [IO.File]::ReadAllText($file.FullName, [Text.UTF8Encoding]::new($true)) | ConvertFrom-Json
            $data.PSObject.Properties | ForEach-Object {
                $v = $_.Value
                $n = [string]$v.name
                if (-not $n) { $n = [string]$_.Name }   # старый формат бэкапа: ключ = имя
                $plan[$n] = @{ x = [int]$v.x; y = [int]$v.y }
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show((T 'msg.backupRead' @($_.Exception.Message)), (T 'msg.restoreTitle'), 'OK', 'Error')
            return
        }
        $layout = [pscustomobject]@{ plan = $plan; grid = $script:Grid; blocks = @(); overflow = $false }
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        try {
            $res = Invoke-DesktopLayout $layout $script:BackupDir
            $status.Text = (T 'status.restored' @($file.Name, $res.placed, $res.mismatches.Count))
        }
        catch {
            $status.Text = (T 'status.restoreError' @($_.Exception.Message))
        }
        finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    })

# ---------------------------------------------------------------- старт

$form.Add_Shown({
        $script:Items = Get-DesktopItems -AlignWithView
        $view = $null
        try {
            $view = Get-DesktopView
            $script:Grid = Get-ViewGridStep $view
        }
        catch {
            $script:GridNote = $_.Exception.Message
        }
        finally {
            if ($view) { Close-DesktopView $view }
        }

        if (-not (Import-Config)) {
            $proposed = New-ProposedGroups $script:Items $script:UiLanguage
            foreach ($g in $proposed) { [void]$script:Groups.Add($g) }
            if ($script:ConfigBroken) {
                [System.Windows.Forms.MessageBox]::Show(
                    (T 'msg.badConfig' @($script:ConfigBroken)),
                    (T 'msg.settingsTitle'), 'OK', 'Warning')
            }
            else {
                Save-Config
            }
        }

        # Имя служебной группы приводим к языку интерфейса: он мог прийти
        # из config.json или параметра -Lang, минуя комбобокс.
        Sync-OtherGroupName

        # Переключатель языка выставляем так, чтобы обработчик не сработал.
        # WinForms доставляет SelectedIndexChanged отложенно, уже после снятия
        # флага, поэтому прокручиваем очередь сообщений ДО снятия флага —
        # иначе интерфейс откатывался на системный язык.
        $script:SuppressLanguageEvent = $true
        $cmbLang.SelectedIndex = 0
        if ($script:UiLanguage -eq 'en') { $cmbLang.SelectedIndex = 1 }
        [System.Windows.Forms.Application]::DoEvents()
        $script:SuppressLanguageEvent = $false
        Update-Language

        $status.Text = (T 'status.overview' @($script:Items.Count, $script:Grid.stepX, $script:Grid.stepY, $script:Version, $script:ConfigPath))
        if ($script:GridNote) {
            $status.Text = (T 'status.gridFallback' @($script:GridNote)) + ' | ' + $status.Text
        }
        if ($script:UnresolvedItems -and @($script:UnresolvedItems).Count -gt 0) {
            $status.Text += ' | ' + (T 'status.unresolved' @((@($script:UnresolvedItems) -join ', ')))
        }
    })

$form.Add_FormClosing({
        Clear-PreviewBackground
        try { Save-Config }
        catch { Write-Warning ('конфиг не сохранён: ' + $_.Exception.Message) }
    })

# ошибки старта при скрытой консоли иначе не увидеть — пишем лог и показываем окно
try {
    [void]$form.ShowDialog()
}
catch {
    $log = Join-Path $script:AppDir 'startup-error.log'
    try { [IO.File]::WriteAllText($log, $_.Exception.ToString(), [Text.UTF8Encoding]::new($true)) }
    catch { Write-Verbose 'лог старта записать не удалось' }
    [System.Windows.Forms.MessageBox]::Show(
        (T 'msg.startupFail' @($_.Exception.Message, $log)),
        'DesktopGroups', 'OK', 'Error')
}
