#Requires -Version 5.1
<#
.SYNOPSIS
Builds the standalone PC Optimizer Portable package.

.DESCRIPTION
Copies only the runtime files, validates PowerShell/XAML, writes package
metadata and checksums, and optionally creates a ZIP with a .sha256 file.
The repository tests, docs, .git directory and local artifacts are never copied.

.PARAMETER Version
Package version. Defaults to the VERSION file at the repository root.
A leading "v" is accepted and removed for the folder/ZIP name.

.PARAMETER OutputDirectory
Destination directory. Defaults to <repo>/dist.

.PARAMETER NoZip
Creates only the staging folder, without the ZIP/checksum artifacts.

.PARAMETER SkipTests
Skips Tests/Validate-Syntax.ps1. Use only when the caller already validated.

.PARAMETER SkipUiValidation
Skips the portable self-test. Useful on non-Windows build agents.
#>
[CmdletBinding()]
param(
    [string]$Version = '',
    [string]$OutputDirectory = '',
    [switch]$NoZip,
    [switch]$SkipTests,
    [switch]$SkipUiValidation
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ('==> ' + $Message) -ForegroundColor Cyan
}

function Get-NormalizedVersion {
    param([string]$Value)
    $normalized = ([string]$Value).Trim()
    if ($normalized.StartsWith('v', [StringComparison]::OrdinalIgnoreCase)) {
        $normalized = $normalized.Substring(1)
    }
    $normalized = $normalized -replace '[^0-9A-Za-z._-]', '-'
    if ([string]::IsNullOrWhiteSpace($normalized)) { throw 'Versão inválida para o pacote portátil.' }
    return $normalized
}

function Copy-PortableFile {
    param([Parameter(Mandatory)][string]$RelativePath)
    $source = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Arquivo obrigatório ausente: $RelativePath"
    }
    $destination = Join-Path $script:StageDirectory $RelativePath
    $destinationDirectory = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $destinationDirectory -Force)
    }
    Copy-Item -LiteralPath $source -Destination $destination -Force
}

function Copy-PortableDirectory {
    param([Parameter(Mandatory)][string]$RelativePath)
    $source = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw "Diretório obrigatório ausente: $RelativePath"
    }
    $destination = Join-Path $script:StageDirectory $RelativePath
    Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
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

function ConvertTo-AssemblyVersion {
    param([Parameter(Mandatory)][string]$Version)
    $parts = @($Version -split '[._-]' | Where-Object { $_ -match '^\d+$' })
    if ($parts.Count -eq 0) { return '0.0.0.0' }
    while ($parts.Count -lt 4) { $parts += '0' }
    return ($parts[0..3] -join '.')
}

