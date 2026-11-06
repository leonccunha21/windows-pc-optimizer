#Requires -Version 5.1
Set-StrictMode -Version 2.0

$script:cachedConfiguration = $null

function Get-OptimizerConfigurationDefaults {
    return [pscustomobject]@{
        MinimumAgeDays = 7
        Browsers = @(
            [pscustomobject]@{ Id='chrome'; Name='Google Chrome'; Folder='Google\Chrome\User Data'; Process='chrome' }
            [pscustomobject]@{ Id='edge'; Name='Microsoft Edge'; Folder='Microsoft\Edge\User Data'; Process='msedge' }
            [pscustomobject]@{ Id='brave'; Name='Brave'; Folder='BraveSoftware\Brave-Browser\User Data'; Process='brave' }
        )
        BrowserCacheFolders = @('Cache\Cache_Data', 'Code Cache', 'GPUCache')
        ProtectedExtensions = @(
            '.ps1', '.psm1', '.bat', '.cmd', '.py', '.js', '.ts', '.tsx', '.jsx',
            '.cs', '.cpp', '.h', '.java', '.rs', '.go', '.sln', '.csproj',
            '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.pdf',
            '.jpg', '.jpeg', '.png', '.heic', '.mp4', '.zip', '.7z', '.rar',
            '.sqlite', '.db', '.pst', '.ost'
        )
        ProtectedFolders = @('.git', 'Epic Games', 'EpicGames', 'Fortnite', 'FortniteGame')
        ProjectMarkers = @('.git', 'package.json', 'pyproject.toml', 'Cargo.toml', 'go.mod', '.optimizer-protect')
    }
}

function Test-OptimizerRelativePath {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ([IO.Path]::IsPathRooted($Value)) { return $false }
    foreach ($segment in @($Value -split '[\\/]')) {
        if ($segment -eq '..') { return $false }
    }
    return $true
}

function Read-OptimizerConfigurationData {
    <#
    .SYNOPSIS
    Reads a data-only .psd1 file on Windows PowerShell 5.1 and PowerShell 7.
    .DESCRIPTION
    Import-PowerShellDataFile is unavailable in Windows PowerShell 5.1. The
    fallback parses the file and calls SafeGetValue, which rejects commands,
    variables and any other dynamic expression instead of executing them.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if ($null -ne (Get-Command -Name Import-PowerShellDataFile -ErrorAction SilentlyContinue)) {
        return Import-PowerShellDataFile -LiteralPath $Path -ErrorAction Stop
    }
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($null -ne $errors -and $errors.Count -gt 0) { throw 'Configuração inválida.' }
    $statements = @($ast.EndBlock.Statements)
    if ($statements.Count -ne 1) { throw 'Configuração inválida.' }
    return $statements[0].SafeGetValue()
}

