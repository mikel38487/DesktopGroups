# Smoke-тесты DesktopGroups: только чистая логика, рабочий стол не трогается.
# Запуск: powershell.exe -NoProfile -File tests\smoke.ps1
# Код возврата 0 — всё прошло, 1 — есть провалы.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'lib\Engine.ps1')

$script:failed = 0

function Check {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        "ok    $Name"
    }
    else {
        "FAIL  $Name $Detail"
        $script:failed++
    }
}

function Test-RectOverlap {
    param($A, $B)
    if ($A.x + $A.w -le $B.x) { return $false }
    if ($B.x + $B.w -le $A.x) { return $false }
    if ($A.y + $A.h -le $B.y) { return $false }
    if ($B.y + $B.h -le $A.y) { return $false }
    return $true
}

# --- синтетический рабочий стол ---
function New-FakeItem([string]$Name, [string]$Ext, [string]$Kind) {
    [pscustomobject]@{ name = $Name; base = [IO.Path]::GetFileNameWithoutExtension($Name); ext = $Ext; path = ''; kind = $Kind }
}

$items = @(
    (New-FakeItem 'Steam' '.lnk' 'shortcut')
    (New-FakeItem 'Counter-Strike 2' '.url' 'link')
    (New-FakeItem 'Visual Studio Code' '.lnk' 'shortcut')
    (New-FakeItem 'Telegram' '.lnk' 'shortcut')
    (New-FakeItem 'VLC media player' '.lnk' 'shortcut')
    (New-FakeItem 'AmneziaVPN' '.lnk' 'shortcut')
    (New-FakeItem 'CPUID HWMonitor' '.lnk' 'shortcut')
    (New-FakeItem 'tsetup-x64.6.6.2' '.exe' 'file')
    (New-FakeItem 'Корзина' '' 'system')
    (New-FakeItem 'странная папка' '' 'folder')
)

$groups = New-ProposedGroups $items 'ru'
Check 'группы предложены' ($groups.Count -gt 0) "получено $($groups.Count)"

$byName = @{}
foreach ($g in $groups) { $byName[$g.name] = @($g.items) }

Check 'Steam попал в игры' ($byName['Игры'] -contains 'Steam')
Check 'установщик попал в установщики' ($byName['Установщики'] -contains 'tsetup-x64.6.6.2')
Check 'корзина в системе' ($byName['Система'] -contains 'Корзина')
Check 'неизвестное ушло в прочее' ($byName['Прочее'] -contains 'странная папка')

$assigned = @()
foreach ($g in $groups) { $assigned += @($g.items) }
Check 'все значки распределены ровно один раз' (($assigned | Sort-Object) -join '|' -eq (($items | ForEach-Object { $_.name } | Sort-Object) -join '|'))

# --- эвристики: совпадение по слову, а не по подстроке ---
$tricky = @(
    (New-FakeItem 'Codecs' '.lnk' 'shortcut')
    (New-FakeItem 'Digit' '.lnk' 'shortcut')
    (New-FakeItem 'Anode' '.lnk' 'shortcut')
    (New-FakeItem 'Immediate' '.lnk' 'shortcut')
    (New-FakeItem 'UltraVNC Launcher' '.lnk' 'shortcut')
)
$trickyGroups = New-ProposedGroups $tricky 'ru'
$tmap = @{}
foreach ($g in $trickyGroups) { $tmap[$g.name] = @($g.items) }

Check 'Codecs не попал в разработку' (-not ($tmap['Разработка и AI'] -contains 'Codecs'))
Check 'Digit не попал в разработку' (-not ($tmap['Разработка и AI'] -contains 'Digit'))
Check 'Anode не попал в разработку' (-not ($tmap['Разработка и AI'] -contains 'Anode'))
Check 'Immediate не попал в медиа' (-not ($tmap['Медиа'] -contains 'Immediate'))
Check 'UltraVNC попал в сеть' ($tmap['Сеть и VPN'] -contains 'UltraVNC Launcher')

# --- раскладка ---
$screen = [pscustomobject]@{ width = 1920; height = 1080; workHeight = 1032 }
$grid = [pscustomobject]@{ stepX = 76; stepY = 100; margin = 14; top = 202 }

$layout = New-Layout $groups $screen $grid
Check 'блоки построены' ($layout.blocks.Count -gt 0)
Check 'переполнения нет' (-not $layout.overflow)

$inScreen = $true
foreach ($b in $layout.blocks) {
    if ($b.x -lt 0 -or ($b.x + $b.w) -gt $screen.width) { $inScreen = $false }
    if ($b.y -lt 0 -or ($b.y + $b.h) -gt $screen.workHeight) { $inScreen = $false }
}
Check 'все блоки внутри экрана' $inScreen

