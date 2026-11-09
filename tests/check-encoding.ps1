# Проверка кодировки и разбора скриптов.
# Windows PowerShell 5.1 читает файл без BOM как ANSI: кириллица ломается,
# файл перестаёт разбираться. CI обязан это ловить.
# Запускать и через powershell.exe (5.1), и через pwsh (7).

$root = Split-Path -Parent $PSScriptRoot
$noBom = @()
$parseErrors = 0
$checked = 0

$files = Get-ChildItem -LiteralPath $root -Recurse -File |
    Where-Object { $_.Extension -eq '.ps1' -or $_.Extension -eq '.psd1' } |
    Where-Object { $_.FullName -notlike '*\dist\*' -and $_.FullName -notlike '*\.git\*' }

foreach ($f in $files) {
    $checked++
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if (-not $hasBom) { $noBom += $f.FullName }

    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
    foreach ($e in $errors) {
        "ОШИБКА РАЗБОРА: $($f.Name):$($e.Extent.StartLineNumber) $($e.Message)"
        $parseErrors++
    }
}

foreach ($f in $noBom) { "НЕТ BOM: $f" }

"проверено файлов: $checked, без BOM: $($noBom.Count), ошибок разбора: $parseErrors"
"хостер: " + $PSVersionTable.PSVersion.ToString()

if ($noBom.Count -gt 0 -or $parseErrors -gt 0) { exit 1 }
exit 0
