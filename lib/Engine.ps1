# Engine.ps1 — ядро DesktopGroups: сканирование ярлыков, предложение групп,
# раскладка по сетке, генерация обоев с рамками, применение позиций.
# Совместимо с Windows PowerShell 5.1 и PowerShell 7.

if (-not ('DesktopIconsNative' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'DesktopIcons.cs')
}
try { Add-Type -AssemblyName System.Drawing -ErrorAction Stop }
catch { Write-Verbose 'System.Drawing недоступен — обои сгенерировать не получится' }
try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop }
catch { Write-Verbose 'System.Windows.Forms недоступен — размеры экрана будут по умолчанию' }

# Структура LVITEM зависит от разрядности процесса. 32-битный PowerShell
# записал бы в 64-битный explorer 60 байт вместо 88 — рабочий стол упал бы.
if (-not [Environment]::Is64BitProcess -and [Environment]::Is64BitOperatingSystem) {
    throw 'DesktopGroups требует 64-битный PowerShell: под 32-битным хостом структура LVITEM не совпадает с explorer.exe.'
}

# Объявляем DPI-awareness до создания окон: иначе на масштабировании 125/150%
# экранные метрики виртуальные, а координаты ListView — физические.
try { [void][DesktopIconsNative]::EnableDpiAwareness() }
catch { Write-Verbose 'DPI-awareness не включился: на масштабировании возможен сдвиг' }

$script:Palette = @(
    '#8B98AB', '#E0A33E', '#D96A8A', '#4FA3E3', '#62C08A',
    '#9A7FE0', '#E07A5F', '#B7B26A', '#8C8C8C', '#5FB7B0', '#C08FC0'
)

# Названия групп на двух языках: id общий, подпись зависит от языка интерфейса
$script:GroupNames = @{
    installers = @{ ru = 'Установщики'; en = 'Installers' }
    network    = @{ ru = 'Сеть и VPN'; en = 'Network & VPN' }
    games      = @{ ru = 'Игры'; en = 'Games' }
    dev        = @{ ru = 'Разработка и AI'; en = 'Development & AI' }
    comms      = @{ ru = 'Связь и интернет'; en = 'Chat & Internet' }
    media      = @{ ru = 'Медиа'; en = 'Media' }
    hardware   = @{ ru = 'Оборудование'; en = 'Hardware' }
    system     = @{ ru = 'Система'; en = 'System' }
    other      = @{ ru = 'Прочее'; en = 'Misc' }
}

function Get-DefaultLanguage {
    # язык Windows, а не потоковая культура: в PowerShell 5.1 CurrentUICulture
    # всегда en-US, поэтому смотрим InstalledUICulture
    $c = [System.Globalization.CultureInfo]::InstalledUICulture
    if ($c -and $c.TwoLetterISOLanguageName -eq 'ru') { return 'ru' }
    return 'en'
}

function Get-GroupName {
    param([string]$Id, [string]$Lang)

    $entry = $script:GroupNames[$Id]
    if (-not $entry) { return $Id }
    if ($Lang -eq 'en') { return $entry.en }
    if ($Lang -eq 'ru') { return $entry.ru }
    # язык не задан — берём язык системы
    if ((Get-DefaultLanguage) -eq 'ru') { return $entry.ru }
    return $entry.en
}

