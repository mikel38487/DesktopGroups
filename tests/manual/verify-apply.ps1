# Ручной тест: сверяет config.json с фактическими позициями значков. Только чтение.
# Запуск: $env:DESKTOPGROUPS_MANUAL_TESTS = 1 ; powershell -File tests\manual\verify-apply.ps1

if (-not $env:DESKTOPGROUPS_MANUAL_TESTS) {
    Write-Host 'Это ручной тест: нужен живой рабочий стол. Запуск с $env:DESKTOPGROUPS_MANUAL_TESTS = 1'
    exit 2
}

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root 'lib\Engine.ps1')

$cfgPath = Join-Path $root 'config.json'
if (-not (Test-Path -LiteralPath $cfgPath)) { throw "нет конфига: $cfgPath" }

$cfg = [IO.File]::ReadAllText($cfgPath, [Text.UTF8Encoding]::new($true)) | ConvertFrom-Json
$groups = @()
foreach ($g in $cfg.groups) { $groups += [pscustomobject]@{ name = $g.name; color = $g.color; items = @($g.items) } }
"групп в конфиге: $($groups.Count)"

$view = Get-DesktopView
try {
    $grid = Get-ViewGridStep $view
    $layout = New-Layout $groups (Get-ScreenInfo) $grid
    $actual = Read-ViewItems $view
}
finally { Close-DesktopView $view }

$bad = 0
foreach ($it in $actual) {
    if (-not $layout.plan.ContainsKey($it.name)) { "вне плана: $($it.name)"; continue }
    $t = $layout.plan[$it.name]
    if ($it.x -ne $t.x -or $it.y -ne $t.y) { "НЕ ВСТАЛО: $($it.name) ждали $($t.x),$($t.y) факт $($it.x),$($it.y)"; $bad++ }
}
"проверено значков: $($actual.Count), расхождений: $bad"

$png = Join-Path $root 'wallpaper.png'
if (Test-Path -LiteralPath $png) { "обои: $((Get-Item $png).Length) байт, $((Get-Item $png).LastWriteTime)" } else { 'обои: файла нет' }
"реестр Wallpaper: $((Get-ItemProperty 'HKCU:\Control Panel\Desktop').Wallpaper)"