function Get-OptimizerConfiguration {
    <#
    .SYNOPSIS
    Loads the non-code cleanup allowlist from config/optimizer.psd1.
    .DESCRIPTION
    The data file is optional. Missing, malformed or out-of-policy values fall
    back to the embedded safe defaults so cleanup never broadens silently.
    #>
    [CmdletBinding()]
    param([string]$Path = '')
    $defaultPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'config\optimizer.psd1'
    $useCache = [string]::IsNullOrWhiteSpace($Path)
    if ($useCache) {
        if ($null -ne $script:cachedConfiguration) { return $script:cachedConfiguration }
        $Path = $defaultPath
    }
    $defaults = Get-OptimizerConfigurationDefaults
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $defaults }
    try {
        $data = Read-OptimizerConfigurationData -Path $Path
        if ($null -eq $data) { return $defaults }
        $minimumAge = [int]$data.MinimumAgeDays
        if ($minimumAge -lt 7) { return $defaults }

        $browsers = New-Object 'System.Collections.Generic.List[object]'
        foreach ($browser in @($data.Browsers)) {
            if ($null -eq $browser) { return $defaults }
            $id = [string]$browser.Id
            $name = [string]$browser.Name
            $folder = [string]$browser.Folder
            $process = [string]$browser.Process
            if ($id -notmatch '^[a-z0-9][a-z0-9-]{0,31}$') { return $defaults }
            if ([string]::IsNullOrWhiteSpace($name)) { return $defaults }
            if (-not (Test-OptimizerRelativePath $folder)) { return $defaults }
            if ($process -and $process -notmatch '^[A-Za-z0-9._-]+$') { return $defaults }
            $browsers.Add([pscustomobject]@{ Id=$id; Name=$name; Folder=$folder; Process=$process })
        }

        $cacheFolders = New-Object 'System.Collections.Generic.List[string]'
        foreach ($folder in @($data.BrowserCacheFolders)) {
            $value = [string]$folder
            if (-not (Test-OptimizerRelativePath $value)) { return $defaults }
            $cacheFolders.Add($value)
        }

        $extensions = New-Object 'System.Collections.Generic.List[string]'
        foreach ($extension in @($data.ProtectedExtensions)) {
            $value = [string]$extension
            if ($value -notmatch '^\.[A-Za-z0-9]{1,16}$') { return $defaults }
            $extensions.Add($value.ToLowerInvariant())
        }

        $folders = New-Object 'System.Collections.Generic.List[string]'
        foreach ($folder in @($data.ProtectedFolders)) {
            $value = [string]$folder
            if ([string]::IsNullOrWhiteSpace($value) -or $value -match '[\\/]') { return $defaults }
            $folders.Add($value)
        }

        $markers = New-Object 'System.Collections.Generic.List[string]'
        foreach ($marker in @($data.ProjectMarkers)) {
            $value = [string]$marker
            if ([string]::IsNullOrWhiteSpace($value) -or $value -match '[\\/]') { return $defaults }
            $markers.Add($value)
        }

        if ($browsers.Count -eq 0 -or $cacheFolders.Count -eq 0 -or $extensions.Count -eq 0 -or $folders.Count -eq 0 -or $markers.Count -eq 0) {
            return $defaults
        }

        $configuration = [pscustomobject]@{
            MinimumAgeDays = $minimumAge
            Browsers = $browsers.ToArray()
            BrowserCacheFolders = $cacheFolders.ToArray()
            ProtectedExtensions = $extensions.ToArray()
            ProtectedFolders = $folders.ToArray()
            ProjectMarkers = $markers.ToArray()
        }
        if ($useCache) { $script:cachedConfiguration = $configuration }
        return $configuration
    } catch {
        return $defaults
    }
}

function Get-OptimizerByteSum {
    [CmdletBinding()]
    param($Items, [string]$Property = 'Bytes')
    [long]$total = 0
    foreach ($item in $Items) {
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
    <#
    .SYNOPSIS
    Returns the allowlisted cache targets for the current user.
    .DESCRIPTION
    Browsers, cache subfolders and the retention floor come from
    config/optimizer.psd1. Only the user temp folder and discovered browser
    profiles are returned; no Documents, Downloads or registry paths.
    .EXAMPLE
    Get-OptimizerTargets | Select-Object Id, Name, Path
    #>
    [CmdletBinding()]
    param()
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { return @() }
    $configuration = Get-OptimizerConfiguration
    # Explicit allowlist: no Documents, Downloads, registry, credentials or event logs.
    $targets = @([pscustomobject]@{ Id='temp'; Name='Temporários do usuário'; Path=(Join-Path $env:LOCALAPPDATA 'Temp'); Process='' })
    foreach ($browser in $configuration.Browsers) {
        $relativeFolder = $browser.Folder -replace '[\\/]', [IO.Path]::DirectorySeparatorChar
        $base = Join-Path $env:LOCALAPPDATA $relativeFolder
        if (-not (Test-Path -LiteralPath $base)) { continue }
        foreach ($profileDir in @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -match '^Profile \d+$' })) {
            foreach ($cache in $configuration.BrowserCacheFolders) {
                $relativeCache = $cache -replace '[\\/]', [IO.Path]::DirectorySeparatorChar
                $targets += [pscustomobject]@{ Id="$($browser.Id)-$($profileDir.Name)-$cache"; Name="$($browser.Name) / $($profileDir.Name) / $cache"; Path=(Join-Path $profileDir.FullName $relativeCache); Process=$browser.Process }
            }
        }
    }
    return $targets
}

function Test-OptimizerPath {
    <#
    .SYNOPSIS
    Checks whether a path is safe to treat as cleanup data.
    .DESCRIPTION
    Rejects paths outside the target root, reparse points, protected folders
    and any directory containing a project marker. The allowlists are loaded
    from config/optimizer.psd1 and revalidated for every file.
    .PARAMETER Path
    Full path of the candidate file or directory.
    .PARAMETER Root
    Allowlisted target root that must contain Path.
    #>
    [CmdletBinding()]
    param([string]$Path, [string]$Root)
    $configuration = Get-OptimizerConfiguration
    try {
        $full = [IO.Path]::GetFullPath($Path)
        $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        if (-not $full.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { return $false }
        if ($configuration.ProtectedFolders.Count -gt 0) {
            $folderPattern = (@($configuration.ProtectedFolders | ForEach-Object { [regex]::Escape($_) }) -join '|')
            if ($full -match "(?i)(^|[\\/])($folderPattern)([\\/]|$)") { return $false }
        }
        # Revalidate every ancestor, including the allowlisted root (junctions must not escape it).
        $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
        while ($null -ne $item) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
            if ($item -is [IO.DirectoryInfo]) {
                foreach ($marker in $configuration.ProjectMarkers) {
                    if (Test-Path -LiteralPath (Join-Path $item.FullName $marker)) { return $false }
                }
                $item = $item.Parent
            } else { $item = $item.Directory }
        }
        return $true
    } catch { return $false }
}