$script:GroupRules = @(
    @{ id = 'installers'; color = '#B7B26A'; words = @() }
    @{ id = 'network'; color = '#9A7FE0'; words = @('vpn', 'proxy', 'zapret', 'vnc', 'ultravnc', 'tgwsproxy', 'amneziavpn', 'rudesktop', 'remote', 'wireshark', 'putty', 'anydesk', 'rustdesk', 'radmin', 'wireguard') }
    @{ id = 'games'; color = '#E0A33E'; words = @('steam', 'epic games', 'faceit', 'deadlock', 'counter-strike', 'tlauncher', 'exitlag', 'happ', 'skydimo', 'riot', 'battle.net', 'ubisoft', 'gog') }
    @{ id = 'dev'; color = '#62C08A'; words = @('code', 'cursor', 'docker', 'harness', 'kimi', 'qwen', 'mobaxterm', 'obsidian', 'xsd', 'xsddiagram', 'git', 'python', 'node', 'studio', 'terminal', 'powershell', 'postman', 'dbeaver', 'notepad', 'wsl') }
    @{ id = 'comms'; color = '#4FA3E3'; words = @('telegram', 'discord', 'teamspeak', 'whatsapp', 'viber', 'skype', 'slack', 'zoom', 'teams', 'chrome', 'firefox', 'browser', 'opera', 'edge', 'thunderbird', 'mail') }
    @{ id = 'media'; color = '#D96A8A'; words = @('vlc', 'spotify', 'itunes', 'media', 'player', 'foobar', 'audacity') }
    @{ id = 'hardware'; color = '#E07A5F'; words = @('cpuid', 'nvidia', 'redragon', 'panteon', 'epson', 'logitech', 'razer', 'hyperx', 'asus', 'msi', 'corsair', 'headset', 'mouse', 'телевизор', 'monitor', 'keyboard') }
    @{ id = 'system'; color = '#8B98AB'; words = @('корзина', 'recycle bin', 'recycle') }
)

# ---------------------------------------------------------------- сканирование

# Имена в оболочке — источник истины: при включённом «скрывать расширения»
# Explorer показывает "app", а не "app.exe". План должен совпадать с ним,
# иначе значок не найдёт свою ячейку и уедет в резервную колонку.
function Sync-ItemNames {
    param($Items)

    $view = $null
    try { $view = Get-DesktopView }
    catch { return , $Items }

    try { $viewNames = @(Read-ViewItems $view | ForEach-Object { $_.name }) }
    finally { Close-DesktopView $view }

    $byName = @{}
    $byBase = @{}
    foreach ($n in $viewNames) {
        $byName[$n.ToLower()] = $n
        $b = [IO.Path]::GetFileNameWithoutExtension($n).ToLower()
        if (-not $byBase.ContainsKey($b)) { $byBase[$b] = $n }
    }

    foreach ($it in $Items) {
        if ($byName.ContainsKey($it.name.ToLower())) { continue }
        $b = $it.base.ToLower()
        if ($byBase.ContainsKey($b)) { $it.name = $byBase[$b] }
    }

    # системные элементы (Корзина и т.п.) оставляем только если они реально в виде
    $Items = @($Items | Where-Object { $_.kind -ne 'system' -or $byName.ContainsKey($_.name.ToLower()) })
    return , $Items
}

function Get-DesktopItems {
    param([switch]$AlignWithView)
    $paths = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:PUBLIC 'Desktop'))
    $seen = @{}
    $items = @()

    foreach ($p in $paths) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        foreach ($f in (Get-ChildItem -LiteralPath $p -Force)) {
            if ($f.Name -eq 'desktop.ini') { continue }
            if ($f.Name -like 'thumbs.db') { continue }
            $name = $f.Name
            # у ярлыков и интернет-ссылок Windows скрывает расширение, у файлов — нет
            if ($f.Extension -eq '.lnk' -or $f.Extension -eq '.url') { $name = $f.BaseName }

            $key = $name.ToLower()
            if ($seen.ContainsKey($key)) { continue }
            $seen[$key] = $true

            $kind = 'file'
            if ($f.PSIsContainer) { $kind = 'folder' }
            elseif ($f.Extension -eq '.lnk') { $kind = 'shortcut' }
            elseif ($f.Extension -eq '.url') { $kind = 'link' }

            $items += [pscustomobject]@{
                name = $name
                base = $f.BaseName
                ext  = $f.Extension
                path = $f.FullName
                kind = $kind
            }
        }
    }

    # Корзина живёт в оболочке, а не на диске: добавляем кандидата,
    # Sync-ItemNames уберёт его, если такого элемента в виде нет.
    # Имя берём на языке интерфейса, чтобы совпасть с тем, что видно на столе.
    $bin = 'Корзина'
    if ((Get-DefaultLanguage) -ne 'ru') { $bin = 'Recycle Bin' }
    if (-not $seen.ContainsKey($bin.ToLower())) {
        $items += [pscustomobject]@{ name = $bin; base = $bin; ext = ''; path = ''; kind = 'system' }
    }

    if ($AlignWithView) { $items = Sync-ItemNames -Items $items }

    return @($items | Sort-Object name)
}

# ---------------------------------------------------------------- группы

