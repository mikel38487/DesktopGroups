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

# Каталог удаляем отдельным процессом: этот скрипт лежит внутри него
$psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$cleanup = 'Start-Sleep -Seconds 2; Remove-Item -LiteralPath ''' + $dest + ''' -Recurse -Force -ErrorAction SilentlyContinue'
Start-Process -FilePath $psExe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-Command', $cleanup) | Out-Null

Write-Host "DesktopGroups удалён. Каталог $dest будет удалён через пару секунд."
