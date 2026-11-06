#Requires -Version 5.1
# Local agent smoke: deterministic, no network, no telemetry, never auto-applies.
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../Modules/Optimizer.Agent.psm1') -Force

function Assert-Agent([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$scan = [pscustomobject]@{
    Bytes = 600MB
    Categories = @(
        [pscustomobject]@{ Id='chrome-cache'; Bytes=300MB; Risk='Baixo' },
        [pscustomobject]@{ Id='win-temp'; Bytes=250MB; Risk='Baixo' },
        [pscustomobject]@{ Id='risky'; Bytes=400MB; Risk='Alto' }
    )
}
$health = [pscustomobject]@{
    Battery = [pscustomobject]@{ HealthPercent = 72 }
    Disks = @([pscustomobject]@{ Rating = 'Atenção' })
    Volumes = @([pscustomobject]@{ Free = '10 GB'; Total = '100 GB' })
}
$recommendations = Get-OptimizerAgentRecommendations `
    -Diagnostics @([pscustomobject]@{ Area='Segurança'; Item='Defender em tempo real'; Value='False' }) `
    -Health $health -Scan $scan -AppInventory @([pscustomobject]@{ Suggested=$true }) -IsAdmin $true

Assert-Agent (@($recommendations).Count -ge 5) 'Agent returned too few recommendations.'
Assert-Agent (@($recommendations | Where-Object { $_.AutoApply }).Count -eq 0) 'Agent must never auto-apply.'
Assert-Agent (@($recommendations | Where-Object { -not $_.RequiresConfirmation }).Count -eq 0) 'Every recommendation must require confirmation.'
$cleanup = $recommendations | Where-Object { $_.Area -eq 'Limpeza' } | Select-Object -First 1
Assert-Agent ($null -ne $cleanup) 'Cleanup recommendation missing.'
Assert-Agent ($cleanup.CleanupCategoryIds -contains 'chrome-cache') 'Cleanup recommendation should include high-gain categories.'
Assert-Agent ($cleanup.CleanupCategoryIds -notcontains 'risky') 'High-risk categories must not be recommended for cleanup.'
$privacy = $recommendations | Where-Object { $_.Area -eq 'Privacidade' } | Select-Object -First 1
Assert-Agent ($privacy.PrivacyIds -contains 'DisableWindowsTelemetry') 'Basic telemetry recommendation missing.'
Assert-Agent ($recommendations[0].Priority -ge $recommendations[-1].Priority) 'Recommendations must be sorted by priority.'

$empty = Get-OptimizerAgentRecommendations
Assert-Agent (@($empty).Count -ge 1) 'Empty input should still recommend running a scan.'
Assert-Agent ($empty[0].Title -match 'análise') 'Empty input should recommend a cleanup scan first.'

Write-Output 'Local agent recommendations, safety gates and sorting passed.'
