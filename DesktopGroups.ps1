# DesktopGroups — группировка ярлыков рабочего стола с подписями на обоях.
# Запуск: DesktopGroups.cmd (или powershell.exe -STA -File DesktopGroups.ps1)

param([string]$ConfigPath)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

. (Join-Path $PSScriptRoot 'lib\Engine.ps1')

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppDir = $PSScriptRoot
if ($ConfigPath) { $script:ConfigPath = $ConfigPath } else { $script:ConfigPath = Join-Path $script:AppDir 'config.json' }
$script:BackupDir = Join-Path $script:AppDir 'backups'
$script:Version = '0.0.0'
$verFile = Join-Path $script:AppDir 'VERSION'
if (Test-Path -LiteralPath $verFile) { $script:Version = (Get-Content -LiteralPath $verFile -Raw).Trim() }
$script:Groups = New-Object System.Collections.ArrayList
$script:Items = @()
$script:Screen = Get-ScreenInfo
$script:Grid = Get-DefaultGrid

# ---------------------------------------------------------------- конфиг

function Save-Config {
    $data = @{ groups = @(); updated = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
    foreach ($g in $script:Groups) {
        $data.groups += @{ name = $g.name; color = $g.color; items = @($g.items) }
    }
    $json = $data | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($script:ConfigPath, $json, [Text.UTF8Encoding]::new($true))
}

function Import-Config {
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) { return $false }
    try {
        $raw = [IO.File]::ReadAllText($script:ConfigPath, [Text.UTF8Encoding]::new($true))
        $data = $raw | ConvertFrom-Json
        # пустой файл и мусор разбираются в $null без исключения — проверяем явно
        if ($null -eq $data -or $null -eq $data.groups) { return $false }
        $script:Groups.Clear()
        foreach ($g in $data.groups) {
            [void]$script:Groups.Add([pscustomobject]@{
                name  = [string]$g.name
                color = [string]$g.color
                items = @($g.items)
            })
        }
        # имена в конфиге могли разойтись с реальными — сопоставляем по базовому имени
        $null = Resolve-GroupItems $script:Groups $script:Items
        return $true
    }
    catch {
        return $false
    }
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

# ---------------------------------------------------------------- интерфейс

$form = New-Object System.Windows.Forms.Form
$form.Text = 'DesktopGroups ' + $script:Version + ' — группы ярлыков рабочего стола'
$form.Size = New-Object System.Drawing.Size(1140, 760)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(1000, 700)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$status = New-Object System.Windows.Forms.Label
$status.AutoSize = $false
$status.Location = New-Object System.Drawing.Point(12, 690)
$status.Size = New-Object System.Drawing.Size(1100, 22)
$status.Text = 'Готово'
$form.Controls.Add($status)

# --- верхняя панель
$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = 'Сканировать стол'
$btnScan.Location = New-Object System.Drawing.Point(12, 12)
$btnScan.Size = New-Object System.Drawing.Size(150, 30)
$form.Controls.Add($btnScan)

$btnPropose = New-Object System.Windows.Forms.Button
$btnPropose.Text = 'Предложить группы'
$btnPropose.Location = New-Object System.Drawing.Point(170, 12)
$btnPropose.Size = New-Object System.Drawing.Size(160, 30)
$form.Controls.Add($btnPropose)

$lblTop = New-Object System.Windows.Forms.Label
$lblTop.Location = New-Object System.Drawing.Point(345, 19)
$lblTop.Size = New-Object System.Drawing.Size(500, 20)
$lblTop.Text = ''
$form.Controls.Add($lblTop)

# --- группы
$grpGroups = New-Object System.Windows.Forms.GroupBox
$grpGroups.Text = 'Группы'
$grpGroups.Location = New-Object System.Drawing.Point(12, 52)
$grpGroups.Size = New-Object System.Drawing.Size(300, 625)
$form.Controls.Add($grpGroups)

$lstGroups = New-Object System.Windows.Forms.ListBox
$lstGroups.Location = New-Object System.Drawing.Point(10, 22)
$lstGroups.Size = New-Object System.Drawing.Size(280, 500)
$lstGroups.IntegralHeight = $false
$grpGroups.Controls.Add($lstGroups)

$btnNew = New-Object System.Windows.Forms.Button
$btnNew.Text = 'Новая'
$btnNew.Location = New-Object System.Drawing.Point(10, 530)
$btnNew.Size = New-Object System.Drawing.Size(85, 28)
$grpGroups.Controls.Add($btnNew)

$btnRename = New-Object System.Windows.Forms.Button
$btnRename.Text = 'Переименовать'
$btnRename.Location = New-Object System.Drawing.Point(100, 530)
$btnRename.Size = New-Object System.Drawing.Size(115, 28)
$grpGroups.Controls.Add($btnRename)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = 'Удалить'
$btnDelete.Location = New-Object System.Drawing.Point(220, 530)
$btnDelete.Size = New-Object System.Drawing.Size(70, 28)
$grpGroups.Controls.Add($btnDelete)

$btnUp = New-Object System.Windows.Forms.Button
$btnUp.Text = '↑ выше'
$btnUp.Location = New-Object System.Drawing.Point(10, 564)
$btnUp.Size = New-Object System.Drawing.Size(100, 28)
$grpGroups.Controls.Add($btnUp)

$btnDown = New-Object System.Windows.Forms.Button
$btnDown.Text = '↓ ниже'
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
$grpItems.Text = 'Значки группы'
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
$btnAdd.Text = 'Добавить значки…'
$btnAdd.Location = New-Object System.Drawing.Point(10, 530)
$btnAdd.Size = New-Object System.Drawing.Size(165, 28)
$grpItems.Controls.Add($btnAdd)

$btnRemove = New-Object System.Windows.Forms.Button
$btnRemove.Text = 'Убрать из группы'
$btnRemove.Location = New-Object System.Drawing.Point(180, 530)
$btnRemove.Size = New-Object System.Drawing.Size(170, 28)
$grpItems.Controls.Add($btnRemove)

$lblItemsHint = New-Object System.Windows.Forms.Label
$lblItemsHint.Location = New-Object System.Drawing.Point(10, 564)
$lblItemsHint.Size = New-Object System.Drawing.Size(340, 40)
$lblItemsHint.Text = 'Порядок значков внутри группы — порядок в списке. Стрелки групп задают порядок блоков.'
$grpItems.Controls.Add($lblItemsHint)

# --- предпросмотр
$grpPreview = New-Object System.Windows.Forms.GroupBox
$grpPreview.Text = 'Предпросмотр раскладки'
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
$grpActions.Text = 'Применить'
$grpActions.Location = New-Object System.Drawing.Point(692, 362)
$grpActions.Size = New-Object System.Drawing.Size(420, 315)
$form.Controls.Add($grpActions)

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = 'Разложить значки и обновить обои'
$btnApply.Location = New-Object System.Drawing.Point(12, 25)
$btnApply.Size = New-Object System.Drawing.Size(396, 40)
$btnApply.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$grpActions.Controls.Add($btnApply)

$btnSaveWall = New-Object System.Windows.Forms.Button
$btnSaveWall.Text = 'Сохранить обои в файл…'
$btnSaveWall.Location = New-Object System.Drawing.Point(12, 75)
$btnSaveWall.Size = New-Object System.Drawing.Size(396, 30)
$grpActions.Controls.Add($btnSaveWall)

$lblHelp = New-Object System.Windows.Forms.Label
$lblHelp.Location = New-Object System.Drawing.Point(12, 118)
$lblHelp.Size = New-Object System.Drawing.Size(396, 185)
$lblHelp.Text = @"
Как это работает

1. «Сканировать стол» — читает ярлыки, папки и файлы с рабочего стола.
2. «Предложить группы» — раскладывает значки по группам по именам.
3. Свои группы: «Новая», «Переименовать», «Удалить», стрелки меняют порядок блоков.
4. «Добавить значки…» — переносит ярлыки в выбранную группу.
5. «Разложить значки и обновить обои» — расставляет значки
   прямоугольниками и рисует рамки с подписями на обоях.

Рамки совпадают с сеткой значков: обои и раскладка
считаются из одного и того же плана.
"@
$grpActions.Controls.Add($lblHelp)

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
    $lblUnassigned.Text = 'Вне групп: ' + $un.Count + ' значков'
    $lblTop.Text = ('Значков на столе: {0}   Групп: {1}' -f $script:Items.Count, $script:Groups.Count)
}

