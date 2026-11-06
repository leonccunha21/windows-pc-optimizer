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

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    $stream = $null
    try {
        $stream = [IO.File]::OpenRead($Path)
        $hash = $algorithm.ComputeHash($stream)
        return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        $algorithm.Dispose()
    }
}

try {
    & (Join-Path $root 'Tools/Build-Portable.ps1') -Version $version -OutputDirectory $temporary -SkipTests -SkipUiValidation | Out-Null
    $stage = Join-Path $temporary $stageName
    Assert-Portable (Test-Path -LiteralPath $stage -PathType Container) 'Portable staging folder was not created.'

    $onWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    $requiredFiles = @(
        'Iniciar-PC-Optimizer.ps1',
        'Otimizador-GUI.ps1',
        'Otimizar-PC.ps1',
        'Modules/Optimizer.Core.psm1',
        'Modules/Optimizer.Agent.psm1',
        'Modules/Optimizer.ProgramUpdates.psm1',
        'Modules/Optimizer.CleanupCatalog.psm1',
        'UI/MainWindow.xaml',
        'Data/cleanup-rules.json',
        'config/optimizer.psd1',
        'LEIA-ME.txt',
        'README-PORTABLE.md',
        'VERSION.txt',
        'SHA256SUMS.txt'
    )
    if ($onWindows) {
        $requiredFiles += 'PC-Optimizer.exe'
    }
    foreach ($required in $requiredFiles) {
        Assert-Portable (Test-Path -LiteralPath (Join-Path $stage $required) -PathType Leaf) "Missing portable file: $required"
    }

    foreach ($forbidden in @('Tests', '.git', 'Repositorios-Github', 'winscript-portable.exe', 'Tools/Build-Portable.ps1', 'Tools/Portable', 'Iniciar-PC-Optimizer.bat', 'Executar-Otimizador.bat')) {
        Assert-Portable (-not (Test-Path -LiteralPath (Join-Path $stage $forbidden))) "Forbidden development artifact included: $forbidden"
    }
    $batFiles = @(Get-ChildItem -LiteralPath $stage -Recurse -File -Filter '*.bat' -ErrorAction SilentlyContinue)
    Assert-Portable ($batFiles.Count -eq 0) 'Portable package must not contain .bat files.'

    if ($onWindows) {
        $exePath = Join-Path $stage 'PC-Optimizer.exe'
        $exeInfo = Get-Item -LiteralPath $exePath
        Assert-Portable ($exeInfo.Length -gt 0) 'PC-Optimizer.exe is empty.'
        $exeStream = [IO.File]::OpenRead($exePath)
        try {
            $header = New-Object byte[] 2
            Assert-Portable ($exeStream.Read($header, 0, 2) -eq 2) 'PC-Optimizer.exe is truncated.'
            Assert-Portable ($header[0] -eq [byte]77 -and $header[1] -eq [byte]90) 'PC-Optimizer.exe is not a valid PE executable.'
        } finally {
            $exeStream.Dispose()
        }
    }

    $metadata = Get-Content -LiteralPath (Join-Path $stage 'VERSION.txt') -Raw
    Assert-Portable ($metadata.Contains("Version: $version")) 'VERSION.txt does not contain the build version.'

    foreach ($line in @(Get-Content -LiteralPath (Join-Path $stage 'SHA256SUMS.txt'))) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line -split '  ', 2
        Assert-Portable ($parts.Count -eq 2) 'Malformed SHA256SUMS.txt line.'
        $file = Join-Path $stage ($parts[1] -replace '/', [IO.Path]::DirectorySeparatorChar)
        Assert-Portable (Test-Path -LiteralPath $file -PathType Leaf) "Checksum references a missing file: $($parts[1])"
        $actual = Get-Sha256 -Path $file
        Assert-Portable ($actual -eq $parts[0]) "Checksum mismatch: $($parts[1])"
    }

    $zip = Join-Path $temporary "$stageName.zip"
    Assert-Portable (Test-Path -LiteralPath $zip -PathType Leaf) 'Portable ZIP was not created.'
    $shaFile = $zip + '.sha256'
    Assert-Portable (Test-Path -LiteralPath $shaFile -PathType Leaf) 'Portable ZIP checksum was not created.'
    $expectedHash = (Get-Content -LiteralPath $shaFile -Raw).Split(' ')[0]
    $actualHash = Get-Sha256 -Path $zip
    Assert-Portable ($expectedHash -eq $actualHash) 'Portable ZIP checksum does not match.'

    if ($onWindows) {
        $launcherExe = Join-Path $stage 'PC-Optimizer.exe'
        if (Test-Path -LiteralPath $launcherExe -PathType Leaf) {
            $launcherSelfTest = Start-Process -FilePath $launcherExe -ArgumentList '-SelfTest' -Wait -PassThru
            Assert-Portable ($launcherSelfTest.ExitCode -eq 0) 'Native launcher self-test failed.'
        }
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
