#Requires -Version 5.1
# Comprehensive function validation. Windows-only; all apply operations use -WhatIf.
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') {
    Write-Output 'Function validation skipped outside Windows.'
    return
}
$root = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'Modules/Optimizer.Core.psm1') -Force
Import-Module (Join-Path $root 'Modules/Optimizer.Technician.psm1') -Force
Import-Module (Join-Path $root 'Modules/Optimizer.NetworkDiagnostics.psm1') -Force
Import-Module (Join-Path $root 'Modules/Optimizer.Events.psm1') -Force
Import-Module (Join-Path $root 'Modules/Optimizer.Privacy.psm1') -Force
Import-Module (Join-Path $root 'Modules/Optimizer.Tweaks.psm1') -Force
Import-Module (Join-Path $root 'Modules/Optimizer.Agent.psm1') -Force

function Assert-Validation([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$diagnostics = @(Get-OptimizerDiagnostics)
Assert-Validation ($diagnostics.Count -ge 5) 'Diagnostics did not return rows.'

$battery = Get-OptimizerBatteryHealth
Assert-Validation ($null -ne $battery -and $battery.PSObject.Properties['HasBattery']) 'Battery health shape invalid.'

$diskHealth = Get-OptimizerDiskHealth
Assert-Validation ($null -ne $diskHealth.Disks -and $null -ne $diskHealth.Volumes) 'Disk health shape invalid.'
Assert-Validation (@($diskHealth.Disks).Count -ge 1 -and @($diskHealth.Volumes).Count -ge 1) 'Disk health did not return disks/volumes.'

$drivers = @(Get-OptimizerDrivers)
Assert-Validation ($drivers.Count -ge 1) 'Drivers inventory empty.'

if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) {
    $apps = @(Get-OptimizerAppInventory)
    Assert-Validation ($apps.Count -ge 1) 'App inventory empty when Appx is available.'
    Assert-Validation (@($apps | Where-Object { $_.PSObject.Properties['PackageFullName'] }).Count -ge 1) 'App inventory missing package names.'
}

foreach ($area in @('Processes','Startup','Software','Network','Updates','Storage')) {
    $rows = @(Get-OptimizerTechnicalInventory -Area $area)
    Assert-Validation ($rows.Count -ge 1) "Technician area $area empty."
}
$network = @(Get-OptimizerNetworkSnapshot -IncludeAddresses:$false)
Assert-Validation ($network.Count -ge 1) 'Network snapshot empty.'
$events = Get-OptimizerEventSummary -Days 14
Assert-Validation ($events.Available -or $events.Examined -ge 0) 'Events summary shape invalid.'

foreach ($item in @(Get-OptimizerOptimizations)) {
    $result = @(Invoke-OptimizerOptimization -Ids @($item.Id) -WhatIf) | Select-Object -First 1
    Assert-Validation ($result.Status -eq 'Simulado') "Optimization WhatIf failed for $($item.Id)."
}
foreach ($item in @(Get-OptimizerPrivacyCatalog)) {
    $result = Invoke-OptimizerPrivacyAction -Action $item.Id -WhatIf
    Assert-Validation ($result.Success) "Privacy WhatIf failed for $($item.Id): $($result.Message)"
}
foreach ($presetName in @('Basic','Strict','Extreme')) {
    $preset = @(Get-OptimizerPrivacyPreset -Preset $presetName)
    $catalogIds = @(Get-OptimizerPrivacyCatalog | ForEach-Object { $_.Id })
    Assert-Validation (@($preset | Where-Object { $_ -notin $catalogIds }).Count -eq 0) "Privacy preset $presetName has unknown IDs."
}
foreach ($item in @(Get-OptimizerTweakCatalog)) {
    $result = Invoke-OptimizerTweak -Action $item.Id -WhatIf
    Assert-Validation ($result.Success) "Tweak WhatIf failed for $($item.Id): $($result.Message)"
}

$agent = @(Get-OptimizerAgentRecommendations -Diagnostics $diagnostics -Health ([pscustomobject]@{ Battery=$battery; Disks=$diskHealth }) -AppInventory @() -IsAdmin $false)
Assert-Validation ($agent.Count -ge 1 -and @($agent | Where-Object { $_.AutoApply }).Count -eq 0) 'Agent recommendations invalid or auto-applying.'

Write-Output 'Function-by-function Windows validation passed.'
