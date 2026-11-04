<#
.SYNOPSIS
    Windows PC Optimizer - Complete PC cleaning, repair and optimization tool.

.DESCRIPTION
    Cleans temporary files, browser/package caches, optimizes startup,
    tweaks system settings, and frees disk space.
    Includes professional maintenance: diagnostics, backups, repairs, reports.
    NEVER removes project files, source code, or Epic Games / Fortnite files.

.PARAMETER Auto
    Run all recommended optimizations without prompts.

.PARAMETER Mode
    Safe (default) or Aggressive.

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

.PARAMETER AutoPush
    Commit and push changes to GitHub after completion.

.PARAMETER TechMode
    Technical mode: more details, fewer prompts.

.EXAMPLE
    .\Otimizar-PC.ps1
    Interactive menu.

.EXAMPLE
    .\Otimizar-PC.ps1 -Auto -Mode Aggressive -Report -AutoPush
#>
#Requires -RunAsAdministrator

param(
    [switch]$Auto,
    [ValidateSet("Safe","Aggressive")]
    [string]$Mode = "Safe",
    [string]$Drives = "C",
    [switch]$DryRun,
    [switch]$SkipLong,
    [switch]$Silent,
    [switch]$SelfUpdate,
    [switch]$Schedule,
    [switch]$Report,
    [switch]$AutoPush,
    [switch]$TechMode,
    [switch]$LoadOnly
)

$ErrorActionPreference = "Continue"
$LogFile = "$env:TEMP\OtimizadorPC_log.txt"
$ReportFile = "$env:TEMP\OtimizadorPC_report.html"
$Protected = @("Epic Games","Fortnite","EpicGames","FortniteGame",".git")
$Version = "3.3.0"
$GitHubRaw = "https://raw.githubusercontent.com/leonccunha21/windows-pc-optimizer/main/Otimizar-PC.ps1"

function Write-Log($msg, $level = "INFO") {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$level] $msg"
    if (-not $Silent) { Write-Host $line }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Is-Protected($path) {
    foreach ($p in $Protected) { if ($path -like "*$p*") { return $true } }
    if (Test-Path (Join-Path $path ".git")) { return $true }
    return $false
}

function Confirm-Action($msg) {
    if ($Auto -or $TechMode) { return $true }
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

# ---------------- DIAGNOSTICO ----------------

function Get-HardwareInfo {
    Write-Log "=== Informacoes de hardware ==="
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $os = Get-CimInstance Win32_OperatingSystem
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $board = Get-CimInstance Win32_BaseBoard | Select-Object -First 1
    $bios = Get-CimInstance Win32_BIOS | Select-Object -First 1
    Write-Log "  CPU: $($cpu.Name) ($($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads)"
    Write-Log "  RAM: $([math]::Round($os.TotalVisibleMemorySize/1MB,2)) GB total, $([math]::Round($os.FreePhysicalMemory/1MB,2)) GB livre"
    Write-Log "  GPU: $($gpu.Name)"
    Write-Log "  Placa-mae: $($board.Manufacturer) $($board.Product)"
    Write-Log "  BIOS: $($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)"
    Write-Log "  SO: $($os.Caption) $($os.Version) ($($os.OSArchitecture))"
    $uptime = (Get-Date) - $os.LastBootUpTime
    Write-Log "  Uptime: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
}

function Check-DiskHealth {
    Write-Log "=== Saude do disco (SMART) ==="
    try {
        $disks = Get-PhysicalDisk
        foreach ($d in $disks) {
            $status = $d.HealthStatus
            $color = if ($status -eq "Healthy") { "OK" } else { "ATENCAO" }
            Write-Log "  $($d.FriendlyName): $status ($color) - $($d.MediaType) - $([math]::Round($d.Size/1GB,0)) GB"
            if ($status -ne "Healthy") { Write-Log "  *** DISCO COM PROBLEMA! Faca backup imediatamente. ***" "WARN" }
        }
    } catch { Write-Log "  Nao foi possivel verificar SMART: $_" "WARN" }
}

function Check-Memory {
    Write-Log "=== Verificacao de memoria ==="
    Write-Log "  Para testar a RAM, execute: mdsched.exe (Windows Memory Diagnostic)"
    Write-Log "  Ou use MemTest86 para teste mais completo."
}

function Check-Drivers {
    Write-Log "=== Drivers com problemas ==="
    try {
        $problemDevices = Get-PnpDevice -Status Error -EA 0
        if ($problemDevices) {
            foreach ($d in $problemDevices) {
                Write-Log "  [PROBLEMA] $($d.FriendlyName) ($($d.Status))" "WARN"
            }
        } else {
            Write-Log "  Nenhum dispositivo com erro detectado"
        }
    } catch { Write-Log "  Nao foi possivel verificar drivers: $_" "WARN" }
}

function Check-WindowsUpdates {
    Write-Log "=== Atualizacoes pendentes ==="
    try {
        $wu = New-Object -ComObject Microsoft.Update.Session
        $searcher = $wu.CreateUpdateSearcher()
        $res = $searcher.Search("IsInstalled=0")
        Write-Log "  Atualizacoes pendentes: $($res.Updates.Count)"
        $res.Updates | Select-Object -First 10 | ForEach-Object { Write-Log "    - $($_.Title)" }
    } catch { Write-Log "  Nao foi possivel verificar updates: $_" "WARN" }
}

function Check-OpenPorts {
    Write-Log "=== Portas abertas (listening) ==="
    try {
        $ports = Get-NetTCPConnection -State Listen -EA 0 | Select-Object LocalPort, OwningProcess -Unique | Sort-Object LocalPort
        $ports | Select-Object -First 20 | ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -EA 0
            Write-Log "  Porta $($_.LocalPort) -> $($proc.Name) (PID $($_.OwningProcess))"
        }
    } catch { Write-Log "  Nao foi possivel verificar portas: $_" "WARN" }
}

function Check-SuspiciousTasks {
    Write-Log "=== Tarefas agendadas suspeitas ==="
    try {
        $tasks = Get-ScheduledTask -EA 0 | Where-Object { $_.State -eq "Ready" -and $_.TaskPath -notlike "\Microsoft\*" }
        $suspicious = $tasks | Where-Object { $_.Actions.Execute -match "powershell|cmd|wscript|cscript|mshta|rundll32|regsvr32" }
        if ($suspicious) {
            foreach ($t in $suspicious) { Write-Log "  [SUSPEITO] $($t.TaskName): $($t.Actions.Execute)" "WARN" }
        } else {
            Write-Log "  Nenhuma tarefa suspeita encontrada"
        }
    } catch { Write-Log "  Nao foi possivel verificar tarefas: $_" "WARN" }
}

# ---------------- BACKUP ----------------

function Backup-Drivers {
    Write-Log "=== Backup de drivers ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Backup seria feito"; return }
    $backupDir = "$env:TEMP\OtimizadorPC_drivers"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    try {
        dism /online /export-driver /destination:"$backupDir" 2>&1 | Out-Null
        Write-Log "  Drivers exportados para $backupDir"
    } catch { Write-Log "  Aviso backup drivers: $_" "WARN" }
}

function Backup-RegistryFull {
    Write-Log "=== Backup completo do registro ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Backup seria feito"; return }
    $backupDir = "$env:TEMP\OtimizadorPC_regbackup"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    reg export "HKLM\SOFTWARE" "$backupDir\hklm_software.reg" /y 2>&1 | Out-Null
    reg export "HKCU\SOFTWARE" "$backupDir\hkcu_software.reg" /y 2>&1 | Out-Null
    Write-Log "  Registro exportado para $backupDir"
}

# ---------------- REPARO ----------------

function Repair-WindowsUpdate {
    Write-Log "=== Reparo do Windows Update ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Reparo seria executado"; return }
    try {
        Stop-Service wuauserv -Force -EA 0
        Stop-Service bits -Force -EA 0
        Stop-Service cryptsvc -Force -EA 0
        Stop-Service msiserver -Force -EA 0
        Rename-Item "$env:WINDIR\SoftwareDistribution" "SoftwareDistribution.old" -EA 0
        Rename-Item "$env:WINDIR\System32\catroot2" "catroot2.old" -EA 0
        Start-Service wuauserv -EA 0
        Start-Service bits -EA 0
        Start-Service cryptsvc -EA 0
        Start-Service msiserver -EA 0
        Write-Log "  Componentes do Windows Update resetados"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Repair-Store {
    Write-Log "=== Reparo da Microsoft Store ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Reparo seria executado"; return }
    try {
        wsreset.exe 2>&1 | Out-Null
        Write-Log "  Cache da Store resetado (wsreset)"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Repair-Network {
    Write-Log "=== Reparo de rede completo ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Reparo seria executado"; return }
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
}

function Clean-StoreCache {
    Write-Log "=== Limpeza de cache da Windows Store ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Cache seria limpo"; return }
    $storeCache = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache"
    if (Test-Path $storeCache) {
        $sz = Get-FolderSize $storeCache
        Remove-Item "$storeCache\*" -Recurse -Force -EA 0
        Write-Log "  Cache da Store limpo ($([math]::Round($sz/1MB,1)) MB)"
    }
}

function Clean-OneDriveCache {
    Write-Log "=== Limpeza de cache do OneDrive ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Cache seria limpo"; return }
    $odCache = "$env:LOCALAPPDATA\Microsoft\OneDrive\logs"
    if (Test-Path $odCache) {
        $sz = Get-FolderSize $odCache
        Remove-Item "$odCache\*" -Recurse -Force -EA 0
        Write-Log "  Logs do OneDrive limpos ($([math]::Round($sz/1MB,1)) MB)"
    }
}

# ---------------- LIMPEZA ----------------

