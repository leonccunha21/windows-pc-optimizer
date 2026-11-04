# Offline deterministic network validation for Windows PowerShell 5.1 and PowerShell 7.
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../Modules/Optimizer.NetworkDiagnostics.psm1') -Force
function Assert-Network([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
foreach ($hostValue in @('localhost','example.com','8.8.8.8','192.168.1.1','2001:db8::1','sub-domain.example.com')) {
    Assert-Network (Test-OptimizerEndpointInput -HostName $hostValue) "Valid host rejected: $hostValue"
}
foreach ($hostValue in @('',' ','http://example.com','example.com;whoami','example..com','-invalid.com','a/b','a@b','host name','.local','local.','example.com?x=1')) {
    Assert-Network (-not (Test-OptimizerEndpointInput -HostName $hostValue)) "Invalid host accepted: $hostValue"
}
Assert-Network (-not (Test-OptimizerEndpointInput -HostName (('a'*64) + '.com'))) 'Overlong DNS label accepted.'
# All network probes require a user-provided target; invalid input must fail before any traffic.
$rejected = $false
try { Invoke-OptimizerConnectivityCheck -ErrorAction Stop | Out-Null } catch { $rejected = $true }
Assert-Network $rejected 'Outbound testing accepted a missing destination.'
$rejected = $false
try { Invoke-OptimizerConnectivityCheck -Target 'https://example.com' -ErrorAction Stop | Out-Null } catch { $rejected = $true }
Assert-Network $rejected 'Outbound testing accepted an untrusted URL.'
$off = Get-OptimizerAdapterAdvice -AdapterStatus Disconnected
Assert-Network ($off.Level -eq 'Info' -and $off.Finding -match 'não ativa') 'Disconnected advice incorrect.'
$apipa = Get-OptimizerAdapterAdvice -AdapterStatus Up -IPv4Address '169.254.10.2'
Assert-Network ($apipa.Level -eq 'Warning' -and $apipa.Finding -match 'APIPA') 'APIPA advice incorrect.'
$ipv6 = Get-OptimizerAdapterAdvice -AdapterStatus Up
Assert-Network ($ipv6.Finding -match 'IPv4') 'IPv6-only advice incorrect.'
$gateway = Get-OptimizerAdapterAdvice -AdapterStatus Up -IPv4Address '10.0.0.2' -DnsPresent $true
Assert-Network ($gateway.Finding -match 'Gateway') 'Missing gateway advice incorrect.'
$dns = Get-OptimizerAdapterAdvice -AdapterStatus Up -IPv4Address '10.0.0.2' -GatewayPresent $true
Assert-Network ($dns.Finding -match 'DNS') 'Missing DNS advice incorrect.'
$healthy = Get-OptimizerAdapterAdvice -AdapterStatus Up -IPv4Address '10.0.0.2' -GatewayPresent $true -DnsPresent $true
Assert-Network ($healthy.Level -eq 'Info' -and $healthy.Advice -match 'Não confirma') 'Healthy state makes unsupported claims.'
& (Join-Path $PSScriptRoot '../Tools/Diagnostico-Rede.ps1') -ValidateOnly | Out-Null
if ($env:OS -eq 'Windows_NT') {
    $rows = @(Get-OptimizerNetworkSnapshot)
    Assert-Network ($rows.Count -gt 0) 'Windows snapshot missing results.'
    Assert-Network (@($rows | Where-Object { $_.Value -match '^(?:\d{1,3}\.){3}\d{1,3}$' }).Count -eq 0) 'Snapshot disclosed IPv4 without explicit opt-in.'
}
Write-Output 'Network diagnostics offline and local validation passed.'
