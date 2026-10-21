# install-ollama-pi.ps1
# Запуск:  powershell -ExecutionPolicy Bypass -File .\install-ollama-pi.ps1
#Requires -Version 5.1

# ---------- UTF-8 и набор символов ----------
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $script:U = $true
} catch { $script:U = $false }

if ($script:U) {
    $SYM = @{
        OK      = '✔'
        FAIL    = '✖'
        ARROW   = '▶'
        DOT     = '•'
        SPIN    = @('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')
        BAR     = '█'
        BAR_OFF = '░'
        LINE    = '─'
        DLINE   = '═'
        STAR    = '★'
    }
} else {
    $SYM = @{
        OK      = '[OK]'
        FAIL    = '[X]'
        ARROW   = '>'
        DOT     = '*'
        SPIN    = @('|','/','-','\')
        BAR     = '#'
        BAR_OFF = '-'
        LINE    = '-'
        DLINE   = '='
        STAR    = '*'
    }
}

# ---------- Дизайн-хелперы ----------

function Write-Typing {
    param([string]$Text, [ConsoleColor]$Color = 'Gray', [int]$DelayMs = 10)
    foreach ($c in $Text.ToCharArray()) {
        Write-Host $c -NoNewline -ForegroundColor $Color
        Start-Sleep -Milliseconds $DelayMs
    }
    Write-Host ''
}

function Show-Banner {
    $gradient = @('DarkCyan','Cyan','Cyan','DarkCyan','Cyan','DarkCyan')
    if ($script:U) {
        $banner = @(
            '  ██████╗ ██╗     ██╗      █████╗ ███╗   ███╗ █████╗ ',
            ' ██╔═══██╗██║     ██║     ██╔══██╗████╗ ████║██╔══██╗',
            ' ██║   ██║██║     ██║     ███████║██╔████╔██║███████║',
            ' ██║   ██║██║     ██║     ██╔══██║██║╚██╔╝██║██╔══██║',
            ' ╚██████╔╝███████╗███████╗██║  ██║██║ ╚═╝ ██║██║  ██║',
            '  ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝'
        )
    } else {
        $banner = @(
            '   ___  _    _    ___  __  __  ___ ',
            '  / _ \| |  | |  / _ \|  \/  |/ _ \',
            ' | | | | |  | | | | | | |\/| | | | |',
            ' | |_| | |__| |_| |_| | |  | | |_| |',
            '  \___/|____|____\___/|_|  |_|\___/ '
        )
    }
    Write-Host ''
    for ($i = 0; $i -lt $banner.Count; $i++) {
        Write-Host $banner[$i] -ForegroundColor $gradient[$i % $gradient.Count]
        Start-Sleep -Milliseconds 55
    }
    Write-Host ''
    $tag = " $($SYM.STAR)  Pi Coding Agent Installer  $($SYM.STAR) "
    $pad = $SYM.DLINE * ($tag.Length + 4)
    Write-Host "   $pad" -ForegroundColor DarkMagenta
    Write-Host "  $tag" -ForegroundColor Magenta
    Write-Host "   $pad" -ForegroundColor DarkMagenta
    Write-Host ''
}

function Write-Section {
    param([string]$Title, [int]$Step, [int]$Total = 4)
    Write-Host ''
    Write-Host "  $($SYM.ARROW) " -NoNewline -ForegroundColor Yellow
    Write-Host "[$Step/$Total] " -NoNewline -ForegroundColor DarkYellow
    Write-Host $Title -ForegroundColor White
    Write-Host "  $($SYM.LINE * 52)" -ForegroundColor DarkGray
}

function Start-Spinner {
    param([string]$Label, [int]$Seconds = 1)
    $end = (Get-Date).AddSeconds($Seconds)
    $i = 0
    while ((Get-Date) -lt $end) {
        $f = $SYM.SPIN[$i % $SYM.SPIN.Count]
        Write-Host "`r  $f  $Label..." -NoNewline -ForegroundColor Cyan
        Start-Sleep -Milliseconds 80
        $i++
    }
    Write-Host "`r  $($SYM.OK)  $Label — готово!        " -ForegroundColor Green
}

function Show-ProgressBar {
    param(
        [string]$Label,
        [int]$Iterations = 40,
        [int]$DelayMs   = 50,
        [int]$Width     = 34
    )
    for ($i = 0; $i -le $Iterations; $i++) {
        $ratio = $i / $Iterations
        $pct   = [math]::Round($ratio * 100)
        $fill  = [int]($ratio * $Width)
        $bar   = ($SYM.BAR * $fill) + ($SYM.BAR_OFF * ($Width - $fill))
        Write-Host "`r  $Label [$bar] $pct%" -NoNewline -ForegroundColor Cyan
        Start-Sleep -Milliseconds $DelayMs
    }
    $full = $SYM.BAR * $Width
    Write-Host "`r  $Label [$full] 100%     " -ForegroundColor Green
}

function Write-Success { param([string]$Text) Write-Host "  $($SYM.OK)  " -NoNewline -ForegroundColor Green;  Write-Host $Text -ForegroundColor Green }
function Write-Failure { param([string]$Text) Write-Host "  $($SYM.FAIL)  " -NoNewline -ForegroundColor Red;    Write-Host $Text -ForegroundColor Red }
function Write-Info    { param([string]$Text) Write-Host "  $($SYM.DOT)  " -NoNewline -ForegroundColor DarkCyan; Write-Host $Text -ForegroundColor Gray }

# ---------- MAIN ----------

try { Clear-Host } catch {}

Show-Banner
Write-Typing "  Привет! Сейчас установим Ollama и запустим Pi-агент." 'Gray' 14
Write-Typing "  Всё займёт пару минут — не отходи надолго." 'DarkGray' 12
Write-Host ''

# ===== ШАГ 1: Проверка окружения =====
Write-Section -Title 'Проверка окружения' -Step 1 -Total 4

$isAdmin = $false
try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    $isAdmin = $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {}

Write-Info "PowerShell $($PSVersionTable.PSVersion)"
Write-Info $(if ($isAdmin) { 'Права администратора: есть' } else { 'Права администратора: нет (обычно не мешает)' })

$netOk = $false
try {
    $client = New-Object System.Net.Sockets.TcpClient
    $async  = $client.BeginConnect('ollama.com', 443, $null, $null)
    $netOk  = $async.AsyncWaitHandle.WaitOne(2000)
    $client.Close()
} catch { $netOk = $false }

if ($netOk) { Write-Info 'Сеть: ollama.com доступен' }
else        { Write-Info 'Сеть: проверка не удалась (продолжаем)' }

Start-Spinner -Label 'Проверки пройдены' -Seconds 1

# ===== ШАГ 2: Установка Ollama =====
Write-Section -Title 'Установка Ollama' -Step 2 -Total 4
Write-Info 'Скачиваем и запускаем официальный установщик...'
Write-Host ''

try {
    irm https://ollama.com/install.ps1 | iex
    Write-Host ''
    Write-Success 'Установщик Ollama завершил работу'
} catch {
    Write-Host ''
    Write-Failure "Ошибка установки: $_"
    exit 1
}

# Обновляем PATH в текущей сессии
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path','User')
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    $candidate = "$env:LOCALAPPDATA\Programs\Ollama"
    if (Test-Path $candidate) {
        $env:Path = "$candidate;$env:Path"
        Write-Info "PATH обновлён вручную: $candidate"
    }
}