function Get-OptimizerScan {
    <#
    .SYNOPSIS
    Scans allowlisted cache targets without deleting anything.
    .DESCRIPTION
    Returns candidate files older than the retention floor plus per-category
    totals and warnings. The default retention comes from
    config/optimizer.psd1 and can never be lower than seven days.
    .PARAMETER Targets
    Targets returned by Get-OptimizerTargets. Defaults to the current user.
    .PARAMETER State
    Synchronized cancellation/progress state used by the GUI.
    .PARAMETER MinimumAgeDays
    Retention in days. Omit to use the configuration value (minimum 7).
    #>
    [CmdletBinding()]
    param([object[]]$Targets = (Get-OptimizerTargets), [hashtable]$State = @{Cancel=$false; Message=''}, [int]$MinimumAgeDays = -1)
    $configuration = Get-OptimizerConfiguration
    if ($MinimumAgeDays -lt 0) { $MinimumAgeDays = [int]$configuration.MinimumAgeDays }
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
                if ($configuration.ProtectedExtensions -contains ([string]$entry.Extension).ToLowerInvariant()) { continue }
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
    <#
    .SYNOPSIS
    Collects a read-only hardware and Windows diagnostics summary.
    .DESCRIPTION
    Queries CIM for system, memory, CPU, disk and battery data plus Defender
    status. Unavailable providers become explanatory rows instead of errors.
    No settings are changed and no data leaves the computer.
    #>
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
    <#
    .SYNOPSIS
    Writes an HTML or JSON maintenance report.
    .DESCRIPTION
    HTML output is escaped and both formats omit personal cleanup paths and
    serial numbers. JSON contains only aggregated cleanup counters.
    .PARAMETER Path
    Destination file. Parent directory must already exist unless created by the caller.
    .PARAMETER Customer
    Optional customer/attendance label.
    .PARAMETER Notes
    Optional technician notes.
    .PARAMETER Diagnostics
    Rows returned by Get-OptimizerDiagnostics.
    .PARAMETER Cleanup
    Optional cleanup result from Invoke-OptimizerCleanup.
    .PARAMETER Format
    HTML (default) or JSON.
    #>
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
            Diagnostics = @($Diagnostics | Where-Object { $null -ne $_ } | ForEach-Object { [ordered]@{ Area = [string]$_.Area; Item = [string]$_.Item; Value = [string]$_.Value } })
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

function Get-OptimizerPropertyValue {
    param($InputObject, [string]$Name)
    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-OptimizerXmlText {
    param($Node, [string]$Name)
    if ($null -eq $Node) { return $null }
    $child = $Node.SelectSingleNode("*[local-name()='$Name']")
    if ($null -eq $child) { return $null }
    return [string]$child.InnerText
}

function Get-OptimizerHealthRating {
    [CmdletBinding()]
    param($HealthPercent)
    if ($null -eq $HealthPercent) { return 'Indisponível' }
    $value = [double]$HealthPercent
    if ($value -ge 80) { return 'Boa' }
    if ($value -ge 60) { return 'Atenção' }
    return 'Substituir'
}

function ConvertFrom-OptimizerBatteryReportXml {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Xml)
    try {
        $document = New-Object Xml.XmlDocument
        $document.LoadXml($Xml)
    } catch { throw 'Relatório de bateria inválido ou ilegível.' }
    $battery = @($document.GetElementsByTagName('Battery')) | Select-Object -First 1
    if ($null -eq $battery) {
        return [pscustomobject]@{ HasBattery=$false; Manufacturer=''; Chemistry=''; SerialNumber=''; DesignCapacityMWh=[long]0; FullChargeCapacityMWh=[long]0; CycleCount=0; HealthPercent=$null; Rating='Indisponível' }
    }
    [long]$design = 0; [long]$full = 0; [long]$cycles = 0
    $designText = Get-OptimizerXmlText $battery 'DesignCapacity'
    $fullText = Get-OptimizerXmlText $battery 'FullChargeCapacity'
    $cycleText = Get-OptimizerXmlText $battery 'CycleCount'
    if (-not [long]::TryParse($designText, [ref]$design)) { $design = 0 }
    if (-not [long]::TryParse($fullText, [ref]$full)) { $full = 0 }
    if (-not [long]::TryParse($cycleText, [ref]$cycles)) { $cycles = 0 }
    $health = $null
    if ($design -gt 0 -and $full -gt 0) { $health = [math]::Round(100 * $full / $design, 1) }
    [pscustomobject]@{
        HasBattery = $true
        Manufacturer = [string](Get-OptimizerXmlText $battery 'Manufacturer')
        Chemistry = [string](Get-OptimizerXmlText $battery 'Chemistry')
        SerialNumber = [string](Get-OptimizerXmlText $battery 'SerialNumber')
        DesignCapacityMWh = $design
        FullChargeCapacityMWh = $full
        CycleCount = $cycles
        HealthPercent = $health
        Rating = Get-OptimizerHealthRating -HealthPercent $health
    }
}

function Get-OptimizerBatteryHealth {
    [CmdletBinding()]
    param()
    $result = [pscustomobject]@{
        HasBattery=$false; Manufacturer=''; Chemistry=''; SerialNumber=''
        DesignCapacityMWh=[long]0; FullChargeCapacityMWh=[long]0; CycleCount=0
        HealthPercent=$null; Rating='Indisponível'; EstimatedChargeRemaining=$null
        BatteryStatus=''; Method=''; Note=''
    }
    if ($env:OS -ne 'Windows_NT') { $result.Note = 'Consulta disponível apenas no Windows.'; return $result }
    try {
        $battery = @(Get-CimInstance Win32_Battery -ErrorAction Stop) | Select-Object -First 1
        if ($null -eq $battery) { $result.Note = 'Nenhuma bateria detectada. Em desktops esse resultado é esperado.'; return $result }
        $result.HasBattery = $true
        $result.EstimatedChargeRemaining = Get-OptimizerPropertyValue $battery 'EstimatedChargeRemaining'
        $result.BatteryStatus = [string](Get-OptimizerPropertyValue $battery 'BatteryStatus')
    } catch {
        $result.Note = 'Não foi possível consultar a bateria: ' + $_.Exception.Message
        return $result
    }
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('pcoptimizer-battery-' + [guid]::NewGuid().ToString('N') + '.xml')
    try {
        & powercfg.exe /batteryreport /xml /output $temp 2>$null | Out-Null
        if (Test-Path -LiteralPath $temp) {
            $parsed = ConvertFrom-OptimizerBatteryReportXml -Xml (Get-Content -LiteralPath $temp -Raw -Encoding UTF8)
            if ($parsed.HasBattery) {
                $result.Manufacturer = $parsed.Manufacturer
                $result.Chemistry = $parsed.Chemistry
                $result.SerialNumber = $parsed.SerialNumber
                $result.DesignCapacityMWh = $parsed.DesignCapacityMWh
                $result.FullChargeCapacityMWh = $parsed.FullChargeCapacityMWh
                $result.CycleCount = $parsed.CycleCount
                $result.HealthPercent = $parsed.HealthPercent
                $result.Rating = $parsed.Rating
                $result.Method = 'powercfg /batteryreport'
            }
        }
    } catch {
        $result.Note = 'Relatório detalhado indisponível: ' + $_.Exception.Message
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
    }
    if ($result.Method -eq '') { $result.Note = 'Capacidade de projeto não informada pelo fabricante; saúde detalhada indisponível.' }
    return $result
}

function Save-OptimizerBatteryReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if ($env:OS -ne 'Windows_NT') { throw 'O relatório de bateria está disponível apenas no Windows.' }
    $fullPath = [IO.Path]::GetFullPath($Path)
    $directory = [IO.Path]::GetDirectoryName($fullPath)
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { throw 'A pasta de destino não existe.' }
    & powercfg.exe /batteryreport /output $fullPath 2>&1 | Out-Null
    if (-not (Test-Path -LiteralPath $fullPath)) { throw 'O Windows não gerou o relatório de bateria.' }
    return $fullPath
}