function Clean-Temp {
    Write-Log "=== Limpeza de temporarios (>=7 dias) ==="
    foreach ($drive in $Drives.Split(",")) {
        $drive = $drive.Trim().ToUpper()
        $tmpPaths = @("$drive`:\Windows\Temp")
        if ($drive -eq "C") { $tmpPaths += "$env:TEMP" }
        foreach ($t in $tmpPaths) {
            if (Test-Path $t) {
                $before = Get-FolderSize $t
                $oldFiles = Get-ChildItem $t -Recurse -File -EA 0 | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) -and -not (Is-Protected $_.FullName) }
                $szOld = ($oldFiles | Measure-Object -Property Length -Sum).Sum
                if ($null -eq $szOld) { $szOld = 0 }
                if ($DryRun) {
                    Write-Log "  [DRY-RUN] Removeria $($oldFiles.Count) arquivos antigos ($([math]::Round($szOld/1MB,1)) MB) de $t"
                } else {
                    $oldFiles | ForEach-Object { Remove-Item $_.FullName -Force -EA 0 }
                    Get-ChildItem $t -Recurse -Directory -EA 0 | Sort-Object FullName -Descending | ForEach-Object {
                        $dir = $_.FullName
                        if (-not (Is-Protected $dir)) {
                            $items = Get-ChildItem $dir -EA 0
                            if ($null -eq $items -or @($items).Count -eq 0) { Remove-Item $dir -Force -EA 0 }
                        }
                    }
                    $after = Get-FolderSize $t
                    Write-Log "  $t : $([math]::Round($before/1MB,1)) MB -> $([math]::Round($after/1MB,1)) MB (liberado $([math]::Round(($before-$after)/1MB,1)) MB)"
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
}

# ---------------- DIAGNOSTICO ----------------

function Get-HardwareInfo {
    Write-Log "=== Informacoes de hardware ==="
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $os = Get-CimInstance Win32_OperatingSystem
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $board = Get-CimInstance Win32_BaseBoard | Select-Object -First 1
    $bios = Get-CimInstance Win32_BIOS | Select-Object -First 1
    Write-Log "  CPU: $($cpu.Name) ($($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads)"
    Write-Log "  RAM: $([math]::Round($os.TotalVisibleMemorySize/1MB,2)) GB total, $([math]::Round($os.FreePhysicalMemory/1MB,2)) GB livre"
    Write-Log "  GPU: $($gpu.Name)"
    Write-Log "  Placa-mae: $($board.Manufacturer) $($board.Product)"
    Write-Log "  BIOS: $($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)"
    Write-Log "  SO: $($os.Caption) $($os.Version) ($($os.OSArchitecture))"
    $uptime = (Get-Date) - $os.LastBootUpTime
    Write-Log "  Uptime: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
}

function Check-DiskHealth {
    Write-Log "=== Saude do disco (SMART) ==="
    try {
        $disks = Get-PhysicalDisk
        foreach ($d in $disks) {
            $status = $d.HealthStatus
            Write-Log "  $($d.FriendlyName): $status - $($d.MediaType) - $([math]::Round($d.Size/1GB,0)) GB"
            if ($status -ne "Healthy") { Write-Log "  *** DISCO COM PROBLEMA! Faca backup imediatamente. ***" "WARN" }
        }
    } catch { Write-Log "  Nao foi possivel verificar SMART: $_" "WARN" }
}

function Check-Memory {
    Write-Log "=== Verificacao de memoria ==="
    Write-Log "  Para testar a RAM, execute: mdsched.exe (Windows Memory Diagnostic)"
}

function Check-Drivers {
    Write-Log "=== Drivers com problemas ==="
    try {
        $problemDevices = Get-PnpDevice -Status Error -EA 0
        if ($problemDevices) {
            foreach ($d in $problemDevices) { Write-Log "  [PROBLEMA] $($d.FriendlyName) ($($d.Status))" "WARN" }
        } else { Write-Log "  Nenhum dispositivo com erro detectado" }
    } catch { Write-Log "  Nao foi possivel verificar drivers: $_" "WARN" }
}

function Check-WindowsUpdates {
    Write-Log "=== Atualizacoes pendentes ==="
    try {
        $wu = New-Object -ComObject Microsoft.Update.Session
        $searcher = $wu.CreateUpdateSearcher()
        $res = $searcher.Search("IsInstalled=0")
        Write-Log "  Atualizacoes pendentes: $($res.Updates.Count)"
        $res.Updates | Select-Object -First 10 | ForEach-Object { Write-Log "    - $($_.Title)" }
    } catch { Write-Log "  Nao foi possivel verificar updates: $_" "WARN" }
}

function Check-OpenPorts {
    Write-Log "=== Portas abertas (listening) ==="
    try {
        $ports = Get-NetTCPConnection -State Listen -EA 0 | Select-Object LocalPort, OwningProcess -Unique | Sort-Object LocalPort
        $ports | Select-Object -First 20 | ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -EA 0
            Write-Log "  Porta $($_.LocalPort) -> $($proc.Name) (PID $($_.OwningProcess))"
        }
    } catch { Write-Log "  Nao foi possivel verificar portas: $_" "WARN" }
}

function Check-SuspiciousTasks {
    Write-Log "=== Tarefas agendadas suspeitas ==="
    try {
        $tasks = Get-ScheduledTask -EA 0 | Where-Object { $_.State -eq "Ready" -and $_.TaskPath -notlike "\Microsoft\*" }
        $suspicious = $tasks | Where-Object { $_.Actions.Execute -match "powershell|cmd|wscript|cscript|mshta|rundll32|regsvr32" }
        if ($suspicious) {
            foreach ($t in $suspicious) { Write-Log "  [SUSPEITO] $($t.TaskName): $($t.Actions.Execute)" "WARN" }
        } else { Write-Log "  Nenhuma tarefa suspeita encontrada" }
    } catch { Write-Log "  Nao foi possivel verificar tarefas: $_" "WARN" }
}

# ---------------- BACKUP ----------------

function Backup-Drivers {
    Write-Log "=== Backup de drivers ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Backup seria feito"; return }
    $backupDir = "$env:TEMP\OtimizadorPC_drivers"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    try {
        dism /online /export-driver /destination:"$backupDir" 2>&1 | Out-Null
        Write-Log "  Drivers exportados para $backupDir"
    } catch { Write-Log "  Aviso backup drivers: $_" "WARN" }
}

function Backup-RegistryFull {
    Write-Log "=== Backup completo do registro ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Backup seria feito"; return }
    $backupDir = "$env:TEMP\OtimizadorPC_regbackup"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    reg export "HKLM\SOFTWARE" "$backupDir\hklm_software.reg" /y 2>&1 | Out-Null
    reg export "HKCU\SOFTWARE" "$backupDir\hkcu_software.reg" /y 2>&1 | Out-Null
    Write-Log "  Registro exportado para $backupDir"
}

# ---------------- REPARO ----------------

function Repair-WindowsUpdate {
    Write-Log "=== Reparo do Windows Update ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Reparo seria executado"; return }
    try {
        Stop-Service wuauserv -Force -EA 0
        Stop-Service bits -Force -EA 0
        Stop-Service cryptsvc -Force -EA 0
        Stop-Service msiserver -Force -EA 0
        Rename-Item "$env:WINDIR\SoftwareDistribution" "SoftwareDistribution.old" -EA 0
        Rename-Item "$env:WINDIR\System32\catroot2" "catroot2.old" -EA 0
        Start-Service wuauserv -EA 0
        Start-Service bits -EA 0
        Start-Service cryptsvc -EA 0
        Start-Service msiserver -EA 0
        Write-Log "  Componentes do Windows Update resetados"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Repair-Store {
    Write-Log "=== Reparo da Microsoft Store ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Reparo seria executado"; return }
    try {
        wsreset.exe 2>&1 | Out-Null
        Write-Log "  Cache da Store resetado (wsreset)"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Repair-Network {
    Write-Log "=== Reparo de rede completo ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Reparo seria executado"; return }
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
}

function Clean-StoreCache {
    Write-Log "=== Limpeza de cache da Windows Store ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Cache seria limpo"; return }
    $storeCache = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache"
    if (Test-Path $storeCache) {
        $sz = Get-FolderSize $storeCache
        Remove-Item "$storeCache\*" -Recurse -Force -EA 0
        Write-Log "  Cache da Store limpo ($([math]::Round($sz/1MB,1)) MB)"
    }
}

function Clean-OneDriveCache {
    Write-Log "=== Limpeza de cache do OneDrive ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Cache seria limpo"; return }
    $odCache = "$env:LOCALAPPDATA\Microsoft\OneDrive\logs"
    if (Test-Path $odCache) {
        $sz = Get-FolderSize $odCache
        Remove-Item "$odCache\*" -Recurse -Force -EA 0
        Write-Log "  Logs do OneDrive limpos ($([math]::Round($sz/1MB,1)) MB)"
    }
}

# ---------------- LIMPEZA AVANCADA ----------------

function Clean-Duplicates {
    Write-Log "=== Busca de arquivos duplicados (Downloads) ==="
    $target = "$env:USERPROFILE\Downloads"
    if (-not (Test-Path $target)) { return }
    $files = Get-ChildItem $target -File -EA 0
    $groups = $files | Group-Object Length | Where-Object { $_.Count -gt 1 }
    $dupCount = 0
    foreach ($g in $groups) {
        $hashes = $g.Group | Get-FileHash -EA 0 | Group-Object Hash | Where-Object { $_.Count -gt 1 }
        foreach ($h in $hashes) {
            $dupCount += ($h.Group.Count - 1)
            if ($TechMode) {
                Write-Log "  Duplicado: $($h.Group[0].Path) ($([math]::Round((Get-Item $h.Group[0].Path).Length/1MB,1)) MB)"
            }
        }
    }
    Write-Log "  Arquivos duplicados encontrados: $dupCount"
    if ($dupCount -gt 0) { Write-Log "  Revise manualmente em $target" "WARN" }
}

function Clean-LargeFiles {
    Write-Log "=== Arquivos grandes (>100MB) em Downloads ==="
    $target = "$env:USERPROFILE\Downloads"
    if (-not (Test-Path $target)) { return }
    $large = Get-ChildItem $target -File -EA 0 | Where-Object { $_.Length -gt 100MB } | Sort-Object Length -Descending
    foreach ($f in $large) {
        Write-Log "  $($f.Name) - $([math]::Round($f.Length/1MB,1)) MB"
    }
    Write-Log "  Total de arquivos grandes: $($large.Count)"
}

function Clean-OldFiles {
    Write-Log "=== Arquivos antigos (>1 ano) em Downloads ==="
    $target = "$env:USERPROFILE\Downloads"
    if (-not (Test-Path $target)) { return }
    $old = Get-ChildItem $target -File -EA 0 | Where-Object { $_.LastWriteTime -lt (Get-Date).AddYears(-1) }
    $sz = ($old | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sz) { $sz = 0 }
    Write-Log "  Arquivos antigos: $($old.Count) ($([math]::Round($sz/1MB,1)) MB)"
    if ($old.Count -gt 0 -and (Confirm-Action "Remover arquivos antigos do Downloads?")) {
        if (-not $DryRun) {
            $old | Remove-Item -Force -EA 0
            Write-Log "  Arquivos antigos removidos"
        }
    }
}