# ===== ШАГ 3: Ожидание готовности Ollama =====
Write-Section -Title 'Ожидание запуска Ollama' -Step 3 -Total 4

$ready = $false
$deadline = (Get-Date).AddSeconds(30)
$i = 0
while ((Get-Date) -lt $deadline) {
    try {
        $null = & ollama list 2>$null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    } catch {}
    $f = $SYM.SPIN[$i % $SYM.SPIN.Count]
    Write-Host "`r  $f  Ollama стартует..." -NoNewline -ForegroundColor Cyan
    Start-Sleep -Milliseconds 200
    $i++
}

if ($ready) {
    Write-Host "`r  $($SYM.OK)  Ollama готов!                       " -ForegroundColor Green
} else {
    Write-Host "`r  $($SYM.FAIL)  Ollama не ответил за 30 сек.      " -ForegroundColor Red
    Write-Info 'Попробуйте вручную: ollama serve'
    exit 1
}

# ===== ШАГ 4: Запуск Pi =====
Write-Section -Title 'Запуск Pi через Ollama' -Step 4 -Total 4
Write-Info 'Устанавливаем Pi (если нужно) и открываем сессию...'
Write-Host ''

Show-ProgressBar -Label 'Подготовка Pi ' -Iterations 30 -DelayMs 45
Write-Host ''

try {
    ollama launch pi
    Write-Host ''
    Write-Success 'Pi завершил сессию'
} catch {
    Write-Host ''
    Write-Failure "Не удалось запустить Pi: $_"
    exit 1
}

# ===== Финал =====
Write-Host ''
$line = $SYM.DLINE * 54
Write-Host "  $line" -ForegroundColor DarkMagenta
Write-Host "  $($SYM.STAR)  Готово! Приятной работы с Ollama + Pi  $($SYM.STAR)  " -ForegroundColor Magenta
Write-Host "  $line" -ForegroundColor DarkMagenta
Write-Host ''