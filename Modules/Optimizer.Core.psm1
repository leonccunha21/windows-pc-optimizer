#Requires -Version 5.1
Set-StrictMode -Version 2.0

function Get-OptimizerByteSum {
    param($Items, [string]$Property = 'Bytes')
    [long]$total = 0
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        $value = $item.PSObject.Properties[$Property]
        if ($null -ne $value -and $null -ne $value.Value) { $total += [long]$value.Value }
    }
    return $total
}

function Format-OptimizerSize {
    [CmdletBinding()]
    param([double]$Bytes)
    if ($Bytes -lt 0) { throw 'Tamanho negativo não é permitido.' }
    if ($Bytes -lt 1KB) { return ('{0:N0} B' -f $Bytes) }
    if ($Bytes -lt 1MB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
    if ($Bytes -lt 1GB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    return ('{0:N2} GB' -f ($Bytes / 1GB))
}

function Get-OptimizerTargets {
    [CmdletBinding()]
    param()
    # Explicit allowlist: no Documents, Downloads, registry, credentials or event logs.
    $targets = @([pscustomobject]@{ Id='temp'; Name='Temporários do usuário'; Path=(Join-Path $env:LOCALAPPDATA 'Temp'); Process='' })
    foreach ($browser in @(
        @{Id='chrome'; Name='Google Chrome'; Folder='Google\Chrome\User Data'; Process='chrome'},
        @{Id='edge'; Name='Microsoft Edge'; Folder='Microsoft\Edge\User Data'; Process='msedge'},
        @{Id='brave'; Name='Brave'; Folder='BraveSoftware\Brave-Browser\User Data'; Process='brave'}
    )) {
        $base = Join-Path $env:LOCALAPPDATA $browser.Folder
        if (-not (Test-Path -LiteralPath $base)) { continue }
        foreach ($profile in @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -match '^Profile \d+$' })) {
            foreach ($cache in @('Cache\Cache_Data', 'Code Cache', 'GPUCache')) {
                $targets += [pscustomobject]@{ Id="$($browser.Id)-$($profile.Name)-$cache"; Name="$($browser.Name) / $($profile.Name) / $cache"; Path=(Join-Path $profile.FullName $cache); Process=$browser.Process }
            }
        }
    }
    return $targets
}

function Test-OptimizerPath {
    [CmdletBinding()]
    param([string]$Path, [string]$Root)
    try {
        $full = [IO.Path]::GetFullPath($Path)
        $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        if (-not $full.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { return $false }
        if ($full -match '(?i)(^|[\\/])(\.git|Epic Games|EpicGames|Fortnite|FortniteGame)([\\/]|$)') { return $false }
        # Revalidate every ancestor, including the allowlisted root (junctions must not escape it).
        $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
        while ($null -ne $item) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
            if ($item -is [IO.DirectoryInfo]) {
                foreach ($marker in @('.git', 'package.json', 'pyproject.toml', 'Cargo.toml', 'go.mod', '.optimizer-protect')) {
                    if (Test-Path -LiteralPath (Join-Path $item.FullName $marker)) { return $false }
                }
                $item = $item.Parent
            } else { $item = $item.Directory }
        }
        return $true
    } catch { return $false }
}

