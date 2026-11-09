# Ручной тест: читает рабочий стол и рисует обои в build\. Ничего не меняет.
# Запуск: $env:DESKTOPGROUPS_MANUAL_TESTS = 1 ; powershell -File tests\manual\test-engine.ps1

if (-not $env:DESKTOPGROUPS_MANUAL_TESTS) {
    Write-Host 'Это ручной тест: нужен живой рабочий стол. Запуск с $env:DESKTOPGROUPS_MANUAL_TESTS = 1'
    exit 2
}

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root 'lib\Engine.ps1')

$items = Get-DesktopItems
"значков на столе: $($items.Count)"

$groups = New-ProposedGroups $items
"групп предложено: $($groups.Count)"
foreach ($g in $groups) {
    "{0,-20} {1,2} : {2}" -f $g.name, @($g.items).Count, (@($g.items) -join ', ')
}

$screen = Get-ScreenInfo
"экран: $($screen.width)x$($screen.height), рабочая высота $($screen.workHeight)"

$view = Get-DesktopView
try { $grid = Get-ViewGridStep $view } finally { Close-DesktopView $view }
"сетка из вида: $($grid.stepX)x$($grid.stepY), верх $($grid.top)"

$layout = New-Layout $groups $screen $grid
"блоков: $($layout.blocks.Count), переполнение: $($layout.overflow)"
foreach ($b in $layout.blocks) {
    "{0,-24} x={1,4} y={2,3}  {3}x{4}  значков: {5}" -f $b.name, $b.x, $b.y, $b.w, $b.h, @($b.items).Count
}

$buildDir = Join-Path $root 'build'
if (-not (Test-Path -LiteralPath $buildDir)) { New-Item -ItemType Directory -Path $buildDir -Force | Out-Null }
$png = Join-Path $buildDir 'test-wallpaper.png'
$null = Save-Wallpaper $layout $png $screen.width $screen.height
"обои: $png, $((Get-Item -LiteralPath $png).Length) байт"