function New-ProposedGroups {
    param($Items, [string]$Lang)

    $groups = @()
    $used = @{}

    foreach ($rule in $script:GroupRules) {
        $members = @()
        foreach ($it in $Items) {
            if ($used.ContainsKey($it.name)) { continue }
            $low = $it.name.ToLower()
            $hit = $false

            if ($rule.id -eq 'installers') {
                if ($it.kind -eq 'file' -and ($it.ext -eq '.exe' -or $it.ext -eq '.msi')) {
                    foreach ($w in @('setup', 'install', '-x64', '-x86', '_x64', '_x86')) {
                        if ($low.Contains($w)) { $hit = $true; break }
                    }
                }
            }
            else {
                foreach ($w in $rule.words) {
                    # совпадение по целому слову: иначе «Codecs» попадает в
                    # разработку из-за «code», а «Immediate» — в медиа из-за «media»
                    $pattern = '(?i)(?<![a-zа-яё0-9])' + [regex]::Escape($w) + '(?![a-zа-яё0-9])'
                    if ($low -match $pattern) { $hit = $true; break }
                }
            }

            if ($hit) {
                $members += $it.name
                $used[$it.name] = $true
            }
        }
        if ($members.Count -gt 0) {
            $groups += [pscustomobject]@{
                name  = (Get-GroupName -Id $rule.id -Lang $Lang)
                color = $rule.color
                items = $members
                id    = $rule.id
            }
        }
    }

    $rest = @($Items | Where-Object { -not $used.ContainsKey($_.name) } | ForEach-Object { $_.name })
    if ($rest.Count -gt 0) {
        $groups += [pscustomobject]@{
            name  = (Get-GroupName -Id 'other' -Lang $Lang)
            color = '#8C8C8C'
            items = $rest
            id    = 'other'
        }
    }

    return , $groups
}

function Get-NextColor {
    param($Groups)
    $usedColors = @{}
    foreach ($g in $Groups) { if ($g.color) { $usedColors[$g.color.ToUpper()] = $true } }
    foreach ($c in $script:Palette) {
        if (-not $usedColors.ContainsKey($c.ToUpper())) { return $c }
    }
    return $script:Palette[0]
}

# Сопоставить имена из конфига с реальными именами на столе:
# имя могло измениться (появилось расширение, сменился ярлык).
function Resolve-GroupItems {
    param($Groups, $Items)

    $script:UnresolvedItems = @()
    $byName = @{}
    $byBase = @{}
    foreach ($it in $Items) {
        $byName[$it.name.ToLower()] = $it.name
        if ($it.base) { $byBase[$it.base.ToLower()] = $it.name }
    }

    foreach ($g in $Groups) {
        $resolved = @()
        foreach ($i in @($g.items)) {
            $k = ([string]$i).ToLower()
            if ($byName.ContainsKey($k)) { $resolved += $byName[$k] }
            elseif ($byBase.ContainsKey($k)) { $resolved += $byBase[$k] }
            else { $script:UnresolvedItems += [string]$i }   # имени больше нет на столе
        }
        $g.items = $resolved
    }

    return , $Groups
}

# ---------------------------------------------------------------- раскладка

