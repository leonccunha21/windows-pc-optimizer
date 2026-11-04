# Otimizador de PC - Script PowerShell
# Versao 1.0
# Execute como Administrador: clique direito > "Executar com PowerShell" ou use o launcher .bat
# NAO remove arquivos do Epic Games / Fortnite (protegidos).

param(
    [switch]$Auto,        # Executa todas as otimizacoes recomendadas sem perguntar
    [string]$ProjectsPath = "",  # Pasta a escanear em busca de lixo de projetos (node_modules, build, etc.)
    [switch]$DryRun,      # Apenas mostra o que seria feito, sem executar
    [switch]$SkipLong     # Pula SFC/DISM e Defender full scan (demorados)
)

$ErrorActionPreference = "Continue"
$LogFile = "$env:TEMP\OtimizadorPC_log.txt"
$Protected = @("Epic Games","Fortnite","EpicGames","FortniteGame")

function Write-Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Is-Protected($path) {
    foreach ($p in $Protected) {
        if ($path -like "*$p*") { return $true }
    }
    return $false
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
    if (Is-Protected $path) {
        Write-Log "  [PROTEGIDO] Pulando: $path"
        return 0
    }
    if (-not (Test-Path $path)) { return 0 }
    $sz = Get-FolderSize $path
    if ($DryRun) {
        Write-Log "  [DRY-RUN] Removeria: $path ($([math]::Round($sz/1MB,1)) MB)"
        return $sz
    }
    Remove-Item $path -Recurse -Force -EA 0
    Write-Log "  Removido: $path ($([math]::Round($sz/1MB,1)) MB)"
    return $sz
}

# ---------------- MENU ----------------
function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   OTIMIZADOR DE PC - Menu Principal" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " 1. Limpeza de temporarios (>=7 dias)"
    Write-Host " 2. Limpeza de caches de navegadores (Chrome/Edge)"
    Write-Host " 3. Limpeza de caches de pacotes (npm/pnpm/pip)"
    Write-Host " 4. Limpeza de lixo de projetos (node_modules, build, dist, .next, .gradle, .venv, __pycache__)"
    Write-Host " 5. Otimizar inicializacao (remover programas do boot)"
    Write-Host " 6. Ajustes de sistema (energia, telemetria, SysMain, visual, pagefile)"
    Write-Host " 7. Otimizar SSD (TRIM)"
    Write-Host " 8. Limpar logs de eventos"
    Write-Host " 9. Desativar apps em segundo plano"
    Write-Host "10. Limpeza de Disco (cleanmgr)"
    Write-Host "11. Flush DNS + reset Winsock"
    Write-Host "12. Ativar Storage Sense (limpeza automatica)"
    Write-Host "13. Verificacao de integridade (SFC + DISM) - demorado"
    Write-Host "14. Varredura completa do Defender"
    Write-Host "15. Executar TUDO (recomendado)"
    Write-Host " 0. Sair"
    Write-Host ""
}

# ---------------- FUNCOES ----------------

function Backup-Registry {
    $backupDir = "$env:TEMP\OtimizadorPC_backup"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" "$backupDir\run_hkcu.reg" /y 2>&1 | Out-Null
    reg export "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" "$backupDir\run_hklm.reg" /y 2>&1 | Out-Null
    Write-Log "Backup de registro salvo em $backupDir"
}

function Clean-Temp {
    Write-Log "=== Limpeza de temporarios (>=7 dias) ==="
    $tmpPaths = @($env:TEMP, "$env:WINDIR\Temp")
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
                        if ($null -eq $items -or $items.Count -eq 0) { Remove-Item $dir -Force -EA 0 }
                    }
                }
                $after = Get-FolderSize $t
                Write-Log "  $t : $([math]::Round($before/1MB,1)) MB -> $([math]::Round($after/1MB,1)) MB (liberado $([math]::Round(($before-$after)/1MB,1)) MB)"
            }
        }
    }
}

