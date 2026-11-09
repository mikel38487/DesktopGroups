# Установка DesktopGroups без компиляции и без прав администратора.
# Копирует программу в %LOCALAPPDATA%\Programs\DesktopGroups, делает ярлык
# в меню «Пуск» и запись в списке установленных приложений.

param(
    [switch]$DesktopShortcut,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$source = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $env:LOCALAPPDATA 'Programs\DesktopGroups'

$skipDirs = @('.git', '.github', 'docs', 'tests', 'dist', 'backups', 'build')
$skipFiles = @('config.json', 'wallpaper.png', '.gitignore', '.gitattributes', 'PSScriptAnalyzerSettings.psd1')

$version = '0.0.0'
$verFile = Join-Path $source 'VERSION'
if (Test-Path -LiteralPath $verFile) {
    $version = (Get-Content -LiteralPath $verFile -Raw).Trim()
}

Write-Host "DesktopGroups $version"
Write-Host "источник: $source"
Write-Host "куда:     $dest"

New-Item -ItemType Directory -Path $dest -Force | Out-Null

foreach ($item in Get-ChildItem -LiteralPath $source -Force) {
    if ($item.PSIsContainer -and ($skipDirs -contains $item.Name)) { continue }
    if (-not $item.PSIsContainer -and ($skipFiles -contains $item.Name)) { continue }
    Copy-Item -LiteralPath $item.FullName -Destination $dest -Recurse -Force
}

$psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$appScript = Join-Path $dest 'DesktopGroups.ps1'

# запоминаем текущие обои, чтобы вернуть их при удалении
# (при повторной установке не перезаписываем — иначе запомним свои же обои)
$prevFile = Join-Path $dest 'previous-wallpaper.json'
if (-not (Test-Path -LiteralPath $prevFile)) {
    $cur = Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop'
    @{
        Wallpaper      = [string]$cur.Wallpaper
        WallpaperStyle = [string]$cur.WallpaperStyle
        TileWallpaper  = [string]$cur.TileWallpaper
    } | ConvertTo-Json | Set-Content -LiteralPath $prevFile -Encoding UTF8
    Write-Host 'обои до установки запомнены'
}

function New-Shortcut {
    param([string]$Path)

    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($Path)
    $link.TargetPath = $psExe
    $link.Arguments = '-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $appScript + '"'
    $link.WorkingDirectory = $dest
    $link.IconLocation = "$env:SystemRoot\System32\shell32.dll,3"
    $link.Description = 'Группы ярлыков рабочего стола'
    $link.Save()
}

$startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'DesktopGroups.lnk'
New-Shortcut -Path $startMenu
Write-Host "ярлык:    $startMenu"

if ($DesktopShortcut) {
    $desktopLink = Join-Path ([Environment]::GetFolderPath('Desktop')) 'DesktopGroups.lnk'
    New-Shortcut -Path $desktopLink
    Write-Host "на столе: $desktopLink"
}

# запись в списке приложений — чтобы удалять штатно, через «Приложения»
$uninstallScript = Join-Path $dest 'tools\uninstall.ps1'
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DesktopGroups'
New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name DisplayName -Value 'DesktopGroups'
Set-ItemProperty -Path $key -Name DisplayVersion -Value $version
Set-ItemProperty -Path $key -Name Publisher -Value 'mikel38487'
Set-ItemProperty -Path $key -Name InstallLocation -Value $dest
Set-ItemProperty -Path $key -Name DisplayIcon -Value "$env:SystemRoot\System32\shell32.dll,3"
Set-ItemProperty -Path $key -Name NoModify -Value 1 -Type DWord
Set-ItemProperty -Path $key -Name NoRepair -Value 1 -Type DWord
Set-ItemProperty -Path $key -Name UninstallString -Value ('"' + $psExe + '" -NoProfile -ExecutionPolicy Bypass -File "' + $uninstallScript + '"')

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'Готово. Запуск: меню «Пуск» → DesktopGroups.'
    Write-Host 'Удаление: «Приложения» в параметрах Windows или uninstall.cmd рядом с программой.'
}