function Update-ItemList {
    $lstItems.BeginUpdate()
    $lstItems.Items.Clear()
    $g = Get-SelectedGroup
    if ($g) {
        foreach ($i in @($g.items)) { [void]$lstItems.Items.Add($i) }
        $grpItems.Text = 'Значки группы «' + $g.name + '»'
    }
    else {
        $grpItems.Text = 'Значки группы'
    }
    $lstItems.EndUpdate()
}

function Get-SelectedGroup {
    $idx = $lstGroups.SelectedIndex
    if ($idx -ge 0 -and $idx -lt $script:Groups.Count) { return $script:Groups[$idx] }
    return $null
}

function Update-Preview {
    $preview.Invalidate()
    $groups = @($script:Groups | Where-Object { @($_.items).Count -gt 0 })
    if ($groups.Count -eq 0) {
        $lblPreviewInfo.Text = 'Групп с ярлыками нет'
        return
    }
    $layout = New-Layout $groups $script:Screen $script:Grid
    $count = 0
    foreach ($b in $layout.blocks) { $count += @($b.items).Count }
    $lblPreviewInfo.Text = ('Блоков: {0}   Значков: {1}' -f $layout.blocks.Count, $count)
    if ($layout.overflow) { $lblPreviewInfo.Text += '   ВНИМАНИЕ: не влезает на экран' }
}