$overlaps = 0
for ($i = 0; $i -lt $layout.blocks.Count; $i++) {
    for ($j = $i + 1; $j -lt $layout.blocks.Count; $j++) {
        if (Test-RectOverlap $layout.blocks[$i] $layout.blocks[$j]) { $overlaps++ }
    }
}
Check 'блоки не пересекаются' ($overlaps -eq 0) "пересечений: $overlaps"

$placed = @($layout.plan.Keys)
Check 'в плане столько же значков, сколько в группах' ($placed.Count -eq $assigned.Count) "в плане $($placed.Count), в группах $($assigned.Count)"

$unique = @{}
foreach ($k in $layout.plan.Keys) {
    $p = $layout.plan[$k]
    $unique["$($p.x),$($p.y)"] = $true
}
Check 'позиции уникальны' ($unique.Count -eq $placed.Count)

# --- крайние случаи раскладки ---
$one = @([pscustomobject]@{ name = 'Один'; color = '#888888'; items = @('Один') })
$l1 = New-Layout $one $screen $grid
Check 'группа из одного значка — блок 1x1' ($l1.blocks[0].w -eq $grid.stepX -and $l1.blocks[0].h -eq $grid.stepY)

$many = @([pscustomobject]@{ name = 'Много'; color = '#888888'; items = @(1..150 | ForEach-Object { "icon$_" }) })
$l2 = New-Layout $many $screen $grid
Check '150 значков раскладываются' ($l2.plan.Count -eq 150)
Check '150 значков помещаются на экран' ((-not $l2.overflow) -and (($l2.blocks[0].x + $l2.blocks[0].w) -le $screen.width) -and (($l2.blocks[0].y + $l2.blocks[0].h) -le $screen.workHeight))

$huge = @([pscustomobject]@{ name = 'Огромная'; color = '#888888'; items = @(1..400 | ForEach-Object { "icon$_" }) })
$l2b = New-Layout $huge $screen $grid
Check '400 значков помечаются как переполнение' ($l2b.overflow -eq $true)

$empty = @([pscustomobject]@{ name = 'Пустая'; color = '#888888'; items = @() })
$l3 = New-Layout $empty $screen $grid
Check 'пустая группа не даёт блоков' ($l3.blocks.Count -eq 0)

# --- обои ---
$png = Join-Path ([IO.Path]::GetTempPath()) ('dg-smoke-' + [guid]::NewGuid().ToString('N') + '.png')
try {
    $null = Save-Wallpaper $layout $png
    Check 'обои созданы' ((Test-Path -LiteralPath $png) -and ((Get-Item -LiteralPath $png).Length -gt 5000))

    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($png)
    Check 'размер обоев 1920x1080' ($img.Width -eq 1920 -and $img.Height -eq 1080)
    $img.Dispose()
}
finally {
    if (Test-Path -LiteralPath $png) { Remove-Item -LiteralPath $png -Force }
}

