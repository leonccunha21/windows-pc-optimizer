#Requires -Version 5.1
Set-StrictMode -Version 2.0

function Get-OptimizerTechnicalInventory {
    <#
    .SYNOPSIS
    Collects read-only technician inventory from the current Windows computer.
    .DESCRIPTION
    Returns a uniform four-column model. No commands are executed against
    services, the registry or user files. No data is sent or persisted.
    .PARAMETER Area
    Read-only inventory type.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Processes','Startup','Software','Network','Updates','Storage')]
        [string]$Area,
        [hashtable]$State = @{ Cancel = $false; Message = '' }
    )
    if ($env:OS -ne 'Windows_NT') { throw 'Inventário técnico requer Windows.' }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    $State.Message = 'Consultando ' + $Area + '...'
    $addRow = {
        param([string]$Name,[string]$Detail,[string]$Status)
        $rows.Add([pscustomobject]@{
            Area = $Area
            Name = $Name
            Detail = $Detail
            Status = $Status
        })
    }
    try {
        switch ($Area) {
            'Processes' {
                foreach ($p in @(Get-Process -ErrorAction Stop | Sort-Object WorkingSet64 -Descending | Select-Object -First 65)) {
                    if ($State.Cancel) { break }
                    & $addRow $p.ProcessName ('PID {0} · RAM {1:N1} MB' -f $p.Id, ([double]$p.WorkingSet64 / 1MB)) 'Executando'
                }
            }
            'Startup' {
                $paths = @(
                    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
                    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
                    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
                )
                foreach ($path in $paths) {
                    if ($State.Cancel) { break }
                    if (-not (Test-Path -LiteralPath $path)) { continue }
                    $entry = Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
                    if ($null -eq $entry) { continue }
                    foreach ($prop in $entry.PSObject.Properties) {
                        if ($prop.Name -match '^PS(Path|ParentPath|ChildName|Drive|Provider)$') { continue }
                        # Registry command strings can contain user data; expose only the program name.
                        $location = if ($path -like 'HKCU*') { 'Registro do usuário' } else { 'Registro do computador' }
                        & $addRow $prop.Name $location 'Revisar no Windows'
                    }
                }
                foreach ($folder in @(
                    [Environment]::GetFolderPath('Startup'),
                    [Environment]::GetFolderPath('CommonStartup')
                )) {
                    if ($State.Cancel) { break }
                    if (-not $folder -or -not (Test-Path -LiteralPath $folder)) { continue }
                    foreach ($file in @(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue)) {
                        & $addRow $file.BaseName 'Pasta de inicialização' 'Revisar no Windows'
                    }
                }
            }
            'Software' {
                $keys = @(
                    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
                )
                $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
                foreach ($key in $keys) {
                    if ($State.Cancel) { break }
                    foreach ($entry in @(Get-ItemProperty -Path $key -ErrorAction SilentlyContinue)) {
                        if ($State.Cancel) { break }
                        $nameProperty = $entry.PSObject.Properties['DisplayName']
                        if ($null -eq $nameProperty -or [string]::IsNullOrWhiteSpace([string]$nameProperty.Value)) { continue }
                        $versionProperty = $entry.PSObject.Properties['DisplayVersion']
                        $publisherProperty = $entry.PSObject.Properties['Publisher']
                        $version = if ($null -ne $versionProperty) { [string]$versionProperty.Value } else { '' }
                        $publisher = if ($null -ne $publisherProperty) { [string]$publisherProperty.Value } else { '' }
                        $identity = [string]$nameProperty.Value + '|' + $version
                        if (-not $seen.Add($identity)) { continue }
                        & $addRow ([string]$nameProperty.Value) ('Versão: ' + $version) $publisher
                        if ($rows.Count -ge 250) { break }
                    }
                }
            }
            'Network' {
                foreach ($adapter in @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction Stop)) {
                    if ($State.Cancel) { break }
                    # IPs and hardware addresses are deliberately excluded from inventory output.
                    & $addRow ([string]$adapter.Description) 'Adaptador IP ativo' ('DHCP: ' + [string]$adapter.DHCPEnabled)
                }
            }
            'Updates' {
                foreach ($update in @(Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending | Select-Object -First 60)) {
                    if ($State.Cancel) { break }
                    & $addRow ([string]$update.HotFixID) ([string]$update.Description) ([string]$update.InstalledOn)
                }
            }
            'Storage' {
                foreach ($disk in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)) {
                    if ($State.Cancel) { break }
                    $sizeGB = [math]::Round(([double]$disk.Size / 1GB), 1)
                    $freeGB = [math]::Round(([double]$disk.FreeSpace / 1GB), 1)
                    & $addRow ([string]$disk.DeviceID) ("Capacidade: {0} GB" -f $sizeGB) ("Livre: {0} GB" -f $freeGB)
                }
            }
        }
    } catch {
        # Display failures rather than making an unsupported health claim.
        & $addRow 'Consulta indisponível' $_.Exception.Message 'Verificar permissões'
    }
    if ($rows.Count -eq 0 -and -not $State.Cancel) {
        & $addRow 'Nenhum dado encontrado' 'O Windows não retornou registros para esta seção.' 'Sem resultados'
    }
    $State.Message = if ($State.Cancel) { 'Consulta interrompida.' } else { 'Consulta concluída.' }
    return $rows.ToArray()
}

Export-ModuleMember -Function Get-OptimizerTechnicalInventory
