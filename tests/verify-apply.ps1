$ErrorActionPreference = 'Stop'
. 'F:\AI\DesktopGroups\lib\Engine.ps1'

$cfg = [IO.File]::ReadAllText('F:\AI\DesktopGroups\config.json', [Text.UTF8Encoding]::new($true)) | ConvertFrom-Json
$groups = @()
foreach ($g in $cfg.groups) { $groups += [pscustomobject]@{ name = $g.name; color = $g.color; items = @($g.items) } }
"групп в конфиге: $($groups.Count)"

$view = Get-DesktopView
try {
    $grid = Get-ViewGridStep $view
    $layout = New-Layout $groups (Get-ScreenInfo) $grid
    $actual = Read-ViewItems $view
} finally { Close-DesktopView $view }

$bad = 0
foreach ($it in $actual) {
    if (-not $layout.plan.ContainsKey($it.name)) { "вне плана: $($it.name)"; continue }
    $t = $layout.plan[$it.name]
    if ($it.x -ne $t.x -or $it.y -ne $t.y) { "НЕ ВСТАЛО: $($it.name) ждали $($t.x),$($t.y) факт $($it.x),$($it.y)"; $bad++ }
}
"проверено значков: $($actual.Count), расхождений: $bad"

$png = 'F:\AI\DesktopGroups\wallpaper.png'
if (Test-Path $png) { "обои: $((Get-Item $png).Length) байт, $((Get-Item $png).LastWriteTime)" } else { "обои: НЕТ ФАЙЛА" }
"реестр Wallpaper: $((Get-ItemProperty 'HKCU:\Control Panel\Desktop').Wallpaper)"