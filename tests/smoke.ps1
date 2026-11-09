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

$groups = New-ProposedGroups $items
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
$trickyGroups = New-ProposedGroups $tricky
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
