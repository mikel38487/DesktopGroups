# Фаззинг config.json: единственный внешний ввод программы — имена групп.
# Проверяем, что мусор в именах не ломает разбор, раскладку и отрисовку обоев.
# Рабочий стол не трогается.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'lib\Engine.ps1')

$cases = @(
    @{ name = 'кавычки'; value = 'Группа "с кавычками" и ''одинарными''' }
    @{ name = 'перевод строки'; value = "Группа`r`nсо второй строкой" }
    @{ name = 'табуляция'; value = "Группа`tтаб" }
    @{ name = 'очень длинное имя'; value = ('Я' * 10000) }
    @{ name = 'путь вместо имени'; value = '..\..\Windows\System32' }
    @{ name = 'HTML'; value = '<script>alert(1)</script>' }
    @{ name = 'эмодзи'; value = 'Игры 🎮🕹️' }
    @{ name = 'RTL'; value = 'مجموعة' }
    @{ name = 'нулевой символ'; value = "до$([char]0)после" }
    @{ name = 'только пробелы'; value = '    ' }
    @{ name = 'пустое имя'; value = '' }
)

$screen = [pscustomobject]@{ width = 1920; height = 1080; workHeight = 1032 }
$grid = [pscustomobject]@{ stepX = 76; stepY = 100; margin = 14; top = 202 }

$failed = 0
$tmpDir = Join-Path ([IO.Path]::GetTempPath()) ('dg-fuzz-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

try {
    foreach ($case in $cases) {
        $label = $case.name
        try {
            # 1. запись конфига и разбор — как это делает программа
            $data = @{
                groups  = @(@{ name = $case.value; color = '#8C8C8C'; items = @('Корзина', 'tdata') })
                updated = '2026-11-09 12:00'
            }
            $path = Join-Path $tmpDir 'config.json'
            [IO.File]::WriteAllText($path, ($data | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($true))

            $raw = [IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($true))
            $parsed = $raw | ConvertFrom-Json
            $groups = @()
            foreach ($g in $parsed.groups) {
                $groups += [pscustomobject]@{ name = [string]$g.name; color = [string]$g.color; items = @($g.items) }
            }

            # 2. раскладка
            $layout = New-Layout $groups $screen $grid

            # 3. обои
            $png = Join-Path $tmpDir ('wall-' + [guid]::NewGuid().ToString('N') + '.png')
            $null = Save-Wallpaper $layout $png
            $ok = (Test-Path -LiteralPath $png) -and ((Get-Item -LiteralPath $png).Length -gt 1000)
            Remove-Item -LiteralPath $png -Force -ErrorAction SilentlyContinue

            if ($ok) {
                "ok    $label"
            }
            else {
                "FAIL  $label — обои не созданы"
                $failed++
            }
        }
        catch {
            "FAIL  $label — исключение: $($_.Exception.Message)"
            $failed++
        }
    }

    # 4. битый JSON: программа должна не упасть, а вернуться к предложению групп
    $broken = Join-Path $tmpDir 'broken.json'
    [IO.File]::WriteAllText($broken, '{ "groups": [ { "name": ', [Text.UTF8Encoding]::new($true))
    try {
        $raw = [IO.File]::ReadAllText($broken, [Text.UTF8Encoding]::new($true))
        $null = $raw | ConvertFrom-Json
        "FAIL  битый JSON не вызвал ошибку"
        $failed++
    }
    catch {
        "ok    битый JSON отвергнут (программа пересоберёт группы)"
    }

    # 5. пустой файл: ConvertFrom-Json вернёт $null без исключения,
    #    поэтому программа обязана проверять результат явно
    $emptyFile = Join-Path $tmpDir 'empty.json'
    [IO.File]::WriteAllText($emptyFile, '', [Text.UTF8Encoding]::new($true))
    $raw = [IO.File]::ReadAllText($emptyFile, [Text.UTF8Encoding]::new($true))
    $data = $raw | ConvertFrom-Json
    if ($null -eq $data -or $null -eq $data.groups) {
        "ok    пустой файл отвергнут явной проверкой"
    }
    else {
        "FAIL  пустой файл прошёл проверку"
        $failed++
    }
}
finally {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

""
if ($failed -eq 0) {
    "ВСЁ ПРОШЛО: провалов 0"
    exit 0
}
"ПРОВАЛОВ: $failed"
exit 1