function New-Layout {
    param($Groups, $Screen, $Grid)

    $stepX = $Grid.stepX
    $stepY = $Grid.stepY
    $margin = $Grid.margin
    $top = $Grid.top

    $y = $top
    $x = $margin
    $bandRows = 0
    $blocks = @()
    $plan = @{}
    $overflow = $false

    foreach ($g in $Groups) {
        $n = @($g.items).Count
        if ($n -eq 0) { continue }

        # форма блока: меньше пустых ячеек, ближе к квадрату;
        # пределы берём из экрана, иначе большая группа уедет за край
        $maxCols = [int][math]::Floor(($Screen.width - 2 * $margin) / $stepX)
        $maxRows = [int][math]::Floor(($Screen.workHeight - $top - $margin) / $stepY)
        if ($maxCols -lt 1) { $maxCols = 1 }
        if ($maxRows -lt 1) { $maxRows = 1 }

        $best = $null
        $bestScore = [double]::MaxValue
        for ($rows = 1; $rows -le $maxRows; $rows++) {
            $cols = [int][math]::Ceiling($n / $rows)
            if ($cols -gt $maxCols) { continue }
            $holes = $cols * $rows - $n
            $score = $holes * 10 + [math]::Abs($cols - $rows)
            if ($cols -gt 6) { $score += 100 }   # компактный блок лучше широкой полосы
            if ($score -lt $bestScore) {
                $bestScore = $score
                $best = @{ rows = $rows; cols = $cols }
            }
        }
        if ($null -eq $best) {
            # группа больше экрана: режем по ширине, остальное уйдёт в переполнение
            $cols = $maxCols
            $rows = [int][math]::Ceiling($n / $cols)
            $best = @{ rows = $rows; cols = $cols }
        }

        $cols = $best.cols
        $rows = $best.rows

        # перенос на новую полосу, если блок не влезает по ширине
        if (($x + $cols * $stepX) -gt ($Screen.width - $margin) -and $x -gt $margin) {
            $y = $y + $bandRows * $stepY + $stepY
            $x = $margin
            $bandRows = 0
        }

        if (($y + $rows * $stepY) -gt ($Screen.workHeight - $margin)) {
            $overflow = $true
        }

        $cells = @()
        for ($i = 0; $i -lt $n; $i++) {
            $c = [int][math]::Floor($i / $rows)
            $r = $i % $rows
            $px = $x + $c * $stepX
            $py = $y + $r * $stepY
            $cells += [pscustomobject]@{ name = $g.items[$i]; x = $px; y = $py }
            $plan[$g.items[$i]] = @{ x = $px; y = $py }
        }

        $blocks += [pscustomobject]@{
            name  = $g.name
            color = $g.color
            x     = $x
            y     = $y
            w     = $cols * $stepX
            h     = $rows * $stepY
            cols  = $cols
            rows  = $rows
            items = $cells
        }

        $x = $x + ($cols + 1) * $stepX
        if ($rows -gt $bandRows) { $bandRows = $rows }
    }

    return [pscustomobject]@{
        blocks   = $blocks
        plan     = $plan
        overflow = $overflow
        grid     = $Grid
        screen   = $Screen
    }
}

function Get-DefaultGrid {
    [pscustomobject]@{ stepX = 76; stepY = 100; margin = 14; top = 202 }
}

function Get-ScreenInfo {
    $s = [System.Windows.Forms.Screen]::PrimaryScreen
    [pscustomobject]@{
        width      = $s.Bounds.Width
        height     = $s.Bounds.Height
        workHeight = $s.WorkingArea.Height
    }
}

# ---------------------------------------------------------------- обои

function Convert-HexColor {
    param([string]$Hex)
    # цвет приходит из config.json, который можно править руками: мусор не должен
    # ронять отрисовку, поэтому подставляем серый вместо исключения
    if ($Hex -notmatch '^#?[0-9A-Fa-f]{6}$') {
        return [System.Drawing.Color]::FromArgb(255, 140, 140, 140)
    }
    $h = $Hex.TrimStart('#')
    return [System.Drawing.Color]::FromArgb(
        255,
        [Convert]::ToInt32($h.Substring(0, 2), 16),
        [Convert]::ToInt32($h.Substring(2, 2), 16),
        [Convert]::ToInt32($h.Substring(4, 2), 16)
    )
}

function New-RoundRectPath {
    param($X, $Y, $W, $H, $R)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $R * 2
    $p.AddArc([single]$X, [single]$Y, [single]$d, [single]$d, 180, 90)
    $p.AddArc([single]($X + $W - $d), [single]$Y, [single]$d, [single]$d, 270, 90)
    $p.AddArc([single]($X + $W - $d), [single]($Y + $H - $d), [single]$d, [single]$d, 0, 90)
    $p.AddArc([single]$X, [single]($Y + $H - $d), [single]$d, [single]$d, 90, 90)
    $p.CloseFigure()
    return $p
}

