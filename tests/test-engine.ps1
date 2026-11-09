$ErrorActionPreference = 'Stop'
. 'F:\AI\DesktopGroups\lib\Engine.ps1'

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

$png = 'F:\AI\DesktopGroups\build\test-wallpaper.png'
$null = Save-Wallpaper $layout $png
"обои: $png, $((Get-Item -LiteralPath $png).Length) байт"
