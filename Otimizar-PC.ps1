<#
.SYNOPSIS
    Windows PC Optimizer - Complete PC cleaning and optimization tool.

.DESCRIPTION
    Cleans temporary files, browser/package caches, project build artifacts,
    optimizes startup, tweaks system settings, and frees disk space.
    Never removes Epic Games / Fortnite files or source code.

.PARAMETER Auto
    Run all recommended optimizations without prompts.

.PARAMETER Mode
    Safe (default) or Aggressive.

.PARAMETER ProjectsPath
    Folder to scan for project junk (node_modules, build, dist, etc.).

.PARAMETER Drives
    Drive letters to optimize (default: C). Example: "C,D".

.PARAMETER DryRun
    Show what would be done without executing.

.PARAMETER SkipLong
    Skip SFC/DISM and Defender full scan.

.PARAMETER Silent
    No console output (logs only).

.PARAMETER SelfUpdate
    Check GitHub for a newer version.

.PARAMETER Schedule
    Create a scheduled task to run weekly.

.PARAMETER Report
    Generate an HTML report at the end.

.EXAMPLE
    .\Otimizar-PC.ps1
    Interactive menu.

.EXAMPLE
    .\Otimizar-PC.ps1 -Auto -Mode Aggressive -ProjectsPath "C:\Users\Leo\Documents" -Report
#>
#Requires -RunAsAdministrator

param(
    [switch]$Auto,
    [ValidateSet("Safe","Aggressive")]
    [string]$Mode = "Safe",
    [string]$ProjectsPath = "",
    [string]$Drives = "C",
    [switch]$DryRun,
    [switch]$SkipLong,
    [switch]$Silent,
    [switch]$SelfUpdate,
    [switch]$Schedule,
    [switch]$Report,
    [switch]$LoadOnly
)

$ErrorActionPreference = "Continue"
$LogFile = "$env:TEMP\OtimizadorPC_log.txt"
$ReportFile = "$env:TEMP\OtimizadorPC_report.html"
$Protected = @("Epic Games","Fortnite","EpicGames","FortniteGame",".git")
$Version = "2.0.0"
$GitHubRaw = "https://raw.githubusercontent.com/leonccunha21/windows-pc-optimizer/main/Otimizar-PC.ps1"

# Load config if exists
$ConfigPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "config.json"
$Config = $null
if (Test-Path $ConfigPath) {
    try { $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json } catch {}
}

function Write-Log($msg, $level = "INFO") {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$level] $msg"
    if (-not $Silent) { Write-Host $line }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Is-Protected($path) {
    foreach ($p in $Protected) { if ($path -like "*$p*") { return $true } }
    # Never delete if contains .git
    if (Test-Path (Join-Path $path ".git")) { return $true }
    return $false
}

function Is-SafeToDelete($path) {
    # Extra safety: never delete if contains source code files
    if (Is-Protected $path) { return $false }
    $codeExts = @("*.py","*.js","*.ts","*.jsx","*.tsx","*.cs","*.java","*.cpp","*.c","*.h","*.go","*.rs","*.rb","*.php","*.swift","*.kt","*.scala","*.vb","*.fs","*.sql","*.sh","*.ps1","*.bat","*.cmd")
    foreach ($ext in $codeExts) {
        if (Get-ChildItem $path -Filter $ext -Recurse -EA 0 | Select-Object -First 1) { return $false }
    }
    return $true
}

function Confirm-Action($msg) {
    if ($Auto) { return $true }
    $r = Read-Host "$msg [S/N]"
    return ($r -match '^[sS]')
}

function Get-FolderSize($path) {
    if (-not (Test-Path $path)) { return 0 }
    $s = (Get-ChildItem $path -Recurse -File -EA 0 | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $s) { $s = 0 }
    return $s
}

function Remove-Safe($path, $label) {
    if (Is-Protected $path) { Write-Log "  [PROTEGIDO] Pulando: $path" "WARN"; return 0 }
    if (-not (Is-SafeToDelete $path)) { Write-Log "  [SEGURO] Pasta contem codigo-fonte, pulando: $path" "WARN"; return 0 }
    if (-not (Test-Path $path)) { return 0 }
    $sz = Get-FolderSize $path
    if ($DryRun) { Write-Log "  [DRY-RUN] Removeria: $path ($([math]::Round($sz/1MB,1)) MB)"; return $sz }
    Remove-Item $path -Recurse -Force -EA 0
    Write-Log "  Removido: $path ($([math]::Round($sz/1MB,1)) MB)"
    return $sz
}