$preview.Add_Paint({
        param($s, $e)
        $gfx = $e.Graphics
        $gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $scale = $s.Width / 1920.0
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
    })

# ---------------------------------------------------------------- действия

$lstGroups.Add_SelectedIndexChanged({ Update-ItemList })

$btnScan.Add_Click({
        $status.Text = 'Сканирую рабочий стол…'
        $script:Items = Get-DesktopItems
        $script:Groups.Clear()
        $script:Items | Out-Null
        Update-GroupList
        Update-ItemList
        Update-Preview
        $status.Text = 'Найдено значков: ' + $script:Items.Count + '. Нажмите «Предложить группы» или создайте свои.'
    })

$btnPropose.Add_Click({
        if ($script:Items.Count -eq 0) { $script:Items = Get-DesktopItems }
        $ans = [System.Windows.Forms.MessageBox]::Show('Заменить текущие группы предложенными?', 'Предложить группы', 'YesNo', 'Question')
        if ($ans -ne 'Yes') { return }
        $script:Groups.Clear()
        $proposed = New-ProposedGroups $script:Items
        foreach ($g in $proposed) { [void]$script:Groups.Add($g) }
        Save-Config
        Update-GroupList
        Update-ItemList
        Update-Preview
        $status.Text = 'Предложено групп: ' + $script:Groups.Count
    })

$btnNew.Add_Click({
        $name = [Microsoft.VisualBasic.Interaction]::InputBox('Название новой группы', 'Новая группа', 'Моя группа')
        if (-not $name) { return }
        $name = $name.Trim()
        if (-not $name) { return }
        foreach ($g in $script:Groups) {
            if ($g.name -eq $name) {
                [System.Windows.Forms.MessageBox]::Show('Группа с таким названием уже есть.', 'Новая группа', 'OK', 'Warning')
                return
            }
        }
        $null = Get-OrCreateGroup $name $null
        Save-Config
        Update-GroupList
        $lstGroups.SelectedIndex = $lstGroups.Items.Count - 1
        Update-ItemList
        Update-Preview
        $status.Text = 'Создана группа «' + $name + '»'
    })

$btnRename.Add_Click({
        $g = Get-SelectedGroup
        if (-not $g) { return }
        $name = [Microsoft.VisualBasic.Interaction]::InputBox('Новое название группы', 'Переименовать', $g.name)
        if (-not $name) { return }
        $name = $name.Trim()
        if (-not $name) { return }
        foreach ($o in $script:Groups) {
            if ($o -ne $g -and $o.name -eq $name) {
                [System.Windows.Forms.MessageBox]::Show('Группа с таким названием уже есть.', 'Переименовать', 'OK', 'Warning')
                return
            }
        }
        $g.name = $name
        Save-Config
        Update-GroupList
        Update-ItemList
        Update-Preview
        $status.Text = 'Группа переименована в «' + $name + '»'
    })

$btnDelete.Add_Click({
        $g = Get-SelectedGroup
        if (-not $g) { return }
        $ans = [System.Windows.Forms.MessageBox]::Show(('Удалить группу «{0}»? Значки вернутся в «Прочее».' -f $g.name), 'Удалить', 'YesNo', 'Question')
        if ($ans -ne 'Yes') { return }
        $target = Get-OrCreateGroup 'Прочее' '#8C8C8C'
        foreach ($i in @($g.items)) {
            if (@($target.items) -notcontains $i) { $target.items = @($target.items) + $i }
        }
        [void]$script:Groups.Remove($g)
        Save-Config
        Update-GroupList
        Update-ItemList
        Update-Preview
        $status.Text = 'Группа удалена'
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
            [System.Windows.Forms.MessageBox]::Show('Свободных значков нет — все уже в группах.', 'Добавить значки', 'OK', 'Information')
            return
        }

        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text = 'Добавить значки в «' + $g.name + '»'
        $dlg.Size = New-Object System.Drawing.Size(380, 500)
        $dlg.StartPosition = 'CenterParent'
        $dlg.FormBorderStyle = 'FixedDialog'
        $dlg.MaximizeBox = $false
        $dlg.MinimizeBox = $false

        $clb = New-Object System.Windows.Forms.CheckedListBox
        $clb.Location = New-Object System.Drawing.Point(12, 12)
        $clb.Size = New-Object System.Drawing.Size(340, 390)
        $clb.CheckOnClick = $true
        foreach ($c in $candidates) { [void]$clb.Items.Add($c) }
        $dlg.Controls.Add($clb)

        $ok = New-Object System.Windows.Forms.Button
        $ok.Text = 'Добавить'
        $ok.DialogResult = 'OK'
        $ok.Location = New-Object System.Drawing.Point(180, 415)
        $ok.Size = New-Object System.Drawing.Size(80, 28)
        $dlg.Controls.Add($ok)

        $cancel = New-Object System.Windows.Forms.Button
        $cancel.Text = 'Отмена'
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
            $status.Text = 'Добавлено значков: ' + $chosen.Count
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
        $status.Text = 'Убрано значков: ' + $sel.Count + ' (вернулись в свободные)'
    })

