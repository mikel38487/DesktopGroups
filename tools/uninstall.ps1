# Удаление DesktopGroups: ярлыки, запись в списке приложений, каталог программы.
# Обои рабочего стола остаются — их возвращают в параметрах Windows.
# Запускается из папки установки или через «Приложения» в параметрах системы.

$ErrorActionPreference = 'SilentlyContinue'

$dest = Split-Path -Parent $PSScriptRoot

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

$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DesktopGroups'
if (Test-Path -Path $key) {
    Remove-Item -Path $key -Recurse -Force
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

# проверяем, что это действительно каталог программы, а не что-то похожее
if (-not (Test-Path -LiteralPath (Join-Path $dest 'DesktopGroups.ps1'))) {
    Write-Host "Каталог $dest не похож на установку DesktopGroups — удаление отменено."
    exit 1
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