function Get-CSharpCompiler {
    $candidates = New-Object 'System.Collections.Generic.List[string]'
    if (-not [string]::IsNullOrWhiteSpace($env:SystemRoot)) {
        $candidates.Add((Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'))
        $candidates.Add((Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe'))
    }
    $command = Get-Command csc.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command) { return $command.Source }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    $programFiles = @($env:ProgramFiles, $env:ProgramW6432) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    foreach ($base in $programFiles) {
        $visualStudio = Join-Path $base 'Microsoft Visual Studio'
        if (-not (Test-Path -LiteralPath $visualStudio -PathType Container)) { continue }
        $found = Get-ChildItem -LiteralPath $visualStudio -Recurse -Filter csc.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $found) { return $found.FullName }
    }
    return $null
}

function Build-NativeLauncher {
    param([Parameter(Mandatory)][string]$Version)
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        Write-Warning 'Compilação do PC-Optimizer.exe ignorada fora do Windows; o pacote de release deve ser gerado no Windows.'
        return $false
    }
    $csc = Get-CSharpCompiler
    if ([string]::IsNullOrWhiteSpace($csc)) {
        throw 'O compilador C# (csc.exe) não foi encontrado. Instale o .NET Framework 4.x ou o Build Tools do Visual Studio para gerar o PC-Optimizer.exe.'
    }
    $sourceDirectory = Join-Path $repoRoot 'Tools/Portable/Launcher'
    $programPath = Join-Path $sourceDirectory 'Program.cs'
    $assemblyTemplate = Join-Path $sourceDirectory 'AssemblyInfo.cs'
    foreach ($requiredSource in @($programPath, $assemblyTemplate)) {
        if (-not (Test-Path -LiteralPath $requiredSource -PathType Leaf)) {
            throw "Fonte do launcher nativo ausente: $requiredSource"
        }
    }
    $assemblyVersion = ConvertTo-AssemblyVersion -Version $Version
    $buildTemp = Join-Path ([IO.Path]::GetTempPath()) ('pc-optimizer-launcher-' + [guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $buildTemp -Force)
    try {
        $assemblyInfo = Get-Content -LiteralPath $assemblyTemplate -Raw -Encoding UTF8
        $assemblyInfo = $assemblyInfo.Replace('__ASSEMBLY_VERSION__', $assemblyVersion).Replace('__PRODUCT_VERSION__', $Version)
        $assemblyPath = Join-Path $buildTemp 'AssemblyInfo.cs'
        [IO.File]::WriteAllText($assemblyPath, $assemblyInfo, (New-Object System.Text.UTF8Encoding($false)))
        $outputPath = Join-Path $script:StageDirectory 'PC-Optimizer.exe'
        $iconPath = Join-Path $sourceDirectory 'PC-Optimizer.ico'
        $compilerArguments = @(
            '/nologo',
            '/target:winexe',
            '/optimize+',
            '/debug-',
            '/platform:anycpu',
            "/out:$outputPath",
            '/reference:System.dll',
            '/reference:System.Windows.Forms.dll',
            '/reference:System.Drawing.dll',
            $programPath,
            $assemblyPath
        )
        if (Test-Path -LiteralPath $iconPath -PathType Leaf) {
            $compilerArguments += "/win32icon:$iconPath"
        }
        & $csc @compilerArguments
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
            throw 'Falha ao compilar o PC-Optimizer.exe.'
        }
        return $true
    } finally {
        if (Test-Path -LiteralPath $buildTemp) {
            Remove-Item -LiteralPath $buildTemp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-PortableTree {
    param([Parameter(Mandatory)][string]$Stage)
    $required = @(
        'Iniciar-PC-Optimizer.ps1',
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
    )
    $onWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    if ($onWindows) {
        $required += 'PC-Optimizer.exe'
    }
    foreach ($relative in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $Stage $relative) -PathType Leaf)) {
            throw "Pacote incompleto: $relative"
        }
    }
    $forbiddenBats = @(Get-ChildItem -LiteralPath $Stage -Recurse -File -Filter '*.bat' -ErrorAction SilentlyContinue)
    if ($forbiddenBats.Count -gt 0) {
        throw 'O pacote portátil não deve conter arquivos .bat: ' + ($forbiddenBats.FullName -join ', ')
    }
    if ($onWindows) {
        $exePath = Join-Path $Stage 'PC-Optimizer.exe'
        $exeStream = [IO.File]::OpenRead($exePath)
        try {
            $header = New-Object byte[] 2
            if ($exeStream.Read($header, 0, 2) -ne 2) { throw 'O PC-Optimizer.exe está truncado.' }
            if ($header[0] -ne [byte]77 -or $header[1] -ne [byte]90) {
                throw 'O PC-Optimizer.exe não é um executável PE válido.'
            }
        } finally {
            $exeStream.Dispose()
        }
    }
    $parseFailures = 0
    $scriptFiles = @(Get-ChildItem -LiteralPath $Stage -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') })
    foreach ($file in $scriptFiles) {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
        if (@($errors).Count -gt 0) {
            $parseFailures++
            Write-Warning ("Erro de sintaxe em {0}: {1}" -f $file.FullName, $errors[0].Message)
        }
    }
    if ($parseFailures -gt 0) { throw 'O pacote contém scripts com erro de sintaxe.' }
    [void]([xml](Get-Content -LiteralPath (Join-Path $Stage 'UI/MainWindow.xaml') -Raw -Encoding UTF8))
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $versionFile = Join-Path $repoRoot 'VERSION'
    if (Test-Path -LiteralPath $versionFile -PathType Leaf) {
        $Version = (Get-Content -LiteralPath $versionFile -Raw).Trim()
    } else {
        $Version = 'dev'
    }
}
$normalizedVersion = Get-NormalizedVersion -Value $Version

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot 'dist'
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $OutputDirectory -Force)
}

$stageName = "PC-Optimizer-Portable-$normalizedVersion"
$script:StageDirectory = Join-Path $OutputDirectory $stageName
if (Test-Path -LiteralPath $script:StageDirectory) {
    Remove-Item -LiteralPath $script:StageDirectory -Recurse -Force
}
[void](New-Item -ItemType Directory -Path $script:StageDirectory -Force)