function New-RestorePoint {
    if ($DryRun) { Write-Log "  [DRY-RUN] Ponto de restauracao seria criado"; return }
    try {
        Checkpoint-Computer -Description "OtimizadorPC v$Version" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "  Ponto de restauracao criado"
    } catch { Write-Log "  Ponto de restauracao nao criado: $($_.Exception.Message)" "WARN" }
}

function Get-DriveType($letter) {
    try {
        $partitions = Get-Partition -DriveLetter $letter -EA 0
        if ($partitions) {
            $disk = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq $partitions[0].DiskNumber }
            if ($disk) { return $disk.MediaType }
        }
    } catch {}
    return "Unknown"
}

function Backup-Registry {
    $backupDir = "$env:TEMP\OtimizadorPC_backup"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" "$backupDir\run_hkcu.reg" /y 2>&1 | Out-Null
    reg export "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" "$backupDir\run_hklm.reg" /y 2>&1 | Out-Null
    Write-Log "Backup de registro salvo em $backupDir"
}

# ---------------- MENU ----------------
function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   OTIMIZADOR DE PC v$Version" -ForegroundColor Cyan
    Write-Host "   Modo: $Mode | DryRun: $DryRun | Drives: $Drives" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " 1. Limpeza de temporarios (>=7 dias)"
    Write-Host " 2. Limpeza de caches de navegadores (Chrome/Edge/Firefox/Brave/Opera)"
    Write-Host " 3. Limpeza de caches de pacotes (npm/pnpm/pip/nuget/cargo/go)"
    Write-Host " 4. Limpeza de lixo de projetos (node_modules, build, dist, .next, .gradle, .venv, __pycache__)"
    Write-Host " 5. Otimizar inicializacao (remover programas do boot)"
    Write-Host " 6. Ajustes de sistema (energia, telemetria, SysMain, visual, pagefile, TCP, servicos)"
    Write-Host " 7. Otimizar disco (TRIM/defrag + WinSxS + prefetch + icon cache + thumbnails)"
    Write-Host " 8. Limpar logs de eventos"
    Write-Host " 9. Desativar apps em segundo plano + Game Bar/DVR + Cortana"
    Write-Host "10. Limpeza de Disco (cleanmgr)"
    Write-Host "11. Flush DNS + reset Winsock"
    Write-Host "12. Ativar Storage Sense (limpeza automatica)"
    Write-Host "13. Verificacao de integridade (SFC + DISM) - demorado"
    Write-Host "14. Varredura completa do Defender"
    Write-Host "15. Limpar caches de aplicativos (Spotify, Discord, Teams, OneDrive, VS Code, JetBrains)"
    Write-Host "16. Desinstalar bloatware UWP (lista segura)"
    Write-Host "17. Analise de espaco em disco (top pastas)"
    Write-Host "18. Agendar limpeza semanal (Task Scheduler)"
    Write-Host "19. Gerar relatorio HTML"
    Write-Host "20. Executar TUDO (recomendado)"
    Write-Host "21. Self-update (verificar nova versao no GitHub)"
    Write-Host " 0. Sair"
    Write-Host ""
}

# ---------------- FUNCOES ----------------