# --- фоновый рисунок: картинка ложится под рамки и затемняется ---
$bgFile = Join-Path ([IO.Path]::GetTempPath()) ('dg-bg-' + [guid]::NewGuid().ToString('N') + '.png')
$bgOut = Join-Path ([IO.Path]::GetTempPath()) ('dg-bgout-' + [guid]::NewGuid().ToString('N') + '.png')
try {
    Add-Type -AssemblyName System.Drawing
    # ровный ярко-красный фон: легко отличить от градиента и от чёрной вуали
    $bmpBg = New-Object System.Drawing.Bitmap(200, 100)
    $gBg = [System.Drawing.Graphics]::FromImage($bmpBg)
    $gBg.Clear([System.Drawing.Color]::FromArgb(255, 220, 30, 30))
    $gBg.Dispose()
    # растягиваем на холст вручную, чтобы не зависеть от DPI
    $big = New-Object System.Drawing.Bitmap(1920, 1080)
    $gBig = [System.Drawing.Graphics]::FromImage($big)
    $gBig.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gBig.DrawImage($bmpBg, (New-Object System.Drawing.Rectangle(0, 0, 1920, 1080)))
    $gBig.Dispose()
    $big.Save($bgFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $big.Dispose()
    $bmpBg.Dispose()

    $null = Save-Wallpaper $layout $bgOut 1920 1080 12 $bgFile
    Check 'обои с фоном созданы' ((Test-Path $bgOut) -and ((Get-Item $bgOut).Length -gt 5000))

    $imgBg = [System.Drawing.Image]::FromFile($bgOut)
    $bmpCheck = New-Object System.Drawing.Bitmap($imgBg)
    # точка в пустой области: фон есть, но затемнён
    $px = $bmpCheck.GetPixel(1800, 1000)
    Check 'фон виден (красный преобладает)' ($px.R -gt $px.G -and $px.R -gt $px.B) "R=$($px.R) G=$($px.G) B=$($px.B)"
    Check 'фон затемнён для читаемости подписей' ($px.R -lt 220) "R=$($px.R)"
    # точка внутри рамки первого блока: там должна быть своя заливка
    $b0 = $layout.blocks[0]
    $px2 = $bmpCheck.GetPixel([int]($b0.x + 5), [int]($b0.y + 5))
    Check 'рамка блока нарисована поверх фона' ($px2.R -ne $px.R) "внутри R=$($px2.R), снаружи R=$($px.R)"
    $bmpCheck.Dispose()
    $imgBg.Dispose()
}
finally {
    foreach ($f in @($bgFile, $bgOut)) {
        if ($f -and (Test-Path -LiteralPath $f)) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    }
}

# --- битый файл фона не должен ломать генерацию ---
$badBg = Join-Path ([IO.Path]::GetTempPath()) ('dg-badbg-' + [guid]::NewGuid().ToString('N') + '.png')
$badOut = Join-Path ([IO.Path]::GetTempPath()) ('dg-badout-' + [guid]::NewGuid().ToString('N') + '.png')
try {
    [IO.File]::WriteAllText($badBg, 'это не картинка', [Text.UTF8Encoding]::new($true))
    $null = Save-Wallpaper $layout $badOut 1920 1080 12 $badBg
    Check 'битый фон не ломает обои (откат на градиент)' ((Test-Path $badOut) -and ((Get-Item $badOut).Length -gt 5000))
}
finally {
    foreach ($f in @($badBg, $badOut)) {
        if ($f -and (Test-Path -LiteralPath $f)) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    }
}

# --- читаемость подписи на светлом фоне ---
$whiteBg = Join-Path ([IO.Path]::GetTempPath()) ('dg-white-' + [guid]::NewGuid().ToString('N') + '.png')
$whiteOut = Join-Path ([IO.Path]::GetTempPath()) ('dg-whiteout-' + [guid]::NewGuid().ToString('N') + '.png')
try {
    Add-Type -AssemblyName System.Drawing
    $wb = New-Object System.Drawing.Bitmap(320, 180)
    $wg = [System.Drawing.Graphics]::FromImage($wb)
    $wg.Clear([System.Drawing.Color]::White)
    $wg.Dispose()
    $wb.Save($whiteBg, [System.Drawing.Imaging.ImageFormat]::Png)
    $wb.Dispose()

    $null = Save-Wallpaper $layout $whiteOut 1920 1080 12 $whiteBg
    $wi = [System.Drawing.Image]::FromFile($whiteOut)
    $wbc = New-Object System.Drawing.Bitmap($wi)
    $b0 = $layout.blocks[0]
    $px = $wbc.GetPixel([int]($b0.x - 12 + 8), [int]($b0.y - 12 - 21))
    $wbc.Dispose(); $wi.Dispose()

    # плашка должна быть заметно темнее светлой картинки
    $lum = 0.2126 * $px.R + 0.7152 * $px.G + 0.0722 * $px.B
    Check 'плашка подписи тёмная даже на белом фоне' ($lum -lt 60) "яркость плашки $([math]::Round($lum,1))"

    # контраст подписи (цвет группы) против плашки — не ниже AA 4.5
    $labelLum = 0.2126 * 224 + 0.7152 * 163 + 0.0722 * 62
    $ratio = ($labelLum + 5) / ($lum + 5)
    if ($ratio -lt 1) { $ratio = 1 / $ratio }
    Check 'контраст подписи не ниже 4.5' ($ratio -ge 4.5) "контраст $([math]::Round($ratio,2))"
}
finally {
    foreach ($f in @($whiteBg, $whiteOut)) {
        if ($f -and (Test-Path -LiteralPath $f)) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    }
}

# --- сопоставление имён ---
$cfg = @([pscustomobject]@{ name = 'Игры'; color = '#E0A33E'; items = @('Steam', 'counter-strike 2') })
$resolved = Resolve-GroupItems $cfg $items
Check 'имена сопоставлены без учёта регистра' ((@($resolved[0].items) -contains 'Counter-Strike 2'))
Check 'несуществующее имя отброшено' ((@($resolved[0].items) -notcontains 'нет такого'))

# --- итог ---
""
if ($script:failed -eq 0) {
    "ВСЁ ПРОШЛО: проверок провалено 0"
    exit 0
}
"ПРОВАЛОВ: $($script:failed)"
exit 1