function Clean-Temp {
    Write-Log "=== Limpeza de temporarios (>=7 dias) ==="
    foreach ($drive in $Drives.Split(",")) {
        $drive = $drive.Trim().ToUpper()
        $tmpPaths = @("$drive`:\Windows\Temp")
        if ($drive -eq "C") { $tmpPaths += "$env:TEMP" }
        foreach ($t in $tmpPaths) {
            if (Test-Path $t) {
                $before = Get-FolderSize $t
                $oldFiles = Get-ChildItem $t -Recurse -File -EA 0 | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) -and -not (Is-Protected $_.FullName) }
                $szOld = ($oldFiles | Measure-Object -Property Length -Sum).Sum
                if ($null -eq $szOld) { $szOld = 0 }
                if ($DryRun) {
                    Write-Log "  [DRY-RUN] Removeria $($oldFiles.Count) arquivos antigos ($([math]::Round($szOld/1MB,1)) MB) de $t"
                } else {
                    $oldFiles | ForEach-Object { Remove-Item $_.FullName -Force -EA 0 }
                    Get-ChildItem $t -Recurse -Directory -EA 0 | Sort-Object FullName -Descending | ForEach-Object {
                        $dir = $_.FullName
                        if (-not (Is-Protected $dir)) {
                            $items = Get-ChildItem $dir -EA 0
                            if ($null -eq $items -or @($items).Count -eq 0) { Remove-Item $dir -Force -EA 0 }
                        }
                    }
                    $after = Get-FolderSize $t
                    Write-Log "  $t : $([math]::Round($before/1MB,1)) MB -> $([math]::Round($after/1MB,1)) MB (liberado $([math]::Round(($before-$after)/1MB,1)) MB)"
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
    )
    foreach ($c in $caches) {
        if (Is-Protected $c.Path) { Write-Log "  [PROTEGIDO] Pulando: $($c.Path)" "WARN"; continue }
        if (Test-Path $c.Path) {
            $sz = Get-FolderSize $c.Path
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] $($c.Name): $($c.Path) ($([math]::Round($sz/1MB,1)) MB)" }
                else {
                    Remove-Item "$($c.Path)\*" -Recurse -Force -EA 0
                    Write-Log "  $($c.Name) limpo: $($c.Path) ($([math]::Round($sz/1MB,1)) MB)"
                }
            }
        }
    }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
    )
    foreach ($c in $caches) {
        if (Is-Protected $c.Path) { Write-Log "  [PROTEGIDO] Pulando: $($c.Path)" "WARN"; continue }
        if (Test-Path $c.Path) {
            $sz = Get-FolderSize $c.Path
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] $($c.Name): $($c.Path) ($([math]::Round($sz/1MB,1)) MB)" }
                else {
                    Remove-Item "$($c.Path)\*" -Recurse -Force -EA 0
                    Write-Log "  $($c.Name) limpo: $($c.Path) ($([math]::Round($sz/1MB,1)) MB)"
                }
            }
        }
    }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
    )
    foreach ($c in $caches) {
        if (Is-Protected $c.Path) { Write-Log "  [PROTEGIDO] Pulando: $($c.Path)" "WARN"; continue }
        if (Test-Path $c.Path) {
            $sz = Get-FolderSize $c.Path
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] $($c.Name): $($c.Path) ($([math]::Round($sz/1MB,1)) MB)" }
                else {
                    Remove-Item "$($c.Path)\*" -Recurse -Force -EA 0
                    Write-Log "  $($c.Name) limpo: $($c.Path) ($([math]::Round($sz/1MB,1)) MB)"
                }
            }
        }
    }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
    )
    foreach ($c in $caches) {
        if (Is-Protected $c.Path) { Write-Log "  [PROTEGIDO] Pulando: $($c.Path)" "WARN"; continue }
        if (Test-Path $c.Path) {
            $sz = Get-FolderSize $c.Path
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] $($c.Name): $($c.Path) ($([math]::Round($sz/1MB,1)) MB)" }
                else {
                    Remove-Item "$($c.Path)\*" -Recurse -Force -EA 0
                    Write-Log "  $($c.Name) limpo: $($c.Path) ($([math]::Round($sz/1MB,1)) MB)"
                }
            }
        }
    }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
    )
    foreach ($c in $caches) {
        if (Is-Protected $c.Path) { Write-Log "  [PROTEGIDO] Pulando: $($c.Path)" "WARN"; continue }
        if (Test-Path $c.Path) {
            $sz = Get-FolderSize $c.Path
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] $($c.Name): $($c.Path) ($([math]::Round($sz/1MB,1)) MB)" }
                else {
                    Remove-Item "$($c.Path)\*" -Recurse -Force -EA 0
                    Write-Log "  $($c.Name) limpo: $($c.Path) ($([math]::Round($sz/1MB,1)) MB)"
                }
            }
        }
    }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
    )
    foreach ($c in $caches) {
        if (Is-Protected $c.Path) { Write-Log "  [PROTEGIDO] Pulando: $($c.Path)" "WARN"; continue }
        if (Test-Path $c.Path) {
            $sz = Get-FolderSize $c.Path
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] $($c.Name): $($c.Path) ($([math]::Round($sz/1MB,1)) MB)" }
                else {
                    Remove-Item "$($c.Path)\*" -Recurse -Force -EA 0
                    Write-Log "  $($c.Name) limpo: $($c.Path) ($([math]::Round($sz/1MB,1)) MB)"
                }
            }
        }
    }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
}

# ---------------- DIAGNOSTICO ----------------

function Get-HardwareInfo {
    Write-Log "=== Informacoes de hardware ==="
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $os = Get-CimInstance Win32_OperatingSystem
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $board = Get-CimInstance Win32_BaseBoard | Select-Object -First 1
    $bios = Get-CimInstance Win32_BIOS | Select-Object -First 1
    Write-Log "  CPU: $($cpu.Name) ($($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads)"
    Write-Log "  RAM: $([math]::Round($os.TotalVisibleMemorySize/1MB,2)) GB total, $([math]::Round($os.FreePhysicalMemory/1MB,2)) GB livre"
    Write-Log "  GPU: $($gpu.Name)"
    Write-Log "  Placa-mae: $($board.Manufacturer) $($board.Product)"
    Write-Log "  BIOS: $($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)"
    Write-Log "  SO: $($os.Caption) $($os.Version) ($($os.OSArchitecture))"
    $uptime = (Get-Date) - $os.LastBootUpTime
    Write-Log "  Uptime: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
}

function Check-DiskHealth {
    Write-Log "=== Saude do disco (SMART) ==="
    try {
        $disks = Get-PhysicalDisk
        foreach ($d in $disks) {
            $status = $d.HealthStatus
            Write-Log "  $($d.FriendlyName): $status - $($d.MediaType) - $([math]::Round($d.Size/1GB,0)) GB"
            if ($status -ne "Healthy") { Write-Log "  *** DISCO COM PROBLEMA! Faca backup imediatamente. ***" "WARN" }
        }
    } catch { Write-Log "  Nao foi possivel verificar SMART: $_" "WARN" }
}

function Check-Memory {
    Write-Log "=== Verificacao de memoria ==="
    Write-Log "  Para testar a RAM, execute: mdsched.exe (Windows Memory Diagnostic)"
}

function Check-Drivers {
    Write-Log "=== Drivers com problemas ==="
    try {
        $problemDevices = Get-PnpDevice -Status Error -EA 0
        if ($problemDevices) {
            foreach ($d in $problemDevices) { Write-Log "  [PROBLEMA] $($d.FriendlyName) ($($d.Status))" "WARN" }
        } else { Write-Log "  Nenhum dispositivo com erro detectado" }
    } catch { Write-Log "  Nao foi possivel verificar drivers: $_" "WARN" }
}

function Check-WindowsUpdates {
    Write-Log "=== Atualizacoes pendentes ==="
    try {
        $wu = New-Object -ComObject Microsoft.Update.Session
        $searcher = $wu.CreateUpdateSearcher()
        $res = $searcher.Search("IsInstalled=0")
        Write-Log "  Atualizacoes pendentes: $($res.Updates.Count)"
        $res.Updates | Select-Object -First 10 | ForEach-Object { Write-Log "    - $($_.Title)" }
    } catch { Write-Log "  Nao foi possivel verificar updates: $_" "WARN" }
}

function Check-OpenPorts {
    Write-Log "=== Portas abertas (listening) ==="
    try {
        $ports = Get-NetTCPConnection -State Listen -EA 0 | Select-Object LocalPort, OwningProcess -Unique | Sort-Object LocalPort
        $ports | Select-Object -First 20 | ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -EA 0
            Write-Log "  Porta $($_.LocalPort) -> $($proc.Name) (PID $($_.OwningProcess))"
        }
    } catch { Write-Log "  Nao foi possivel verificar portas: $_" "WARN" }
}

function Check-SuspiciousTasks {
    Write-Log "=== Tarefas agendadas suspeitas ==="
    try {
        $tasks = Get-ScheduledTask -EA 0 | Where-Object { $_.State -eq "Ready" -and $_.TaskPath -notlike "\Microsoft\*" }
        $suspicious = $tasks | Where-Object { $_.Actions.Execute -match "powershell|cmd|wscript|cscript|mshta|rundll32|regsvr32" }
        if ($suspicious) {
            foreach ($t in $suspicious) { Write-Log "  [SUSPEITO] $($t.TaskName): $($t.Actions.Execute)" "WARN" }
        } else { Write-Log "  Nenhuma tarefa suspeita encontrada" }
    } catch { Write-Log "  Nao foi possivel verificar tarefas: $_" "WARN" }
}

# ---------------- BACKUP ----------------

function Backup-Drivers {
    Write-Log "=== Backup de drivers ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Backup seria feito"; return }
    $backupDir = "$env:TEMP\OtimizadorPC_drivers"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    try {
        dism /online /export-driver /destination:"$backupDir" 2>&1 | Out-Null
        Write-Log "  Drivers exportados para $backupDir"
    } catch { Write-Log "  Aviso backup drivers: $_" "WARN" }
}

function Backup-RegistryFull {
    Write-Log "=== Backup completo do registro ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Backup seria feito"; return }
    $backupDir = "$env:TEMP\OtimizadorPC_regbackup"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    reg export "HKLM\SOFTWARE" "$backupDir\hklm_software.reg" /y 2>&1 | Out-Null
    reg export "HKCU\SOFTWARE" "$backupDir\hkcu_software.reg" /y 2>&1 | Out-Null
    Write-Log "  Registro exportado para $backupDir"
}