function Get-OptimizerDiskHealth {
    [CmdletBinding()]
    param()
    $disks = New-Object 'System.Collections.Generic.List[object]'
    $volumes = New-Object 'System.Collections.Generic.List[object]'
    $note = ''
    if ($env:OS -ne 'Windows_NT') {
        return [pscustomobject]@{ Disks=@(); Volumes=@(); Note='Consulta disponível apenas no Windows.' }
    }
    $smartError = ''
    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        try {
            foreach ($disk in @(Get-PhysicalDisk -ErrorAction Stop)) {
                $temperature = $null; $wear = $null; $hours = $null; $readErrors = $null
                if ([string]::IsNullOrWhiteSpace($smartError)) {
                    try {
                        $counter = $disk | Get-StorageReliabilityCounter -ErrorAction Stop
                        $temperature = Get-OptimizerPropertyValue $counter 'Temperature'
                        $wear = Get-OptimizerPropertyValue $counter 'Wear'
                        $hours = Get-OptimizerPropertyValue $counter 'PowerOnHours'
                        $readErrors = Get-OptimizerPropertyValue $counter 'ReadErrorsTotal'
                    } catch {
                        $smartError = $_.Exception.Message
                        Write-Verbose ('SMART indisponível: ' + $smartError)
                    }
                }
                $health = [string](Get-OptimizerPropertyValue $disk 'HealthStatus')
                $rating = switch ($health) {
                    'Healthy' { 'Saudável' }
                    'Warning' { 'Atenção' }
                    'Unhealthy' { 'Crítica' }
                    default { if ($health) { $health } else { 'Não informado' } }
                }
                $size = Get-OptimizerPropertyValue $disk 'Size'
                $disks.Add([pscustomobject]@{
                    Device=[string](Get-OptimizerPropertyValue $disk 'FriendlyName')
                    Media=[string](Get-OptimizerPropertyValue $disk 'MediaType')
                    Bus=[string](Get-OptimizerPropertyValue $disk 'BusType')
                    Size=if ($null -ne $size) { Format-OptimizerSize $size } else { '—' }
                    Health=$health
                    Rating=$rating
                    Status=(@((Get-OptimizerPropertyValue $disk 'OperationalStatus')) -join ', ')
                    Temperature=if ($temperature -and $temperature -gt 0) { "$temperature °C" } else { '—' }
                    Wear=if ($null -ne $wear) { "$wear%" } else { '—' }
                    PowerOnHours=if ($null -ne $hours) { [string]$hours } else { '—' }
                    ReadErrors=if ($null -ne $readErrors) { [string]$readErrors } else { '—' }
                })
            }
        } catch { $note = 'Consulta de discos indisponível: ' + $_.Exception.Message }
    }
    if ($disks.Count -eq 0) {
        try {
            foreach ($drive in @(Get-CimInstance Win32_DiskDrive -ErrorAction Stop)) {
                $disks.Add([pscustomobject]@{
                    Device=[string](Get-OptimizerPropertyValue $drive 'Model'); Media=[string](Get-OptimizerPropertyValue $drive 'MediaType'); Bus=[string](Get-OptimizerPropertyValue $drive 'InterfaceType')
                    Size=if ($drive.Size) { Format-OptimizerSize $drive.Size } else { '—' }
                    Health=[string](Get-OptimizerPropertyValue $drive 'Status'); Rating='Ver Relatório'; Status=[string](Get-OptimizerPropertyValue $drive 'Status')
                    Temperature='—'; Wear='—'; PowerOnHours='—'; ReadErrors='—'
                })
            }
        } catch { $note = 'Não foi possível consultar os discos: ' + $_.Exception.Message }
    }
    try {
        foreach ($volume in @(Get-Volume -ErrorAction Stop | Where-Object { $null -ne $_.DriveLetter })) {
            $remaining = Get-OptimizerPropertyValue $volume 'SizeRemaining'
            $total = Get-OptimizerPropertyValue $volume 'Size'
            $volumes.Add([pscustomobject]@{
                Letter=[string]$volume.DriveLetter; Label=[string](Get-OptimizerPropertyValue $volume 'FileSystemLabel')
                FileSystem=[string](Get-OptimizerPropertyValue $volume 'FileSystem'); Free=if ($null -ne $remaining) { Format-OptimizerSize $remaining } else { '—' }
                Total=if ($null -ne $total) { Format-OptimizerSize $total } else { '—' }
                Health=switch ([string](Get-OptimizerPropertyValue $volume 'HealthStatus')) { 'Healthy' { 'Saudável' } 'Warning' { 'Atenção' } 'Unhealthy' { 'Crítica' } default { if (Get-OptimizerPropertyValue $volume 'HealthStatus') { [string](Get-OptimizerPropertyValue $volume 'HealthStatus') } else { '-' } } }
            })
        }
    } catch { Write-Verbose 'Leitura opcional indisponível.' }
    if ($volumes.Count -eq 0) {
        try {
            foreach ($logical in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)) {
                $volumes.Add([pscustomobject]@{ Letter=[string]$logical.DeviceID; Label=[string]$logical.VolumeName; FileSystem=[string]$logical.FileSystem; Free=Format-OptimizerSize $logical.FreeSpace; Total=Format-OptimizerSize $logical.Size; Health='Não informado' })
            }
        } catch { Write-Verbose 'Leitura opcional indisponível.' }
    }
    if ([string]::IsNullOrWhiteSpace($note) -and -not [string]::IsNullOrWhiteSpace($smartError)) {
        $note = 'Temperatura/horas via SMART requerem permissão de administrador (Get-StorageReliabilityCounter: ' + $smartError + '). Execute como administrador para obter o SMART completo; a saúde do disco segue visível.'
    }
    [pscustomobject]@{ Disks=$disks.ToArray(); Volumes=$volumes.ToArray(); Note=$note }
}

