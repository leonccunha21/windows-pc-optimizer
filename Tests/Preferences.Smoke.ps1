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
    $portableData = Join-Path $testDir 'portable-data'
    [void](New-Item -ItemType Directory -Path $portableData -Force)
    $previousPortableData = $env:PC_OPTIMIZER_PORTABLE_DATA
    $env:PC_OPTIMIZER_PORTABLE_DATA = $portableData
    try {
        $portablePath = Get-OptimizerPreferencesPath
        Assert-Preferences ($portablePath -eq (Join-Path $portableData 'preferences.json')) 'Portable preferences path was not honored.'
    } finally {
        $env:PC_OPTIMIZER_PORTABLE_DATA = $previousPortableData
    }
    $default=Read-OptimizerPreferences -Path $path
    Assert-Preferences ($default.SchemaVersion -eq 2 -and -not $default.HighContrast -and $default.TextScale -eq 100 -and @($default.SelectedCategories).Count -eq 0) 'Defaults incorrect.'
    $selected=[pscustomobject]@{SchemaVersion=2;HighContrast=$true;TextScale=125;SelectedCategories=@('temp','chrome-Default-Code Cache');Customer='PRIVATE-NAME';IP='192.0.2.2';CleanupPath='SECRET'}
    $saved=Save-OptimizerPreferences -Preferences $selected -Path $path
    Assert-Preferences ($saved.HighContrast -and $saved.TextScale -eq 125 -and @($saved.SelectedCategories).Count -eq 2) 'Saved values incorrect.'
    $disk=[IO.File]::ReadAllText($path)
    Assert-Preferences (-not $disk.Contains('PRIVATE-NAME') -and -not $disk.Contains('192.0.2.2') -and -not $disk.Contains('SECRET')) 'Private fields leaked to preferences.'
    Assert-Preferences ($disk.Contains('"HighContrast"') -and $disk.Contains('"TextScale"') -and $disk.Contains('"SelectedCategories"')) 'Missing saved keys.'
    $read=Read-OptimizerPreferences -Path $path
    Assert-Preferences ($read.HighContrast -and $read.TextScale -eq 125 -and @($read.SelectedCategories).Count -eq 2) 'Persistence failed.'
    $again=Save-OptimizerPreferences -Preferences ([pscustomobject]@{SchemaVersion=1;HighContrast=$false;TextScale=115}) -Path $path
    Assert-Preferences (-not $again.HighContrast -and (Read-OptimizerPreferences -Path $path).TextScale -eq 115) 'Atomic overwrite failed.'
    [IO.File]::WriteAllText($path,'{"SchemaVersion":1,"HighContrast":true,"TextScale":100}')
    $migrated=Read-OptimizerPreferences -Path $path
    Assert-Preferences ($migrated.SchemaVersion -eq 2 -and $migrated.HighContrast -and @($migrated.SelectedCategories).Count -eq 0) 'Schema 1 did not migrate safely.'
    foreach ($bad in @(
        [pscustomobject]@{SchemaVersion=2;HighContrast=$false;TextScale=150},
        [pscustomobject]@{SchemaVersion=3;HighContrast=$false;TextScale=100},
        [pscustomobject]@{SchemaVersion=2;HighContrast='false';TextScale=100},
        [pscustomobject]@{SchemaVersion=2;HighContrast=$true;TextScale='100'},
        [pscustomobject]@{SchemaVersion=2;HighContrast=$true},
        [pscustomobject]@{SchemaVersion=2;HighContrast=$false;TextScale=100;SelectedCategories=@('../escape')},
        [pscustomobject]@{SchemaVersion=2;HighContrast=$false;TextScale=100;SelectedCategories=@(42)}
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
