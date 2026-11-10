@echo off
rem Удаление DesktopGroups: ярлыки, запись в списке приложений, каталог программы.
rem Настройки сохраняются в %%APPDATA%%\DesktopGroups, обои восстанавливаются.
rem Для портативной копии нужен флаг -Force: %~n0 -Force

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\uninstall.ps1" %*
pause
