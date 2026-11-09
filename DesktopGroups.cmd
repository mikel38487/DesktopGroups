@echo off
rem DesktopGroups — запуск без окна консоли
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0DesktopGroups.ps1"
