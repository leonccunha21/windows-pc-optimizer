# Dependency-free regression checks for the preserved legacy definitions.
# Parse/load function declarations only: never execute the legacy main program.
$ErrorActionPreference = 'Stop'
$path = Join-Path (Split-Path $PSScriptRoot -Parent) 'Otimizar-PC.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
foreach ($node in $ast.EndBlock.Statements) {
    if ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
        . ([scriptblock]::Create($node.Extent.Text))
    }
}
$Protected = @('Epic Games','Fortnite','EpicGames','FortniteGame','.git')
if (@($Protected).Count -eq 0) { throw 'Protected path list must not be empty' }
foreach ($name in @('Clean-Temp','Clean-BrowserCaches','Clean-PackageCaches','Optimize-Startup','System-Tweaks','Optimize-Disk','Clear-EventLogs','Disable-BackgroundApps','Flush-DNS','Enable-StorageSense','Run-CleanMgr','Show-DiskSpace','Is-Protected','Get-FolderSize','Write-StructuredLog')) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { throw "Missing legacy function: $name" }
}
if (Get-Command Clean-ProjectJunk -ErrorAction SilentlyContinue) { throw 'Project removal function must not exist' }
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('optimizer-legacy-test-' + [guid]::NewGuid().ToString('N'))
try {
    [void](New-Item -ItemType Directory $fixture)
    foreach($name in @('Epic Games','Fortnite','EpicGames')) {
        if (-not (Is-Protected (Join-Path $fixture $name))) { throw "Legacy protection regression: $name" }
    }
    if (Is-Protected (Join-Path $fixture 'ordinary')) { throw 'Unexpected legacy path exclusion' }
    if ((Get-FolderSize (Join-Path $fixture 'absent')) -ne 0) { throw 'Missing directory must have zero size' }
    [IO.File]::WriteAllText((Join-Path $fixture 'sample.tmp'), 'sample')
    if ((Get-FolderSize $fixture) -ne 6) { throw 'Legacy folder size regression' }
    $StructuredLogFile = Join-Path $fixture 'structured.jsonl'
    Write-StructuredLog -Level 'INFO' -Function 'Remove-Safe' -Target 'C:\Users\Private\client\cache' -Result 'Removido: C:\Users\Private\client\cache (12,3 MB)'
    $jsonLine = Get-Content -LiteralPath $StructuredLogFile -Raw
    if ($jsonLine -match 'C:\\Users' -or $jsonLine -notmatch 'caminho omitido') { throw 'Structured log leaked a personal path' }
    $entry = $jsonLine | ConvertFrom-Json
    if ($entry.level -ne 'INFO' -or $entry.function -ne 'Remove-Safe' -or [string]::IsNullOrWhiteSpace($entry.timestamp)) { throw 'Structured log fields are incomplete' }
    Write-Output 'Legacy function existence, protection, structured logging and size regressions passed without executing maintenance.'
} finally { Remove-Item -LiteralPath $fixture -Recurse -Force }