$btnApply.Add_Click({
        $groups = @($script:Groups | Where-Object { @($_.items).Count -gt 0 })
        if ($groups.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('Нет групп со значками.', 'Применить', 'OK', 'Warning')
            return
        }
        if (Test-AutoArrange) {
            [System.Windows.Forms.MessageBox]::Show(
                'На рабочем столе включено «Упорядочить автоматически» — Windows переставит значки, и рамки разъедутся.' + "`r`n`r`n" +
                'Выключите его: правый клик по столу → Упорядочить значки → снять «Упорядочить автоматически». Потом повторите.',
                'Применить', 'OK', 'Warning')
            return
        }
        $status.Text = 'Применяю раскладку…'
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        try {
            $layout = New-Layout $groups $script:Screen $script:Grid
            if ($layout.overflow) {
                $ans = [System.Windows.Forms.MessageBox]::Show('Блоки не влезают на экран по высоте. Продолжить?', 'Применить', 'YesNo', 'Warning')
                if ($ans -ne 'Yes') { return }
            }
            $res = Invoke-DesktopLayout $layout $script:BackupDir
            $png = Join-Path $script:AppDir 'wallpaper.png'
            $null = Save-Wallpaper $layout $png
            $ok = Set-DesktopWallpaper $png

            $msg = 'Расставлено: {0}, проходов: {1}' -f $res.placed, $res.passes
            if ($res.mismatches.Count -gt 0) {
                $msg += '; не встало: ' + $res.mismatches.Count
                $details = ($res.mismatches | ForEach-Object { '{0}: ждали {1}, получили {2}' -f $_.name, $_.expected, $_.actual }) -join "`r`n"
                $msg += "`r`n" + $details
            }
            if ($res.unknown.Count -gt 0) {
                $msg += '; вне плана: ' + ($res.unknown -join ', ')
            }
            if (-not $ok) { $msg += '; обои применились не сразу' }
            $status.Text = $msg -replace "`r`n", ' | '
            Save-Config
            Update-Preview
        }
        catch {
            $status.Text = 'Ошибка: ' + $_.Exception.Message
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Ошибка', 'OK', 'Error')
        }
        finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    })

$btnSaveWall.Add_Click({
        $groups = @($script:Groups | Where-Object { @($_.items).Count -gt 0 })
        if ($groups.Count -eq 0) { return }
        $dlg = New-Object System.Windows.Forms.SaveFileDialog
        $dlg.Filter = 'PNG|*.png'
        $dlg.FileName = 'desktop-groups.png'
        if ($dlg.ShowDialog() -eq 'OK') {
            $layout = New-Layout $groups $script:Screen $script:Grid
            $null = Save-Wallpaper $layout $dlg.FileName
            $status.Text = 'Обои сохранены: ' + $dlg.FileName
        }
    })

# ---------------------------------------------------------------- старт

$form.Add_Shown({
        $script:Items = Get-DesktopItems
        $view = $null
        try {
            $view = Get-DesktopView
            $script:Grid = Get-ViewGridStep $view
        }
        catch {
            $script:GridNote = 'сетка по умолчанию: ' + $_.Exception.Message
        }
        finally {
            if ($view) { Close-DesktopView $view }
        }

        if (-not (Import-Config)) {
            $proposed = New-ProposedGroups $script:Items
            foreach ($g in $proposed) { [void]$script:Groups.Add($g) }
            Save-Config
        }
        Update-GroupList
        Update-ItemList
        Update-Preview
        $status.Text = 'Значков: {0}. Сетка {1}×{2}. Версия {3}. Конфиг: {4}' -f $script:Items.Count, $script:Grid.stepX, $script:Grid.stepY, $script:Version, $script:ConfigPath
        if ($script:GridNote) { $status.Text = $script:GridNote + ' | ' + $status.Text }
    })

$form.Add_FormClosing({
        try { Save-Config }
        catch { Write-Warning ('конфиг не сохранён: ' + $_.Exception.Message) }
    })

[void]$form.ShowDialog()