function Clean-Temp {
    Write-Log "=== Limpeza de temporarios (>=7 dias) ==="
    foreach ($drive in $Drives.Split(",")) {
        $drive = $drive.Trim().ToUpper()
        $tmpPaths = @("$drive`:\Users\*\AppData\Local\Temp", "$drive`:\Windows\Temp")
        foreach ($t in $tmpPaths) {
            $resolved = Resolve-Path $t -EA 0
            foreach ($r in $resolved) {
                $path = $r.Path
                if (Test-Path $path) {
                    $before = Get-FolderSize $path
                    $oldFiles = Get-ChildItem $path -Recurse -File -EA 0 | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) -and -not (Is-Protected $_.FullName) }
                    $szOld = ($oldFiles | Measure-Object -Property Length -Sum).Sum
                    if ($null -eq $szOld) { $szOld = 0 }
                    if ($DryRun) {
                        Write-Log "  [DRY-RUN] Removeria $($oldFiles.Count) arquivos antigos ($([math]::Round($szOld/1MB,1)) MB) de $path"
                    } else {
                        $oldFiles | ForEach-Object { Remove-Item $_.FullName -Force -EA 0 }
                        Get-ChildItem $path -Recurse -Directory -EA 0 | Sort-Object FullName -Descending | ForEach-Object {
                            $dir = $_.FullName
                            if (-not (Is-Protected $dir)) {
                                $items = Get-ChildItem $dir -EA 0
                                if ($null -eq $items -or @($items).Count -eq 0) { Remove-Item $dir -Force -EA 0 }
                            }
                        }
                        $after = Get-FolderSize $path
                        Write-Log "  $path : $([math]::Round($before/1MB,1)) MB -> $([math]::Round($after/1MB,1)) MB (liberado $([math]::Round(($before-$after)/1MB,1)) MB)"
                    }
                }
            }
        }
    }
}

function Clean-BrowserCaches {
    Write-Log "=== Limpeza caches navegadores ==="
    $browsers = @(
        @{ Name="Chrome"; Paths=@("$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache","$env:LOCALAPPDATA\Google\Chrome\User Data\*\Code Cache","$env:LOCALAPPDATA\Google\Chrome\User Data\*\GPUCache") },
        @{ Name="Edge"; Paths=@("$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache","$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Code Cache","$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\GPUCache") },
        @{ Name="Firefox"; Paths=@("$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2") },
        @{ Name="Brave"; Paths=@("$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\*\Cache","$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\*\Code Cache") },
        @{ Name="Opera"; Paths=@("$env:APPDATA\Opera Software\Opera Stable\Cache","$env:APPDATA\Opera Software\Opera GX Stable\Cache") },
        @{ Name="Vivaldi"; Paths=@("$env:LOCALAPPDATA\Vivaldi\User Data\*\Cache") }
    )
    foreach ($b in $browsers) {
        foreach ($pattern in $b.Paths) {
            $resolved = Resolve-Path $pattern -EA 0
            foreach ($r in $resolved) {
                $sz = Get-FolderSize $r.Path
                if ($sz -gt 0) {
                    if ($DryRun) { Write-Log "  [DRY-RUN] $($b.Name): $($r.Path) ($([math]::Round($sz/1MB,1)) MB)" }
                    else {
                        Remove-Item "$($r.Path)\*" -Recurse -Force -EA 0
                        Write-Log "  $($b.Name) limpo: $($r.Path) ($([math]::Round($sz/1MB,1)) MB)"
                    }
                }
            }
        }
    }
}

function Clean-PackageCaches {
    Write-Log "=== Limpeza caches pacotes ==="
    $caches = @(
        @{ Path = "$env:LOCALAPPDATA\npm-cache"; Name = "npm" },
        @{ Path = "$env:LOCALAPPDATA\pnpm\store"; Name = "pnpm" },
        @{ Path = "$env:LOCALAPPDATA\pip\cache"; Name = "pip" },
        @{ Path = "$env:LOCALAPPDATA\ms-playwright"; Name = "playwright" },
        @{ Path = "$env:LOCALAPPDATA\Cypress"; Name = "cypress" },
        @{ Path = "$env:USERPROFILE\.gradle\caches"; Name = "gradle" },
        @{ Path = "$env:USERPROFILE\.m2\repository"; Name = "maven" },
        @{ Path = "$env:USERPROFILE\.cargo\registry\cache"; Name = "cargo" },
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" }
    )
    foreach ($c in $caches) { Remove-Safe $c.Path $c.Name | Out-Null }
}