function Clean-BrowserCaches {
    Write-Log "=== Limpeza caches navegadores ==="
    $cacheFolders = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache"
    )
    foreach ($c in $cacheFolders) {
        if (Test-Path $c) {
            $sz = Get-FolderSize $c
            if ($DryRun) { Write-Log "  [DRY-RUN] $c ($([math]::Round($sz/1MB,1)) MB)" }
            else {
                Remove-Item "$c\*" -Recurse -Force -EA 0
                Write-Log "  Limpo $c ($([math]::Round($sz/1MB,1)) MB)"
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
        @{ Path = "$env:LOCALAPPDATA\Cypress"; Name = "cypress" }
    )
    foreach ($c in $caches) {
        Remove-Safe $c.Path $c.Name | Out-Null
    }
}

function Clean-ProjectJunk {
    param([string]$RootPath)
    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $RootPath = Read-Host "Caminho da pasta de projetos (ex: C:\Users\Leo\Documents)"
    }
    if (-not (Test-Path $RootPath)) {
        Write-Log "Caminho nao existe: $RootPath"
        return
    }
    Write-Log "=== Limpeza de lixo de projetos em $RootPath ==="
    $lixoNames = @("node_modules","build","dist",".next","target","__pycache__",".gradle",".cache","out",".turbo",".nuxt",".output","coverage",".parcel-cache",".vite",".svelte-kit")
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
    # Remove .venv folders entirely
    Get-ChildItem $RootPath -Recurse -Directory -Filter ".venv" -EA 0 | Where-Object { -not (Is-Protected $_.FullName) } | ForEach-Object {
        $sz = Remove-Safe $_.FullName ".venv"
        $freed += $sz; $removed++
    }
    Write-Log "  Total: $removed pastas, $([math]::Round($freed/1MB,1)) MB"
}

function Optimize-Startup {
    Write-Log "=== Otimizacao de inicializacao ==="
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $removeNames = @("EpicGamesLauncher","Steam","IDMan","EpicGamesLauncher")
    foreach ($n in $removeNames) {
        if (Get-ItemProperty $runKey -Name $n -EA 0) {
            if ($DryRun) { Write-Log "  [DRY-RUN] Removeria do startup: $n" }
            else {
                Remove-ItemProperty $runKey -Name $n -Force -EA 0
                Write-Log "  Removido do startup: $n"
            }
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
    if (-not $DryRun) {
        # Power plan High Performance
        try { powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null; Write-Log "  Energia: Alto Desempenho" } catch {}
        # Disable DiagTrack
        try { Stop-Service DiagTrack -Force -EA 0; Set-Service DiagTrack -StartupType Disabled -EA 0; Write-Log "  DiagTrack desativado" } catch {}
        # Disable SysMain
        try { Stop-Service SysMain -Force -EA 0; Set-Service SysMain -StartupType Disabled -EA 0; Write-Log "  SysMain desativado (SSD)" } catch {}
        # DoSvc -> Disabled (via registry)
        try { Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DoSvc" -Name Start -Value 4 -EA 0; Write-Log "  DoSvc desativado" } catch {}
        # Visual effects
        try { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name VisualFXSetting -Value 2 -EA 0; Write-Log "  Efeitos visuais: melhor desempenho" } catch {}
        # Transparency off
        try { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name EnableTransparency -Value 0 -EA 0; Write-Log "  Transparencia desativada" } catch {}
        # Disable tips
        $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        if (Test-Path $cdm) {
            Set-ItemProperty -Path $cdm -Name "SubscribedContent-338389Enabled" -Value 0 -EA 0
            Set-ItemProperty -Path $cdm -Name "SoftLandingEnabled" -Value 0 -EA 0
            Write-Log "  Dicas desativadas"
        }
        # Disable background apps
        $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
        if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
        Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
        Write-Log "  Apps em background desativados"
    } else {
        Write-Log "  [DRY-RUN] Ajustes de sistema seriam aplicados"
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
        # Fallback via registry
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "C:\pagefile.sys 8192 8192" /f 2>&1 | Out-Null
        Write-Log "  Pagefile configurado via registro (requer reinicio)"
    }
}

function Optimize-SSD {
    Write-Log "=== TRIM no volume C: ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] TRIM seria executado"; return }
    try {
        Optimize-Volume -DriveLetter C -ReTrim -Verbose 2>&1 | Out-Null
        Write-Log "  TRIM concluido"
    } catch { Write-Log "  Aviso TRIM: $_" }
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
    Write-Log "=== Apps em segundo plano ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Seriam desativados"; return }
    $ba = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (-not (Test-Path $ba)) { New-Item -Path $ba -Force | Out-Null }
    Set-ItemProperty -Path $ba -Name "GlobalUserDisabled" -Value 1 -EA 0
    Write-Log "  Apps em background desativados"
}

function Flush-DNS {
    Write-Log "=== Rede (DNS/Winsock) ==="
    if ($DryRun) { Write-Log "  [DRY-RUN] Flush DNS + Winsock reset"; return }
    ipconfig /flushdns 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    Write-Log "  Cache DNS limpo; Winsock reset agendado (aplica no reinicio)"
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
    } catch { Write-Log "  Aviso cleanmgr: $_" }
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
    } catch { Write-Log "  Aviso: $_" }
}

