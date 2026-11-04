# Offline Windows Event Diagnostics regressions (no real logs, no machine changes).
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../Modules/Optimizer.Events.psm1') -Force
function Assert-OptimizerEvent([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
$catalog=@(Get-OptimizerEventCatalog)
Assert-OptimizerEvent ($catalog.Count -ge 12) 'The allowlist is missing expected event categories.'
$now=[datetime]'2026-11-04T12:00:00Z'
$sample=@(
    [pscustomobject]@{ProviderName='Microsoft-Windows-Kernel-Power';Id=41;TimeCreated=$now;Message='PRIVATE-CUSTOMER-PATH-C:\\Users\\Client\\Secrets'}
    [pscustomobject]@{ProviderName='disk';Id=7;TimeCreated=$now.AddMinutes(-1);Message='PRIVATE-CUSTOMER-PATH-C:\\Users\\Client\\Secrets'}
    [pscustomobject]@{ProviderName='Microsoft-Windows-WHEA-Logger';Id=18;TimeCreated=$now.AddMinutes(-2);Message='PRIVATE-SECRET'}
    [pscustomobject]@{ProviderName='Service Control Manager';Id=7031;TimeCreated=$now.AddMinutes(-3);Message='PRIVATE-SECRET'}
    [pscustomobject]@{ProviderName='UnrecognizedTool';Id=7;TimeCreated=$now;Message='PRIVATE-SECRET'}
    [pscustomobject]@{ProviderName='disk';Id=9999;TimeCreated=$now;Message='PRIVATE-SECRET'}
)
$result=Get-OptimizerEventSummary -Records $sample -Days 14 -MaxEvents 100
Assert-OptimizerEvent ($result.Examined -eq 6) 'Unexpected number of events examined.'
Assert-OptimizerEvent ($result.Matched -eq 4) 'Wrong provider or ID classification.'
Assert-OptimizerEvent ($result.Categories.Count -eq 4) 'Category aggregation failed.'
Assert-OptimizerEvent ($result.Available -and -not $result.Truncated) 'Offline records erroneously marked unavailable.'
Assert-OptimizerEvent (@($result.Categories | Where-Object { $_.Category -eq 'Armazenamento / E/S' }).Count -eq 1) 'Disk classification failed.'
$serialized=ConvertTo-Json -InputObject $result -Depth 8
Assert-OptimizerEvent (-not $serialized.Contains('PRIVATE-SECRET')) 'Raw private messages leaked to results.'
Assert-OptimizerEvent (-not $serialized.Contains('PRIVATE-CUSTOMER-PATH')) 'Paths leaked to results.'
Assert-OptimizerEvent (-not $serialized.Contains('UnrecognizedTool')) 'Unexpected providers leaked.'
$empty=Get-OptimizerEventSummary -Records @() -Days 7 -MaxEvents 100
Assert-OptimizerEvent ($empty.Examined -eq 0 -and $empty.Matched -eq 0) 'Empty event set not handled.'
Assert-OptimizerEvent (@($empty.Warnings | Where-Object { $_ -match 'não comprova ausência' }).Count -eq 1) 'Empty event set must not claim a healthy PC.'
$cancelled=Get-OptimizerEventSummary -Records $sample -State @{Cancel=$true;Message=''} -MaxEvents 100
Assert-OptimizerEvent ($cancelled.Cancelled -and $cancelled.Examined -eq 0) 'Cancellation not respected.'
$many=New-Object 'System.Collections.Generic.List[object]'
for($i=0;$i -lt 105;$i++) {
    $many.Add([pscustomobject]@{ProviderName='disk';Id=153;TimeCreated=$now.AddMinutes(-$i);Message='PRIVATE-SECRET'})
}
$limited=Get-OptimizerEventSummary -Records $many.ToArray() -MaxEvents 100
Assert-OptimizerEvent ($limited.Truncated -and $limited.Examined -eq 100 -and $limited.Matched -eq 100) 'Event query bound not enforced.'
& (Join-Path $PSScriptRoot '../Tools/Diagnostico-Eventos.ps1') -ValidateOnly | Out-Null
Write-Output 'Event-log diagnostic classification, limits, cancellation, and privacy validated.'