function Clean-AppCaches {
    Write-Log "=== Limpeza caches de aplicativos ==="
    $appCaches = @(
        @{ Path = "$env:APPDATA\Spotify\*\Cache"; Name = "Spotify" },
        @{ Path = "$env:APPDATA\discord\Cache"; Name = "Discord" },
        @{ Path = "$env:APPDATA\discord\Code Cache"; Name = "Discord Code Cache" },
        @{ Path = "$env:APPDATA\Slack\Cache"; Name = "Slack" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Teams\Cache"; Name = "Teams" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\OneDrive\logs"; Name = "OneDrive logs" },
        @{ Path = "$env:APPDATA\Code\Cache"; Name = "VS Code Cache" },
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" },
        @{ Path = "$env:APPDATA\JetBrains"; Name = "JetBrains (manual)" }
    )
    foreach ($a in $appCaches) {
        $resolved = Resolve-Path $a.Path -EA 0
        foreach ($r in $resolved) {
            $sz = Get-FolderSize $r.Path
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] $($a.Name): $($r.Path) ($([math]::Round($sz/1MB,1)) MB)" }
                else {
                    Remove-Item "$($r.Path)\*" -Recurse -Force -EA 0
                    Write-Log "  $($a.Name) limpo: $($r.Path) ($([math]::Round($sz/1MB,1)) MB)"
                }
            }
        }
    }
}

function Clean-ProjectJunk {
    param([string]$RootPath)
    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $RootPath = Read-Host "Caminho da pasta de projetos (ex: C:\Users\Leo\Documents)"
    }
    if (-not (Test-Path $RootPath)) { Write-Log "Caminho nao existe: $RootPath" "WARN"; return }
    Write-Log "=== Limpeza de lixo de projetos em $RootPath ==="
    $lixoNames = @("node_modules","build","dist",".next","target","__pycache__",".gradle",".cache","out",".turbo",".nuxt",".output","coverage",".parcel-cache",".vite",".svelte-kit","bin","obj",".pytest_cache",".mypy_cache",".tox","htmlcov")
    $freed = 0; $removed = 0
    Get-ChildItem $RootPath -Recurse -Directory -EA 0 | Where-Object {
        $lixoNames -contains $_.Name -and
        $_.FullName -notmatch '\\node_modules\\' -and
        $_.FullName -notmatch '\\\.venv\\' -and
        -not (Is-Protected $_.FullName)
    } | ForEach-Object {
        $sz = Remove-Safe $_.FullName "lixo"
        $freed += $sz; $removed++
    }
    Get-ChildItem $RootPath -Recurse -Directory -Filter ".venv" -EA 0 | Where-Object { -not (Is-Protected $_.FullName) } | ForEach-Object {
        $sz = Remove-Safe $_.FullName ".venv"
        $freed += $sz; $removed++
    }
    Write-Log "  Total: $removed pastas, $([math]::Round($freed/1MB,1)) MB"
}

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams","OneDrive","GoogleDriveFS")
    foreach ($n in $removeNames) {
        if (Get-ItemProperty $runKey -Name $n -EA 0) {
            if ($DryRun) { Write-Log "  [DRY-RUN] Removeria do startup: $n" }
            else { Remove-ItemProperty $runKey -Name $n -Force -EA 0; Write-Log "  Removido do startup: $n" }
        }
    }
    $startup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    foreach ($f in @("OmniRoute.vbs","SolutiPlugin.lnk")) {
        $p = Join-Path $startup $f
        if (Test-Path $p) {
            if ($DryRun) { Write-Log "  [DRY-RUN] Removeria: $f" }
            else { Remove-Item $p -Force -EA 0; Write-Log "  Removido: $f" }
        }
    }
    # Scheduled tasks that auto-start programs
    Write-Log "  OneDrive e Google Drive podem ser reativados manualmente se necessario."
}

function System-Tweaks {
    Write-Log "=== Ajustes de sistema ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Ajustes seriam aplicados"; return }
    try { powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null; Write-Log "  Energia: Alto Desempenho" } catch {}
    try { Stop-Service DiagTrack -Force -EA 0; Set-Service DiagTrack -StartupType Disabled -EA 0; Write-Log "  DiagTrack desativado" } catch {}
    try { Stop-Service SysMain -Force -EA 0; Set-Service SysMain -StartupType Disabled -EA 0; Write-Log "  SysMain desativado (SSD)" } catch {}
    try { Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DoSvc" -Name Start -Value 4 -EA 0; Write-Log "  DoSvc desativado" } catch {}
    try { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name VisualFXSetting -Value 2 -EA 0; Write-Log "  Efeitos visuais: melhor desempenho" } catch {}
    try { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name EnableTransparency -Value 0 -EA 0; Write-Log "  Transparencia desativada" } catch {}
    $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    if (Test-Path $cdm) {
        Set-ItemProperty -Path $cdm -Name "SubscribedContent-338389Enabled" -Value 0 -EA 0
        Set-ItemProperty -Path $cdm -Name "SoftLandingEnabled" -Value 0 -EA 0
        Set-ItemProperty -Path $cdm -Name "SystemPaneSuggestionsEnabled" -Value 0 -EA 0
        Write-Log "  Dicas/sugestoes desativadas"
    }
    # Disable Cortana / web search
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    # Disable Start menu suggestions
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    # Background apps
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    # TCP
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
    # Disable notifications
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
}