function Show-DiskSpace {
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    Write-Log "C: Livre = $([math]::Round($disk.FreeSpace/1GB,2)) GB de $([math]::Round($disk.Size/1GB,2)) GB"
}

# ---------------- MAIN ----------------
Write-Host "Log: $LogFile" -ForegroundColor DarkGray
"=== Inicio $(Get-Date) ===" | Out-File $LogFile -Encoding UTF8

if ($Auto) {
    Write-Log "Modo AUTO: executando todas as otimizacoes recomendadas"
    Backup-Registry
    Clean-Temp
    Clean-BrowserCaches
    Clean-PackageCaches
    if ($ProjectsPath) { Clean-ProjectJunk -RootPath $ProjectsPath }
    Optimize-Startup
    System-Tweaks
    Set-Pagefile
    Optimize-SSD
    Clear-EventLogs
    Disable-BackgroundApps
    Flush-DNS
    Enable-StorageSense
    Run-CleanMgr
    if (-not $SkipLong) { Run-SFC-DISM; Run-DefenderScan }
    Show-DiskSpace
    Write-Log "=== CONCLUIDO ==="
    exit
}

# Modo interativo
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
        "7"  { Optimize-SSD }
        "8"  { Clear-EventLogs }
        "9"  { Disable-BackgroundApps }
        "10" { Run-CleanMgr }
        "11" { Flush-DNS }
        "12" { Enable-StorageSense }
        "13" { Run-SFC-DISM }
        "14" { Run-DefenderScan }
        "15" {
            Backup-Registry
            Clean-Temp
            Clean-BrowserCaches
            Clean-PackageCaches
            $p = Read-Host "Caminho de projetos para limpar lixo (Enter para pular)"
            if ($p) { Clean-ProjectJunk -RootPath $p }
            Optimize-Startup
            System-Tweaks
            Set-Pagefile
            Optimize-SSD
            Clear-EventLogs
            Disable-BackgroundApps
            Flush-DNS
            Enable-StorageSense
            Run-CleanMgr
            if (-not $SkipLong) { Run-SFC-DISM; Run-DefenderScan }
            Show-DiskSpace
            Write-Log "=== CONCLUIDO ==="
        }
        "0"  { Write-Host "Saindo."; break }
        default { Write-Host "Opcao invalida." }
    }
    if ($choice -eq "0") { break }
    Read-Host "Pressione Enter para continuar"
}