function Get-OptimizerDrivers {
    [CmdletBinding()]
    param([int]$OutdatedDays = 1095)
    if ($env:OS -ne 'Windows_NT') { return @() }
    if ($OutdatedDays -lt 365) { throw 'O limite mínimo de driver antigo é de 365 dias.' }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    $drivers = @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop | Where-Object { $_.DeviceName -and $_.DriverVersion })
    foreach ($driver in $drivers) {
        $driverDate = $null
        try { if ($driver.DriverDate) { $driverDate = [DateTime]$driver.DriverDate } } catch { Write-Verbose 'Leitura opcional indisponível.' }
        $ageDays = $null
        if ($null -ne $driverDate) { $ageDays = [int]((Get-Date) - $driverDate).TotalDays }
        $signed = [bool](Get-OptimizerPropertyValue $driver 'IsSigned')
        $manufacturer = [string](Get-OptimizerPropertyValue $driver 'Manufacturer')
        $status = 'OK'
        if (-not $signed) { $status = 'Não assinado' }
        elseif ($null -ne $ageDays -and $ageDays -gt $OutdatedDays -and $manufacturer -notmatch '^Microsoft') { $status = 'Verificar atualização' }
        $rows.Add([pscustomobject]@{
            Class=[string](Get-OptimizerPropertyValue $driver 'DeviceClass')
            Device=[string]$driver.DeviceName
            Manufacturer=$manufacturer
            Version=[string]$driver.DriverVersion
            Date=if ($null -ne $driverDate) { $driverDate.ToString('dd/MM/yyyy') } else { '—' }
            AgeDays=$ageDays
            Signed=if ($signed) { 'Sim' } else { 'Não' }
            Status=$status
        })
    }
    return @($rows | Sort-Object Class, Device)
}