function Set-Pagefile {
    if ($DryRun) { Write-Log "  [DRY-RUN] Pagefile seria fixado em 8GB"; return }
    if (-not (Confirm-Action "Fixar pagefile em 8GB? (requer reinicio)")) { return }
    try {
        $cs = Get-WmiObject Win32_ComputerSystem
        $cs.AutomaticManagedPagefile = $false
        $cs.Put() | Out-Null
        $existing = Get-WmiObject Win32_PageFileSetting
        foreach ($p in $existing) { $p.Delete() | Out-Null }
        $np = ([WmiClass]"Win32_PageFileSetting").CreateInstance()
        $np.Name = "C:\pagefile.sys"
        $np.InitialSize = 8192
        $np.MaximumSize = 8192
        $np.Put() | Out-Null
        Write-Log "  Pagefile fixado em 8GB (requer reinicio)"
    } catch {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "C:\pagefile.sys 8192 8192" /f 2>&1 | Out-Null
        Write-Log "  Pagefile configurado via registro (requer reinicio)"
    }
}

function Optimize-Disk {
    Write-Log "=== Otimizacao de disco ==="
    foreach ($drive in $Drives.Split(",")) {
        $drive = $drive.Trim().ToUpper()
        $driveType = Get-DriveType $drive
        Write-Log "  Drive $drive`: tipo $driveType"
        if ($DryRun) { Write-Log "  [DRY-RUN] Otimizacao seria executada"; continue }
        if ($driveType -eq "SSD") {
            try { Optimize-Volume -DriveLetter $drive -ReTrim -Verbose 2>&1 | Out-Null; Write-Log "  TRIM concluido ($drive SSD)" } catch { Write-Log "  Aviso TRIM: $_" "WARN" }
        } else {
            try { Optimize-Volume -DriveLetter $drive -Defrag -Verbose 2>&1 | Out-Null; Write-Log "  Desfrag concluido ($drive HDD)" } catch { Write-Log "  Aviso defrag: $_" "WARN" }
        }
    }
    # WinSxS cleanup
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
    # Prefetch
    $prefetch = "$env:WINDIR\Prefetch"
    if (Test-Path $prefetch) {
        $sz = Get-FolderSize $prefetch
        if ($Mode -eq "Aggressive") {
            Remove-Item "$prefetch\*" -Force -EA 0
            Write-Log "  Prefetch limpo ($([math]::Round($sz/1MB,1)) MB)"
        } else {
            Write-Log "  Prefetch: $([math]::Round($sz/1MB,1)) MB (use modo Aggressive para limpar)"
        }
    }
    # Icon cache
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    # Thumbnail cache
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
    # Font cache
    try {
        Stop-Service FontCache -Force -EA 0
        Remove-Item "$env:WINDIR\System32\FNTCACHE.DAT" -Force -EA 0
        Start-Service FontCache -EA 0
        Write-Log "  Cache de fontes limpo"
    } catch { Write-Log "  Aviso font cache: $_" "WARN" }
}

function Clear-EventLogs {
    Write-Log "=== Limpeza de logs de eventos ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Logs seriam limpos"; return }
    $cleared = 0
    wevtutil el 2>&1 | ForEach-Object {
        try { wevtutil cl "$_" 2>&1 | Out-Null; $script:cleared++ } catch {}
    }
    Write-Log "  Logs limpos: $cleared"
}

function Disable-BackgroundApps {
    Write-Log "=== Apps em segundo plano + Game Bar/DVR + Cortana ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Seriam desativados"; return }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $gameBar = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
    if (-not (Test-Path $gameBar)) { New-Item -Path $gameBar -Force | Out-Null }
    Set-ItemProperty -Path $gameBar -Name "AppCaptureEnabled" -Value 0 -EA 0
    $gameConfig = "HKCU:\System\GameConfigStore"
    if (Test-Path $gameConfig) { Set-ItemProperty -Path $gameConfig -Name "GameDVR_Enabled" -Value 0 -EA 0 }
    Write-Log "  Game Bar / DVR desativados"
}

