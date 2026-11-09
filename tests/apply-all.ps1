$ErrorActionPreference = 'Stop'
. 'F:\AI\DesktopGroups\lib\Engine.ps1'

$dir = 'F:\AI\DesktopGroups'

# 1. скан
$items = Get-DesktopItems
"значков: $($items.Count)"

# 2. предложение групп
$groups = New-ProposedGroups $items
"групп: $($groups.Count)"

# 3. конфиг
$data = @{ groups = @(); updated = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
foreach ($g in $groups) { $data.groups += @{ name = $g.name; color = $g.color; items = @($g.items) } }
[IO.File]::WriteAllText((Join-Path $dir 'config.json'), ($data | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($true))
"конфиг записан"

# 4. раскладка
$view = Get-DesktopView
try { $grid = Get-ViewGridStep $view } finally { Close-DesktopView $view }
$layout = New-Layout $groups (Get-ScreenInfo) $grid
"блоков: $($layout.blocks.Count), переполнение: $($layout.overflow)"

# 5. применение
$res = Invoke-DesktopLayout $layout (Join-Path $dir 'backups')
"расставлено: $($res.placed), проходов: $($res.passes), расхождений: $($res.mismatches.Count)"
foreach ($m in $res.mismatches) { "  не встало: $($m.name) ждали $($m.expected), факт $($m.actual)" }
foreach ($u in $res.unknown) { "  вне плана: $u" }

# 6. обои
$png = Join-Path $dir 'wallpaper.png'
$null = Save-Wallpaper $layout $png
$ok = Set-DesktopWallpaper $png
"обои: $png, $((Get-Item $png).Length) байт, применены: $ok"

# 7. контрольная сверка
$view = Get-DesktopView
try { $actual = Read-ViewItems $view } finally { Close-DesktopView $view }
$bad = 0
foreach ($it in $actual) {
    if (-not $layout.plan.ContainsKey($it.name)) { "НЕТ В ПЛАНЕ: $($it.name)"; $bad++; continue }
    $t = $layout.plan[$it.name]
    if ($it.x -ne $t.x -or $it.y -ne $t.y) { "НЕ ВСТАЛО: $($it.name) ждали $($t.x),$($t.y) факт $($it.x),$($it.y)"; $bad++ }
}
"итог: значков $($actual.Count), проблем $bad"
