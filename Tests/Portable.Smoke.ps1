#Requires -Version 5.1
# Verifies the standalone portable build without touching the real user profile.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('optimizer-portable-test-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temporary -Force)
$version = '0.0-test'
$stageName = "PC-Optimizer-Portable-$version"

function Assert-Portable([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

try {
    & (Join-Path $root 'Tools/Build-Portable.ps1') -Version $version -OutputDirectory $temporary -SkipTests -SkipUiValidation | Out-Null
    $stage = Join-Path $temporary $stageName
    Assert-Portable (Test-Path -LiteralPath $stage -PathType Container) 'Portable staging folder was not created.'

    foreach ($required in @(
        'Iniciar-PC-Optimizer.bat',
        'Iniciar-PC-Optimizer.ps1',
        'Executar-Otimizador.bat',
        'Otimizador-GUI.ps1',
        'Otimizar-PC.ps1',
        'Modules/Optimizer.Core.psm1',
        'Modules/Optimizer.CleanupCatalog.psm1',
        'UI/MainWindow.xaml',
        'Data/cleanup-rules.json',
        'config/optimizer.psd1',
        'LEIA-ME.txt',
        'README-PORTABLE.md',
        'VERSION.txt',
        'SHA256SUMS.txt'
    )) {
        Assert-Portable (Test-Path -LiteralPath (Join-Path $stage $required) -PathType Leaf) "Missing portable file: $required"
    }

    foreach ($forbidden in @('Tests', '.git', 'Repositorios-Github', 'winscript-portable.exe', 'Tools/Build-Portable.ps1', 'Tools/Portable')) {
        Assert-Portable (-not (Test-Path -LiteralPath (Join-Path $stage $forbidden))) "Forbidden development artifact included: $forbidden"
    }

    $metadata = Get-Content -LiteralPath (Join-Path $stage 'VERSION.txt') -Raw
    Assert-Portable ($metadata.Contains("Version: $version")) 'VERSION.txt does not contain the build version.'

    foreach ($line in @(Get-Content -LiteralPath (Join-Path $stage 'SHA256SUMS.txt'))) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line -split '  ', 2
        Assert-Portable ($parts.Count -eq 2) 'Malformed SHA256SUMS.txt line.'
        $file = Join-Path $stage ($parts[1] -replace '/', [IO.Path]::DirectorySeparatorChar)
        Assert-Portable (Test-Path -LiteralPath $file -PathType Leaf) "Checksum references a missing file: $($parts[1])"
        $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-Portable ($actual -eq $parts[0]) "Checksum mismatch: $($parts[1])"
    }

    $zip = Join-Path $temporary "$stageName.zip"
    Assert-Portable (Test-Path -LiteralPath $zip -PathType Leaf) 'Portable ZIP was not created.'
    $shaFile = $zip + '.sha256'
    Assert-Portable (Test-Path -LiteralPath $shaFile -PathType Leaf) 'Portable ZIP checksum was not created.'
    $expectedHash = (Get-Content -LiteralPath $shaFile -Raw).Split(' ')[0]
    $actualHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-Portable ($expectedHash -eq $actualHash) 'Portable ZIP checksum does not match.'

    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf) {
            & $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $stage 'Iniciar-PC-Optimizer.ps1') -SelfTest | Out-Null
            Assert-Portable ($LASTEXITCODE -eq 0) 'Portable self-test failed.'
        }
    }

    Write-Output 'Portable build, structure, checksums, ZIP and self-test passed.'
} finally {
    if (Test-Path -LiteralPath $temporary) {
        Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
    }
}