function Disable-Services {
    if ($Mode -ne "Aggressive") { return }
    Write-Log "=== Desativacao de servicos (Aggressive) ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Servicos seriam desativados"; return }
    $services = @("Fax","XblAuthManager","XblGameSave","MapsBroker","RetailDemo","SharedAccess","icssvc","lfsvc","WMPNetworkSvc","RemoteRegistry")
    foreach ($s in $services) {
        $svc = Get-Service $s -EA 0
        if ($svc) {
            try { Stop-Service $s -Force -EA 0; Set-Service $s -StartupType Disabled -EA 0; Write-Log "  $s desativado" } catch { Write-Log "  ${s}: $_" "WARN" }
        }
    }
}

function Disable-Bloatware {
    Write-Log "=== Desinstalar bloatware UWP (lista segura) ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Bloatware seria removido"; return }
    if (-not (Confirm-Action "Desinstalar apps UWP de bloatware? (seguro)")) { return }
    $bloatware = @(
        "Microsoft.3DBuilder","Microsoft.BingNews","Microsoft.BingWeather","Microsoft.GetHelp",
        "Microsoft.Getstarted","Microsoft.Messaging","Microsoft.Microsoft3DViewer","Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection","Microsoft.NetworkSpeedTest","Microsoft.News",
        "Microsoft.Office.Sway","Microsoft.OneConnect","Microsoft.People","Microsoft.Print3D",
        "Microsoft.SkypeApp","Microsoft.Wallet","Microsoft.WindowsAlarms","Microsoft.WindowsCamera",
        "Microsoft.windowscommunicationsapps","Microsoft.WindowsFeedbackHub","Microsoft.WindowsMaps",
        "Microsoft.WindowsPhone","Microsoft.WindowsSoundRecorder","Microsoft.XboxApp",
        "Microsoft.ZuneMusic","Microsoft.ZuneVideo","king.com.CandyCrushSaga","king.com.CandyCrushSodaSaga",
        "ShazamEntertainmentLtd.Shazam","PandoraMediaInc.29680B314EFC2","Facebook.Facebook",
        "Flipboard.Flipboard","Twitter.Twitter","SpotifyAB.SpotifyMusic"
    )
    foreach ($app in $bloatware) {
        $pkg = Get-AppxPackage -Name $app -EA 0
        if ($pkg) {
            try { Remove-AppxPackage -Package $pkg.PackageFullName -EA 0; Write-Log "  Removido: $app" } catch { Write-Log "  Falha ao remover $app : $_" "WARN" }
        }
    }
    Write-Log "  Bloatware removido (reinstalavel pela Store)"
}

function Flush-DNS {
    Write-Log "=== Rede (DNS/Winsock) ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Flush DNS + Winsock reset"; return }
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    Write-Log "  Cache DNS limpo; Winsock/IP reset agendados (aplicam no reinicio)"
}

function Enable-StorageSense {
    Write-Log "=== Storage Sense ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Storage Sense seria ativado"; return }
    $ss = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
    if (-not (Test-Path $ss)) { New-Item -Path $ss -Force | Out-Null }
    Set-ItemProperty -Path $ss -Name "01" -Value 1 -EA 0
    Set-ItemProperty -Path $ss -Name "04" -Value 1 -EA 0
    Set-ItemProperty -Path $ss -Name "08" -Value 1 -EA 0
    Set-ItemProperty -Path $ss -Name "02" -Value 30 -EA 0
    Set-ItemProperty -Path $ss -Name "20" -Value 7 -EA 0
    Write-Log "  Storage Sense ativado (temp + lixeira; Downloads protegidos)"
}

function Run-CleanMgr {
    Write-Log "=== Limpeza de Disco (cleanmgr) ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] cleanmgr seria executado"; return }
    try {
        Start-Process cleanmgr -ArgumentList "/d C /AUTOCLEAN" -Wait -WindowStyle Hidden
        Write-Log "  cleanmgr concluido"
    } catch { Write-Log "  Aviso cleanmgr: $_" "WARN" }
}