# Загружает картинку в память и отдаёт её вместе с потоком.
# Image::FromFile держал бы файл заблокированным до конца работы программы,
# поэтому читаем байты и разбираем из памяти. Вызывающий обязан всё освободить.
function Get-BackgroundImage {
    param([string]$Path, [int]$MaxBytes = 104857600)   # 100 МБ — защита от абсурдных файлов

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }

    $info = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($info.Length -le 0) { return $null }
    if ($info.Length -gt $MaxBytes) { throw ('файл фона слишком большой: {0} МБ' -f [math]::Round($info.Length / 1MB, 1)) }

    $bytes = [IO.File]::ReadAllBytes($info.FullName)
    $ms = New-Object System.IO.MemoryStream(, $bytes)
    try {
        $img = [System.Drawing.Image]::FromStream($ms)
    }
    catch {
        $ms.Dispose()
        throw
    }
    return [pscustomobject]@{ Image = $img; Stream = $ms }
}

function Save-Wallpaper {
    param(
        $Layout,
        [string]$Path,
        [int]$Width = 1920,
        [int]$Height = 1080,
        [int]$Pad = 12,
        [string]$BackgroundImage
    )

    $bmp = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

    $rect = New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)

    # --- подложка: картинка пользователя, а без неё — градиент
    $hasPhoto = $false
    if ($BackgroundImage) {
        $loaded = $null
        try {
            $loaded = Get-BackgroundImage -Path $BackgroundImage
            if ($loaded) {
                # заполняем холст целиком с сохранением пропорций (как «Заполнение»)
                $scale = [Math]::Max($Width / [double]$loaded.Image.Width, $Height / [double]$loaded.Image.Height)
                $dw = [int][Math]::Ceiling($loaded.Image.Width * $scale)
                $dh = [int][Math]::Ceiling($loaded.Image.Height * $scale)
                $dx = [int](($Width - $dw) / 2)
                $dy = [int](($Height - $dh) / 2)

                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $g.DrawImage($loaded.Image, (New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)))
                $hasPhoto = $true
            }
        }
        catch {
            # битый или недоступный файл не должен ломать обои
            $hasPhoto = $false
        }
        finally {
            if ($loaded) {
                $loaded.Image.Dispose()
                $loaded.Stream.Dispose()
            }
        }
    }

    if ($hasPhoto) {
        # Затемняем фото, чтобы подписи читались, но сама картинка оставалась
        # видна: сверху чуть плотнее (там подписи), снизу светлее.
        $scrimRect = New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)
        $scrim = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $scrimRect,
            [System.Drawing.Color]::FromArgb(120, 0, 0, 0),
            [System.Drawing.Color]::FromArgb(70, 0, 0, 0),
            90)
        $g.FillRectangle($scrim, $scrimRect)
        $scrim.Dispose()
    }
    else {
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $rect,
            [System.Drawing.Color]::FromArgb(13, 16, 22),
            [System.Drawing.Color]::FromArgb(24, 29, 41),
            90)
        $g.FillRectangle($brush, $rect)
        $brush.Dispose()
    }

    $plateAlpha = 26
    $outlineAlpha = 150
    if ($hasPhoto) {
        # на фотографии блок должен быть заметнее
        $plateAlpha = 46
        $outlineAlpha = 190
    }

    foreach ($b in $Layout.blocks) {
        $c = Convert-HexColor $b.color
        $x0 = $b.x - $Pad
        $y0 = $b.y - $Pad
        $bw = $b.w + 2 * $Pad
        $bh = $b.h + 2 * $Pad

        $gp = New-RoundRectPath $x0 $y0 $bw $bh 16
        $fill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($plateAlpha, $c.R, $c.G, $c.B))
        $g.FillPath($fill, $gp)
        $fill.Dispose()
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($outlineAlpha, $c.R, $c.G, $c.B), 2)
        $g.DrawPath($pen, $gp)
        $pen.Dispose()
        $gp.Dispose()

        # подпись над рамкой, размер подбирается под ширину
        $size = 13.0
        $font = New-Object System.Drawing.Font('Segoe UI', [single]$size, [System.Drawing.FontStyle]::Bold)
        while ($size -gt 7.5 -and $g.MeasureString($b.name, $font).Width -gt ($bw - 12)) {
            $font.Dispose()
            $size -= 0.5
            $font = New-Object System.Drawing.Font('Segoe UI', [single]$size, [System.Drawing.FontStyle]::Bold)
        }

        $textRect = New-Object System.Drawing.RectangleF([single]($x0 + 10), [single]($y0 - 31), [single]($bw - 16), [single]20)

        # тёмная плашка под подписью: текст читается и на светлом фото.
        # Плотность почти непрозрачная: при 170 контраст подписи на белой
        # картинке падал до 2,9 — ниже порога читаемости.
        $tw = [Math]::Min(($bw - 8), ($g.MeasureString($b.name, $font).Width + 14))
        $plate = New-RoundRectPath ($x0 + 2) ($y0 - 32) $tw 22 6
        $plateBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 10, 13, 20))
        $g.FillPath($plateBrush, $plate)
        $plateBrush.Dispose()
        $plate.Dispose()

        $tb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240, $c.R, $c.G, $c.B))
        # длинное название не должно вылезать за рамку и наезжать на соседей
        $fmt = New-Object System.Drawing.StringFormat
        $fmt.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
        $fmt.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
        $g.DrawString($b.name, $font, $tb, $textRect, $fmt)
        $fmt.Dispose()
        $tb.Dispose()
        $font.Dispose()

        # засечка у левого края подписи
        $tick = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, $c.R, $c.G, $c.B))
        $g.FillRectangle($tick, [single]($x0 + 5), [single]($y0 - 27), [single]3, [single]13)
        $tick.Dispose()
    }

    $g.Dispose()
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return $Path
}