function Get-OptimizerDriverUpdates {
    [CmdletBinding()]
    param()
    $result = [pscustomobject]@{ Available=$false; Updates=@(); Error='' }
    if ($env:OS -ne 'Windows_NT') { $result.Error = 'Consulta disponível apenas no Windows.'; return $result }
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $found = $searcher.Search("IsInstalled=0 and Type='Driver'")
        $updates = New-Object 'System.Collections.Generic.List[object]'
        foreach ($update in @($found.Updates)) {
            $manufacturer = ''; $model = ''; $updateClass = ''
            try { $manufacturer = [string]$update.DriverManufacturer } catch { Write-Verbose 'Leitura opcional indisponível.' }
            try { $model = [string]$update.DriverModel } catch { Write-Verbose 'Leitura opcional indisponível.' }
            try { $updateClass = [string]$update.DriverClass } catch { Write-Verbose 'Leitura opcional indisponível.' }
            $updates.Add([pscustomobject]@{
                Title=[string]$update.Title; Manufacturer=$manufacturer; Model=$model
                Class=$updateClass; Downloaded=[bool]$update.IsDownloaded
            })
        }
        $result.Updates = $updates.ToArray()
        $result.Available = $updates.Count -gt 0
    } catch {
        $result.Error = 'Não foi possível consultar o Windows Update: ' + $_.Exception.Message
    }
    return $result
}

