. 'F:\AI\DesktopGroups\lib\Engine.ps1'
$view = Get-DesktopView
try { $actual = Read-ViewItems $view } finally { Close-DesktopView $view }
$cfg = [IO.File]::ReadAllText('F:\AI\DesktopGroups\config.json', [Text.UTF8Encoding]::new($true)) | ConvertFrom-Json
$cfgNames = @{}
foreach ($g in $cfg.groups) { foreach ($i in @($g.items)) { $cfgNames[[string]$i] = $g.name } }

"--- в конфиге, но не совпало с видом ---"
foreach ($k in $cfgNames.Keys) {
  if (-not ($actual.name -contains $k)) { "конфиг: [$k] (группа $($cfgNames[$k]))" }
}
"--- в виде, но не в конфиге ---"
foreach ($a in $actual) { if (-not $cfgNames.ContainsKey($a.name)) { "вид: [$($a.name)]  x=$($a.x) y=$($a.y)" } }