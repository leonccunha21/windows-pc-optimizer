#Requires -Version 5.1
<#
.SYNOPSIS
Installed-program updater backed by winget.

.DESCRIPTION
Read-only listing first (Get-OptimizerProgramUpdates), then explicit
selection + confirmation before Invoke-OptimizerProgramUpdates runs
`winget upgrade`. Supports -WhatIf. No telemetry or network calls are made
by this module itself; winget contacts its configured sources only when
listing/upgrading.
#>
Set-StrictMode -Version 2.0

function Get-OptimizerProgramUpdates {
    [CmdletBinding()]
    param([string]$WingetPath = '')
    $result = [pscustomobject]@{ Available=$false; Updates=@(); Error='' }
    if ($env:OS -ne 'Windows_NT') {
        $result.Error = 'Atualização de programas disponível apenas no Windows.'
        return $result
    }
    $winget = $WingetPath
    if ([string]::IsNullOrWhiteSpace($winget)) {
        $command = Get-Command winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) { $winget = $command.Source }
    }
    if ([string]::IsNullOrWhiteSpace($winget) -or -not (Test-Path -LiteralPath $winget)) {
        $result.Error = 'winget não encontrado. Instale o App Installer / winget para verificar atualizações de programas.'
        return $result
    }
    try {
        $output = & $winget upgrade --accept-source-agreements --disable-interactivity 2>&1 | Out-String
        $lines = @($output -split "`r?`n")
        $updates = New-Object 'System.Collections.Generic.List[object]'
        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line -match 'Nome' -and $line -match 'ID' -and $line -match 'Origem') { continue }
            if ($line -match '^-{3,}') { continue }
            if ($line -match 'atualizaç') { continue }
            $tokens = @($line.Trim() -split '\s+')
            if ($tokens.Count -lt 5) { continue }
            $source = [string]$tokens[$tokens.Count - 1]
            $available = [string]$tokens[$tokens.Count - 2]
            $version = [string]$tokens[$tokens.Count - 3]
            $id = [string]$tokens[$tokens.Count - 4]
            $name = (@($tokens[0..($tokens.Count - 5)]) -join ' ')
            if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($id)) { continue }
            $updates.Add([pscustomobject]@{
                Selected=$false
                Name=$name
                Id=$id
                Version=$version
                AvailableVersion=$available
                Source=$source
            })
        }
        $result.Updates = $updates.ToArray()
        $result.Available = $updates.Count -gt 0
    } catch {
        $result.Error = 'Não foi possível consultar o winget: ' + $_.Exception.Message
    }
    return $result
}

function Invoke-OptimizerProgramUpdates {
    <#
    .SYNOPSIS
    Upgrades selected programs with winget.
    .DESCRIPTION
    Only the explicit IDs passed by the caller are upgraded. Supports
    -WhatIf. Elevate the session if machine-wide installers require it.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string[]]$Ids,
        [string]$WingetPath = ''
    )
    $results = New-Object 'System.Collections.Generic.List[object]'
    if ($env:OS -ne 'Windows_NT') {
        foreach ($id in $Ids) {
            $results.Add([pscustomobject]@{ Id=$id; Status='Falhou'; Detail='Disponível apenas no Windows.' })
        }
        return $results.ToArray()
    }
    $winget = $WingetPath
    if ([string]::IsNullOrWhiteSpace($winget)) {
        $command = Get-Command winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) { $winget = $command.Source }
    }
    if ([string]::IsNullOrWhiteSpace($winget)) {
        foreach ($id in $Ids) {
            $results.Add([pscustomobject]@{ Id=$id; Status='Falhou'; Detail='winget não encontrado.' })
        }
        return $results.ToArray()
    }
    foreach ($id in $Ids) {
        $status = 'Ignorado'
        $detail = ''
        try {
            if (-not $PSCmdlet.ShouldProcess($id, 'Atualizar programa com winget')) {
                $status = 'Simulado'
                $detail = 'Nenhuma alteração feita.'
            } else {
                $arguments = @(
                    'upgrade',
                    '--id', $id,
                    '--exact',
                    '--accept-source-agreements',
                    '--accept-package-agreements',
                    '--disable-interactivity'
                )
                $output = & $winget @arguments 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0) { throw ($output.Trim().Split("`n") | Select-Object -Last 1) }
                $status = 'Aplicado'
                $detail = 'Atualizado com winget.'
            }
        } catch {
            $status = 'Falhou'
            $detail = $_.Exception.Message
        }
        $results.Add([pscustomobject]@{ Id=$id; Status=$status; Detail=$detail })
    }
    return $results.ToArray()
}

Export-ModuleMember -Function Get-OptimizerProgramUpdates, Invoke-OptimizerProgramUpdates