function Set-DesktopWallpaper {
    param([string]$Path)
    $key = 'HKCU:\Control Panel\Desktop'
    Set-ItemProperty -Path $key -Name Wallpaper -Value $Path
    Set-ItemProperty -Path $key -Name WallpaperStyle -Value '10'
    Set-ItemProperty -Path $key -Name TileWallpaper -Value '0'
    return [DesktopIconsNative]::SetWallpaper($Path)
}

# ---------------------------------------------------------------- вид стола

function Get-DesktopView {
    $lv = [DesktopIconsNative]::FindDesktopListView()
    if ($lv -eq [IntPtr]::Zero) { throw 'Не найден список значков рабочего стола (SysListView32)' }

    $procId = [uint32]0
    [void][DesktopIconsNative]::GetWindowThreadProcessId($lv, [ref]$procId)
    $proc = [DesktopIconsNative]::OpenProcess(0x438, $false, $procId)
    if ($proc -eq [IntPtr]::Zero) { throw 'Не удалось открыть процесс explorer.exe' }

    try {
        $remote = [DesktopIconsNative]::VirtualAllocEx($proc, [IntPtr]::Zero, [UIntPtr]::new(4096), 0x3000, 0x04)
        if ($remote -eq [IntPtr]::Zero) { throw 'Не удалось выделить память в explorer.exe' }
    }
    catch {
        # без этого хендл процесса утёк бы при неудачном выделении памяти
        [void][DesktopIconsNative]::CloseHandle($proc)
        throw
    }

    return [pscustomobject]@{ lv = $lv; proc = $proc; remote = $remote }
}

function Close-DesktopView {
    param($View)
    if ($null -eq $View) { return }
    if ($View.remote -ne [IntPtr]::Zero) {
        [void][DesktopIconsNative]::VirtualFreeEx($View.proc, $View.remote, [UIntPtr]::Zero, 0x8000)
    }
    if ($View.proc -ne [IntPtr]::Zero) {
        [void][DesktopIconsNative]::CloseHandle($View.proc)
    }
}