# ---------------- REPARO ----------------

function Repair-WindowsUpdate {
    Write-Log "=== Reparo do Windows Update ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Reparo seria executado"; return }
    try {
        Stop-Service wuauserv -Force -EA 0
        Stop-Service bits -Force -EA 0
        Stop-Service cryptsvc -Force -EA 0
        Stop-Service msiserver -Force -EA 0
        Rename-Item "$env:WINDIR\SoftwareDistribution" "SoftwareDistribution.old" -EA 0
        Rename-Item "$env:WINDIR\System32\catroot2" "catroot2.old" -EA 0
        Start-Service wuauserv -EA 0
        Start-Service bits -EA 0
        Start-Service cryptsvc -EA 0
        Start-Service msiserver -EA 0
        Write-Log "  Componentes do Windows Update resetados"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Repair-Store {
    Write-Log "=== Reparo da Microsoft Store ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Reparo seria executado"; return }
    try {
        wsreset.exe 2>&1 | Out-Null
        Write-Log "  Cache da Store resetado (wsreset)"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Repair-Network {
    Write-Log "=== Reparo de rede completo ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Reparo seria executado"; return }
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
}

function Clean-StoreCache {
    Write-Log "=== Limpeza de cache da Windows Store ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Cache seria limpo"; return }
    $storeCache = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache"
    if (Test-Path $storeCache) {
        $sz = Get-FolderSize $storeCache
        Remove-Item "$storeCache\*" -Recurse -Force -EA 0
        Write-Log "  Cache da Store limpo ($([math]::Round($sz/1MB,1)) MB)"
    }
}

function Clean-OneDriveCache {
    Write-Log "=== Limpeza de cache do OneDrive ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Cache seria limpo"; return }
    $odCache = "$env:LOCALAPPDATA\Microsoft\OneDrive\logs"
    if (Test-Path $odCache) {
        $sz = Get-FolderSize $odCache
        Remove-Item "$odCache\*" -Recurse -Force -EA 0
        Write-Log "  Logs do OneDrive limpos ($([math]::Round($sz/1MB,1)) MB)"
    }
}

function Clean-Duplicates {
    Write-Log "=== Busca de arquivos duplicados (Downloads) ==="
    $target = "$env:USERPROFILE\Downloads"
    if (-not (Test-Path $target)) { return }
    $files = Get-ChildItem $target -File -EA 0
    $groups = $files | Group-Object Length | Where-Object { $_.Count -gt 1 }
    $dupCount = 0
    foreach ($g in $groups) {
        $hashes = $g.Group | Get-FileHash -EA 0 | Group-Object Hash | Where-Object { $_.Count -gt 1 }
        foreach ($h in $hashes) {
            $dupCount += ($h.Group.Count - 1)
            if ($TechMode) {
                Write-Log "  Duplicado: $($h.Group[0].Path) ($([math]::Round((Get-Item $h.Group[0].Path).Length/1MB,1)) MB)"
            }
        }
    }
    Write-Log "  Arquivos duplicados encontrados: $dupCount"
    if ($dupCount -gt 0) { Write-Log "  Revise manualmente em $target" "WARN" }
}

function Clean-LargeFiles {
    Write-Log "=== Arquivos grandes (>100MB) em Downloads ==="
    $target = "$env:USERPROFILE\Downloads"
    if (-not (Test-Path $target)) { return }
    $large = Get-ChildItem $target -File -EA 0 | Where-Object { $_.Length -gt 100MB } | Sort-Object Length -Descending
    foreach ($f in $large) {
        Write-Log "  $($f.Name) - $([math]::Round($f.Length/1MB,1)) MB"
    }
    Write-Log "  Total de arquivos grandes: $($large.Count)"
}

function Clean-OldFiles {
    Write-Log "=== Arquivos antigos (>1 ano) em Downloads ==="
    $target = "$env:USERPROFILE\Downloads"
    if (-not (Test-Path $target)) { return }
    $old = Get-ChildItem $target -File -EA 0 | Where-Object { $_.LastWriteTime -lt (Get-Date).AddYears(-1) }
    $sz = ($old | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sz) { $sz = 0 }
    Write-Log "  Arquivos antigos: $($old.Count) ($([math]::Round($sz/1MB,1)) MB)"
    if ($old.Count -gt 0 -and (Confirm-Action "Remover arquivos antigos do Downloads?")) {
        if (-not $DryRun) {
            $old | Remove-Item -Force -EA 0
            Write-Log "  Arquivos antigos removidos"
        }
    }
}

function Clean-Temp {
    Write-Log "=== Limpeza de temporarios (>=7 dias) ==="
    foreach ($drive in $Drives.Split(",")) {
        $drive = $drive.Trim().ToUpper()
        $tmpPaths = @("$drive`:\Windows\Temp")
        if ($drive -eq "C") { $tmpPaths += "$env:TEMP" }
        foreach ($t in $tmpPaths) {
            if (Test-Path $t) {
                $before = Get-FolderSize $t
                $oldFiles = Get-ChildItem $t -Recurse -File -EA 0 | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) -and -not (Is-Protected $_.FullName) }
                $szOld = ($oldFiles | Measure-Object -Property Length -Sum).Sum
                if ($null -eq $szOld) { $szOld = 0 }
                if ($DryRun) {
                    Write-Log "  [DRY-RUN] Removeria $($oldFiles.Count) arquivos antigos ($([math]::Round($szOld/1MB,1)) MB) de $t"
                } else {
                    $oldFiles | ForEach-Object { Remove-Item $_.FullName -Force -EA 0 }
                    Get-ChildItem $t -Recurse -Directory -EA 0 | Sort-Object FullName -Descending | ForEach-Object {
                        $dir = $_.FullName
                        if (-not (Is-Protected $dir)) {
                            $items = Get-ChildItem $dir -EA 0
                            if ($null -eq $items -or @($items).Count -eq 0) { Remove-Item $dir -Force -EA 0 }
                        }
                    }
                    $after = Get-FolderSize $t
                    Write-Log "  $t : $([math]::Round($before/1MB,1)) MB -> $([math]::Round($after/1MB,1)) MB (liberado $([math]::Round(($before-$after)/1MB,1)) MB)"
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
    )
    foreach ($c in $caches) {
        if (Is-Protected $c.Path) { Write-Log "  [PROTEGIDO] Pulando: $($c.Path)" "WARN"; continue }
        if (Test-Path $c.Path) {
            $sz = Get-FolderSize $c.Path
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] $($c.Name): $($c.Path) ($([math]::Round($sz/1MB,1)) MB)" }
                else {
                    Remove-Item "$($c.Path)\*" -Recurse -Force -EA 0
                    Write-Log "  $($c.Name) limpo: $($c.Path) ($([math]::Round($sz/1MB,1)) MB)"
                }
            }
        }
    }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
    )
    foreach ($c in $caches) {
        if (Is-Protected $c.Path) { Write-Log "  [PROTEGIDO] Pulando: $($c.Path)" "WARN"; continue }
        if (Test-Path $c.Path) {
            $sz = Get-FolderSize $c.Path
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] $($c.Name): $($c.Path) ($([math]::Round($sz/1MB,1)) MB)" }
                else {
                    Remove-Item "$($c.Path)\*" -Recurse -Force -EA 0
                    Write-Log "  $($c.Name) limpo: $($c.Path) ($([math]::Round($sz/1MB,1)) MB)"
                }
            }
        }
    }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
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
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "BingSearchEnabled" -Value 0 -EA 0
    Set-ItemProperty -Path $search -Name "CortanaConsent" -Value 0 -EA 0
    Write-Log "  Cortana / busca web desativadas"
    $explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $explorer) {
        Set-ItemProperty -Path $explorer -Name "ShowSyncProviderNotifications" -Value 0 -EA 0
        Write-Log "  Sugestoes do menu Iniciar desativadas"
    }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
    $notif = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $notif)) { New-Item -Path $notif -Force | Out-Null }
    Set-ItemProperty -Path $notif -Name "ToastEnabled" -Value 0 -EA 0
    Write-Log "  Notificacoes toast desativadas"
    if ($Mode -eq "Aggressive") {
        try { netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null; Write-Log "  TCP autotuning: normal" } catch {}
    }
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
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
        Write-Log "  WinSxS component cleanup concluido"
        if ($Mode -eq "Aggressive") {
            DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
            Write-Log "  WinSxS ResetBase concluido (agressivo)"
        }
    } catch { Write-Log "  Aviso WinSxS: $_" "WARN" }
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
    if ($Mode -eq "Aggressive") {
        try {
            Stop-Process -Name explorer -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
            Start-Process explorer
            Write-Log "  Cache de icones reconstruido"
        } catch { Write-Log "  Aviso icon cache: $_" "WARN" }
    }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache de miniaturas limpo"
    } catch { Write-Log "  Aviso thumbnail cache: $_" "WARN" }
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
    Write-Log "=== Apps em segundo plano + Game Bar/DVR ==="
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
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
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
DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File "$env:TEMP\OtimizadorPC_sfc_log.txt" -Append
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
        @{ Path = "$env:USERPROFILE\go\pkg\mod\cache"; Name = "go" },
        @{ Path = "$env:USERPROFILE\.nuget\packages"; Name = "nuget" }
    )
    foreach ($c in $caches) {
        if (Is-Protected $c.Path) { Write-Log "  [PROTEGIDO] Pulando: $($c.Path)" "WARN"; continue }
        if (Test-Path $c.Path) {
            $sz = Get-FolderSize $c.Path
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] $($c.Name): $($c.Path) ($([math]::Round($sz/1MB,1)) MB)" }
                else {
                    Remove-Item "$($c.Path)\*" -Recurse -Force -EA 0
                    Write-Log "  $($c.Name) limpo: $($c.Path) ($([math]::Round($sz/1MB,1)) MB)"
                }
            }
        }
    }
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
        @{ Path = "$env:APPDATA\Code\CachedData"; Name = "VS Code CachedData" }
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

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","Skype","Spotify","Discord","Teams")
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
    Write-Log "  OneDrive e Google Drive mantidos (sincronizacao)."
}

# ---------------- DIAGNOSTICO ----------------