try {
    if (-not $SkipTests) {
        Write-Step 'Validando sintaxe e XAML do repositório'
        $validate = Join-Path $repoRoot 'Tests/Validate-Syntax.ps1'
        if (Test-Path -LiteralPath $validate -PathType Leaf) {
            & $validate
        } else {
            Write-Warning 'Tests/Validate-Syntax.ps1 não encontrado; seguindo sem a validação prévia.'
        }
    }

    Write-Step "Copiando runtime para $stageName"
    foreach ($directory in @('Modules', 'UI', 'Data', 'config')) {
        Copy-PortableDirectory -RelativePath $directory
    }
    foreach ($file in @(
        'Otimizador-GUI.ps1',
        'Otimizar-PC.ps1',
        'README.md',
        'README-PORTABLE.md',
        'CHANGELOG.md',
        'LICENSE',
        'SECURITY.md',
        'docs/CATALOGO-LIMPEZA.md',
        'Tools/Diagnostico-Eventos.ps1',
        'Tools/Diagnostico-Rede.ps1'
    )) {
        Copy-PortableFile -RelativePath $file
    }
    foreach ($launcher in @('Iniciar-PC-Optimizer.ps1', 'LEIA-ME.txt')) {
        $launcherSource = Join-Path $repoRoot ("Tools/Portable/$launcher")
        if (-not (Test-Path -LiteralPath $launcherSource -PathType Leaf)) {
            throw "Launcher obrigatório ausente: $launcher"
        }
        Copy-Item -LiteralPath $launcherSource -Destination (Join-Path $script:StageDirectory $launcher) -Force
    }
    $nativeLauncherBuilt = Build-NativeLauncher -Version $normalizedVersion
    if ($nativeLauncherBuilt -and -not $SkipUiValidation -and [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        Write-Step 'Executando self-test do PC-Optimizer.exe'
        $launcherExe = Join-Path $script:StageDirectory 'PC-Optimizer.exe'
        $launcherSelfTest = Start-Process -FilePath $launcherExe -ArgumentList '-SelfTest' -Wait -PassThru
        if ($launcherSelfTest.ExitCode -ne 0) { throw 'O self-test do PC-Optimizer.exe falhou.' }
    }

    $dataDirectory = Join-Path $script:StageDirectory 'Dados'
    [void](New-Item -ItemType Directory -Path $dataDirectory -Force)
    $dataReadme = @'
Esta pasta guarda preferências, logs e estado local do PC Optimizer Portable.

- preferences.json: opções de leitura e categorias selecionadas.
- Logs/: mensagens do launcher e diagnósticos de inicialização.

Se o pacote estiver em mídia somente leitura, o programa usa
%TEMP%\PCOptimizer-Portable automaticamente. Nenhum dado de cliente é gravado.
'@
    [IO.File]::WriteAllText((Join-Path $dataDirectory 'LEIA-ME.txt'), $dataReadme, (New-Object System.Text.UTF8Encoding($true)))

    $sourceCommit = 'local'
    try {
        Push-Location $repoRoot
        $commit = & git rev-parse --short HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commit)) { $sourceCommit = [string]$commit }
    } catch {
        Write-Verbose 'Git indisponível; usando identificador local.'
    } finally {
        Pop-Location
    }
    $versionText = @"
PC Optimizer Portable
Version: $normalizedVersion
Built: $((Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK'))
Source: $sourceCommit
Requires: Windows 10/11 + Windows PowerShell 5.1 or PowerShell 7
"@
    [IO.File]::WriteAllText((Join-Path $script:StageDirectory 'VERSION.txt'), $versionText, (New-Object System.Text.UTF8Encoding($true)))

    Write-Step 'Gerando SHA256SUMS.txt'
    $hashLines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($file in @(Get-ChildItem -LiteralPath $script:StageDirectory -Recurse -File | Sort-Object FullName)) {
        if ($file.Name -eq 'SHA256SUMS.txt') { continue }
        $relative = $file.FullName.Substring($script:StageDirectory.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) -replace '\\', '/'
        $hash = Get-Sha256 -Path $file.FullName
        $hashLines.Add("$hash  $relative")
    }
    [IO.File]::WriteAllText((Join-Path $script:StageDirectory 'SHA256SUMS.txt'), ($hashLines -join [Environment]::NewLine) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))

    Write-Step 'Validando conteúdo do pacote'
    Test-PortableTree -Stage $script:StageDirectory

    if (-not $SkipUiValidation -and [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf) {
            Write-Step 'Executando self-test do pacote'
            & $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:StageDirectory 'Iniciar-PC-Optimizer.ps1') -SelfTest
            if ($LASTEXITCODE -ne 0) { throw 'O self-test do pacote portátil falhou.' }
        }
    }

    if (-not $NoZip) {
        Write-Step 'Criando ZIP e checksum'
        $zipPath = Join-Path $OutputDirectory "$stageName.zip"
        if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
        Compress-Archive -LiteralPath $script:StageDirectory -DestinationPath $zipPath -CompressionLevel Optimal -Force
        $zipHash = Get-Sha256 -Path $zipPath
        [IO.File]::WriteAllText(($zipPath + '.sha256'), "$zipHash  $stageName.zip" + [Environment]::NewLine, (New-Object System.Text.ASCIIEncoding))
        $zipInfo = Get-Item -LiteralPath $zipPath
        Write-Output ''
        Write-Output ('Pacote: {0}' -f $script:StageDirectory)
        Write-Output ('ZIP:    {0} ({1:N1} MB)' -f $zipPath, ($zipInfo.Length / 1MB))
        Write-Output ('SHA256: {0}' -f $zipHash)
    } else {
        Write-Output ''
        Write-Output ('Pacote: {0}' -f $script:StageDirectory)
    }
    Write-Output 'Portable package ready. Copy the folder or ZIP and run PC-Optimizer.exe.'
} catch {
    if (Test-Path -LiteralPath $script:StageDirectory) {
        Remove-Item -LiteralPath $script:StageDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
    throw
}
