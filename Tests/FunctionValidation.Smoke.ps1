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
Import-Module (Join-Path $root 'Modules/Optimizer.ProgramUpdates.psm1') -Force

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

$apps = @(Get-OptimizerAppInventory)
if ($PSVersionTable.PSEdition -eq 'Desktop') {
    Assert-Validation ($apps.Count -ge 1) 'App inventory empty on Windows PowerShell.'
    Assert-Validation (@($apps | Where-Object { $_.PSObject.Properties['PackageFullName'] }).Count -ge 1) 'App inventory missing package names.'
} else {
    Assert-Validation ($null -ne $apps) 'App inventory must not throw on PowerShell 7 when Appx is unavailable.'
}
$driverUpdates = Get-OptimizerDriverUpdates
Assert-Validation ($null -ne $driverUpdates -and $null -ne $driverUpdates.Updates) 'Driver updates shape invalid.'
$driverInstallWhatIf = @(Invoke-OptimizerDriverUpdates -WhatIf)
Assert-Validation (@($driverInstallWhatIf | Where-Object { $_.Status -notin @('Simulado','Ignorado') }).Count -eq 0) 'Driver install WhatIf did not simulate safely.'
$programUpdates = Get-OptimizerProgramUpdates
Assert-Validation ($null -ne $programUpdates -and $null -ne $programUpdates.Updates) 'Program updates shape invalid.'
if (@($programUpdates.Updates).Count -gt 0) {
    $programWhatIf = Invoke-OptimizerProgramUpdates -Ids @($programUpdates.Updates[0].Id) -WhatIf
    Assert-Validation ($programWhatIf.Status -eq 'Simulado') 'Program update WhatIf did not simulate safely.'
}
$validationDirectory = Join-Path ([IO.Path]::GetTempPath()) ('optimizer-function-validation-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $validationDirectory -Force)
try {
    $batteryReportPath = Join-Path $validationDirectory 'bateria.html'
    $savedBatteryReport = Save-OptimizerBatteryReport -Path $batteryReportPath
    Assert-Validation (Test-Path -LiteralPath $savedBatteryReport) 'Battery report file was not created.'
    $reportHtml = Join-Path $validationDirectory 'relatorio.html'
    $reportJson = Join-Path $validationDirectory 'relatorio.json'
    Export-OptimizerReport -Path $reportHtml -Customer 'Validacao' -Notes 'Teste' -Diagnostics $diagnostics -Format HTML
    Export-OptimizerReport -Path $reportJson -Customer 'Validacao' -Notes 'Teste' -Diagnostics $diagnostics -Format JSON
    Assert-Validation ((Test-Path -LiteralPath $reportHtml) -and (Test-Path -LiteralPath $reportJson)) 'Report export files were not created.'
    $jsonText = Get-Content -LiteralPath $reportJson -Raw
    Assert-Validation ($jsonText -notmatch 'C:\\Users\\') 'JSON report exposed a user path.'
} finally {
    if (Test-Path -LiteralPath $validationDirectory) { Remove-Item -LiteralPath $validationDirectory -Recurse -Force }
}

foreach ($area in @('Processes','Startup','Software','Network','Updates','Storage')) {
    $rows = @(Get-OptimizerTechnicalInventory -Area $area)
    Assert-Validation ($rows.Count -ge 1) "Technician area $area empty."
}
$network = @(Get-OptimizerNetworkSnapshot -IncludeAddresses:$false)
Assert-Validation ($network.Count -ge 1) 'Network snapshot empty.'
$probe = @(Invoke-OptimizerConnectivityCheck -DnsName 'localhost' -Target '127.0.0.1' -Port 135)
Assert-Validation ($probe.Count -ge 1) 'Network probe returned no rows.'
$events = Get-OptimizerEventSummary -Days 14
Assert-Validation ($events.Available -or $events.Examined -ge 0) 'Events summary shape invalid.'
$repairPath = Join-Path $root 'Modules/Repair.Tools.ps1'
$repairTokens = $null; $repairErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($repairPath, [ref]$repairTokens, [ref]$repairErrors)
Assert-Validation (@($repairErrors).Count -eq 0) 'Repair.Tools.ps1 has parse errors.'
$repairText = Get-Content -LiteralPath $repairPath -Raw
foreach ($mode in @('SFC-Verify','DISM-Scan','CHKDSK-Scan','SFC-Repair','DISM-Repair')) {
    Assert-Validation ($repairText -match [regex]::Escape($mode)) "Repair mode missing: $mode"
}

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