function Get-OptimizerScan {
    [CmdletBinding()]
    param([object[]]$Targets = (Get-OptimizerTargets), [hashtable]$State = @{Cancel=$false; Message=''}, [int]$MinimumAgeDays = 7)
    if ($MinimumAgeDays -lt 7) { throw 'A retenção mínima é de sete dias.' }
    $cutoff = [DateTime]::UtcNow.AddDays(-$MinimumAgeDays)
    $files = New-Object 'System.Collections.Generic.List[object]'
    $categories = New-Object 'System.Collections.Generic.List[object]'
    $warnings = New-Object 'System.Collections.Generic.List[string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($target in $Targets) {
        if ($State.Cancel) { break }
        $State.Message = "Analisando $($target.Name)..."
        [long]$bytes = 0; $count = 0
        if (-not (Test-Path -LiteralPath $target.Path -PathType Container)) { continue }
        if ($target.Process -and (Get-Process -Name $target.Process -ErrorAction SilentlyContinue)) {
            $warnings.Add("$($target.Name): navegador aberto; categoria ignorada. Feche-o e analise novamente.")
            continue
        }
        $stack = New-Object 'System.Collections.Generic.Stack[string]'
        $stack.Push($target.Path)
        while ($stack.Count -gt 0 -and -not $State.Cancel) {
            $directory = $stack.Pop()
            try { $children = @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) }
            catch { $warnings.Add("Sem acesso: $directory"); continue }
            foreach ($entry in $children) {
                if ($State.Cancel) { break }
                if (-not (Test-OptimizerPath -Path $entry.FullName -Root $target.Path)) { continue }
                if ($entry.PSIsContainer) { $stack.Push($entry.FullName); continue }
                if ($entry.LastWriteTimeUtc -ge $cutoff) { continue }
                # Source code and potentially personal content are never cleanup candidates.
                if ($entry.Extension -match '^\.(ps1|psm1|bat|cmd|py|js|ts|tsx|jsx|cs|cpp|h|java|rs|go|sln|csproj|docx?|xlsx?|pptx?|pdf|jpe?g|png|heic|mp4|zip|7z|rar|sqlite|db|pst|ost)$') { continue }
                if (-not $seen.Add($entry.FullName)) { continue }
                $files.Add([pscustomobject]@{ Category=$target.Id; CategoryName=$target.Name; Path=$entry.FullName; Root=$target.Path; Process=$target.Process; Bytes=[long]$entry.Length; ModifiedUtc=$entry.LastWriteTimeUtc; Selected=$true })
                $bytes += $entry.Length; $count++
            }
        }
        $categories.Add([pscustomobject]@{ Selected=$true; Id=$target.Id; Name=$target.Name; Count=$count; Bytes=$bytes; Size=(Format-OptimizerSize $bytes) })
    }
    [pscustomobject]@{ CreatedUtc=[DateTime]::UtcNow; CutoffUtc=$cutoff; Files=$files.ToArray(); Categories=$categories.ToArray(); Warnings=$warnings.ToArray(); Cancelled=[bool]$State.Cancel; Bytes=(Get-OptimizerByteSum $files) }
}

function Invoke-OptimizerCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)]$Scan, [Parameter(Mandatory)][string[]]$CategoryIds, [hashtable]$State = @{Cancel=$false; Message=''}, [object[]]$Targets = (Get-OptimizerTargets))
    if ($Scan.Cancelled) { throw 'A análise foi cancelada. Analise novamente antes de limpar.' }
    if (([DateTime]::UtcNow - [DateTime]$Scan.CreatedUtc).TotalMinutes -gt 30) { throw 'A análise expirou após 30 minutos. Analise novamente.' }
    $results = New-Object 'System.Collections.Generic.List[object]'
    $allowed = @{}; foreach ($target in $Targets) { $allowed[$target.Id] = $target }
    $selectedFiles = @($Scan.Files | Where-Object { $_.Category -in $CategoryIds })
    $State.Total = $selectedFiles.Count
    $State.Processed = 0
    foreach ($file in $selectedFiles) {
        if ($State.Cancel) { break }
        $State.Message = "Limpando $($file.CategoryName)..."
        $status = 'Ignorado'; $detail = ''; [long]$removed = 0
        try {
            if (-not $allowed.ContainsKey($file.Category)) { throw 'Categoria fora da lista permitida.' }
            $target = $allowed[$file.Category]
            if (-not (Test-OptimizerPath -Path $file.Path -Root $target.Path)) { throw 'Arquivo protegido, removido ou caminho alterado.' }
            if ($target.Process -and (Get-Process -Name $target.Process -ErrorAction SilentlyContinue)) { throw 'Navegador aberto. Feche-o e analise novamente.' }
            $current = Get-Item -LiteralPath $file.Path -Force -ErrorAction Stop
            if ($current.PSIsContainer -or $current.Length -ne $file.Bytes -or $current.LastWriteTimeUtc -ne [DateTime]$file.ModifiedUtc -or $current.LastWriteTimeUtc -ge [DateTime]$Scan.CutoffUtc) { throw 'Arquivo alterado desde a análise.' }
            if ($PSCmdlet.ShouldProcess($file.Path, 'Excluir arquivo temporário analisado')) {
                # No recursive delete: only the exact analyzed file is removed.
                Remove-Item -LiteralPath $file.Path -Force -ErrorAction Stop
                $removed = $file.Bytes; $status = 'Removido'
            } else { $status = 'Simulado' }
        } catch { $detail = $_.Exception.Message }
        $results.Add([pscustomobject]@{ Category=$file.CategoryName; Path=$file.Path; Status=$status; Bytes=$removed; Detail=$detail })
        $State.Processed++
    }
    [pscustomobject]@{ Date=(Get-Date).ToString('o'); Cancelled=[bool]$State.Cancel; RemovedBytes=(Get-OptimizerByteSum $results); RemovedCount=@($results | Where-Object Status -eq 'Removido').Count; SkippedCount=@($results | Where-Object Status -eq 'Ignorado').Count; Results=$results.ToArray() }
}