function ConvertTo-Bytes {
    param($Obj)
    $size = [Runtime.InteropServices.Marshal]::SizeOf($Obj)
    $ptr = [Runtime.InteropServices.Marshal]::AllocHGlobal($size)
    try {
        [Runtime.InteropServices.Marshal]::StructureToPtr($Obj, $ptr, $false)
        $bytes = New-Object byte[] $size
        [Runtime.InteropServices.Marshal]::Copy($ptr, $bytes, 0, $size)
        return , $bytes
    }
    finally {
        [Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
    }
}

function Write-Remote {
    param($View, [int]$Offset, [byte[]]$Bytes)
    $written = [UIntPtr]::Zero
    $addr = [IntPtr]($View.remote.ToInt64() + $Offset)
    $ok = [DesktopIconsNative]::WriteProcessMemory($View.proc, $addr, $Bytes, [UIntPtr]::new($Bytes.Length), [ref]$written)
    if (-not $ok) { throw 'WriteProcessMemory не удался' }
}

function Read-Remote {
    param($View, [int]$Offset, [int]$Length)
    $buf = New-Object byte[] $Length
    $read = [UIntPtr]::Zero
    $addr = [IntPtr]($View.remote.ToInt64() + $Offset)
    $ok = [DesktopIconsNative]::ReadProcessMemory($View.proc, $addr, $buf, [UIntPtr]::new($Length), [ref]$read)
    if (-not $ok) { throw 'ReadProcessMemory не удался' }
    return , $buf
}

function Read-ViewItems {
    param($View)

    $count = [int][DesktopIconsNative]::SendMessage($View.lv, [DesktopIconsNative]::LVM_GETITEMCOUNT, [IntPtr]::Zero, [IntPtr]::Zero)
    $items = @()

    for ($i = 0; $i -lt $count; $i++) {
        $lvi = New-Object DesktopIconsNative+LVITEM
        $lvi.mask = 0x1
        $lvi.iItem = $i
        $lvi.iSubItem = 0
        $lvi.pszText = [IntPtr]($View.remote.ToInt64() + 128)
        $lvi.cchTextMax = 260
        Write-Remote $View 0 (ConvertTo-Bytes $lvi)
        [void][DesktopIconsNative]::SendMessage($View.lv, [DesktopIconsNative]::LVM_GETITEMTEXTW, [IntPtr]$i, [IntPtr]($View.remote.ToInt64() + 0))
        $raw = Read-Remote $View 128 520
        $s = [Text.Encoding]::Unicode.GetString($raw)
        $nul = $s.IndexOf([char]0)
        if ($nul -ge 0) { $s = $s.Substring(0, $nul) }

        $pt = New-Object DesktopIconsNative+POINT
        Write-Remote $View 2048 (ConvertTo-Bytes $pt)
        [void][DesktopIconsNative]::SendMessage($View.lv, [DesktopIconsNative]::LVM_GETITEMPOSITION, [IntPtr]$i, [IntPtr]($View.remote.ToInt64() + 2048))
        $rawPt = Read-Remote $View 2048 8

        $items += [pscustomobject]@{
            index = $i
            name  = $s
            x     = [BitConverter]::ToInt32($rawPt, 0)
            y     = [BitConverter]::ToInt32($rawPt, 4)
        }
    }

    return , $items
}

function Set-ViewPosition {
    param($View, [int]$Index, [int]$X, [int]$Y)
    $pt = New-Object DesktopIconsNative+POINT
    $pt.X = $X
    $pt.Y = $Y
    Write-Remote $View 2048 (ConvertTo-Bytes $pt)
    [void][DesktopIconsNative]::SendMessage($View.lv, [DesktopIconsNative]::LVM_SETITEMPOSITION32, [IntPtr]$Index, [IntPtr]($View.remote.ToInt64() + 2048))
}

# Включено ли «Упорядочить автоматически» — тогда Windows переставит значки сама.
function Test-AutoArrange {
    $bag = 'HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop'
    $p = Get-ItemProperty -Path $bag -ErrorAction SilentlyContinue
    if ($null -eq $p -or $null -eq $p.FFlags) { return $false }
    return [bool](([uint32]$p.FFlags) -band 0x1)
}

function Get-ViewGridStep {
    param($View)

    # Шаг зависит от режима отображения: у мелких значков он другой.
    # LVS_TYPEMASK = 0x3, LVS_SMALLICON = 0x2.
    $style = [DesktopIconsNative]::GetWindowLong($View.lv, -16)
    $smallIcons = (($style -band 0x3) -eq 0x2)
    $wParam = [IntPtr]::Zero
    if ($smallIcons) { $wParam = [IntPtr]1 }

    $r = [DesktopIconsNative]::SendMessage($View.lv, [DesktopIconsNative]::LVM_GETITEMSPACING, $wParam, [IntPtr]::Zero)
    $v = $r.ToInt64()
    $cx = [int]($v -band 0xFFFF)
    $cy = [int](($v -shr 16) -band 0xFFFF)
    if ($cx -le 0 -or $cy -le 0) { return (Get-DefaultGrid) }
    [pscustomobject]@{ stepX = $cx; stepY = $cy; margin = 14; top = 202 }
}

# ---------------------------------------------------------------- применение

function Invoke-DesktopLayout {
    param($Layout, [string]$BackupDir)

    $view = Get-DesktopView
    try {
        $before = Read-ViewItems $view

        if ($BackupDir) {
            if (-not (Test-Path -LiteralPath $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
            $file = Join-Path $BackupDir ('before-apply-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
            $obj = @{}
            # ключ включает индекс: одноимённые ярлык и папка иначе схлопнутся
            foreach ($it in $before) { $obj["$($it.index)|$($it.name)"] = @{ name = $it.name; x = $it.x; y = $it.y } }
            $obj | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $file -Encoding UTF8

            # держим не больше 20 бэкапов, иначе папка растёт бесконечно
            $old = Get-ChildItem -LiteralPath $BackupDir -Filter 'before-apply-*.json' |
                Sort-Object LastWriteTime -Descending |
                Select-Object -Skip 20
            foreach ($f in $old) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
        }

        $grid = $Layout.grid
        $screen = $Layout.screen
        if ($null -eq $screen) { $screen = Get-ScreenInfo }

        $maxCols = [int][math]::Floor(($screen.width - 2 * $grid.margin) / $grid.stepX)
        $maxRows = [int][math]::Floor(($screen.workHeight - $grid.top - $grid.margin) / $grid.stepY)
        if ($maxCols -lt 1) { $maxCols = 1 }
        if ($maxRows -lt 1) { $maxRows = 1 }

        # цели привязаны к индексу значка, а не к имени: одноимённые ярлык и папка
        # получают разные ячейки, а не одну на двоих
        $used = @{}
        $targets = @{}
        $unknown = @()
        $fallbackIndex = 0
        $limit = $maxCols * $maxRows

        foreach ($it in $before) {
            $t = $null
            if ($Layout.plan.ContainsKey($it.name)) {
                $cand = $Layout.plan[$it.name]
                $key = "$($cand.x),$($cand.y)"
                if (-not $used.ContainsKey($key)) {
                    $t = $cand
                    $used[$key] = $true
                }
            }

            if ($null -eq $t) {
                # свободное место: колонки справа налево, сверху вниз, в пределах экрана
                $x = $grid.margin
                $y = $grid.top
                $guard = 0
                do {
                    $c = [int][math]::Floor($fallbackIndex / $maxRows)
                    $r = $fallbackIndex % $maxRows
                    $fallbackIndex++
                    $guard++
                    $x = $grid.margin + ($maxCols - 1 - $c) * $grid.stepX
                    if ($x -lt $grid.margin) { $x = $grid.margin }
                    $y = $grid.top + $r * $grid.stepY
                    $key = "$x,$y"
                } while ($used.ContainsKey($key) -and $guard -lt ($limit * 2))

                $t = @{ x = $x; y = $y }
                $used[$key] = $true
                $unknown += $it.name
            }

            $targets[$it.index] = $t
        }

        # проходы до сходимости: попадание в занятую ячейку сдвигает соседа
        $passes = 0
        for ($pass = 1; $pass -le 10; $pass++) {
            $moved = 0
            $cur = Read-ViewItems $view
            foreach ($it in $cur) {
                if (-not $targets.ContainsKey($it.index)) { continue }
                $t = $targets[$it.index]
                if ($it.x -ne $t.x -or $it.y -ne $t.y) {
                    Set-ViewPosition $view $it.index $t.x $t.y
                    $moved++
                }
            }
            Start-Sleep -Milliseconds 200
            $passes = $pass
            if ($moved -eq 0) { break }
        }

        # контроль
        $final = Read-ViewItems $view
        $bad = @()
        foreach ($it in $final) {
            if (-not $targets.ContainsKey($it.index)) { continue }
            $t = $targets[$it.index]
            if ($it.x -ne $t.x -or $it.y -ne $t.y) {
                $bad += [pscustomobject]@{ name = $it.name; expected = "$($t.x),$($t.y)"; actual = "$($it.x),$($it.y)" }
            }
        }

        return [pscustomobject]@{
            placed     = $targets.Count
            passes     = $passes
            mismatches = $bad
            unknown    = @($unknown | Select-Object -Unique)
        }
    }
    finally {
        Close-DesktopView $view
    }
}
