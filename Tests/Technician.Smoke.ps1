# Read-only inventory API and destructive-command allowlist safety.
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot '../Modules/Optimizer.Technician.psm1'
$repairPath = Join-Path $PSScriptRoot '../Modules/Repair.Tools.ps1'
Import-Module $modulePath -Force
if (-not (Get-Command Get-OptimizerTechnicalInventory -ErrorAction Stop)) { throw 'Inventory command missing' }
$failed = $false
try { Get-OptimizerTechnicalInventory -Area 'Untrusted' -ErrorAction Stop | Out-Null } catch { $failed = $true }
if (-not $failed) { throw 'Untrusted inventory action was accepted' }
$repairSource = Get-Content -LiteralPath $repairPath -Raw
foreach ($action in @('SFC-Verify','DISM-Scan','CHKDSK-Scan','SFC-Repair','DISM-Repair')) {
    if (-not $repairSource.Contains("'$action'")) { throw "Repair allowlist does not include $action" }
}
if ($repairSource -match '(?i)Invoke-Expression|iex[ (]|https?://') { throw 'Remote script or dynamic execution detected in repair launcher' }
if ($env:OS -eq 'Windows_NT') {
    $rows = @(Get-OptimizerTechnicalInventory -Area Processes)
    if ($rows.Count -eq 0 -or $rows[0].PSObject.Properties.Name -notcontains 'Detail') { throw 'Processes inventory is empty or invalid' }
    $cancelled = @(Get-OptimizerTechnicalInventory -Area Processes -State @{ Cancel=$true; Message='' })
    if ($cancelled.Count -gt 1) { throw 'Inventory ignores cancellation' }
}
Write-Output 'Technical inventory and repair command allowlist validated.'
