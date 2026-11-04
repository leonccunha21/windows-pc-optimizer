$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$failures = 0
Get-ChildItem $root -Recurse -Include *.ps1,*.psm1 | ForEach-Object {
    $tokens=$null; $errors=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors)
    if ($errors) { $errors | ForEach-Object { Write-Output $_ }; $failures++ }
    $duplicates=@($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] } | Group-Object Name | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) { Write-Output "Duplicate functions in $($_.Name): $($duplicates.Name -join ', ')"; $failures++ }
}
[void]([xml](Get-Content (Join-Path $root 'UI/MainWindow.xaml') -Raw -Encoding UTF8))
if ($failures -gt 0) { throw "$failures files failed validation" }
Write-Output 'PowerShell syntax, duplicate definitions and XAML XML validation passed.'
