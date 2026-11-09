# Как проверять такой код на уязвимости

Заметка про инструменты: чем проверять PowerShell-программу, которая лезет
в процесс `explorer.exe`, пишет в реестр и генерирует обои. Всё проверено на
этом проекте, команды рабочие.

## 1. PSScriptAnalyzer — основной статический анализатор

Единственный зрелый SAST для PowerShell. Ставится из PSGallery, работает
локально и в CI, правил безопасности у него около двух десятков.

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
Get-ScriptAnalyzerRule | Where-Object { $_.RuleName -match 'Password|Credential|Invoke|PlainText|Hash|Unsafe' }
```

Что реально ловит из нашего списка:

| Правило | Что ищет |
|---|---|
| `PSAvoidUsingInvokeExpression` | `Invoke-Expression` — прямой путь к инъекции кода |
| `PSAvoidUsingPlainTextForPassword` | пароль строкой вместо `SecureString` |
| `PSAvoidUsingConvertToSecureStringWithPlainText` | «секрет» в открытом виде |
| `PSAvoidUsingUsernameAndPasswordParams` | логин/пароль параметрами |
| `PSAvoidUsingBrokenHashAlgorithms` | MD5/SHA1 там, где нужен SHA-256 |
| `PSAvoidUsingWMICmdlet` | устаревший и небезопасный WMI-путь |
| `PSAvoidUsingEmptyCatchBlock` | проглоченные ошибки (и скрытые сбои безопасности) |
| `PSAvoidUsingComputerNameHardcoded` | зашитый хост |

Ограничение: правил про P/Invoke, `WriteProcessMemory` и реестр у него нет —
эти места проверяются глазами и тестами.

В проекте: `PSScriptAnalyzerSettings.psd1` отключает два стилевых правила
с обоснованием, CI падает на `Error`.

## 2. Semgrep — не для PowerShell

Синтаксис PowerShell у Semgrep не поддерживается (есть только эксперимент
с Bash). Для наших файлов он бесполезен; держать его в CI смысла нет.

## 3. Поиск секретов: gitleaks / trufflehog

Проверяют историю git и рабочую копию на токены, ключи, пароли.

```powershell
docker run --rm -v ${PWD}:/repo zricethezav/gitleaks:latest detect -s /repo -v
# или бинарником
gitleaks detect --source . --verbose
```

В проекте секретов нет и не планируется, но проверка дешёвая — включать
в CI стоит на публичном репозитории.

## 4. CodeQL — не поддерживает PowerShell

CodeQL умеет C#, JS/TS, Python, Java, Go, Ruby, C/C++, Swift, Kotlin.
PowerShell в списке нет, поэтому «code scanning» на GitHub для этого
репозитория не включить. Замена — PSScriptAnalyzer в Actions.

## 5. Сканирование артефактов: VirusTotal

Перед релизом полезно прогнать ZIP и, если делаете EXE, сам EXE.

- Веб: загрузить файл вручную, посмотреть отчёт.
- API: `curl --request POST --url https://www.virustotal.com/api/v3/files --header "x-apikey: $env:VT_API_KEY" --form file=@dist/DesktopGroups-1.0.0.zip`
- Дальше — `GET /api/v3/analyses/{id}` до `status: completed`.

Важно понимать: PowerShell-скрипт, который вызывает `WriteProcessMemory`
и `VirtualAllocEx`, может давать ложные срабатывания эвристик. Это не
уязвимость, но объяснять пользователям придётся.

## 6. Подпись кода и SmartScreen

Неподписанный скрипт, скачанный из интернета, получает метку «Из интернета»
(Zone.Identifier) и предупреждение SmartScreen при запуске `.cmd`.

- Снять метку: `Unblock-File .\DesktopGroups.cmd` (или «Разблокировать»
  в свойствах файла).
- Подписать: `Set-AuthenticodeSignature -FilePath .\install.ps1 -Certificate $cert`
  или `signtool sign /fd SHA256 /a ...`. Нужен сертификат; самоподписанный
  доверия не даёт, OV/EV — платно.
- Пока подписи нет, в README стоит явно писать про «Разблокировать» —
  это честнее, чем молчать.

## 7. Защитник Windows и AMSI

- Проверить архив: `Start-MpScan -ScanType CustomScan -ScanPath .\dist` или
  `MpCmdRun.exe -Scan -ScanType 3 -File <путь>`.
- AMSI сканирует скрипт в момент выполнения, поэтому «замаскировать» код
  не получится — и не нужно.
- Полезно проверить программу под включёнными ASR-правилами Defender
  (например, «Блокировать создание дочерних процессов Office») — наша
  программа не создаёт процессов, кроме собственного окна.

## 8. Фаззинг входных данных

Единственный внешний ввод — `config.json` и имена ярлыков. Дешёвый фаззинг:
подставить в имя группы кавычки, перевод строки, эмодзи, 10000 символов,
`..\..\` и посмотреть, что будет с разбором JSON, раскладкой и отрисовкой.

```powershell
$bad = @('a"b', "line`nbreak", ('x' * 10000), '..\..\windows', '<script>')
foreach ($name in $bad) {
    $cfg = @{ groups = @(@{ name = $name; color = '#888888'; items = @('Корзина') }) } | ConvertTo-Json -Depth 5
    # разобрать обратно и построить раскладку + обои во временный файл
}
```

## 9. Ревью человеком и моделью

Автоматика не видит логических дыр: «что если explorer перезапустился между
чтением и записью», «что если имя группы совпало с именем значка».
Поэтому в проекте было три независимых ревью (безопасность, корректность,
готовность к релизу) с отчётами в `docs/review/`.

## 10. Что в итоге включено в проект

| Проверка | Где | Блокирует релиз |
|---|---|---|
| PSScriptAnalyzer (Error) | CI, `PSScriptAnalyzerSettings.psd1` | да |
| Синтаксис PowerShell 5.1 и 7 | CI | да |
| Smoke-тесты логики и обоев | CI, `tests\smoke.ps1` | да |
| Проверка на секреты | вручную / по желанию в CI | нет |
| VirusTotal | вручную перед релизом | нет |
| Подпись кода | нет сертификата | нет |

## Чего эти инструменты не проверят

- **Логика раскладки** — только тесты и ревью.
- **Побочные эффекты в системе** — только чтение кода и наблюдение за
  рабочим столом.
- **Совместимость с чужими сборками Windows** — только ручной прогон на
  чистой машине.
