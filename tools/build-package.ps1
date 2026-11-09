# Сборка релизного архива DesktopGroups.
# Кладёт в dist\DesktopGroups-<версия>.zip только то, что нужно пользователю.

param(
    [string]$Output = 'dist'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$stage = Join-Path $root (Join-Path $Output "DesktopGroups-$version")
$zip = Join-Path $root (Join-Path $Output "DesktopGroups-$version.zip")

if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

$include = @(
    'DesktopGroups.ps1'
    'DesktopGroups.cmd'
    'install.cmd'
    'uninstall.cmd'
    'VERSION'
    'README.md'
    'CHANGELOG.md'
    'SECURITY.md'
    'LICENSE'
    'lib'
    'tools'
    'docs'
)

# отчёты ревью в пакет не кладём: это внутренняя переписка, не документация для пользователя

foreach ($item in $include) {
    $src = Join-Path $root $item
    if (-not (Test-Path -LiteralPath $src)) { throw "нет файла для пакета: $item" }
    Copy-Item -LiteralPath $src -Destination $stage -Recurse -Force
}

# убираем после копирования, иначе отчёты успевают попасть в архив
$reviewDir = Join-Path $stage 'docs\review'
if (Test-Path -LiteralPath $reviewDir) { Remove-Item -LiteralPath $reviewDir -Recurse -Force }

# сборщик в пакет не нужен
$builder = Join-Path $stage 'tools\build-package.ps1'
if (Test-Path -LiteralPath $builder) { Remove-Item -LiteralPath $builder -Force }

Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
Remove-Item -LiteralPath $stage -Recurse -Force

$size = [math]::Round((Get-Item -LiteralPath $zip).Length / 1KB, 1)
Write-Host "собран пакет: $zip ($size КБ)"
Write-Host $zip
