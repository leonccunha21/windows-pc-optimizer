# Dependency-free safety regression suite. Uses only its own temporary directory.
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../Modules/Optimizer.Core.psm1') -Force
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('optimizer-test-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testRoot)
$script:passed = 0
function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:passed++; Write-Output "PASS: $Message"
}
function New-OldFile([string]$Path) {
    [void](New-Item -ItemType Directory -Path (Split-Path $Path) -Force)
    [IO.File]::WriteAllText($Path, 'fixture-data')
    (Get-Item -LiteralPath $Path).LastWriteTimeUtc = [DateTime]::UtcNow.AddDays(-10)
}
try {
    $cache = Join-Path $testRoot 'cache'; [void](New-Item -ItemType Directory $cache)
    $targets = @([pscustomobject]@{Id='fixture';Name='Fixture';Path=$cache;Process=''})
    $old = Join-Path $cache 'old.tmp'; New-OldFile $old
    $recent = Join-Path $cache 'recent.tmp'; [IO.File]::WriteAllText($recent,'recent')
    $code = Join-Path $cache 'script.ps1'; New-OldFile $code
    $personal = Join-Path $cache 'photo.jpg'; New-OldFile $personal
    $protected = Join-Path $cache 'project/old.tmp'; New-OldFile $protected
    [IO.File]::WriteAllText((Join-Path $cache 'project/package.json'),'{}')
    $game = Join-Path $cache 'Epic Games/old.tmp'; New-OldFile $game
    $outside = Join-Path $testRoot 'cache-sibling/old.tmp'; New-OldFile $outside
    Assert-True (-not (Test-OptimizerPath $outside $cache)) 'Prefix-sibling path is rejected'
    Assert-True (-not (Test-OptimizerPath $protected $cache)) 'Project ancestors are protected'
    Assert-True (-not (Test-OptimizerPath $game $cache)) 'Game folder is protected'
    $scan = Get-OptimizerScan -Targets $targets
    Assert-True (@($scan.Files).Count -eq 1) 'Only the old temporary file is eligible'
    Assert-True ($scan.Files[0].Path -eq $old) 'Scan excludes recent files, code, photos and projects'
    Assert-True (Test-Path $old) 'Analysis never deletes files'
    $result = Invoke-OptimizerCleanup -Scan $scan -CategoryIds fixture -Targets $targets -WhatIf
    Assert-True ((Test-Path $old) -and $result.RemovedBytes -eq 0) 'WhatIf preserves data and reports zero removed bytes'
    [IO.File]::AppendAllText($old,'changed')
    $result = Invoke-OptimizerCleanup -Scan $scan -CategoryIds fixture -Targets $targets -Confirm:$false
    Assert-True ((Test-Path $old) -and $result.SkippedCount -eq 1) 'Changed file is skipped'
    (Get-Item $old).LastWriteTimeUtc = [DateTime]::UtcNow.AddDays(-10)
    $scan = Get-OptimizerScan -Targets $targets
    $result = Invoke-OptimizerCleanup -Scan $scan -CategoryIds unselected -Targets $targets -Confirm:$false
    Assert-True ((Test-Path $old) -and $result.RemovedCount -eq 0) 'Unselected category is preserved'
    $result = Invoke-OptimizerCleanup -Scan $scan -CategoryIds fixture -Targets $targets -Confirm:$false
    Assert-True ((-not (Test-Path $old)) -and $result.RemovedCount -eq 1 -and $result.RemovedBytes -gt 0) 'Cleanup reports actual successful deletion'
    Assert-True ((Test-Path $recent) -and (Test-Path $code) -and (Test-Path $protected) -and (Test-Path $personal)) 'Protected and recent data survives cleanup'
    $cancelled = Get-OptimizerScan -Targets $targets -State @{Cancel=$true;Message=''}
    Assert-True $cancelled.Cancelled 'Analysis supports cooperative cancellation'
    $threw=$false; try { Invoke-OptimizerCleanup -Scan $cancelled -CategoryIds fixture -Targets $targets } catch {$threw=$true}
    Assert-True $threw 'Cancelled scan cannot be cleaned'
    $scan.CreatedUtc = [DateTime]::UtcNow.AddHours(-1)
    $threw=$false; try { Invoke-OptimizerCleanup -Scan $scan -CategoryIds fixture -Targets $targets } catch {$threw=$true}
    Assert-True $threw 'Expired analysis is rejected'
    $threw=$false; try { Get-OptimizerScan -Targets $targets -MinimumAgeDays 0 } catch {$threw=$true}
    Assert-True $threw 'Retention cannot be reduced below seven days'
    New-OldFile $old
    $scan = Get-OptimizerScan -Targets $targets
    $scan.Files[0].Category='not-allowed'
    $result=Invoke-OptimizerCleanup -Scan $scan -CategoryIds not-allowed -Targets $targets -Confirm:$false
    Assert-True ((Test-Path $old) -and $result.SkippedCount -eq 1) 'Unknown cleanup category is rejected'
    $scan = Get-OptimizerScan -Targets $targets
    $result=Invoke-OptimizerCleanup -Scan $scan -CategoryIds fixture -Targets $targets -State @{Cancel=$true;Message=''} -Confirm:$false
    Assert-True ((Test-Path $old) -and $result.Cancelled) 'Cancellation stops cleanup before the next file'
    $scan = Get-OptimizerScan -Targets $targets
    [IO.File]::WriteAllText((Join-Path $cache '.optimizer-protect'),'')
    $result=Invoke-OptimizerCleanup -Scan $scan -CategoryIds fixture -Targets $targets -Confirm:$false
    Assert-True ((Test-Path $old) -and $result.SkippedCount -eq 1) 'New protection marker is revalidated before deletion'
    Remove-Item -LiteralPath (Join-Path $cache '.optimizer-protect') -Force
    # Junctions require no developer mode on Windows; symbolic links work on Linux.
    $link=Join-Path $cache 'linked'
    if ($env:OS -eq 'Windows_NT') { [void](New-Item -ItemType Junction -Path $link -Target (Split-Path $outside)) }
    else { [void](New-Item -ItemType SymbolicLink -Path $link -Target (Split-Path $outside)) }
    Assert-True (-not (Test-OptimizerPath (Join-Path $link 'old.tmp') $cache)) 'Links cannot escape the allowed root'
    $scan=Get-OptimizerScan -Targets $targets
    Assert-True (@($scan.Files | Where-Object { $_.Path -like '*linked*' }).Count -eq 0) 'Scan does not traverse linked directories'
    [IO.Directory]::Delete($link)
    $report=Join-Path $testRoot 'report.html'
    Export-OptimizerReport -Path $report -Customer '<script>alert(1)</script>' -Notes '<img onerror=x>' -Diagnostics @([pscustomobject]@{Area='Test';Item='Value';Value='<b>data</b>'}) -Cleanup $result
    $html=Get-Content $report -Raw
    Assert-True ($html -notmatch '<script>' -and $html -match '&lt;script&gt;') 'Customer input is HTML-escaped'
    Assert-True ($html -notmatch '<img onerror' -and $html -notmatch '<b>data') 'Notes and diagnostics are HTML-escaped'
    Assert-True ($html -notmatch [regex]::Escape($old)) 'Report omits personal file paths'

    $plainReport=Join-Path $testRoot 'sem-limpeza.html'
    Export-OptimizerReport -Path $plainReport -Customer 'João & Cia' -Notes 'Teste <ok>' -Cleanup $null
    $markup=Get-Content -LiteralPath $plainReport -Raw
    Assert-True ($markup -match '<head>' -and $markup -match '<body>' -and $markup -match '</body>') 'HTML report has head and body'
    Assert-True ($markup -match '&amp; Cia' -and $markup -match '&lt;ok&gt;' -and [System.Net.WebUtility]::HtmlDecode($markup) -match 'João & Cia') 'HTML report escapes personal text with accents'
    $jsonPath=Join-Path $testRoot 'relatorio.json'
    Export-OptimizerReport -Path $jsonPath -Customer 'João' -Notes 'Registro' -Diagnostics @([pscustomobject]@{Area='Disco';Item='Teste';Value='OK'}) -Cleanup $result -Format JSON
    $json=Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
    Assert-True ($json.Customer -eq 'João' -and $json.Diagnostics[0].Area -eq 'Disco') 'JSON exports unicode and diagnostic details'
    Assert-True (-not ((Get-Content -LiteralPath $jsonPath -Raw).Contains($old))) 'JSON excludes private cleanup paths'
    Export-OptimizerReport -Path (Join-Path $testRoot 'empty.json') -Cleanup $null -Format JSON
    Assert-True ((Format-OptimizerSize 0) -like '*B' -and (Format-OptimizerSize 1MB) -like '*MB' -and (Format-OptimizerSize 1GB) -like '*GB') 'Formatter handles B, MB and GB'
    $sum = & (Get-Module Optimizer.Core) { Get-OptimizerByteSum @([pscustomobject]@{Bytes=10}, [pscustomobject]@{Other=2}, $null) }
    Assert-True ($sum -eq 10) 'Byte summation tolerates missing properties'
    $empty=Join-Path $testRoot 'empty';[void](New-Item -ItemType Directory $empty)
    $emptyScan=Get-OptimizerScan -Targets @([pscustomobject]@{Id='empty';Name='Empty';Path=$empty;Process=''})
    Assert-True ($emptyScan.Bytes -eq 0 -and @($emptyScan.Files).Count -eq 0) 'Empty analysis returns zero without failing'
    Write-Output "All $script:passed safety checks passed."
} finally {
    if(Test-Path (Join-Path $testRoot 'cache/linked')) { [IO.Directory]::Delete((Join-Path $testRoot 'cache/linked')) }
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
