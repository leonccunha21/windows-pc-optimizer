#Requires -Version 5.1
<#
.SYNOPSIS
Technician's read-only network inventory and optional connectivity tests.
.EXAMPLE
powershell.exe -NoProfile -File .\Tools\Diagnostico-Rede.ps1
.EXAMPLE
powershell.exe -NoProfile -File .\Tools\Diagnostico-Rede.ps1 -IncludeAddresses
.EXAMPLE
powershell.exe -NoProfile -File .\Tools\Diagnostico-Rede.ps1 -DnsName example.com -Target example.com -Port 443
#>
[CmdletBinding()]
param(
    [switch]$IncludeAddresses,
    [string]$DnsName = '',
    [string]$Target = '',
    [ValidateRange(1,65535)][int]$Port = 443,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot '../Modules/Optimizer.NetworkDiagnostics.psm1'
Import-Module $modulePath -Force -ErrorAction Stop
if ($ValidateOnly) {
    foreach ($command in @('Test-OptimizerEndpointInput','Get-OptimizerAdapterAdvice','Get-OptimizerNetworkSnapshot','Invoke-OptimizerConnectivityCheck')) {
        if (-not (Get-Command -Name $command -ErrorAction SilentlyContinue)) { throw "Comando ausente: $command" }
    }
    Write-Output 'Diagnóstico de rede: módulo carregado e comandos disponíveis.'
    return
}
if ($DnsName -and -not (Test-OptimizerEndpointInput -HostName $DnsName)) { throw 'Destino DNS inválido.' }
if ($Target -and -not (Test-OptimizerEndpointInput -HostName $Target -Port $Port)) { throw 'Destino de teste inválido.' }
if ($env:OS -ne 'Windows_NT') { throw 'Abra esta ferramenta no Windows.' }
Write-Host 'PC Optimizer | Diagnóstico de rede local' -ForegroundColor Cyan
Write-Host 'Consulta sem alterações no sistema. Endereços são ocultos por padrão.' -ForegroundColor Gray
$state = @{Cancel=$false;Message=''}
@(Get-OptimizerNetworkSnapshot -IncludeAddresses:$IncludeAddresses -State $state) |
    Format-Table -Property Area,Item,Value,Level -AutoSize -Wrap | Out-Host
if ($Target -or $DnsName) {
    Write-Host 'Consultas externas explicitamente solicitadas:' -ForegroundColor Yellow
    @(Invoke-OptimizerConnectivityCheck -DnsName $DnsName -Target $Target -Port $Port -State $state) |
        Format-Table -Property Area,Item,Value,Level -AutoSize -Wrap | Out-Host
} else {
    Write-Host 'Nenhum teste externo iniciado. Use -Target ou -DnsName somente com autorização.' -ForegroundColor Gray
}
