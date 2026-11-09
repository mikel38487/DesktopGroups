@echo off
rem DesktopGroups — запуск без окна консоли.
rem powershell.exe вызывается по полному пути: иначе Windows ищет его
rem в текущем каталоге раньше PATH и может запустить подложенный файл.

start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0DesktopGroups.ps1"
