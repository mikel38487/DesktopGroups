# Ручной тест: РАСКЛАДЫВАЕТ значки и ставит обои. В CI не запускается.
# Запуск: $env:DESKTOPGROUPS_MANUAL_TESTS = 1 ; powershell -File tests\manual\apply-all.ps1

if (-not $env:DESKTOPGROUPS_MANUAL_TESTS) {
    Write-Host 'Это ручной тест: он меняет раскладку и обои рабочего стола.'
    Write-Host 'Запуск: $env:DESKTOPGROUPS_MANUAL_TESTS = 1 ; powershell -File tests\manual\apply-all.ps1'
    exit 2
}

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root 'lib\Engine.ps1')

$items = Get-DesktopItems
"значков: $($items.Count)"

$groups = New-ProposedGroups $items
"групп: $($groups.Count)"

$data = @{ groups = @(); updated = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
foreach ($g in $groups) { $data.groups += @{ name = $g.name; color = $g.color; items = @($g.items) } }
[IO.File]::WriteAllText((Join-Path $root 'config.json'), ($data | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($true))
"конфиг записан"

$view = Get-DesktopView
try { $grid = Get-ViewGridStep $view } finally { Close-DesktopView $view }
$layout = New-Layout $groups (Get-ScreenInfo) $grid
"блоков: $($layout.blocks.Count), переполнение: $($layout.overflow)"

$res = Invoke-DesktopLayout $layout (Join-Path $root 'backups')
"расставлено: $($res.placed), проходов: $($res.passes), расхождений: $($res.mismatches.Count)"
foreach ($m in $res.mismatches) { "  не встало: $($m.name) ждали $($m.expected), факт $($m.actual)" }
foreach ($u in $res.unknown) { "  вне плана: $u" }

$screen = Get-ScreenInfo
$png = Join-Path $root 'wallpaper.png'
$null = Save-Wallpaper $layout $png $screen.width $screen.height
$ok = Set-DesktopWallpaper $png
"обои: $png, применены: $ok"

$view = Get-DesktopView
try { $actual = Read-ViewItems $view } finally { Close-DesktopView $view }
$bad = 0
foreach ($it in $actual) {
    if (-not $layout.plan.ContainsKey($it.name)) { "НЕТ В ПЛАНЕ: $($it.name)"; $bad++; continue }
    $t = $layout.plan[$it.name]
    if ($it.x -ne $t.x -or $it.y -ne $t.y) { "НЕ ВСТАЛО: $($it.name) ждали $($t.x),$($t.y) факт $($it.x),$($it.y)"; $bad++ }
}
"итог: значков $($actual.Count), проблем $bad"
