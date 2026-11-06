# UI structure and contrast regressions, executable on PowerShell 7 and Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
[xml]$layout = Get-Content -LiteralPath (Join-Path $root 'UI/MainWindow.xaml') -Raw -Encoding UTF8
$ns = New-Object Xml.XmlNamespaceManager $layout.NameTable
$ns.AddNamespace('x','http://schemas.microsoft.com/winfx/2006/xaml')
function Assert-OptimizerUx([bool]$Pass,[string]$Message) {
    if (-not $Pass) { throw $Message }
}
$names = @($layout.SelectNodes('//*[@x:Name]', $ns) | ForEach-Object {
    $_.GetAttribute('Name','http://schemas.microsoft.com/winfx/2006/xaml')
})
$dupes = @($names | Group-Object | Where-Object Count -gt 1)
Assert-OptimizerUx ($dupes.Count -eq 0) 'Duplicate x:Name values block WPF binding.'
foreach ($required in @('NavOverview','NavDiagnose','NavHealth','NavCleanup','NavMaintenance','NavBench','NavReport','NavSettings','Pages','MaintenanceTabs','WorkbenchTabs','WorkbenchGrid','NetworkGrid','EventsGrid')) {
    Assert-OptimizerUx ($names -contains $required) "Missing UI navigation control: $required"
}
$workbench = $layout.SelectSingleNode("//*[@x:Name='WorkbenchTabs']", $ns)
$workbenchTabs = @($workbench.SelectNodes("./*[local-name()='TabItem']"))
Assert-OptimizerUx ($workbenchTabs.Count -eq 4) 'Workbench must have four focused tabs.'
$tabLabels = @($workbenchTabs | ForEach-Object { $_.GetAttribute('Header') })
Assert-OptimizerUx (($tabLabels -join ',') -eq 'Inventário,Rede,Histórico,Reparos') 'Unexpected workbench section labels or order.'
$buttons = @($layout.SelectNodes("//*[local-name()='Button']"))
$unnamed = @($buttons | Where-Object {
    $_.GetAttribute('Content') -and -not $_.GetAttribute('AutomationProperties.Name')
})
Assert-OptimizerUx ($unnamed.Count -eq 0) 'Some buttons lack accessible AutomationProperties.Name.'
$dataGrids = @($layout.SelectNodes("//*[local-name()='DataGrid']"))
$unnamedGrids = @($dataGrids | Where-Object { -not $_.GetAttribute('AutomationProperties.Name') })
Assert-OptimizerUx ($unnamedGrids.Count -eq 0) 'Some data grids lack accessible AutomationProperties.Name.'
$navButtonNames = @('NavOverview','NavDiagnose','NavHealth','NavCleanup','NavMaintenance','NavBench','NavSettings','NavReport')
for ($index = 0; $index -lt $navButtonNames.Count; $index++) {
    $name = $navButtonNames[$index]
    $btn = $layout.SelectSingleNode("//*[@x:Name='$name']", $ns)
    Assert-OptimizerUx ($btn.GetAttribute('Style') -match 'SidebarNavButton') "Missing keyboard-focusable navigation style: $name"
    Assert-OptimizerUx ($btn.GetAttribute('TabIndex') -eq [string]($index + 1)) "Explicit tab order missing for navigation: $name"
}
# Contrast calculations follow WCAG relative luminance, checking the app's primary color pairs.
function Get-OptimizerUxLuminance([string]$Hex) {
    $digits = $Hex.TrimStart('#')
    if ($digits.Length -ne 6) { throw 'Color must be six-digit hex.' }
    $values = New-Object 'System.Collections.Generic.List[double]'
    foreach ($index in @(0,2,4)) {
        $value = [Convert]::ToInt32($digits.Substring($index,2),16) / 255.0
        if ($value -le 0.04045) { $values.Add($value / 12.92) }
        else { $values.Add([math]::Pow((($value+0.055)/1.055),2.4)) }
    }
    return 0.2126*$values[0] + 0.7152*$values[1] + 0.0722*$values[2]
}
function Get-OptimizerUxContrast([string]$Foreground,[string]$Background) {
    $first = Get-OptimizerUxLuminance $Foreground
    $second = Get-OptimizerUxLuminance $Background
    return ([math]::Max($first,$second)+0.05)/([math]::Min($first,$second)+0.05)
}
foreach ($pair in @(
    @('#E2EDF5','#13283C'), # Sidebar normal
    @('#FFFFFF','#008080'), # Selected sidebar navigation
    @('#526B80','#F3F6FA'), # Muted text on app background
    @('#526B80','#E2F3EE'), # Muted text on green action card
    @('#526B80','#E7EDF4'), # Unselected tab label
    @('#FFFFFF','#117B6D')  # Primary buttons
)) {
    $ratio = Get-OptimizerUxContrast -Foreground $pair[0] -Background $pair[1]
    Assert-OptimizerUx ($ratio -ge 4.5) ("Insufficient text contrast: {0} on {1} ({2:N2})" -f $pair[0],$pair[1],$ratio)
}

# Dynamic resource references must resolve; this guards against blank text on theme changes.
$rawLayout = $layout.OuterXml
$keys = @($layout.SelectNodes('//*[@x:Key]', $ns) | ForEach-Object {
    $_.GetAttribute('Key','http://schemas.microsoft.com/winfx/2006/xaml')
})
$repeated = @($keys | Group-Object | Where-Object Count -gt 1)
Assert-OptimizerUx ($repeated.Count -eq 0) 'Duplicate theme resource keys.'
$dynamicReferences = [regex]::Matches($rawLayout,'\{DynamicResource (Ui[A-Za-z0-9]+)\}')
foreach ($reference in $dynamicReferences) {
    $key = $reference.Groups[1].Value
    Assert-OptimizerUx ($keys -contains $key) "Theme resource is undefined: $key"
}
foreach ($required in @('PreferenceHighContrast','PreferenceTextScale','PreferenceApplyButton','PreferenceResetButton')) {
    Assert-OptimizerUx ($names -contains $required) "Missing preferences UI control: $required"
}
$settingsTab = @($layout.SelectNodes("//*[local-name()='TabItem']") | Where-Object { $_.GetAttribute('Header') -eq 'Preferências' })
Assert-OptimizerUx ($settingsTab.Count -eq 1) 'Preferences must have exactly one main tab.'
Assert-OptimizerUx ($dynamicReferences.Count -ge 90) 'Theme resources not used consistently.'
$gui = Get-Content -LiteralPath (Join-Path $root 'Otimizador-GUI.ps1') -Raw -Encoding UTF8
foreach ($marker in @('function Open-OptimizerSection','Update-SidebarSelection','[Windows.Input.Key]::B','NavBench.RaiseEvent','WorkbenchTabs.SelectedIndex','Aplicar filtro','Restore-OptimizerCategorySelection','Save-OptimizerCategorySelection','Set-OptimizerDialogDirectory')) {
    Assert-OptimizerUx ($gui.Contains($marker)) "Missing functional keyboard/navigation binding: $marker"
}
Write-Output 'UX structural navigation, accessibility names and contrast checks passed.'