function Get-OptimizerDiagnostics {
    [CmdletBinding()]
    param()
    $rows = New-Object 'System.Collections.Generic.List[object]'
    $labels = @{ Caption='Windows'; Version='Versão'; LastBootUpTime='Última inicialização'; Manufacturer='Fabricante'; Model='Modelo'; TotalPhysicalMemory='Memória RAM'; Name='Identificação'; NumberOfCores='Núcleos'; NumberOfLogicalProcessors='Processadores lógicos'; Size='Capacidade'; Status='Status básico WMI'; EstimatedChargeRemaining='Carga restante (%)'; BatteryStatus='Estado da bateria (código WMI)' }
    foreach ($query in @(
        @{Name='Sistema'; Class='Win32_OperatingSystem'; Properties=@('Caption','Version','LastBootUpTime')},
        @{Name='Computador'; Class='Win32_ComputerSystem'; Properties=@('Manufacturer','Model','TotalPhysicalMemory')},
        @{Name='Processador'; Class='Win32_Processor'; Properties=@('Name','NumberOfCores','NumberOfLogicalProcessors')},
        @{Name='Disco físico'; Class='Win32_DiskDrive'; Properties=@('Model','Size','Status')},
        @{Name='Bateria'; Class='Win32_Battery'; Properties=@('Name','EstimatedChargeRemaining','BatteryStatus')}
    )) {
        try {
            $items = @(Get-CimInstance -ClassName $query.Class -ErrorAction Stop)
            if ($items.Count -eq 0) { $rows.Add([pscustomobject]@{ Area=$query.Name; Item='Disponibilidade'; Value='Não informado pelo equipamento' }) }
            foreach ($item in $items) {
                foreach ($property in $query.Properties) {
                    $value = $item.$property
                    if ($property -in @('Size','TotalPhysicalMemory')) { $value = Format-OptimizerSize $value }
                    $rows.Add([pscustomobject]@{ Area=$query.Name; Item=$labels[$property]; Value=[string]$value })
                }
            }
        } catch { $rows.Add([pscustomobject]@{ Area=$query.Name; Item='Consulta'; Value='Indisponível: ' + $_.Exception.Message }) }
    }
    try {
        foreach ($disk in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)) {
            $rows.Add([pscustomobject]@{ Area='Armazenamento'; Item=$disk.DeviceID; Value=('Livre: {0} / {1}' -f (Format-OptimizerSize $disk.FreeSpace), (Format-OptimizerSize $disk.Size)) })
        }
    } catch { $rows.Add([pscustomobject]@{Area='Armazenamento';Item='Consulta';Value=$_.Exception.Message}) }
    try {
        $defender = Get-MpComputerStatus -ErrorAction Stop
        $rows.Add([pscustomobject]@{Area='Segurança';Item='Defender em tempo real';Value=[string]$defender.RealTimeProtectionEnabled})
    } catch { $rows.Add([pscustomobject]@{Area='Segurança';Item='Defender';Value='Indisponível; confira o antivírus instalado'}) }
    return $rows.ToArray()
}

