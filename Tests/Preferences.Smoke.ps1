# PowerShell 5.1 / 7 smoke: only an isolated temp directory, no user settings changed.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../Modules/Optimizer.Preferences.psm1') -Force
function Assert-Preferences([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
$testDir=Join-Path ([IO.Path]::GetTempPath()) ('optimizer-settings-test-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testDir -Force)
$path=Join-Path $testDir 'preferences.json'
try {
    $default=Read-OptimizerPreferences -Path $path
    Assert-Preferences ($default.SchemaVersion -eq 1 -and -not $default.HighContrast -and $default.TextScale -eq 100) 'Defaults incorrect.'
    $selected=[pscustomobject]@{SchemaVersion=1;HighContrast=$true;TextScale=125;Customer='PRIVATE-NAME';IP='192.0.2.2';CleanupPath='SECRET'}
    $saved=Save-OptimizerPreferences -Preferences $selected -Path $path
    Assert-Preferences ($saved.HighContrast -and $saved.TextScale -eq 125) 'Saved values incorrect.'
    $disk=[IO.File]::ReadAllText($path)
    Assert-Preferences (-not $disk.Contains('PRIVATE-NAME') -and -not $disk.Contains('192.0.2.2') -and -not $disk.Contains('SECRET')) 'Private fields leaked to preferences.'
    Assert-Preferences ($disk.Contains('"HighContrast"') -and $disk.Contains('"TextScale"')) 'Missing saved keys.'
    $read=Read-OptimizerPreferences -Path $path
    Assert-Preferences ($read.HighContrast -and $read.TextScale -eq 125) 'Persistence failed.'
    $again=Save-OptimizerPreferences -Preferences ([pscustomobject]@{SchemaVersion=1;HighContrast=$false;TextScale=115}) -Path $path
    Assert-Preferences (-not $again.HighContrast -and (Read-OptimizerPreferences -Path $path).TextScale -eq 115) 'Atomic overwrite failed.'
    foreach ($bad in @(
        [pscustomobject]@{SchemaVersion=1;HighContrast=$false;TextScale=150},
        [pscustomobject]@{SchemaVersion=2;HighContrast=$false;TextScale=100},
        [pscustomobject]@{SchemaVersion=1;HighContrast='false';TextScale=100},
        [pscustomobject]@{SchemaVersion=1;HighContrast=$true;TextScale='100'},
        [pscustomobject]@{SchemaVersion=1;HighContrast=$true}
    )) {
        Assert-Preferences (-not (Test-OptimizerPreferenceValues -Preferences $bad)) 'Invalid settings accepted.'
        $rejected=$false
        try { Save-OptimizerPreferences -Preferences $bad -Path $path -ErrorAction Stop | Out-Null } catch { $rejected=$true }
        Assert-Preferences $rejected 'Invalid settings written to disk.'
    }
    [IO.File]::WriteAllText($path,'{broken-json')
    $broken=Read-OptimizerPreferences -Path $path
    Assert-Preferences ($broken.TextScale -eq 100 -and -not $broken.HighContrast) 'Malformed JSON did not fall back to defaults.'
    [IO.File]::WriteAllText($path,(' ' * 4100))
    Assert-Preferences ((Read-OptimizerPreferences -Path $path).TextScale -eq 100) 'Oversize settings file accepted.'
    [IO.File]::WriteAllText($path,'{"SchemaVersion":1,"HighContrast":true,"TextScale":111}')
    Assert-Preferences ((Read-OptimizerPreferences -Path $path).TextScale -eq 100) 'Unsupported scale accepted.'
    Write-Output 'Preferences defaults, privacy, invalid-file handling and persistence passed.'
} finally {
    if (Test-Path -LiteralPath $testDir) { Remove-Item -LiteralPath $testDir -Recurse -Force }
}
