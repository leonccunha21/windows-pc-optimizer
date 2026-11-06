#Requires -Version 5.1
<#
.SYNOPSIS
Starts the portable PC Optimizer and keeps its local data beside the package.

.DESCRIPTION
This launcher is copied to the root of the portable package. It validates the
required runtime files, prepares a writable data folder (Dados) and starts the
WPF interface with the same arguments it received. No installer, repository,
telemetry or network access is required.

Use -SelfTest to validate the package without opening the interface.
#>
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$gui = Join-Path $root 'Otimizador-GUI.ps1'
$selfTest = @($args) -contains '-SelfTest'

$required = @(
    'Otimizador-GUI.ps1',
    'Modules/Optimizer.Core.psm1',
    'Modules/Optimizer.Preferences.psm1',
    'Modules/Optimizer.Privacy.psm1',
    'Modules/Optimizer.Tweaks.psm1',
    'Modules/Optimizer.Technician.psm1',
    'Modules/Optimizer.NetworkDiagnostics.psm1',
    'Modules/Optimizer.Events.psm1',
    'Modules/Optimizer.CleanupCatalog.psm1',
    'Modules/Repair.Tools.ps1',
    'UI/MainWindow.xaml',
    'Data/cleanup-rules.json',
    'config/optimizer.psd1'
)

function Test-PortableDataDirectory {
    param([Parameter(Mandatory)][string]$Path)
    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop)
        }
        $probe = Join-Path $Path ('.write-test-' + [guid]::NewGuid().ToString('N'))
        [IO.File]::WriteAllText($probe, 'ok')
        Remove-Item -LiteralPath $probe -Force -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Write-PortableError {
    param([Parameter(Mandatory)][string]$Message)
    try {
        $logDirectory = if ([string]::IsNullOrWhiteSpace($env:PC_OPTIMIZER_LOG_DIR)) {
            Join-Path $root 'Dados/Logs'
        } else {
            $env:PC_OPTIMIZER_LOG_DIR
        }
        if (-not (Test-Path -LiteralPath $logDirectory -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction SilentlyContinue)
        }
        $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
        Add-Content -LiteralPath (Join-Path $logDirectory 'portable-launcher.log') -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {
        Write-Verbose 'Não foi possível registrar o erro do launcher portátil.'
    }
}

$missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_) -PathType Leaf) })
if ($missing.Count -gt 0) {
    $message = 'Arquivos obrigatórios ausentes: ' + ($missing -join ', ')
    Write-PortableError $message
    Write-Host 'ERRO: o pacote portátil está incompleto.' -ForegroundColor Red
    Write-Host $message
    Write-Host 'Extraia novamente o ZIP completo do PC Optimizer Portable.'
    exit 2
}

# WPF requires an STA thread. Relaunch only when the user started the .ps1
# directly from a non-STA shell; the .bat launcher already passes -STA.
if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
    try {
        $hostPath = (Get-Process -Id $PID).Path
        $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
        $childArguments = @('-NoLogo', '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) + @($args)
        $child = Start-Process -FilePath $hostPath -ArgumentList $childArguments -Wait -PassThru
        exit $child.ExitCode
    } catch {
        Write-PortableError ('Falha ao reiniciar em STA: ' + $_.Exception.Message)
        Write-Host 'ERRO: não foi possível iniciar a interface em modo STA.' -ForegroundColor Red
        exit 3
    }
}

$dataDirectory = Join-Path $root 'Dados'
if (-not (Test-PortableDataDirectory -Path $dataDirectory)) {
    $dataDirectory = Join-Path ([IO.Path]::GetTempPath()) 'PCOptimizer-Portable'
    if (-not (Test-PortableDataDirectory -Path $dataDirectory)) {
        $message = 'Não foi possível criar uma pasta de dados gravável em Dados ou em %TEMP%.'
        Write-PortableError $message
        Write-Host "ERRO: $message" -ForegroundColor Red
        exit 4
    }
}

$logDirectory = Join-Path $dataDirectory 'Logs'
[void](New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction SilentlyContinue)

$env:PC_OPTIMIZER_PORTABLE = '1'
$env:PC_OPTIMIZER_PORTABLE_DATA = $dataDirectory
$env:PC_OPTIMIZER_HOME = $root
$env:PC_OPTIMIZER_LOG_DIR = $logDirectory

if ($selfTest) {
    Import-Module (Join-Path $root 'Modules/Optimizer.Preferences.psm1') -Force
    $preferencesPath = Get-OptimizerPreferencesPath
    $expectedPreferences = Join-Path $dataDirectory 'preferences.json'
    if ($preferencesPath -ne $expectedPreferences) {
        throw "O caminho de preferências portátil não foi aplicado: $preferencesPath"
    }
    Write-Output 'Portable self-test passed.'
    Write-Output "Package: $root"
    Write-Output "Data: $dataDirectory"
    Write-Output "Preferences: $preferencesPath"
    exit 0
}

Set-Location -LiteralPath $root
try {
    & $gui @args
    exit 0
} catch {
    $message = $_.Exception.Message
    Write-PortableError $message
    Write-Host ''
    Write-Host 'PC Optimizer encontrou um erro ao iniciar.' -ForegroundColor Red
    Write-Host $message
    Write-Host "Detalhes: $(Join-Path $logDirectory 'portable-launcher.log')"
    exit 1
}
