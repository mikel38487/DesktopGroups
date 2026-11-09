@echo off
rem Удаление DesktopGroups: ярлыки, запись в списке приложений, каталог программы.
rem Обои рабочего стола восстанавливаются из previous-wallpaper.json.

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\uninstall.ps1"
pause
