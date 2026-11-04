#Requires -Version 5.1
<#
.SYNOPSIS
Executes one allowlisted Windows maintenance command in a separate elevated console.
.DESCRIPTION
Launched only after a user's explicit confirmation and a Windows UAC prompt.
Output stays in the local console. Nothing is downloaded or sent to a server.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('SFC-Verify','DISM-Scan','CHKDSK-Scan','SFC-Repair','DISM-Repair')]
    [string]$Mode
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Esta ferramenta requer Windows.' }
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'É necessária elevação pelo UAC para executar esta ferramenta.'
}
$actions = @{
    'SFC-Verify'  = @{ Exe = 'sfc.exe'; Args = @('/verifyonly') }
    'SFC-Repair'  = @{ Exe = 'sfc.exe'; Args = @('/scannow') }
    'DISM-Scan'   = @{ Exe = 'dism.exe'; Args = @('/Online','/Cleanup-Image','/ScanHealth') }
    'DISM-Repair' = @{ Exe = 'dism.exe'; Args = @('/Online','/Cleanup-Image','/RestoreHealth') }
    'CHKDSK-Scan' = @{ Exe = 'chkdsk.exe'; Args = @($env:SystemDrive,'/scan') }
}
$action = $actions[$Mode]
if ($Mode -eq 'CHKDSK-Scan' -and [string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    throw 'A unidade do Windows não pôde ser identificada.'
}
Write-Host "PC Optimizer | $Mode" -ForegroundColor Cyan
Write-Host 'Execute somente após verificar backup e autorização do proprietário.' -ForegroundColor Yellow
Write-Host ('Comando: {0} {1}' -f $action.Exe, ($action.Args -join ' '))
& $action.Exe @($action.Args)
$code = $LASTEXITCODE
Write-Host ("Processo encerrado com código {0}. Leia as mensagens acima; o código isolado não confirma reparo." -f $code)
if ($code -ne 0) { exit $code }
