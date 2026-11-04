$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$failures = 0
Get-ChildItem $root -Recurse -Include *.ps1,*.psm1 | ForEach-Object {
    $tokens=$null; $errors=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors)
    if (@($errors).Count -gt 0) {
        foreach ($parseError in $errors) {
            Write-Host ("Parse error in {0} at {1}:{2}: {3}" -f $_.FullName, $parseError.Extent.StartLineNumber, $parseError.Extent.StartColumnNumber, $parseError.Message)
        }
        $failures++
    }
    $duplicates=@($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] } | Group-Object Name | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) { Write-Host "Duplicate functions in $($_.FullName): $($duplicates.Name -join ', ')"; $failures++ }
}
[void]([xml](Get-Content (Join-Path $root 'UI/MainWindow.xaml') -Raw -Encoding UTF8))
if ($failures -gt 0) { throw "$failures files failed validation" }
Write-Output 'PowerShell syntax, duplicate definitions and XAML XML validation passed.'
