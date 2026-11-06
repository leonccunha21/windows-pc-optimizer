#Requires -Version 5.1
Set-StrictMode -Version 2.0

function Get-OptimizerCatalogValue {
    param($Rule, [string]$Name, $Default = $null)
    if ($null -eq $Rule) { return $Default }
    $property = $Rule.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function Test-OptimizerElevated {
    <#
    .SYNOPSIS
    Informa se o processo atual está elevado no Windows.
    .DESCRIPTION
    Retorna sempre falso fora do Windows. A checagem é usada para ignorar
    categorias que exigem administrador quando a interface roda sem elevação.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    try {
        if ($env:OS -ne 'Windows_NT') { return $false }
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Get-OptimizerCleanupCatalog {
    <#
    .SYNOPSIS
    Lê o catálogo declarativo de categorias de limpeza.
    .DESCRIPTION
    As regras vêm de Data/cleanup-rules.json e usam tokens como
    {LocalAppData}, {AppData}, {SystemRoot} e {ProgramData}. O catálogo é
    próprio do projeto e não deriva de definições de produtos comerciais.
    #>
    [CmdletBinding()]
    param([string]$Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Data\cleanup-rules.json'))
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Catálogo de limpeza não encontrado: $Path" }
    try { $document = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { throw "Catálogo de limpeza inválido: $($_.Exception.Message)" }
    $rules = New-Object 'System.Collections.Generic.List[object]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($category in @(Get-OptimizerCatalogValue $document 'Categories' @())) {
        $id = [string](Get-OptimizerCatalogValue $category 'Id' '')
        $name = [string](Get-OptimizerCatalogValue $category 'Name' '')
        $path = [string](Get-OptimizerCatalogValue $category 'Path' '')
        if ([string]::IsNullOrWhiteSpace($id) -or [string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($path)) {
            throw 'Cada categoria do catálogo exige Id, Name e Path.'
        }
        if (-not $seen.Add($id)) { throw "Categoria duplicada no catálogo: $id" }
        $patterns = New-Object 'System.Collections.Generic.List[string]'
        foreach ($pattern in @(Get-OptimizerCatalogValue $category 'Patterns' @())) {
            if (-not [string]::IsNullOrWhiteSpace([string]$pattern)) { $patterns.Add([string]$pattern) }
        }
        $extensions = New-Object 'System.Collections.Generic.List[string]'
        foreach ($extension in @(Get-OptimizerCatalogValue $category 'AllowedExtensions' @())) {
            if (-not [string]::IsNullOrWhiteSpace([string]$extension)) { $extensions.Add([string]$extension) }
        }
        $rules.Add([pscustomobject]@{
            Id                = $id
            Name              = $name
            Path              = $path
            Process           = [string](Get-OptimizerCatalogValue $category 'Process' '')
            RequiresAdmin     = [bool](Get-OptimizerCatalogValue $category 'RequiresAdmin' $false)
            Risk              = [string](Get-OptimizerCatalogValue $category 'Risk' 'Baixo')
            Note              = [string](Get-OptimizerCatalogValue $category 'Note' '')
            Patterns          = $patterns.ToArray()
            AllowedExtensions = $extensions.ToArray()
        })
    }
    return $rules.ToArray()
}

function Get-OptimizerCleanupPathExpansion {
    param([string]$Path)
    if ($Path.IndexOf('*') -lt 0) { return @($Path) }
    $root = [IO.Path]::GetPathRoot($Path)
    if ([string]::IsNullOrWhiteSpace($root)) { return @() }
    $relative = $Path.Substring($root.Length)
    $segments = @($relative -split '[\\/]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($segments.Count -eq 0) { return @() }
    # Only a whole segment may be a wildcard; partial patterns are refused.
    foreach ($segment in $segments) {
        if ($segment.Contains('*') -and $segment -ne '*') { return @() }
    }
    $paths = New-Object 'System.Collections.Generic.List[string]'
    $paths.Add($root)
    foreach ($segment in $segments) {
        $next = New-Object 'System.Collections.Generic.List[string]'
        foreach ($base in $paths) {
            if ($segment -eq '*') {
                foreach ($child in @(Get-ChildItem -LiteralPath $base -Directory -Force -ErrorAction SilentlyContinue)) {
                    if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                    $next.Add($child.FullName)
                    if ($next.Count -ge 64) { break }
                }
            } else {
                $next.Add((Join-Path $base $segment))
            }
            if ($next.Count -ge 64) { break }
        }
        $paths = $next
        if ($paths.Count -eq 0) { return @() }
    }
    return $paths.ToArray()
}

function Get-OptimizerCleanupTargets {
    <#
    .SYNOPSIS
    Resolve o catálogo em pastas existentes no computador atual.
    .DESCRIPTION
    Tokens de ambiente são expandidos e categorias cuja pasta não existe são
    omitidas. Caminhos relativos ou com tokens não resolvidos nunca entram no
    resultado. Um segmento `*` expande perfis de navegador, no máximo 64 por
    regra, sem atravessar junctions ou links simbólicos.
    #>
    [CmdletBinding()]
    param([string]$Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Data\cleanup-rules.json'))
    $tokens = @{
        '{LocalAppData}' = [string]$env:LOCALAPPDATA
        '{AppData}'      = [string]$env:APPDATA
        '{UserProfile}'  = [string]$env:USERPROFILE
        '{SystemRoot}'   = [string]$env:SystemRoot
        '{ProgramData}'  = [string]$env:ProgramData
        '{Temp}'         = [IO.Path]::GetTempPath().TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    }
    $targets = New-Object 'System.Collections.Generic.List[object]'
    $seenIds = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($rule in @(Get-OptimizerCleanupCatalog -Path $Path)) {
        $resolved = [string]$rule.Path
        $missingToken = $false
        foreach ($token in @($tokens.Keys)) {
            if ($resolved.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
            $value = [string]$tokens[$token]
            if ([string]::IsNullOrWhiteSpace($value)) { $missingToken = $true; break }
            $resolved = $resolved.Replace($token, $value)
        }
        if ($missingToken -or $resolved -match '%[^%]+%') { continue }
        if (-not [IO.Path]::IsPathRooted($resolved)) { continue }
        $expanded = $resolved.IndexOf('*') -ge 0
        $wildcardPrefix = ''
        if ($expanded) {
            $root = [IO.Path]::GetPathRoot($resolved)
            $segments = @($resolved.Substring($root.Length) -split '[\\/]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $wildcardIndex = [Array]::IndexOf($segments, '*')
            $wildcardPrefix = $root
            for ($position = 0; $position -lt $wildcardIndex; $position++) { $wildcardPrefix = Join-Path $wildcardPrefix $segments[$position] }
        }
        $paths = @(Get-OptimizerCleanupPathExpansion -Path $resolved)
        $index = 0
        foreach ($candidate in $paths) {
            if (-not (Test-Path -LiteralPath $candidate -PathType Container)) { continue }
            $index++
            $id = if ($expanded) { '{0}-{1}' -f $rule.Id, $index } else { [string]$rule.Id }
            while (-not $seenIds.Add($id)) {
                $index++
                $id = '{0}-{1}' -f $rule.Id, $index
            }
            $name = [string]$rule.Name
            if ($expanded) {
                $relative = $candidate.Substring($wildcardPrefix.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
                $parts = @($relative -split '[\\/]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                if ($parts.Count -gt 0) { $name = '{0} / {1}' -f $rule.Name, $parts[0] }
            }
            $targets.Add([pscustomobject]@{
                Id                = $id
                Name              = $name
                Path              = $candidate
                Process           = [string]$rule.Process
                RequiresAdmin     = [bool]$rule.RequiresAdmin
                Risk              = [string]$rule.Risk
                Note              = [string]$rule.Note
                Patterns          = @($rule.Patterns)
                AllowedExtensions = @($rule.AllowedExtensions)
            })
        }
    }
    return $targets.ToArray()
}

Export-ModuleMember -Function Test-OptimizerElevated, Get-OptimizerCleanupCatalog, Get-OptimizerCleanupTargets