function Get-OptimizerBloatCatalog {
    [CmdletBinding()]
    param()
    return @(
        [pscustomobject]@{ Match='Microsoft.Xbox*'; Label='Xbox e Game Pass' }
        [pscustomobject]@{ Match='Microsoft.BingNews'; Label='Notícias Bing' }
        [pscustomobject]@{ Match='Microsoft.BingWeather'; Label='Clima MSN' }
        [pscustomobject]@{ Match='Microsoft.GetHelp'; Label='Obter Ajuda' }
        [pscustomobject]@{ Match='Microsoft.Getstarted'; Label='Dicas do Windows' }
        [pscustomobject]@{ Match='Microsoft.WindowsFeedbackHub'; Label='Hub de Comentários' }
        [pscustomobject]@{ Match='Microsoft.MicrosoftSolitaireCollection'; Label='Paciência Microsoft' }
        [pscustomobject]@{ Match='Clipchamp.Clipchamp'; Label='Editor Clipchamp' }
        [pscustomobject]@{ Match='MicrosoftTeams'; Label='Microsoft Teams (consumidor)' }
        [pscustomobject]@{ Match='Microsoft.SkypeApp'; Label='Skype' }
        [pscustomobject]@{ Match='Microsoft.YourPhone'; Label='Vincular ao Celular' }
        [pscustomobject]@{ Match='Microsoft.People'; Label='Pessoas' }
        [pscustomobject]@{ Match='Microsoft.MixedReality.Portal'; Label='Realidade Misturada' }
        [pscustomobject]@{ Match='Microsoft.Microsoft3DViewer'; Label='Visualizador 3D' }
        [pscustomobject]@{ Match='Microsoft.Print3D'; Label='Imprimir em 3D' }
        [pscustomobject]@{ Match='Microsoft.ZuneMusic'; Label='Música legada (Groove)' }
        [pscustomobject]@{ Match='Microsoft.ZuneVideo'; Label='Filmes e TV' }
        [pscustomobject]@{ Match='Microsoft.MicrosoftOfficeHub'; Label='Hub do Office' }
        [pscustomobject]@{ Match='Microsoft.WindowsMaps'; Label='Mapas' }
        [pscustomobject]@{ Match='SpotifyAB.SpotifyMusic'; Label='Spotify pré-instalado' }
        [pscustomobject]@{ Match='*TikTok*'; Label='TikTok pré-instalado' }
        [pscustomobject]@{ Match='*Facebook*'; Label='Facebook pré-instalado' }
        [pscustomobject]@{ Match='*Instagram*'; Label='Instagram pré-instalado' }
        [pscustomobject]@{ Match='*Twitter*'; Label='X/Twitter pré-instalado' }
        [pscustomobject]@{ Match='*CandyCrush*'; Label='Candy Crush pré-instalado' }
        [pscustomobject]@{ Match='*Disney*'; Label='Disney+ pré-instalado' }
    )
}

function Get-OptimizerAppInventory {
    [CmdletBinding()]
    param()
    if ($env:OS -ne 'Windows_NT') { return @() }
    $catalog = Get-OptimizerBloatCatalog
    $rows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($package in @(Get-AppxPackage -ErrorAction Stop | Where-Object { -not $_.IsFramework -and -not $_.IsResourcePackage })) {
        $match = @($catalog | Where-Object { $package.Name -like $_.Match }) | Select-Object -First 1
        $rows.Add([pscustomobject]@{
            Selected=$false
            Label=if ($null -ne $match) { $match.Label } else { [string]$package.Name }
            Name=[string]$package.Name
            Version=[string]$package.Version
            Publisher=[string](Get-OptimizerPropertyValue $package 'PublisherDisplayName')
            Suggested=($null -ne $match)
            NonRemovable=[bool](Get-OptimizerPropertyValue $package 'NonRemovable')
            PackageFullName=[string]$package.PackageFullName
        })
    }
    return @($rows | Sort-Object @{ Expression='Suggested'; Descending=$true }, Label)
}

function Invoke-OptimizerAppRemoval {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string[]]$PackageFullNames)
    if ($env:OS -ne 'Windows_NT') { throw 'A remoção de aplicativos está disponível apenas no Windows.' }
    $results = New-Object 'System.Collections.Generic.List[object]'
    foreach ($fullName in $PackageFullNames) {
        $status = 'Ignorado'; $detail = ''; $label = $fullName
        try {
            $package = Get-AppxPackage -ErrorAction Stop | Where-Object { $_.PackageFullName -eq $fullName } | Select-Object -First 1
            if ($null -eq $package) { throw 'Pacote não encontrado para o usuário atual.' }
            $label = [string]$package.Name
            if ([bool](Get-OptimizerPropertyValue $package 'NonRemovable')) { throw 'O Windows marca este pacote como não removível.' }
            if ($PSCmdlet.ShouldProcess($label, 'Remover aplicativo do usuário atual')) {
                Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                $status = 'Removido'; $detail = 'Pode ser reinstalado pela Microsoft Store.'
            } else { $status = 'Simulado' }
        } catch { $status = 'Falhou'; $detail = $_.Exception.Message }
        $results.Add([pscustomobject]@{ PackageFullName=$fullName; Name=$label; Status=$status; Detail=$detail })
    }
    return $results.ToArray()
}

