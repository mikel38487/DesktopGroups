# Ручной тест: показывает, какие имена из config.json не совпали с рабочим столом.
# Только чтение. Запуск: $env:DESKTOPGROUPS_MANUAL_TESTS = 1 ; powershell -File tests\manual\diff-names.ps1

if (-not $env:DESKTOPGROUPS_MANUAL_TESTS) {
    Write-Host 'Это ручной тест: нужен живой рабочий стол. Запуск с $env:DESKTOPGROUPS_MANUAL_TESTS = 1'
    exit 2
}

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root 'lib\Engine.ps1')

$view = Get-DesktopView
try { $actual = Read-ViewItems $view } finally { Close-DesktopView $view }

$cfgPath = Join-Path $root 'config.json'
$cfg = [IO.File]::ReadAllText($cfgPath, [Text.UTF8Encoding]::new($true)) | ConvertFrom-Json

$cfgNames = @{}
foreach ($g in $cfg.groups) { foreach ($i in @($g.items)) { $cfgNames[[string]$i] = $g.name } }

"--- в конфиге, но не совпало с видом ---"
foreach ($k in $cfgNames.Keys) {
    if (-not ($actual.name -contains $k)) { "конфиг: [$k] (группа $($cfgNames[$k]))" }
}

"--- в виде, но не в конфиге ---"
foreach ($a in $actual) {
    if (-not $cfgNames.ContainsKey($a.name)) { "вид: [$($a.name)]  x=$($a.x) y=$($a.y)" }
}
