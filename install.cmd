@echo off
rem Установка DesktopGroups: копирует программу в профиль пользователя,
rem создаёт ярлык в меню «Пуск» и запись в списке приложений.
rem Права администратора не нужны.

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\install.ps1" %*
if errorlevel 1 (
    echo.
    echo Установка не удалась. Подробности выше.
    pause
)
