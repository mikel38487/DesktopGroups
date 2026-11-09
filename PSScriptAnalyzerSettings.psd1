@{
    # Настройки PSScriptAnalyzer для проекта.
    # Отключённые правила — осознанно, с причиной.

    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # Имена вроде Get-DesktopItems / Read-ViewItems читаются лучше, чем
        # Get-DesktopItem: функция возвращает коллекцию, и это видно по имени.
        'PSUseSingularNouns'

        # Правило требует -WhatIf/-Confirm у всех функций с глаголами Set/New/Update.
        # Здесь это GUI-приложение: подтверждения живут в диалогах, а движок
        # вызывается из окна, а не из конвейера. Добавлять ShouldProcess к
        # New-Layout (чистая функция без побочных эффектов) бессмысленно.
        'PSUseShouldProcessForStateChangingFunctions'

        # Write-Host в install/uninstall/build — это консольные утилиты, где вывод
        # адресован человеку, а не конвейеру. Write-Information тут был бы лишним.
        'PSAvoidUsingWriteHost'
    )
}