function Get-HardwareInfo {
    Write-Log "=== Informacoes de hardware ==="
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $os = Get-CimInstance Win32_OperatingSystem
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $board = Get-CimInstance Win32_BaseBoard | Select-Object -First 1
    $bios = Get-CimInstance Win32_BIOS | Select-Object -First 1
    Write-Log "  CPU: $($cpu.Name) ($($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads)"
    Write-Log "  RAM: $([math]::Round($os.TotalVisibleMemorySize/1MB,2)) GB total, $([math]::Round($os.FreePhysicalMemory/1MB,2)) GB livre"
    Write-Log "  GPU: $($gpu.Name)"
    Write-Log "  Placa-mae: $($board.Manufacturer) $($board.Product)"
    Write-Log "  BIOS: $($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)"
    Write-Log "  SO: $($os.Caption) $($os.Version) ($($os.OSArchitecture))"
    $uptime = (Get-Date) - $os.LastBootUpTime
    Write-Log "  Uptime: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
}

function Check-DiskHealth {
    Write-Log "=== Saude do disco (SMART) ==="
    try {
        $disks = Get-PhysicalDisk
        foreach ($d in $disks) {
            $status = $d.HealthStatus
            Write-Log "  $($d.FriendlyName): $status - $($d.MediaType) - $([math]::Round($d.Size/1GB,0)) GB"
            if ($status -ne "Healthy") { Write-Log "  *** DISCO COM PROBLEMA! Faca backup imediatamente. ***" "WARN" }
        }
    } catch { Write-Log "  Nao foi possivel verificar SMART: $_" "WARN" }
}

function Check-Memory {
    Write-Log "=== Verificacao de memoria ==="
    Write-Log "  Para testar a RAM, execute: mdsched.exe (Windows Memory Diagnostic)"
}

function Check-Drivers {
    Write-Log "=== Drivers com problemas ==="
    try {
        $problemDevices = Get-PnpDevice -Status Error -EA 0
        if ($problemDevices) {
            foreach ($d in $problemDevices) { Write-Log "  [PROBLEMA] $($d.FriendlyName) ($($d.Status))" "WARN" }
        } else { Write-Log "  Nenhum dispositivo com erro detectado" }
    } catch { Write-Log "  Nao foi possivel verificar drivers: $_" "WARN" }
}

function Check-WindowsUpdates {
    Write-Log "=== Atualizacoes pendentes ==="
    try {
        $wu = New-Object -ComObject Microsoft.Update.Session
        $searcher = $wu.CreateUpdateSearcher()
        $res = $searcher.Search("IsInstalled=0")
        Write-Log "  Atualizacoes pendentes: $($res.Updates.Count)"
        $res.Updates | Select-Object -First 10 | ForEach-Object { Write-Log "    - $($_.Title)" }
    } catch { Write-Log "  Nao foi possivel verificar updates: $_" "WARN" }
}

function Check-OpenPorts {
    Write-Log "=== Portas abertas (listening) ==="
    try {
        $ports = Get-NetTCPConnection -State Listen -EA 0 | Select-Object LocalPort, OwningProcess -Unique | Sort-Object LocalPort
        $ports | Select-Object -First 20 | ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -EA 0
            Write-Log "  Porta $($_.LocalPort) -> $($proc.Name) (PID $($_.OwningProcess))"
        }
    } catch { Write-Log "  Nao foi possivel verificar portas: $_" "WARN" }
}

function Check-SuspiciousTasks {
    Write-Log "=== Tarefas agendadas suspeitas ==="
    try {
        $tasks = Get-ScheduledTask -EA 0 | Where-Object { $_.State -eq "Ready" -and $_.TaskPath -notlike "\Microsoft\*" }
        $suspicious = $tasks | Where-Object { $_.Actions.Execute -match "powershell|cmd|wscript|cscript|mshta|rundll32|regsvr32" }
        if ($suspicious) {
            foreach ($t in $suspicious) { Write-Log "  [SUSPEITO] $($t.TaskName): $($t.Actions.Execute)" "WARN" }
        } else { Write-Log "  Nenhuma tarefa suspeita encontrada" }
    } catch { Write-Log "  Nao foi possivel verificar tarefas: $_" "WARN" }
}

# ---------------- BACKUP ----------------

function Backup-Drivers {
    Write-Log "=== Backup de drivers ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Backup seria feito"; return }
    $backupDir = "$env:TEMP\OtimizadorPC_drivers"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    try {
        dism /online /export-driver /destination:"$backupDir" 2>&1 | Out-Null
        Write-Log "  Drivers exportados para $backupDir"
    } catch { Write-Log "  Aviso backup drivers: $_" "WARN" }
}

function Backup-RegistryFull {
    Write-Log "=== Backup completo do registro ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Backup seria feito"; return }
    $backupDir = "$env:TEMP\OtimizadorPC_regbackup"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    reg export "HKLM\SOFTWARE" "$backupDir\hklm_software.reg" /y 2>&1 | Out-Null
    reg export "HKCU\SOFTWARE" "$backupDir\hkcu_software.reg" /y 2>&1 | Out-Null
    Write-Log "  Registro exportado para $backupDir"
}

# ---------------- REPARO ----------------

function Repair-WindowsUpdate {
    Write-Log "=== Reparo do Windows Update ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Reparo seria executado"; return }
    try {
        Stop-Service wuauserv -Force -EA 0
        Stop-Service bits -Force -EA 0
        Stop-Service cryptsvc -Force -EA 0
        Stop-Service msiserver -Force -EA 0
        Rename-Item "$env:WINDIR\SoftwareDistribution" "SoftwareDistribution.old" -EA 0
        Rename-Item "$env:WINDIR\System32\catroot2" "catroot2.old" -EA 0
        Start-Service wuauserv -EA 0
        Start-Service bits -EA 0
        Start-Service cryptsvc -EA 0
        Start-Service msiserver -EA 0
        Write-Log "  Componentes do Windows Update resetados"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Repair-Store {
    Write-Log "=== Reparo da Microsoft Store ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Reparo seria executado"; return }
    try {
        wsreset.exe 2>&1 | Out-Null
        Write-Log "  Cache da Store resetado (wsreset)"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Repair-Network {
    Write-Log "=== Reparo de rede completo ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Reparo seria executado"; return }
    ipconfig /release 2>&1 | Out-Null
    ipconfig /renew 2>&1 | Out-Null
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null
    arp -d * 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    Write-Log "  Rede resetada completamente (aplica no reinicio)"
}

function Clean-StoreCache {
    Write-Log "=== Limpeza de cache da Windows Store ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Cache seria limpo"; return }
    $storeCache = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache"
    if (Test-Path $storeCache) {
        $sz = Get-FolderSize $storeCache
        Remove-Item "$storeCache\*" -Recurse -Force -EA 0
        Write-Log "  Cache da Store limpo ($([math]::Round($sz/1MB,1)) MB)"
    }
}

function Clean-OneDriveCache {
    Write-Log "=== Limpeza de cache do OneDrive ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Cache seria limpo"; return }
    $odCache = "$env:LOCALAPPDATA\Microsoft\OneDrive\logs"
    if (Test-Path $odCache) {
        $sz = Get-FolderSize $odCache
        Remove-Item "$odCache\*" -Recurse -Force -EA 0
        Write-Log "  Logs do OneDrive limpos ($([math]::Round($sz/1MB,1)) MB)"
    }
}

# ---------------- LIMPEZA AVANCADA ----------------

function Clean-Duplicates {
    Write-Log "=== Busca de arquivos duplicados (Downloads) ==="
    $target = "$env:USERPROFILE\Downloads"
    if (-not (Test-Path $target)) { return }
    $files = Get-ChildItem $target -File -EA 0
    $groups = $files | Group-Object Length | Where-Object { $_.Count -gt 1 }
    $dupCount = 0
    foreach ($g in $groups) {
        $hashes = $g.Group | Get-FileHash -EA 0 | Group-Object Hash | Where-Object { $_.Count -gt 1 }
        foreach ($h in $hashes) {
            $dupCount += ($h.Group.Count - 1)
            if ($TechMode) {
                Write-Log "  Duplicado: $($h.Group[0].Path) ($([math]::Round((Get-Item $h.Group[0].Path).Length/1MB,1)) MB)"
            }
        }
    }
    Write-Log "  Arquivos duplicados encontrados: $dupCount"
    if ($dupCount -gt 0) { Write-Log "  Revise manualmente em $target" "WARN" }
}

function Clean-LargeFiles {
    Write-Log "=== Arquivos grandes (>100MB) em Downloads ==="
    $target = "$env:USERPROFILE\Downloads"
    if (-not (Test-Path $target)) { return }
    $large = Get-ChildItem $target -File -EA 0 | Where-Object { $_.Length -gt 100MB } | Sort-Object Length -Descending
    foreach ($f in $large) {
        Write-Log "  $($f.Name) - $([math]::Round($f.Length/1MB,1)) MB"
    }
    Write-Log "  Total de arquivos grandes: $($large.Count)"
}

function Clean-OldFiles {
    Write-Log "=== Arquivos antigos (>1 ano) em Downloads ==="
    $target = "$env:USERPROFILE\Downloads"
    if (-not (Test-Path $target)) { return }
    $old = Get-ChildItem $target -File -EA 0 | Where-Object { $_.LastWriteTime -lt (Get-Date).AddYears(-1) }
    $sz = ($old | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sz) { $sz = 0 }
    Write-Log "  Arquivos antigos: $($old.Count) ($([math]::Round($sz/1MB,1)) MB)"
    if ($old.Count -gt 0 -and (Confirm-Action "Remover arquivos antigos do Downloads?")) {
        if (-not $DryRun) {
            $old | Remove-Item -Force -EA 0
            Write-Log "  Arquivos antigos removidos"
        }
    }
}

function Clean-Temp {
    Write-Log "=== Limpeza de temporarios (>=7 dias) ==="
    foreach ($drive in $Drives.Split(",")) {
        $drive = $drive.Trim().ToUpper()
        $tmpPaths = @("$drive`:\Windows\Temp")
        if ($drive -eq "C") { $tmpPaths += "$env:TEMP" }
        foreach ($t in $tmpPaths) {
            if (Test-Path $t) {
                $before = Get-FolderSize $t
                $oldFiles = Get-ChildItem $t -Recurse -File -EA 0 | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) -and -not (Is-Protected $_.FullName) }
                $szOld = ($oldFiles | Measure-Object -Property Length -Sum).Sum
                if ($null -eq $szOld) { $szOld = 0 }
                if ($DryRun) {
                    Write-Log "  [DRY-RUN] Removeria $($oldFiles.Count) arquivos antigos ($([math]::Round($szOld/1MB,1)) MB) de $t"
                } else {
                    $oldFiles | ForEach-Object { Remove-Item $_.FullName -Force -EA 0 }
                    Get-ChildItem $t -Recurse -Directory -EA 0 | Sort-Object FullName -Descending | ForEach-Object {
                        $dir = $_.FullName
                        if (-not (Is-Protected $dir)) {
                            $items = Get-ChildItem $dir -EA 0
                            if ($null -eq $items -or @($items).Count -eq 0) { Remove-Item $dir -Force -EA 0 }
                        }
                    }
                    $after = Get-FolderSize $t
                    Write-Log "  $t : $([math]::Round($before/1MB,1)) MB -> $([math]::Round($after/1MB,1)) MB (liberado $([math]::Round(($before-$after)/1MB,1)) MB)"
                }
            }
        }
    }
}