function Export-OptimizerReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [string]$Customer, [string]$Notes, [object[]]$Diagnostics, $Cleanup, [ValidateSet('HTML','JSON')][string]$Format = 'HTML')
    $encode = { param($value) [System.Net.WebUtility]::HtmlEncode([string]$value) }
    if ($Format -eq 'JSON') {
        # Files and private paths are intentionally excluded from the structured report.
        $summary = $null
        if ($null -ne $Cleanup) {
            $summary = [ordered]@{ RemovedBytes = [long]$Cleanup.RemovedBytes; RemovedCount = [int]$Cleanup.RemovedCount; SkippedCount = [int]$Cleanup.SkippedCount; Cancelled = [bool]$Cleanup.Cancelled }
        }
        $payload = [ordered]@{
            SchemaVersion = 1
            GeneratedAt = (Get-Date).ToString('o')
            Customer = [string]$Customer
            Notes = [string]$Notes
            Diagnostics = @($Diagnostics | ForEach-Object { [ordered]@{ Area = [string]$_.Area; Item = [string]$_.Item; Value = [string]$_.Value } })
            Cleanup = $summary
        }
        [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $payload -Depth 6), (New-Object Text.UTF8Encoding $true))
        return
    }
    $rows = foreach ($row in $Diagnostics) { '<tr><td>{0}</td><td>{1}</td><td>{2}</td></tr>' -f (& $encode $row.Area), (& $encode $row.Item), (& $encode $row.Value) }
    $summary = 'Nenhuma limpeza realizada nesta sessão.'
    if ($null -ne $Cleanup) { $summary = '{0} liberados; {1} arquivos removidos; {2} ignorados. Interrompido: {3}.' -f (Format-OptimizerSize $Cleanup.RemovedBytes), $Cleanup.RemovedCount, $Cleanup.SkippedCount, $Cleanup.Cancelled }
    $html = @"
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Relatório de manutenção</title>
<style>body{font:15px 'Segoe UI',sans-serif;color:#192c42;max-width:950px;margin:48px auto;padding:0 24px}h1{color:#116b60}header{border-bottom:3px solid #20b89e;padding-bottom:20px}table{border-collapse:collapse;width:100%}td,th{padding:12px;text-align:left;border-bottom:1px solid #dce5ed}th{background:#edf5f6}p{line-height:1.7;white-space:pre-wrap}.note{color:#526578} @media print{body{margin:0}}</style></head><body>
<header><h1>PC Optimizer • Relatório de manutenção</h1><p>Atendimento: $(& $encode $Customer)<br>Emitido em: $(Get-Date -Format 'dd/MM/yyyy HH:mm')</p></header>
<h2>Resultado da última limpeza</h2><p>$(& $encode $summary)</p>
<h2>Equipamento</h2><table><tr><th>Área</th><th>Item</th><th>Resultado</th></tr>$($rows -join '')</table>
<h2>Observações do técnico</h2><p>$(& $encode $Notes)</p>
<p class="note">Consulta pontual. O status de disco informado pelo Windows não substitui um teste SMART completo. Este relatório não certifica ausência de defeitos ou malware. Caminhos pessoais e números de série não são incluídos.</p></body></html>
"@
    [IO.File]::WriteAllText($Path, $html, (New-Object Text.UTF8Encoding $true))
}

Export-ModuleMember -Function Format-OptimizerSize, Get-OptimizerTargets, Test-OptimizerPath, Get-OptimizerScan, Invoke-OptimizerCleanup, Get-OptimizerDiagnostics, Export-OptimizerReport
