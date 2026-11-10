# Удаление DesktopGroups: ярлыки, запись в списке приложений, каталог программы.
# Перед удалением настройки копируются в %APPDATA%\DesktopGroups, чтобы группы
# не пропали. Обои возвращаются к тем, что были до установки.
# Запускается из папки установки или через «Приложения» в параметрах системы.

param(
    [switch]$Purge,      # не сохранять настройки
    [switch]$Force       # удалять, даже если это похоже на портативную копию
)

$ErrorActionPreference = 'SilentlyContinue'

$dest = Split-Path -Parent $PSScriptRoot

# проверяем, что это действительно каталог программы, а не что-то похожее
if (-not (Test-Path -LiteralPath (Join-Path $dest 'DesktopGroups.ps1'))) {
    Write-Host "Каталог $dest не похож на установку DesktopGroups — удаление отменено."
    exit 1
}

$installedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DesktopGroups'

# Важно: проверяем не «есть ли установка на машине», а «этот каталог — она».
# Иначе запуск из распакованной папки сносил бы чужие установки и ярлыки.
$installLocation = $null
if (Test-Path -Path $installedKey) {
    $installLocation = [string](Get-ItemProperty -Path $installedKey -ErrorAction SilentlyContinue).InstallLocation
}
$isInstalledHere = $false
if ($installLocation) {
    try {
        $a = [IO.Path]::GetFullPath($installLocation).TrimEnd('\')
        $b = [IO.Path]::GetFullPath($dest).TrimEnd('\')
        $isInstalledHere = ($a -eq $b)
    }
    catch {
        $isInstalledHere = $false
    }
}

# Портативная копия: каталог целиком удаляется, поэтому предупреждаем,
# если рядом могли лежать чужие файлы.
if (-not $isInstalledHere -and -not $Force) {
    Write-Host 'Это не установленная копия, а распакованная вручную.'
    Write-Host "Каталог $dest будет удалён полностью, вместе с файлами, которые вы туда положили."
    Write-Host 'Ни ярлыки, ни запись в списке приложений, ни обои затронуты не будут.'
    Write-Host 'Если это не то, что нужно, закройте окно. Для удаления повторите с -Force.'
    exit 2
}

# Настройки сохраняем до удаления: иначе вместе с программой уедут и группы.
$config = Join-Path $dest 'config.json'
$savedConfig = $null
if ((Test-Path -LiteralPath $config) -and -not $Purge) {
    $keepDir = Join-Path $env:APPDATA 'DesktopGroups'
    New-Item -ItemType Directory -Path $keepDir -Force | Out-Null
    $savedConfig = Join-Path $keepDir ('config-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Copy-Item -LiteralPath $config -Destination $savedConfig -Force
    Write-Host "настройки сохранены: $savedConfig"
}

# Ярлыки, запись в приложениях и обои — только для установленной копии:
# портативная папка не должна трогать систему.
if ($isInstalledHere) {
$links = @(
    (Join-Path ([Environment]::GetFolderPath('Programs')) 'DesktopGroups.lnk'),
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'DesktopGroups.lnk')
)
foreach ($link in $links) {
    if (Test-Path -LiteralPath $link) {
        Remove-Item -LiteralPath $link -Force
        Write-Host "удалён ярлык: $link"
    }
}

if (Test-Path -Path $installedKey) {
    Remove-Item -Path $installedKey -Recurse -Force
    Write-Host 'удалена запись в списке приложений'
}

# возвращаем обои, которые были до установки
$prevFile = Join-Path $dest 'previous-wallpaper.json'
$restored = $false
if (Test-Path -LiteralPath $prevFile) {
    try {
        $prev = Get-Content -LiteralPath $prevFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $wall = [string]$prev.Wallpaper
        if ($wall -and (Test-Path -LiteralPath $wall)) {
            Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $wall
            Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value ([string]$prev.WallpaperStyle)
            Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value ([string]$prev.TileWallpaper)
            Add-Type -Namespace W -Name U -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);'
            [void][W.U]::SystemParametersInfo(0x0014, 0, $wall, 3)
            $restored = $true
            Write-Host "обои восстановлены: $wall"
        }
    }
    catch {
        Write-Host 'не удалось вернуть прежние обои: ' + $_.Exception.Message
    }
}
if (-not $restored) {
    $fallback = Join-Path $env:SystemRoot 'web\wallpaper\Windows\img0.jpg'
    if (Test-Path -LiteralPath $fallback) {
        Add-Type -Namespace W -Name U2 -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);'
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $fallback
        [void][W.U2]::SystemParametersInfo(0x0014, 0, $fallback, 3)
        Write-Host 'поставлены стандартные обои Windows'
    }
}
}
else {
    Write-Host 'Портативная копия: ярлыки, запись в списке приложений и обои не тронуты.'
}

# Каталог удаляем отдельным процессом: этот скрипт лежит внутри него.
# Путь передаём переменной окружения, а не склейкой в текст команды:
# апостроф в пути иначе стал бы исполняемым кодом.
$psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$env:DESKTOPGROUPS_UNINSTALL_DIR = $dest
Start-Process -FilePath $psExe -WindowStyle Hidden -ArgumentList @(
    '-NoProfile',
    '-Command',
    'Start-Sleep -Seconds 2; Remove-Item -LiteralPath $env:DESKTOPGROUPS_UNINSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue'
) | Out-Null

Write-Host "DesktopGroups удалён. Каталог $dest будет удалён через пару секунд."
if ($savedConfig) { Write-Host "Группы сохранены: $savedConfig" }