# ---------------- ANALISE ----------------

function Analyze-DiskSpace {
    Write-Log "=== Analise de espaco em disco ==="
    foreach ($drive in $Drives.Split(",")) {
        $drive = $drive.Trim().ToUpper()
        Write-Log "  Drive $drive`:"
        $root = "$drive`:\"
        if (Test-Path $root) {
            Get-ChildItem $root -Directory -EA 0 | ForEach-Object {
                $sz = Get-FolderSize $_.FullName
                if ($sz -gt 100MB) { Write-Log "    $($_.Name): $([math]::Round($sz/1GB,2)) GB" }
            }
        }
    }
}

function Schedule-Task {
    Write-Log "=== Agendar limpeza semanal ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Tarefa seria criada"; return }
    $taskName = "OtimizadorPC_Weekly"
    $scriptPath = $PSCommandPath
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Auto -SkipLong -Silent"
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
    $hw = Get-CimInstance Win32_Processor | Select-Object -First 1
    $os = Get-CimInstance Win32_OperatingSystem
    $html = @"
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>OtimizadorPC Report</title>
<style>body{font-family:Segoe UI,Arial;margin:20px;background:#f5f5f5}
.card{background:#fff;padding:20px;margin:10px 0;border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,.1)}
h1{color:#2c3e50}h2{color:#3498db}.ok{color:#27ae60}.warn{color:#e67e22}
table{width:100%;border-collapse:collapse}th,td{padding:8px;border-bottom:1px solid #ddd;text-align:left}
th{background:#3498db;color:#fff}</style></head><body>
<h1>OtimizadorPC - Relatorio</h1>
<div class="card"><h2>Sistema</h2>
<table><tr><th>Item</th><th>Valor</th></tr>
<tr><td>CPU</td><td>$($hw.Name)</td></tr>
<tr><td>RAM</td><td>$([math]::Round($os.TotalVisibleMemorySize/1MB,2)) GB</td></tr>
<tr><td>SO</td><td>$($os.Caption) $($os.Version)</td></tr>
<tr><td>Modo</td><td>$Mode</td></tr>
<tr><td>DryRun</td><td>$DryRun</td></tr>
<tr><td>Data</td><td>$(Get-Date)</td></tr></table></div>
<div class="card"><h2>Disco C:</h2>
<p>Total: $totalGB GB | Usado: $usedGB GB | Livre: <span class="ok">$freeGB GB</span></p></div>
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

function Push-ToGitHub {
    Write-Log "=== Auto-push para GitHub ==="
    $git = "C:\Program Files\Git\bin\git.exe"
    if (-not (Test-Path $git)) { Write-Log "  Git nao encontrado, pulando push" "WARN"; return }
    $repoDir = Split-Path -Parent $PSCommandPath
    if (-not (Test-Path (Join-Path $repoDir ".git"))) { Write-Log "  Nao e um repositorio git, pulando push" "WARN"; return }
    try {
        & $git -C $repoDir add -A 2>&1 | Out-Null
        $status = & $git -C $repoDir status --porcelain 2>&1
        if ($status) {
            & $git -C $repoDir -c user.email="leo@example.com" -c user.name="Leo" commit -m "Auto-update: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" 2>&1 | Out-Null
            & $git -C $repoDir push origin main 2>&1 | Out-Null
            Write-Log "  Push para GitHub concluido"
        } else {
            Write-Log "  Nenhuma mudanca para commitar"
        }
    } catch { Write-Log "  Erro no push: $_" "WARN" }
}

function Show-ExternalTools {
    Write-Log "=== Ferramentas externas recomendadas (gratuitas) ==="
    Write-Log "  AdwCleaner: https://www.malwarebytes.com/adwcleaner"
    Write-Log "  Malwarebytes: https://www.malwarebytes.com/"
    Write-Log "  CrystalDiskInfo: https://crystalmark.info/en/software/crystaldiskinfo/"
    Write-Log "  HWiNFO: https://www.hwinfo.com/"
    Write-Log "  BleachBit: https://www.bleachbit.org/"
    Write-Log "  Revo Uninstaller: https://www.revouninstaller.com/"
    Write-Log "  Everything (busca): https://www.voidtools.com/"
    Write-Log "  CCleaner: https://www.ccleaner.com/"
}

function Show-DiskSpace {
    foreach ($drive in $Drives.Split(",")) {
        $drive = $drive.Trim().ToUpper()
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive`:'"
        if ($disk) { Write-Log "Drive $drive`: Livre = $([math]::Round($disk.FreeSpace/1GB,2)) GB de $([math]::Round($disk.Size/1GB,2)) GB" }
    }
}

# ---------------- NOVAS FUNCOES (v3.2) ----------------

function Check-Temperatures {
    Write-Log "=== Temperatura do sistema ==="
    try {
        $temps = Get-CimInstance -Namespace "root\WMI" -ClassName "MSAcpi_ThermalZoneTemperature" -EA 0
        if ($temps) {
            foreach ($t in $temps) {
                $celsius = [math]::Round(($t.CurrentTemperature - 2732) / 10, 1)
                $status = if ($celsius -gt 80) { "QUENTE" } elseif ($celsius -gt 60) { "MORNO" } else { "OK" }
                Write-Log "  $($t.InstanceName): ${celsius}C ($status)"
            }
        } else {
            Write-Log "  Sensores de temperatura nao disponiveis via WMI"
            Write-Log "  Use HWiNFO ou MSI Afterburner para monitoramento detalhado"
        }
    } catch { Write-Log "  Nao foi possivel ler temperaturas: $_" "WARN" }
}

function Clean-ExplorerCache {
    Write-Log "=== Limpeza de cache do Explorer ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Cache seria limpo"; return }
    try {
        Stop-Process -Name explorer -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\*cache*" -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
        Start-Process explorer
        Write-Log "  Cache do Explorer limpo"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Check-DiskIntegrity {
    Write-Log "=== Verificacao de integridade do disco (chkdsk) ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] chkdsk seria agendado"; return }
    try {
        $result = chkdsk C: /scan 2>&1
        $result | ForEach-Object { Write-Log "  $_" }
        Write-Log "  Verificacao de disco concluida"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Kill-HighCPU {
    Write-Log "=== Processos com alto uso de CPU ==="
    $procs = Get-Process -EA 0 | Where-Object { $_.CPU -gt 50 } | Sort-Object CPU -Descending | Select-Object -First 10
    if ($procs) {
        foreach ($p in $procs) {
            Write-Log "  $($p.Name) (PID $($p.Id)): CPU $([math]::Round($p.CPU,1))s, Mem $([math]::Round($p.WorkingSet64/1MB,1)) MB"
        }
        if (Confirm-Action "Encerrar processos com alto CPU?") {
            if (-not $DryRun) {
                $procs | ForEach-Object { Stop-Process -Id $_.Id -Force -EA 0; Write-Log "  Encerrado: $($_.Name)" }
            }
        }
    } else {
        Write-Log "  Nenhum processo com alto uso de CPU"
    }
}

function Show-ToastNotification {
    param([string]$Title, [string]$Message)
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $textNodes = $template.GetElementsByTagName("text")
        $textNodes.Item(0).AppendChild($template.CreateTextNode($Title)) | Out-Null
        $textNodes.Item(1).AppendChild($template.CreateTextNode($Message)) | Out-Null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("OtimizadorPC").Show($toast)
    } catch {
        # Fallback: balloon tip
        try {
            $notify = New-Object System.Windows.Forms.NotifyIcon
            $notify.Icon = [System.Drawing.SystemIcons]::Information
            $notify.BalloonTipTitle = $Title
            $notify.BalloonTipText = $Message
            $notify.Visible = $true
            $notify.ShowBalloonTip(5000)
            Start-Sleep -Seconds 1
            $notify.Dispose()
        } catch {}
    }
}

function Analyze-FileTypeSpace {
    Write-Log "=== Analise de espaco por tipo de arquivo (Downloads) ==="
    $target = "$env:USERPROFILE\Downloads"
    if (-not (Test-Path $target)) { return }
    $files = Get-ChildItem $target -File -Recurse -EA 0
    $groups = $files | Group-Object Extension | Sort-Object { ($_.Group | Measure-Object -Property Length -Sum).Sum } -Descending | Select-Object -First 15
    foreach ($g in $groups) {
        $sz = ($g.Group | Measure-Object -Property Length -Sum).Sum
        Write-Log "  $($g.Name): $($g.Count) arquivos ($([math]::Round($sz/1MB,1)) MB)"
    }
}

function Quick-Maintenance {
    Write-Log "=== Manutencao rapida ==="
    Clean-Temp
    Clean-BrowserCaches
    Clear-EventLogs
    Flush-DNS
    Optimize-Disk
    Write-Log "=== Manutencao rapida concluida ==="
    Show-ToastNotification "OtimizadorPC" "Manutencao rapida concluida!"
}

function Full-Maintenance {
    Write-Log "=== Manutencao completa ==="
    New-RestorePoint
    Backup-Registry
    Get-HardwareInfo
    Check-DiskHealth
    Clean-Temp
    Clean-BrowserCaches
    Clean-PackageCaches
    Clean-AppCaches
    Optimize-Startup
    System-Tweaks
    Set-Pagefile
    Optimize-Disk
    Clear-EventLogs
    Disable-BackgroundApps
    Flush-DNS
    Enable-StorageSense
    Run-CleanMgr
    Clean-StoreCache
    Clean-OneDriveCache
    if (-not $SkipLong) { Run-SFC-DISM; Run-DefenderScan }
    Analyze-DiskSpace
    Show-DiskSpace
    Write-Log "=== Manutencao completa concluida ==="
    Show-ToastNotification "OtimizadorPC" "Manutencao completa concluida!"
}

# ---------------- NOVAS FUNCOES v3.3 ----------------

function Clean-SteamCache {
    Write-Log "=== Limpeza de cache do Steam ==="
    $steamPaths = @(
        "$env:PROGRAMFILES(X86)\Steam\appcache",
        "$env:PROGRAMFILES(X86)\Steam\depotcache",
        "$env:PROGRAMFILES(X86)\Steam\logs",
        "$env:LOCALAPPDATA\Steam\htmlcache"
    )
    foreach ($p in $steamPaths) {
        if (Test-Path $p) {
            $sz = Get-FolderSize $p
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] Steam: $p ($([math]::Round($sz/1MB,1)) MB)" }
                else {
                    Remove-Item "$p\*" -Recurse -Force -EA 0
                    Write-Log "  Steam limpo: $p ($([math]::Round($sz/1MB,1)) MB)"
                }
            }
        }
    }
    Write-Log "  Nota: jogos do Steam NAO foram removidos"
}

function Clean-DockerCache {
    Write-Log "=== Limpeza de cache do Docker/WSL ==="
    $dockerPaths = @(
        "$env:LOCALAPPDATA\Docker\log",
        "$env:PROGRAMDATA\Docker\log"
    )
    foreach ($p in $dockerPaths) {
        if (Test-Path $p) {
            $sz = Get-FolderSize $p
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] Docker: $p ($([math]::Round($sz/1MB,1)) MB)" }
                else {
                    Remove-Item "$p\*" -Recurse -Force -EA 0
                    Write-Log "  Docker limpo: $p ($([math]::Round($sz/1MB,1)) MB)"
                }
            }
        }
    }
    $wslPaths = @("$env:LOCALAPPDATA\Packages\CanonicalGroupLimited.Ubuntu*\LocalState\ext4.vhdx")
    $wslResolved = Resolve-Path $wslPaths -EA 0
    if ($wslResolved) {
        Write-Log "  WSL detectado. Para compactar: wsl --shutdown && optimize-vhd"
    } else {
        Write-Log "  WSL nao detectado"
    }
    Write-Log "  Nota: imagens/containers do Docker NAO foram removidos"
}

function Clean-GPUCache {
    Write-Log "=== Limpeza de cache da GPU ==="
    $gpuCaches = @(
        @{ Name="NVIDIA Shader Cache"; Path="$env:LOCALAPPDATA\NVIDIA\DXCache" },
        @{ Name="NVIDIA GLCache"; Path="$env:LOCALAPPDATA\NVIDIA\GLCache" },
        @{ Name="AMD Shader Cache"; Path="$env:LOCALAPPDATA\AMD\DxCache" },
        @{ Name="Intel Shader Cache"; Path="$env:LOCALAPPDATA\Intel\ShaderCache" },
        @{ Name="DirectX Shader Cache"; Path="$env:LOCALAPPDATA\D3DSCache" }
    )
    foreach ($g in $gpuCaches) {
        if (Test-Path $g.Path) {
            $sz = Get-FolderSize $g.Path
            if ($sz -gt 0) {
                if ($DryRun) { Write-Log "  [DRY-RUN] $($g.Name): $([math]::Round($sz/1MB,1)) MB" }
                else {
                    Remove-Item "$($g.Path)\*" -Recurse -Force -EA 0
                    Write-Log "  $($g.Name) limpo: $([math]::Round($sz/1MB,1)) MB"
                }
            }
        }
    }
}

function Clean-PrinterSpooler {
    Write-Log "=== Limpeza do spooler de impressao ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Spooler seria limpo"; return }
    try {
        Stop-Service spooler -Force -EA 0
        Remove-Item "$env:WINDIR\System32\spool\PRINTERS\*" -Recurse -Force -EA 0
        Start-Service spooler -EA 0
        Write-Log "  Spooler de impressao limpo"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Clean-RecycleBin {
    Write-Log "=== Esvaziar lixeira ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Lixeira seria esvaziada"; return }
    try {
        Clear-RecycleBin -Force -EA 0
        Write-Log "  Lixeira esvaziada"
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Clean-WindowsOld {
    Write-Log "=== Remover Windows.old (instalacao anterior) ==="
    $oldPath = "C:\Windows.old"
    if (Test-Path $oldPath) {
        $sz = Get-FolderSize $oldPath
        Write-Log "  Windows.old encontrado: $([math]::Round($sz/1GB,2)) GB"
        if (Confirm-Action "Remover Windows.old? (libera ~$([math]::Round($sz/1GB,2)) GB)") {
            if (-not $DryRun) {
                try {
                    takeown /F $oldPath /A /R /D Y 2>&1 | Out-Null
                    icacls $oldPath /grant Administradores:F /T 2>&1 | Out-Null
                    Remove-Item $oldPath -Recurse -Force -EA 0
                    Write-Log "  Windows.old removido"
                } catch { Write-Log "  Aviso: $_" "WARN" }
            }
        }
    } else {
        Write-Log "  Windows.old nao encontrado"
    }
}

function Optimize-Windows11 {
    Write-Log "=== Otimizacoes especificas do Windows 11 ==="
    $os = Get-CimInstance Win32_OperatingSystem
    if ($os.Version -lt "10.0.22000") {
        Write-Log "  Nao e Windows 11, pulando"
        return
    }
    if ($DryRun) { Write-Log "  [DRY-RUN] Otimizacoes seriam aplicadas"; return }
    $widgets = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $widgets) {
        Set-ItemProperty -Path $widgets -Name "TaskbarDa" -Value 0 -EA 0
        Write-Log "  Widgets desativados"
        Set-ItemProperty -Path $widgets -Name "TaskbarMn" -Value 0 -EA 0
        Write-Log "  Chat/Teams desativado"
    }
    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
    if (-not (Test-Path $search)) { New-Item -Path $search -Force | Out-Null }
    Set-ItemProperty -Path $search -Name "IsDynamicSearchBoxEnabled" -Value 0 -EA 0
    Write-Log "  Search highlights desativados"
    Write-Log "  Otimizacoes do Windows 11 aplicadas"
}

function Block-Telemetry {
    Write-Log "=== Bloqueio de telemetria (hosts) ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Telemetria seria bloqueada"; return }
    $hostsPath = "$env:WINDIR\System32\drivers\etc\hosts"
    $telemetryDomains = @(
        "telemetry.microsoft.com","vortex.data.microsoft.com","vortex-win.data.microsoft.com",
        "settings-win.data.microsoft.com","watson.telemetry.microsoft.com","watson.ppe.telemetry.microsoft.com",
        "oca.telemetry.microsoft.com","sqm.telemetry.microsoft.com","telecommand.telemetry.microsoft.com",
        "watson.live.com","watson.microsoft.com","statsfe2.ws.microsoft.com","corpext.msitadfs.glbdns2.microsoft.com",
        "compatexchange.cloudapp.net","cs1.wpc.v0cdn.net","a-0001.a-msedge.net","statsfe2.update.microsoft.com.akadns.net",
        "sls.update.microsoft.com.akadns.net","fe2.update.microsoft.com.akadns.net","diagnostics.support.microsoft.com",
        "corp.sts.microsoft.com","statsfe1.ws.microsoft.com","pre.footprintpredict.com","i1.services.social.microsoft.com",
        "i1.services.social.microsoft.com.nsatc.net","feedback.windows.com","feedback.microsoft-hohm.com",
        "feedback.search.microsoft.com","rad.msn.com","ads.msn.com","ads1.msn.com","a.ads1.msn.com",
        "a.ads2.msn.com","adnexus.net","adnxs.com","m.adnxs.com","mobile.adnxs.com"
    )
    $existing = Get-Content $hostsPath -EA 0
    $added = 0
    foreach ($domain in $telemetryDomains) {
        if ($existing -notmatch [regex]::Escape($domain)) {
            Add-Content -Path $hostsPath -Value "0.0.0.0 $domain" -EA 0
            $added++
        }
    }
    Write-Log "  $added dominios de telemetria bloqueados no hosts"
    $telServices = @("DiagTrack","dmwappushservice")
    foreach ($s in $telServices) {
        $svc = Get-Service $s -EA 0
        if ($svc) {
            try { Stop-Service $s -Force -EA 0; Set-Service $s -StartupType Disabled -EA 0 } catch {}
        }
    }
    Write-Log "  Servicos de telemetria desativados"
}

function Optimize-WindowsSearch {
    Write-Log "=== Otimizacao do Windows Search ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Otimizacao seria aplicada"; return }
    try {
        $search = Get-Service WSearch -EA 0
        if ($search) {
            Write-Log "  Windows Search otimizado (indexacao reduzida)"
        }
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Clean-WindowsUpdateCache {
    Write-Log "=== Limpeza de cache do Windows Update ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Cache seria limpo"; return }
    try {
        Stop-Service wuauserv -Force -EA 0
        Stop-Service bits -Force -EA 0
        $wuPath = "$env:WINDIR\SoftwareDistribution\Download"
        if (Test-Path $wuPath) {
            $sz = Get-FolderSize $wuPath
            Remove-Item "$wuPath\*" -Recurse -Force -EA 0
            Write-Log "  Cache do Windows Update limpo ($([math]::Round($sz/1MB,1)) MB)"
        }
        Start-Service wuauserv -EA 0
        Start-Service bits -EA 0
    } catch { Write-Log "  Aviso: $_" "WARN" }
}

function Optimize-Privacy {
    Write-Log "=== Otimizacoes de privacidade ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Privacidade seria otimizada"; return }
    $privacy = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
    if (-not (Test-Path $privacy)) { New-Item -Path $privacy -Force | Out-Null }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -EA 0
    $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    if (Test-Path $cdm) {
        Set-ItemProperty -Path $cdm -Name "SubscribedContent-338388Enabled" -Value 0 -EA 0
        Set-ItemProperty -Path $cdm -Name "SubscribedContent-338389Enabled" -Value 0 -EA 0
        Set-ItemProperty -Path $cdm -Name "SubscribedContent-353698Enabled" -Value 0 -EA 0
    }
    $activity = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (-not (Test-Path $activity)) { New-Item -Path $activity -Force | Out-Null }
    Set-ItemProperty -Path $activity -Name "PublishUserActivities" -Value 0 -EA 0
    Set-ItemProperty -Path $activity -Name "EnableActivityFeed" -Value 0 -EA 0
    Write-Log "  Privacidade otimizada (advertising ID, activity history, tailored experiences)"
}

function Analyze-DiskByType {
    Write-Log "=== Analise de espaco por tipo de arquivo ==="
    $target = "C:\Users"
    if (-not (Test-Path $target)) { return }
    $files = Get-ChildItem $target -File -Recurse -EA 0 | Where-Object { $_.Length -gt 1MB }
    $groups = $files | Group-Object Extension | Sort-Object { ($_.Group | Measure-Object -Property Length -Sum).Sum } -Descending | Select-Object -First 20
    foreach ($g in $groups) {
        $sz = ($g.Group | Measure-Object -Property Length -Sum).Sum
        Write-Log "  $($g.Name): $($g.Count) arquivos ($([math]::Round($sz/1MB,1)) MB)"
    }
}

function Backup-Bookmarks {
    Write-Log "=== Backup de favoritos do navegador ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Backup seria feito"; return }
    $backupDir = "$env:TEMP\OtimizadorPC_bookmarks"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $chromeBookmarks = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Bookmarks"
    if (Test-Path $chromeBookmarks) {
        Copy-Item $chromeBookmarks "$backupDir\chrome_bookmarks.json" -EA 0
        Write-Log "  Favoritos do Chrome copiados"
    }
    $edgeBookmarks = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks"
    if (Test-Path $edgeBookmarks) {
        Copy-Item $edgeBookmarks "$backupDir\edge_bookmarks.json" -EA 0
        Write-Log "  Favoritos do Edge copiados"
    }
    Write-Log "  Backup salvo em $backupDir"
}

