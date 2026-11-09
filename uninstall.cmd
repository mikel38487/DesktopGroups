@echo off
rem Удаление DesktopGroups: ярлыки, запись в списке приложений, папка программы.
rem Обои рабочего стола не восстанавливаются — их можно вернуть в параметрах Windows.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\uninstall.ps1"
pause