function Run-SFC-DISM {
    Write-Log "=== Verificacao de integridade (SFC + DISM) ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] SFC+DISM seriam executados"; return }
    if (-not (Confirm-Action "Executar SFC + DISM? (pode demorar 15-30 min)")) { return }
    $bgScript = "$env:TEMP\OtimizadorPC_sfc.ps1"
    @"
"SFC inicio: `$(Get-Date)" | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt"
sfc /scannow 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
"SFC fim: `$(Get-Date)" | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
"FIM: `$(Get-Date)" | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
"@ | Out-File $bgScript -Encoding UTF8
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $bgScript" -WindowStyle Hidden
    Write-Log "  SFC+DISM iniciados em background. Log: $env:TEMP\OtimizadorPC_sfc_log.txt"
}

function Run-DefenderScan {
    Write-Log "=== Varredura completa do Defender ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Full scan seria iniciado"; return }
    if (-not (Confirm-Action "Iniciar full scan do Defender? (demorado)")) { return }
    try {
        Start-Process powershell -ArgumentList "-NoProfile -WindowStyle Hidden -Command `"Start-MpScan -ScanType FullScan`"" -WindowStyle Hidden
        Write-Log "  Full scan iniciado em background"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Analyze-DiskSpace {
    Write-Log "=== Analise de espaco em disco (top pastas em C:\Users) ==="
    $targets = @("C:\Users\Leo\Downloads","C:\Users\Leo\Documents","C:\Users\Leo\Desktop","C:\Users\Leo\AppData\Local","C:\Users\Leo\AppData\Roaming")
    foreach ($t in $targets) {
        if (Test-Path $t) {
            Get-ChildItem $t -Directory -EA 0 | ForEach-Object {
                $sz = Get-FolderSize $_.FullName
                Write-Log "  $($_.FullName): $([math]::Round($sz/1GB,2)) GB"
            }
        }
    }
}

function Schedule-Task {
    Write-Log "=== Agendar limpeza semanal ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Tarefa seria criada"; return }
    $taskName = "OtimizadorPC_Weekly"
    $scriptPath = $MyInvocation.ScriptName
    if (-not $scriptPath) { $scriptPath = $PSCommandPath }
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Auto -SkipLong"
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -EA 0 | Out-Null
    Write-Log "  Tarefa agendada: $taskName (domingos 3h)"
}

function Generate-Report {
    Write-Log "=== Gerando relatorio HTML ==="
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $freeGB = [math]::Round($disk.FreeSpace/1GB,2)
    $totalGB = [math]::Round($disk.Size/1GB,2)
    $usedGB = [math]::Round(($disk.Size-$disk.FreeSpace)/1GB,2)
    $html = @"
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>OtimizadorPC Report</title>
<style>body{font-family:Segoe UI,Arial;margin:20px;background:#f5f5f5}
.card{background:#fff;padding:20px;margin:10px 0;border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,.1)}
h1{color:#2c3e50}h2{color:#3498db}.ok{color:#27ae60}.warn{color:#e67e22}
table{width:100%;border-collapse:collapse}th,td{padding:8px;border-bottom:1px solid #ddd;text-align:left}
th{background:#3498db;color:#fff}</style></head><body>
<h1>OtimizadorPC - Relatorio</h1>
<div class="card"><h2>Disco C:</h2>
<p>Total: $totalGB GB | Usado: $usedGB GB | Livre: <span class="ok">$freeGB GB</span></p>
<table><tr><th>Metrica</th><th>Valor</th></tr>
<tr><td>Espaco livre</td><td>$freeGB GB</td></tr>
<tr><td>Espaco total</td><td>$totalGB GB</td></tr>
<tr><td>Modo</td><td>$Mode</td></tr>
<tr><td>DryRun</td><td>$DryRun</td></tr>
<tr><td>Data</td><td>$(Get-Date)</td></tr></table></div>
<div class="card"><h2>Log</h2><pre>$(Get-Content $LogFile -Raw)</pre></div>
</body></html>
"@
    $html | Out-File $ReportFile -Encoding UTF8
    Write-Log "  Relatorio salvo em $ReportFile"
    if (-not $Silent) { Start-Process $ReportFile }
}

function Invoke-SelfUpdate {
    Write-Log "=== Self-update ==="
    try {
        $latest = Invoke-WebRequest -Uri $GitHubRaw -UseBasicParsing -TimeoutSec 15
        $localHash = (Get-FileHash $PSCommandPath -Algorithm SHA256).Hash
        $remoteHash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($latest.Content))) -replace "-"
        if ($localHash -ne $remoteHash) {
            Write-Log "  Nova versao disponivel. Atualizando..."
            $latest.Content | Out-File $PSCommandPath -Encoding UTF8 -Force
            Write-Log "  Script atualizado. Reinicie para usar a nova versao."
        } else {
            Write-Log "  Ja esta na versao mais recente."
        }
    } catch { Write-Log "  Nao foi possivel verificar atualizacoes: $_" "WARN" }
}

function Show-DiskSpace {
    foreach ($drive in $Drives.Split(",")) {
        $drive = $drive.Trim().ToUpper()
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive`:'"
        if ($disk) { Write-Log "Drive $drive`: Livre = $([math]::Round($disk.FreeSpace/1GB,2)) GB de $([math]::Round($disk.Size/1GB,2)) GB" }
    }
}

