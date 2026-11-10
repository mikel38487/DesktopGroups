# Проверка двуязычности: наборы ключей совпадают, пустых строк нет,
# все ключи из кода существуют в таблице, названия групп локализованы.
# Запуск: powershell.exe -NoProfile -File tests\i18n.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'lib\Engine.ps1')
. (Join-Path $root 'lib\Strings.ps1')

$failed = 0

function Check {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) { "ok    $Name" }
    else { "FAIL  $Name $Detail"; $script:failed++ }
}

$ruKeys = Get-StringKeys 'ru'
$enKeys = Get-StringKeys 'en'

Check 'ключей в ru столько же, сколько в en' ($ruKeys.Count -eq $enKeys.Count) "ru=$($ruKeys.Count) en=$($enKeys.Count)"

$onlyRu = @($ruKeys | Where-Object { $enKeys -notcontains $_ })
$onlyEn = @($enKeys | Where-Object { $ruKeys -notcontains $_ })
Check 'нет ключей только в ru' ($onlyRu.Count -eq 0) ($onlyRu -join ', ')
Check 'нет ключей только в en' ($onlyEn.Count -eq 0) ($onlyEn -join ', ')

foreach ($lang in @('ru', 'en')) {
    $empty = @()
    foreach ($k in (Get-StringKeys $lang)) {
        $v = $script:StringTable[$lang][$k]
        if ($null -eq $v -or -not ([string]$v).Trim()) { $empty += $k }
    }
    Check "нет пустых строк ($lang)" ($empty.Count -eq 0) ($empty -join ', ')
}

# все ключи, которые реально используются в коде, должны существовать
$luaKeys = @{}
foreach ($file in @('DesktopGroups.ps1', 'lib\Engine.ps1')) {
    $text = [IO.File]::ReadAllText((Join-Path $root $file), [Text.UTF8Encoding]::new($true))
    foreach ($m in [regex]::Matches($text, "T\s+'([a-z][a-z0-9]*\.[A-Za-z0-9]+)'")) {
        $luaKeys[$m.Groups[1].Value] = $true
    }
    foreach ($m in [regex]::Matches($text, "-Key '([a-z][a-z0-9]*\.[A-Za-z0-9]+)'")) {
        $luaKeys[$m.Groups[1].Value] = $true
    }
}
$missing = @($luaKeys.Keys | Where-Object { $ruKeys -notcontains $_ })
Check 'все ключи из кода есть в таблице' ($missing.Count -eq 0) ($missing -join ', ')

# литералы там, где должен быть перевод: .Text и MessageBox
$literals = @()
foreach ($file in @('DesktopGroups.ps1')) {
    $lines = [IO.File]::ReadAllLines((Join-Path $root $file), [Text.UTF8Encoding]::new($true))
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l -match "\.Text\s*=\s*'[^']*[А-Яа-яЁё]{3}" ) { $literals += "${file}:$($i+1)" }
        if ($l -match "MessageBox\]::Show\('" ) { $literals += "${file}:$($i+1)" }
    }
}
Check 'нет русских литералов в .Text и MessageBox' ($literals.Count -eq 0) ($literals -join ', ')

# одинаковые наборы плейсхолдеров в обоих языках
$mismatch = @()
foreach ($k in $ruKeys) {
    $ruText = [string]$script:StringTable['ru'][$k]
    $enText = [string]$script:StringTable['en'][$k]
    $ruPh = @([regex]::Matches($ruText, '\{\d+\}') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    $enPh = @([regex]::Matches($enText, '\{\d+\}') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    if (($ruPh -join ',') -ne ($enPh -join ',')) { $mismatch += "$k (ru: $($ruPh -join ',') / en: $($enPh -join ','))" }
}
Check 'плейсхолдеры совпадают в обоих языках' ($mismatch.Count -eq 0) ($mismatch -join '; ')

# подстановка параметров
Set-Language 'ru'
$s1 = T 'lbl.top' @(47, 9)
Check 'подстановка параметров (ru)' ($s1 -match '47' -and $s1 -match '9') $s1

# ноль — отдельный случай: массив из одного нуля ложен в логическом контексте
$zero = T 'lbl.unassigned' @(0)
Check 'подстановка нуля' ($zero -notmatch '\{0\}' -and $zero -match '0') $zero

$zeroEn = & { Set-Language 'en'; T 'lbl.unassigned' @(0) }
Check 'подстановка нуля (en)' ($zeroEn -notmatch '\{0\}' -and $zeroEn -match '0') $zeroEn

Set-Language 'en'
$s2 = T 'lbl.top' @(47, 9)
Check 'подстановка параметров (en)' ($s2 -match 'Icons' -and $s2 -match '47') $s2
Check 'английский текст отличается от русского' ($s1 -ne $s2)

# названия групп
Check 'название группы ru' ((Get-GroupName -Id 'games' -Lang 'ru') -eq 'Игры') (Get-GroupName -Id 'games' -Lang 'ru')
Check 'название группы en' ((Get-GroupName -Id 'games' -Lang 'en') -eq 'Games') (Get-GroupName -Id 'games' -Lang 'en')
Check 'служебная группа ru' ((Get-GroupName -Id 'other' -Lang 'ru') -eq 'Прочее')
Check 'служебная группа en' ((Get-GroupName -Id 'other' -Lang 'en') -eq 'Misc')

# предложение групп на английском даёт английские названия
$items = @(
    [pscustomobject]@{ name = 'Steam'; base = 'Steam'; ext = '.lnk'; path = ''; kind = 'shortcut' }
    [pscustomobject]@{ name = 'Telegram'; base = 'Telegram'; ext = '.lnk'; path = ''; kind = 'shortcut' }
    [pscustomobject]@{ name = 'VLC media player'; base = 'VLC media player'; ext = '.lnk'; path = ''; kind = 'shortcut' }
    [pscustomobject]@{ name = 'Random folder'; base = 'Random folder'; ext = ''; path = ''; kind = 'folder' }
)

$en = New-ProposedGroups $items 'en'
$enNames = @($en | ForEach-Object { $_.name })
Check 'английские названия групп при -Lang en' (($enNames -contains 'Games') -and ($enNames -contains 'Chat & Internet') -and ($enNames -contains 'Media') -and ($enNames -contains 'Misc')) ($enNames -join ', ')

$ru = New-ProposedGroups $items 'ru'
$ruNames = @($ru | ForEach-Object { $_.name })
Check 'русские названия групп при -Lang ru' (($ruNames -contains 'Игры') -and ($ruNames -contains 'Связь и интернет') -and ($ruNames -contains 'Прочее')) ($ruNames -join ', ')

# ключ из одного языка не должен «течь» в другой
Set-Language 'en'
$before = T 'btn.apply'
Set-Language 'ru'
$after = T 'btn.apply'
Check 'смена языка меняет подпись кнопки' ($before -ne $after) "$before / $after"

""
if ($failed -eq 0) {
    "ВСЁ ПРОШЛО: провалов 0"
    exit 0
}
"ПРОВАЛОВ: $failed"
exit 1