function Get-OptimizerOptimizations {
    [CmdletBinding()]
    param()
    return @(
        [pscustomobject]@{ Id='power-high'; Name='Plano de energia: alto desempenho'; Description='Mantém o processador em frequência alta. Em notebooks aumenta o consumo e o calor.'; RequiresAdmin=$false }
        [pscustomobject]@{ Id='power-balanced'; Name='Plano de energia: equilibrado'; Description='Equilibra desempenho e consumo. Recomendado para uso diário e notebooks.'; RequiresAdmin=$false }
        [pscustomobject]@{ Id='storage-sense'; Name='Ativar Sensor de Armazenamento'; Description='Permite ao Windows remover temporários e arquivos antigos automaticamente.'; RequiresAdmin=$false }
        [pscustomobject]@{ Id='delivery-cache'; Name='Limpar cache de Otimização de Entrega'; Description='Libera cópias de atualizações usadas para compartilhamento local.'; RequiresAdmin=$false }
        [pscustomobject]@{ Id='recycle-bin'; Name='Esvaziar Lixeira'; Description='Remove definitivamente os itens já enviados à Lixeira.'; RequiresAdmin=$false }
        [pscustomobject]@{ Id='fast-startup-off'; Name='Desativar inicialização rápida'; Description='Desliga o estado hibernado do desligamento. Útil quando há dupla inicialização ou drivers instáveis.'; RequiresAdmin=$true }
    )
}

function Invoke-OptimizerOptimization {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string[]]$Ids, [object[]]$Catalog = (Get-OptimizerOptimizations))
    $known = @{}
    foreach ($item in $Catalog) { $known[$item.Id] = $item }
    $results = New-Object 'System.Collections.Generic.List[object]'
    foreach ($id in $Ids) {
        $status = 'Ignorado'; $detail = ''
        if (-not $known.ContainsKey($id)) {
            $results.Add([pscustomobject]@{ Id=$id; Name=$id; Status=$status; Detail='Ação desconhecida.' })
            continue
        }
        $action = $known[$id]
        try {
            if ($env:OS -ne 'Windows_NT') { throw 'Disponível apenas no Windows.' }
            if (-not $PSCmdlet.ShouldProcess($action.Name, 'Aplicar otimização')) {
                $status = 'Simulado'
            } else {
                switch ($id) {
                    'power-high' { & powercfg.exe /setactive SCHEME_MIN 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw 'O Windows recusou o plano de energia.' }; $status = 'Aplicado'; $detail = 'Alto desempenho ativado.' }
                    'power-balanced' { & powercfg.exe /setactive SCHEME_BALANCED 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw 'O Windows recusou o plano de energia.' }; $status = 'Aplicado'; $detail = 'Equilibrado ativado.' }
                    'storage-sense' { & reg.exe add 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' /v 01 /t REG_DWORD /d 1 /f 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw 'Não foi possível ativar o Sensor de Armazenamento.' }; $status = 'Aplicado'; $detail = 'Sensor de Armazenamento ativado.' }
                    'delivery-cache' { if (-not (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue)) { throw 'Cmdlet de Otimização de Entrega indisponível.' }; Delete-DeliveryOptimizationCache -Force -ErrorAction Stop; $status = 'Aplicado'; $detail = 'Cache de entrega limpo.' }
                    'recycle-bin' { Clear-RecycleBin -Force -ErrorAction Stop; $status = 'Aplicado'; $detail = 'Lixeira esvaziada.' }
                    'fast-startup-off' { & reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power' /v HiberbootEnabled /t REG_DWORD /d 0 /f 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw 'Requer administrador para alterar a inicialização rápida.' }; $status = 'Aplicado'; $detail = 'Inicialização rápida desativada.' }
                    default { throw 'Ação sem implementação.' }
                }
            }
        } catch { $status = 'Falhou'; $detail = $_.Exception.Message }
        $results.Add([pscustomobject]@{ Id=$id; Name=$action.Name; Status=$status; Detail=$detail })
    }
    return $results.ToArray()
}

Export-ModuleMember -Function Format-OptimizerSize, Get-OptimizerTargets, Test-OptimizerPath, Get-OptimizerScan, Invoke-OptimizerCleanup, Get-OptimizerDiagnostics, Export-OptimizerReport, ConvertFrom-OptimizerBatteryReportXml, Get-OptimizerHealthRating, Get-OptimizerBatteryHealth, Save-OptimizerBatteryReport, Get-OptimizerDiskHealth, Get-OptimizerDrivers, Get-OptimizerDriverUpdates, Get-OptimizerBloaTCatalog, Get-OptimizerAppInventory, Invoke-OptimizerAppRemoval, Get-OptimizerOptimizations, Invoke-OptimizerOptimization