# ---------------- MAIN ----------------
"=== Inicio $(Get-Date) - v$Version - Modo $Mode ===" | Out-File $LogFile -Encoding UTF8

if ($LoadOnly) { return }

if ($SelfUpdate) { Invoke-SelfUpdate; exit }

if ($Schedule) { Schedule-Task; exit }

if ($Auto) {
    Write-Log "Modo AUTO: executando todas as otimizacoes recomendadas (Mode=$Mode)"
    New-RestorePoint
    Backup-Registry
    Clean-Temp
    Clean-BrowserCaches
    Clean-PackageCaches
    Clean-AppCaches
    if ($ProjectsPath) { Clean-ProjectJunk -RootPath $ProjectsPath }
    Optimize-Startup
    System-Tweaks
    Set-Pagefile
    Optimize-Disk
    Disable-Services
    Disable-Bloatware
    Clear-EventLogs
    Disable-BackgroundApps
    Flush-DNS
    Enable-StorageSense
    Run-CleanMgr
    if (-not $SkipLong) { Run-SFC-DISM; Run-DefenderScan }
    Analyze-DiskSpace
    Show-DiskSpace
    if ($Report) { Generate-Report }
    Write-Log "=== CONCLUIDO ==="
    exit
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Escolha uma opcao"
    switch ($choice) {
        "1"  { Clean-Temp }
        "2"  { Clean-BrowserCaches }
        "3"  { Clean-PackageCaches }
        "4"  { Clean-ProjectJunk }
        "5"  { Optimize-Startup }
        "6"  { System-Tweaks; Set-Pagefile }
        "7"  { Optimize-Disk }
        "8"  { Clear-EventLogs }
        "9"  { Disable-BackgroundApps }
        "10" { Run-CleanMgr }
        "11" { Flush-DNS }
        "12" { Enable-StorageSense }
        "13" { Run-SFC-DISM }
        "14" { Run-DefenderScan }
        "15" { Clean-AppCaches }
        "16" { Disable-Bloatware }
        "17" { Analyze-DiskSpace }
        "18" { Schedule-Task }
        "19" { Generate-Report }
        "20" {
            New-RestorePoint
            Backup-Registry
            Clean-Temp
            Clean-BrowserCaches
            Clean-PackageCaches
            Clean-AppCaches
            $p = Read-Host "Caminho de projetos para limpar lixo (Enter para pular)"
            if ($p) { Clean-ProjectJunk -RootPath $p }
            Optimize-Startup
            System-Tweaks
            Set-Pagefile
            Optimize-Disk
            Disable-Services
            Disable-Bloatware
            Clear-EventLogs
            Disable-BackgroundApps
            Flush-DNS
            Enable-StorageSense
            Run-CleanMgr
            if (-not $SkipLong) { Run-SFC-DISM; Run-DefenderScan }
            Analyze-DiskSpace
            Show-DiskSpace
            if ($Report) { Generate-Report }
            Write-Log "=== CONCLUIDO ==="
        }
        "21" { Invoke-SelfUpdate }
        "0"  { Write-Host "Saindo."; break }
        default { Write-Host "Opcao invalida." }
    }
    if ($choice -eq "0") { break }
    Read-Host "Pressione Enter para continuar"
}
