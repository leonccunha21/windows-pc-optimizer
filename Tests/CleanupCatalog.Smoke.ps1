# Dependency-free regression suite for the declarative cleanup catalog.
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../Modules/Optimizer.CleanupCatalog.psm1') -Force
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('optimizer-catalog-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testRoot)
$script:passed = 0
function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:passed++; Write-Output "PASS: $Message"
}
try {
    $cache = Join-Path $testRoot 'cache'
    [void](New-Item -ItemType Directory -Path $cache)
    $tokenFolder = 'optimizer-token-' + [guid]::NewGuid().ToString('N')
    $tokenPath = Join-Path ([IO.Path]::GetTempPath()) $tokenFolder
    [void](New-Item -ItemType Directory -Path $tokenPath)
    $separator = [IO.Path]::DirectorySeparatorChar
    $document = @{
        Categories = @(
            @{ Id='fixture'; Name='Fixture'; Path=$cache; Process=''; RequiresAdmin=$false; Risk='Baixo'; Note='Fixture'; Patterns=@('*.tmp'); AllowedExtensions=@('.tmp') },
            @{ Id='token'; Name='Token'; Path=('{Temp}' + $separator + $tokenFolder); Process=''; RequiresAdmin=$true; Risk='Médio'; Note='Token'; Patterns=@(); AllowedExtensions=@() },
            @{ Id='missing'; Name='Missing'; Path=(Join-Path $testRoot 'missing'); Process=''; RequiresAdmin=$false; Risk='Baixo'; Note=''; Patterns=@(); AllowedExtensions=@() }
        )
    }
    $fixturePath = Join-Path $testRoot 'rules.json'
    $document | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $fixturePath -Encoding UTF8
    $catalog = @(Get-OptimizerCleanupCatalog -Path $fixturePath)
    Assert-True ($catalog.Count -eq 3) 'Catalog reads every declared category'
    Assert-True (@($catalog | Where-Object { -not $_.Id -or -not $_.Name -or -not $_.Path }).Count -eq 0) 'Catalog entries have required fields'
    $targets = @(Get-OptimizerCleanupTargets -Path $fixturePath)
    Assert-True ($targets.Count -eq 2) 'Only existing folders become targets'
    Assert-True (@($targets | Where-Object Id -eq 'missing').Count -eq 0) 'Missing folder is omitted'
    $fixtureTarget = @($targets | Where-Object Id -eq 'fixture')[0]
    Assert-True ($fixtureTarget.Path -eq $cache) 'Absolute path is preserved'
    Assert-True ($fixtureTarget.Patterns.Count -eq 1 -and $fixtureTarget.AllowedExtensions.Count -eq 1) 'Pattern and extension filters survive catalog loading'
    $tokenTarget = @($targets | Where-Object Id -eq 'token')[0]
    Assert-True ($tokenTarget.Path -eq $tokenPath) 'Environment token is expanded to the real folder'
    Assert-True ($tokenTarget.RequiresAdmin -and $tokenTarget.Risk -eq 'Médio') 'Risk metadata is carried to the target'
    $profileRoot = Join-Path $testRoot 'profiles'
    foreach ($profileName in @('Default', 'Profile 1')) {
        [void](New-Item -ItemType Directory -Path (Join-Path $profileRoot "$profileName\Cache\Cache_Data") -Force)
    }
    $wildcardDocument = @{ Categories = @(
        @{ Id='wild'; Name='Browser'; Path=(Join-Path $profileRoot '*\Cache\Cache_Data'); Process=''; RequiresAdmin=$false; Risk='Baixo'; Note='Perfis'; Patterns=@(); AllowedExtensions=@() },
        @{ Id='partial'; Name='Partial'; Path=(Join-Path $profileRoot 'wild*\Cache\Cache_Data'); Process=''; RequiresAdmin=$false; Risk='Baixo'; Note='Parcial'; Patterns=@(); AllowedExtensions=@() }
    ) }
    $wildcardPath = Join-Path $testRoot 'wildcard.json'
    $wildcardDocument | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $wildcardPath -Encoding UTF8
    $wildcardTargets = @(Get-OptimizerCleanupTargets -Path $wildcardPath)
    Assert-True ($wildcardTargets.Count -eq 2) 'Wildcard expands each matching profile folder'
    Assert-True (@($wildcardTargets | Group-Object Id | Where-Object Count -gt 1).Count -eq 0) 'Expanded targets receive unique ids'
    Assert-True (@($wildcardTargets | Where-Object { $_.Name -notmatch 'Default|Profile 1' }).Count -eq 0) 'Expanded target names identify the profile folder'
    Assert-True (@($wildcardTargets | Where-Object Id -like 'partial*').Count -eq 0) 'Partial wildcard segments are refused'
    Assert-True ((Test-OptimizerElevated) -eq $true -or (Test-OptimizerElevated) -eq $false) 'Elevation probe returns a boolean'
    $default = @(Get-OptimizerCleanupCatalog)
    Assert-True ($default.Count -ge 15) 'Bundled catalog contains the expected categories'
    Assert-True (@($default | Group-Object Id | Where-Object Count -gt 1).Count -eq 0) 'Bundled catalog ids are unique'
    Assert-True (@($default | Where-Object { $_.Risk -notin @('Baixo','Médio','Alto') }).Count -eq 0) 'Bundled catalog declares a known risk level'
    Assert-True (@($default | Where-Object { -not $_.Note }).Count -eq 0) 'Every bundled category explains its impact'
    $werRules = @($default | Where-Object { $_.Id -in @('wer-user','wer-machine') })
    Assert-True ($werRules.Count -eq 2 -and @($werRules | Where-Object Id -eq 'wer-machine')[0].RequiresAdmin) 'Bundled catalog covers user and machine WER with elevation'
    $browserRules = @($default | Where-Object { $_.Process -in @('chrome','msedge','brave','firefox','opera','vivaldi','chromium') })
    Assert-True ($browserRules.Count -ge 20) 'Bundled catalog covers the supported browsers'
    foreach ($browserProcess in @('chrome','msedge','brave','firefox','opera','vivaldi','chromium')) {
        Assert-True (@($browserRules | Where-Object Process -eq $browserProcess).Count -gt 0) "Bundled catalog covers $browserProcess"
    }
    $duplicate = @{ Categories = @(
        @{ Id='same'; Name='A'; Path=$cache },
        @{ Id='same'; Name='B'; Path=$cache }
    ) }
    $duplicatePath = Join-Path $testRoot 'duplicate.json'
    $duplicate | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $duplicatePath -Encoding UTF8
    $threw = $false
    try { [void](Get-OptimizerCleanupCatalog -Path $duplicatePath) } catch { $threw = $true }
    Assert-True $threw 'Duplicate category ids are rejected'
    $threw = $false
    try { [void](Get-OptimizerCleanupCatalog -Path (Join-Path $testRoot 'absent.json')) } catch { $threw = $true }
    Assert-True $threw 'Missing catalog file is rejected'
    Write-Output "All $script:passed catalog checks passed."
} finally {
    if (Test-Path -LiteralPath $tokenPath) { Remove-Item -LiteralPath $tokenPath -Recurse -Force }
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
