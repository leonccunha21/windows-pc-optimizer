#Requires -Version 5.1
# Only non-sensitive user interface choices are persisted. No machine inventory or client data.
Set-StrictMode -Version 2.0

function Get-OptimizerPreferenceDefaults {
    [CmdletBinding()]
    param()
    return [pscustomobject]@{
        SchemaVersion = 2
        HighContrast = $false
        TextScale = 100
        SelectedCategories = @()
    }
}

function Test-OptimizerPreferenceValues {
    <#
    .SYNOPSIS
    Validates the strictly allowlisted preference schema.
    .DESCRIPTION
    Schema 1 files remain readable. Schema 2 adds an optional list of generic
    cleanup category ids; only generic names without path traversal are accepted.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Preferences
    )
    if ($null -eq $Preferences) { return $false }
    $properties = $Preferences.PSObject.Properties
    foreach ($required in @('SchemaVersion','HighContrast','TextScale')) {
        if ($null -eq $properties[$required]) { return $false }
    }
    if ($Preferences.SchemaVersion -isnot [int] -and $Preferences.SchemaVersion -isnot [long]) { return $false }
    $version = [int]$Preferences.SchemaVersion
    if ($version -notin @(1,2)) { return $false }
    if ($Preferences.HighContrast -isnot [bool]) { return $false }
    if ($Preferences.TextScale -isnot [int] -and $Preferences.TextScale -isnot [long]) { return $false }
    if ([int]$Preferences.TextScale -notin @(100,115,125)) { return $false }
    if ($version -ge 2 -and $null -ne $properties['SelectedCategories']) {
        $selected = @($Preferences.SelectedCategories)
        if ($selected.Count -gt 64) { return $false }
        foreach ($item in $selected) {
            if ($item -isnot [string]) { return $false }
            if ($item -notmatch '^[A-Za-z0-9 ._\\-]{1,128}$') { return $false }
            if ($item.Contains('..')) { return $false }
        }
    }
    return $true
}

function Get-OptimizerPreferencesPath {
    [CmdletBinding()]
    param()
    $local = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($local)) {
        throw 'A pasta local de preferências não está disponível neste perfil.'
    }
    return (Join-Path (Join-Path $local 'PCOptimizer') 'preferences.json')
}

function Read-OptimizerPreferences {
    <#
    .SYNOPSIS
    Reads a small local preferences JSON and returns defaults when absent/invalid.
    .PARAMETER Path
    Explicit path is intended for tests only. The GUI uses the current user's local app data.
    #>
    [CmdletBinding()]
    param([string]$Path = '')
    $defaults = Get-OptimizerPreferenceDefaults
    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = Get-OptimizerPreferencesPath }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $defaults }
    try {
        $info = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($info.Length -gt 4096) { return $defaults }
        $raw = [IO.File]::ReadAllText([IO.Path]::GetFullPath($Path))
        if ([string]::IsNullOrWhiteSpace($raw)) { return $defaults }
        $preferences = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
        if (-not (Test-OptimizerPreferenceValues -Preferences $preferences)) { return $defaults }
        $selected = @()
        if ($null -ne $preferences.PSObject.Properties['SelectedCategories']) {
            $selected = @($preferences.SelectedCategories | Where-Object { $_ -is [string] } | Sort-Object -Unique)
        }
        return [pscustomobject]@{
            SchemaVersion=2
            HighContrast=[bool]$preferences.HighContrast
            TextScale=[int]$preferences.TextScale
            SelectedCategories=@($selected)
        }
    } catch {
        return $defaults
    }
}

function Save-OptimizerPreferences {
    <#
    .SYNOPSIS
    Writes strictly validated non-sensitive settings with an atomic replace.
    .DESCRIPTION
    Only SchemaVersion, HighContrast, TextScale and generic cleanup category
    ids are ever serialized; any additional input members (such as customer
    details) are ignored.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Preferences,
        [string]$Path = ''
    )
    if (-not (Test-OptimizerPreferenceValues -Preferences $Preferences)) {
        throw 'Preferências inválidas. Use HighContrast (booleano), TextScale (100, 115 ou 125) e categorias seguras.'
    }
    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = Get-OptimizerPreferencesPath }
    $fullPath = [IO.Path]::GetFullPath($Path)
    if ([IO.Path]::GetExtension($fullPath).ToLowerInvariant() -ne '.json') {
        throw 'O arquivo de preferências deve ter extensão .json.'
    }
    $directory = [IO.Path]::GetDirectoryName($fullPath)
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop)
    }
    $selected = @()
    if ($null -ne $Preferences.PSObject.Properties['SelectedCategories']) {
        $selected = @($Preferences.SelectedCategories | Where-Object { $_ -is [string] } | Sort-Object -Unique)
    }
    $clean = [ordered]@{
        SchemaVersion=2
        HighContrast=[bool]$Preferences.HighContrast
        TextScale=[int]$Preferences.TextScale
        SelectedCategories=@($selected)
    }
    $json = ConvertTo-Json -InputObject $clean -Depth 3
    $temporary = Join-Path $directory ('.preferences-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup = ''
    try {
        [IO.File]::WriteAllText($temporary, $json, (New-Object Text.UTF8Encoding($false)))
        if ([IO.File]::Exists($fullPath)) {
            $backup = Join-Path $directory ('.preferences-backup-' + [guid]::NewGuid().ToString('N') + '.tmp')
            [IO.File]::Replace($temporary, $fullPath, $backup)
            if ([IO.File]::Exists($backup)) { [IO.File]::Delete($backup) }
        } else {
            [IO.File]::Move($temporary, $fullPath)
        }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
        if ($backup -and [IO.File]::Exists($backup)) { [IO.File]::Delete($backup) }
    }
    return [pscustomobject]$clean
}

Export-ModuleMember -Function Get-OptimizerPreferenceDefaults,Test-OptimizerPreferenceValues,Get-OptimizerPreferencesPath,Read-OptimizerPreferences,Save-OptimizerPreferences