function Optimize-Services {
    Write-Log "=== Otimizacao de servicos (Safe) ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Servicos seriam otimizados"; return }
    $safeDisable = @("Fax","XblAuthManager","XblGameSave","RetailDemo","SharedAccess","icssvc","RemoteRegistry","WMPNetworkSvc")
    foreach ($s in $safeDisable) {
        $svc = Get-Service $s -EA 0
        if ($svc -and $svc.StartType -ne "Disabled") {
            try { Stop-Service $s -Force -EA 0; Set-Service $s -StartupType Disabled -EA 0; Write-Log "  $s desativado" } catch {}
        }
    }
    $safeManual = @("MapsBroker","lfsvc","DoSvc")
    foreach ($s in $safeManual) {
        $svc = Get-Service $s -EA 0
        if ($svc -and $svc.StartType -eq "Automatic") {
            try { Set-Service $s -StartupType Manual -EA 0; Write-Log "  $s -> Manual" } catch {}
        }
    }
    Write-Log "  Servicos otimizados"
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
    Write-Host " 2. Limpeza de caches de navegadores (Chrome/Edge/Firefox/Brave/Opera/Vivaldi)"
    Write-Host " 3. Limpeza de caches de pacotes (npm/pnpm/pip/gradle/maven/cargo/go/nuget)"
    Write-Host " 4. Limpeza de caches de aplicativos (Spotify, Discord, Teams, VS Code, etc.)"
    Write-Host " 5. Otimizar inicializacao (remover programas do boot)"
    Write-Host " 6. Ajustes de sistema (energia, telemetria, SysMain, visual, pagefile, TCP, Cortana, notif)"
    Write-Host " 7. Otimizar disco (TRIM/defrag + WinSxS + prefetch + icon cache + thumbnails + font cache)"
    Write-Host " 8. Limpar logs de eventos"
    Write-Host " 9. Desativar apps em segundo plano + Game Bar/DVR"
    Write-Host "10. Limpeza de Disco (cleanmgr)"
    Write-Host "11. Flush DNS + reset Winsock + reset rede"
    Write-Host "12. Ativar Storage Sense (limpeza automatica)"
    Write-Host "13. Verificacao de integridade (SFC + DISM) - demorado"
    Write-Host "14. Varredura completa do Defender"
    Write-Host "15. Desinstalar bloatware UWP (lista segura)"
    Write-Host "16. Limpeza avancada (duplicados, arquivos grandes, arquivos antigos)"
    Write-Host "17. Diagnostico de hardware/software (CPU, RAM, disco, drivers, updates, portas, tarefas)"
    Write-Host "18. Backup (drivers, registro)"
    Write-Host "19. Reparos (Windows Update, Store, rede)"
    Write-Host "20. Limpeza de caches de sistema (Store, OneDrive)"
    Write-Host "21. Agendar limpeza semanal (Task Scheduler)"
    Write-Host "22. Gerar relatorio HTML"
    Write-Host "23. Ferramentas externas recomendadas (links)"
    Write-Host "24. Analise de espaco em disco (top pastas)"
    Write-Host "25. Executar TUDO (recomendado)"
    Write-Host "26. Self-update (verificar nova versao no GitHub)"
    Write-Host "27. Auto-push para GitHub"
    Write-Host "28. Verificar temperaturas (CPU/GPU)"
    Write-Host "29. Limpar cache do Explorer"
    Write-Host "30. Verificar integridade do disco (chkdsk)"
    Write-Host "31. Encerrar processos com alto CPU"
    Write-Host "32. Analise de espaco por tipo de arquivo"
    Write-Host "33. Manutencao rapida (limpeza rapida)"
    Write-Host "34. Manutencao completa (tudo)"
    Write-Host "35. Otimizacoes de privacidade (telemetria, advertising ID, activity history)"
    Write-Host "36. Bloquear telemetria (hosts file)"
    Write-Host "37. Otimizar Windows Search"
    Write-Host "38. Otimizacoes especificas do Windows 11"
    Write-Host "39. Limpar cache do Steam (sem remover jogos)"
    Write-Host "40. Limpar cache do Docker/WSL"
    Write-Host "41. Limpar cache da GPU (shaders)"
    Write-Host "42. Limpar spooler de impressao"
    Write-Host "43. Esvaziar lixeira"
    Write-Host "44. Remover Windows.old (instalacao anterior)"
    Write-Host "45. Limpar cache do Windows Update"
    Write-Host "46. Backup de favoritos do navegador"
    Write-Host "47. Otimizar servicos (Safe)"
    Write-Host "48. Executar TUDO + extras (completo)"
    Write-Host "23. Ferramentas externas recomendadas (links)"
    Write-Host " 0. Sair"
    Write-Host ""
    Write-Host "  NOTA: Nao remove arquivos de projetos/codigo-fonte. Projetos preservados." -ForegroundColor Yellow
    Write-Host ""
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
    Get-HardwareInfo
    Check-DiskHealth
    Check-Drivers
    Check-WindowsUpdates
    Clean-Temp
    Clean-BrowserCaches
    Clean-PackageCaches
    Clean-AppCaches
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
    Clean-StoreCache
    Clean-OneDriveCache
    Clean-Duplicates
    Clean-LargeFiles
    Clean-ExplorerCache
    if (-not $SkipLong) { Run-SFC-DISM; Run-DefenderScan }
    Check-OpenPorts
    Check-SuspiciousTasks
    Analyze-DiskSpace
    Show-DiskSpace
    if ($Report) { Generate-Report }
    if ($AutoPush) { Push-ToGitHub }
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
        "4"  { Clean-AppCaches }
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
        "15" { Disable-Bloatware }
        "16" { Clean-Duplicates; Clean-LargeFiles; Clean-OldFiles }
        "17" { Get-HardwareInfo; Check-DiskHealth; Check-Memory; Check-Drivers; Check-WindowsUpdates; Check-OpenPorts; Check-SuspiciousTasks }
        "18" { Backup-Drivers; Backup-Registry; Backup-RegistryFull }
        "19" { Repair-WindowsUpdate; Repair-Store; Repair-Network }
        "20" { Clean-StoreCache; Clean-OneDriveCache }
        "21" { Schedule-Task }
        "22" { Generate-Report }
        "23" { Show-ExternalTools }
        "24" { Analyze-DiskSpace }
        "25" {
            New-RestorePoint
            Backup-Registry
            Get-HardwareInfo
            Check-DiskHealth
            Clean-Temp
            Clean-BrowserCaches
            Clean-PackageCaches
            Clean-AppCaches
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
            Clean-StoreCache
            Clean-OneDriveCache
            Clean-Duplicates
            Clean-LargeFiles
            if (-not $SkipLong) { Run-SFC-DISM; Run-DefenderScan }
            Check-OpenPorts
            Check-SuspiciousTasks
            Analyze-DiskSpace
            Show-DiskSpace
            if ($Report) { Generate-Report }
            if ($AutoPush) { Push-ToGitHub }
            Write-Log "=== CONCLUIDO ==="
        }
        "26" { Invoke-SelfUpdate }
        "27" { Push-ToGitHub }
        "28" { Check-Temperatures }
        "29" { Clean-ExplorerCache }
        "30" { Check-DiskIntegrity }
        "31" { Kill-HighCPU }
        "32" { Analyze-FileTypeSpace }
        "33" { Quick-Maintenance }
        "34" { Full-Maintenance }
        "35" { Optimize-Privacy }
        "36" { Block-Telemetry }
        "37" { Optimize-WindowsSearch }
        "38" { Optimize-Windows11 }
        "39" { Clean-SteamCache }
        "40" { Clean-DockerCache }
        "41" { Clean-GPUCache }
        "42" { Clean-PrinterSpooler }
        "43" { Clean-RecycleBin }
        "44" { Clean-WindowsOld }
        "45" { Clean-WindowsUpdateCache }
        "46" { Backup-Bookmarks }
        "47" { Optimize-Services }
        "48" {
            New-RestorePoint
            Backup-Registry
            Get-HardwareInfo
            Check-DiskHealth
            Clean-Temp
            Clean-BrowserCaches
            Clean-PackageCaches
            Clean-AppCaches
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
            Clean-StoreCache
            Clean-OneDriveCache
            Clean-ExplorerCache
            Optimize-Privacy
            Block-Telemetry
            Optimize-WindowsSearch
            Optimize-Windows11
            Clean-SteamCache
            Clean-DockerCache
            Clean-GPUCache
            Clean-PrinterSpooler
            Clean-RecycleBin
            Clean-WindowsUpdateCache
            Backup-Bookmarks
            Optimize-Services
            if (-not $SkipLong) { Run-SFC-DISM; Run-DefenderScan }
            Check-OpenPorts
            Check-SuspiciousTasks
            Analyze-DiskSpace
            Show-DiskSpace
            if ($Report) { Generate-Report }
            if ($AutoPush) { Push-ToGitHub }
            Write-Log "=== CONCLUIDO ==="
        }
        "23" { Show-ExternalTools }
        "0"  { Write-Host "Saindo."; break }
        default { Write-Host "Opcao invalida." }
    }
    if ($choice -eq "0") { break }
    Read-Host "Pressione Enter para continuar"
}
