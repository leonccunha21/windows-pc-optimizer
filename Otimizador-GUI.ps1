#Requires -Version 5.1
param([switch]$ValidateUI, [string]$PreviewPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Import-Module (Join-Path $PSScriptRoot 'Modules\Optimizer.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules\Optimizer.Preferences.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules\Optimizer.Privacy.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules\Optimizer.Tweaks.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules\Optimizer.Agent.psm1') -Force
[xml]$layout = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'UI\MainWindow.xaml') -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $layout
$window = [Windows.Markup.XamlReader]::Load($reader)
$ui = @{}
$namespaces = New-Object Xml.XmlNamespaceManager $layout.NameTable
$namespaces.AddNamespace('x','http://schemas.microsoft.com/winfx/2006/xaml')
foreach ($node in $layout.SelectNodes('//*[@x:Name]', $namespaces)) {
    $ui[$node.GetAttribute('Name','http://schemas.microsoft.com/winfx/2006/xaml')] = $window.FindName($node.GetAttribute('Name','http://schemas.microsoft.com/winfx/2006/xaml'))
}
$script:scan = $null; $script:cleanup = $null; $script:diagnostics = @(); $script:worker = $null
$script:battery = $null; $script:disks = $null; $script:appx = @(); $script:optimizations = @(); $script:driverUpdates = $null; $script:agentRecommendations = @()
$script:lastSaveDirectory = ''
$script:state = [hashtable]::Synchronized(@{Cancel=$false; Message=''; Result=$null; Error=$null; Total=0; Processed=0})
$script:modulePath = Join-Path $PSScriptRoot 'Modules\Optimizer.Core.psm1'
$script:technicianPath = Join-Path $PSScriptRoot 'Modules\Optimizer.Technician.psm1'
$script:networkPath = Join-Path $PSScriptRoot 'Modules\Optimizer.NetworkDiagnostics.psm1'
$script:eventsPath = Join-Path $PSScriptRoot 'Modules\Optimizer.Events.psm1'
$script:privacyPath = Join-Path $PSScriptRoot 'Modules\Optimizer.Privacy.psm1'
$script:tweaksPath = Join-Path $PSScriptRoot 'Modules\Optimizer.Tweaks.psm1'
$script:agentPath = Join-Path $PSScriptRoot 'Modules\Optimizer.Agent.psm1'
$script:isAdmin = $false
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $script:isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { Write-Verbose 'Não foi possível verificar elevação.' }
if ($script:isAdmin) { $ui.ElevateButton.Visibility = 'Collapsed' }


# Non-sensitive display settings, never stored alongside customer data or diagnostics.
$script:themeNormal = @{}
$script:fontDefaults = @{}
foreach ($resourceKey in @($window.Resources.Keys)) {
    $resourceName = [string]$resourceKey
    if ($resourceName -like 'UiColor*' -or $resourceName -eq 'UiCardBrush') {
        $script:themeNormal[$resourceName] = [string]$window.Resources[$resourceName].Color
    }
    if ($resourceName -like 'UiFont*') {
        $script:fontDefaults[$resourceName] = [double]$window.Resources[$resourceName]
    }
}
$script:highContrastColors = @{
    UiColor102638='#000000'
    UiColorF3F6FA='#050505'
    UiColor192C42='#FFFFFF'
    UiColor117B6D='#004F78'
    UiColor38BDF8='#FFFF00'
    UiColorE2EDF5='#FFFFFF'
    UiColor5BD7C4='#FFDD55'
    UiColorF5D579='#FFFF00'
    UiColorE1E8F0='#F2F2F2'
    UiColorC7D5E2='#FFFFFF'
    UiColorE7EDF3='#777777'
    UiColorF7FAFC='#1D1D1D'
    UiColorE7EDF4='#242424'
    UiColor526B80='#EEEEEE'
    UiColor13283C='#000000'
    UiColor23C6AA='#FFFF00'
    UiColor86A6C0='#FFFFFF'
    UiColor9BB5C7='#FFFFFF'
    UiColor0E887A='#005A85'
    UiColor203C50='#161616'
    UiColor6DE0D0='#FFFF00'
    UiColorD2E2EC='#FFFFFF'
    UiColor67DDC6='#FFFF00'
    UiColorC0392B='#981B1B'
    UiColorE2F3EE='#191919'
    UiColor40566C='#214C70'
    UiColorFFF5DF='#282213'
    UiColor99601E='#735013'
    UiColorDCE6EF='#666666'
    UiCardBrush='#101010'
}
function Set-OptimizerVisualPreferences {
    param([Parameter(Mandatory)][object]$Preferences)
    if (-not (Test-OptimizerPreferenceValues -Preferences $Preferences)) {
        throw 'Preferências de interface inválidas.'
    }
    $systemContrast = [bool][Windows.SystemParameters]::HighContrast
    $contrast = [bool]$Preferences.HighContrast -or $systemContrast
    foreach ($key in $script:themeNormal.Keys) {
        $color = $script:themeNormal[$key]
        if ($contrast -and $script:highContrastColors.ContainsKey($key)) {
            $color = $script:highContrastColors[$key]
        }
        $window.Resources[$key] = [Windows.Media.SolidColorBrush]::new(
            [Windows.Media.ColorConverter]::ConvertFromString($color)
        )
    }
    $factor = [double]$Preferences.TextScale / 100.0
    $window.FontSize = [double](13.0 * $factor)
    foreach ($key in $script:fontDefaults.Keys) {
        $window.Resources[$key] = [double]($script:fontDefaults[$key] * $factor)
    }
    $window.Resources['UiRowHeight'] = [double](38 * $factor)
    $script:activePreferences = [pscustomobject]@{
        SchemaVersion=1
        HighContrast=[bool]$Preferences.HighContrast
        TextScale=[int]$Preferences.TextScale
    }
    $ui.PreferenceHighContrast.IsChecked = $contrast
    $ui.PreferenceHighContrast.IsEnabled = -not $systemContrast
    $target = [string]$Preferences.TextScale
    foreach ($option in $ui.PreferenceTextScale.Items) {
        if ([string]$option.Tag -eq $target) {
            $ui.PreferenceTextScale.SelectedItem = $option
            break
        }
    }
    $ui.PreferenceStatus.Text = if ($systemContrast) {
        'O Alto Contraste do Windows está ativo; ele tem prioridade nesta janela.'
    } else {
        'Leitura ajustada. Escolha Aplicar e salvar para gravar o ajuste.'
    }
    Update-SidebarSelection
}
function Save-OptimizerVisualPreferencesFromUI {
    $selected = $ui.PreferenceTextScale.SelectedItem
    if ($null -eq $selected) { throw 'Escolha uma ampliação de texto.' }
    $values = [pscustomobject]@{
        SchemaVersion=1
        HighContrast=([bool]$ui.PreferenceHighContrast.IsChecked)
        TextScale=[int]([string]$selected.Tag)
    }
    $saved = Save-OptimizerPreferences -Preferences $values
    Set-OptimizerVisualPreferences -Preferences $saved
    $ui.PreferenceStatus.Text = 'Preferências salvas neste perfil do Windows.'
}
$ui.PreferenceApplyButton.Add_Click({
    try { Save-OptimizerVisualPreferencesFromUI }
    catch {
        $ui.PreferenceStatus.Text = 'Não foi possível salvar: ' + $_.Exception.Message
        if (-not $ValidateUI) { [void][Windows.MessageBox]::Show($window,$_.Exception.Message,'Preferências','OK','Warning') }
    }
})
$ui.PreferenceResetButton.Add_Click({
    try {
        $saved = Save-OptimizerPreferences -Preferences (Get-OptimizerPreferenceDefaults)
        Set-OptimizerVisualPreferences -Preferences $saved
        $ui.PreferenceStatus.Text = 'Preferências padrão restauradas neste perfil.'
    } catch {
        $ui.PreferenceStatus.Text = 'Não foi possível restaurar: ' + $_.Exception.Message
    }
})

# Cleanup category ids are generic names, never customer data or file paths.
function Get-OptimizerSelectedCategoryIds {
    if ($null -eq $script:scan) { return @() }
    return @($script:scan.Categories | Where-Object Selected | ForEach-Object { [string]$_.Id })
}
function Save-OptimizerCategorySelection {
    try {
        $current = Read-OptimizerPreferences
        $current.SelectedCategories = @(Get-OptimizerSelectedCategoryIds)
        [void](Save-OptimizerPreferences -Preferences $current)
    } catch { Write-Verbose ('Seleção de categorias não gravada: ' + $_.Exception.Message) }
}
function Restore-OptimizerCategorySelection($Scan) {
    if ($null -eq $Scan) { return }
    try {
        if (-not (Test-Path -LiteralPath (Get-OptimizerPreferencesPath) -PathType Leaf)) { return }
        $saved = @((Read-OptimizerPreferences).SelectedCategories)
        foreach ($category in @($Scan.Categories)) {
            $category.Selected = [string]$category.Id -in $saved
        }
    } catch { Write-Verbose ('Seleção anterior indisponível: ' + $_.Exception.Message) }
}
function Set-OptimizerDialogDirectory($Dialog) {
    if ($script:lastSaveDirectory -and (Test-Path -LiteralPath $script:lastSaveDirectory -PathType Container)) {
        $Dialog.InitialDirectory = $script:lastSaveDirectory
    }
}
function Save-OptimizerDialogDirectory($Dialog) {
    try {
        $directory = [IO.Path]::GetDirectoryName([string]$Dialog.FileName)
        if ($directory -and (Test-Path -LiteralPath $directory -PathType Container)) { $script:lastSaveDirectory = $directory }
    } catch { Write-Verbose 'Pasta de destino não memorizada.' }
}

function Set-Busy([bool]$Busy) {
    foreach ($name in @('ScanButton','DiagnoseButton','DiagnoseHome','GoClean','ExportButton','SelectAllButton','SelectNoneButton','ElevateButton','HealthAnalyzeButton','HealthHome','BatteryReportButton','DriverScanButton','DriverUpdatesButton','DriverUpdateTool','DeviceManagerTool','AppxScanButton','AppxRemoveButton','OptimizationRunButton','PreferenceApplyButton','PreferenceResetButton','HealthShortcut','MaintenanceShortcut','WorkbenchShortcut','AgentButton','AgentApplyButton','InvProcessesButton','InvStartupButton','InvSoftwareButton','InvNetworkButton','InvUpdatesButton','InvStorageButton','NetworkSnapshotButton','NetworkRevealButton','NetworkProbeButton','EventsAnalyzeButton','SfcVerifyButton','DismScanButton','ChkdskScanButton','SfcRepairButton','DismRepairButton')) { $ui[$name].IsEnabled = -not $Busy }
    $ui.CleanButton.IsEnabled = -not $Busy -and $null -ne $script:scan -and -not $script:scan.Cancelled -and @($script:scan.Files).Count -gt 0
    $ui.DetailsButton.IsEnabled = -not $Busy -and ($null -ne $script:scan -or $null -ne $script:cleanup)
    $ui.ExportResultsButton.IsEnabled = -not $Busy -and $null -ne $script:cleanup
    $ui.Categories.IsEnabled = -not $Busy
    $ui.CancelButton.IsEnabled = $Busy -and $script:operation -ne 'Diagnose'
    $ui.Progress.IsIndeterminate = $Busy -and $script:operation -ne 'Clean'
    if (-not $Busy) { $ui.Progress.Value = 0 }
}
function Update-BatteryView {
    if ($null -eq $script:battery) { return }
    $battery = $script:battery
    $rows = @(
        [pscustomobject]@{ Item='Bateria detectada'; Value=if ($battery.HasBattery) { 'Sim' } else { 'Não' } }
        [pscustomobject]@{ Item='Carga restante'; Value=if ($null -ne $battery.EstimatedChargeRemaining) { "$($battery.EstimatedChargeRemaining)%" } else { 'Não informada' } }
        [pscustomobject]@{ Item='Fabricante'; Value=if ($battery.Manufacturer) { $battery.Manufacturer } else { 'Não informado' } }
        [pscustomobject]@{ Item='Química'; Value=if ($battery.Chemistry) { $battery.Chemistry } else { 'Não informada' } }
        [pscustomobject]@{ Item='Saúde estimada'; Value=if ($null -ne $battery.HealthPercent) { "$($battery.HealthPercent)% ($($battery.Rating))" } else { 'Indisponível' } }
        [pscustomobject]@{ Item='Capacidade de projeto'; Value=if ($battery.DesignCapacityMWh -gt 0) { "$([math]::Round($battery.DesignCapacityMWh / 1000)) mAh (nominal)" } else { '—' } }
        [pscustomobject]@{ Item='Carga completa atual'; Value=if ($battery.FullChargeCapacityMWh -gt 0) { "$([math]::Round($battery.FullChargeCapacityMWh / 1000)) mAh (nominal)" } else { '—' } }
        [pscustomobject]@{ Item='Ciclos'; Value=if ($battery.CycleCount -gt 0) { [string]$battery.CycleCount } else { 'Não informado' } }
        [pscustomobject]@{ Item='Método'; Value=if ($battery.Method) { $battery.Method } else { 'WMI / indisponível' } }
        [pscustomobject]@{ Item='Observação'; Value=if ($battery.Note) { $battery.Note } else { '—' } }
    )
    $ui.BatteryGrid.ItemsSource = $rows
    if (-not $battery.HasBattery) {
        $ui.BatterySummary.Text = if ($battery.Note) { $battery.Note } else { 'Nenhuma bateria detectada.' }
    } elseif ($null -ne $battery.HealthPercent) {
        $cycles = if ($battery.CycleCount -gt 0) { $battery.CycleCount } else { 'não informado' }
        $ui.BatterySummary.Text = "Saúde estimada: $($battery.HealthPercent)% — $($battery.Rating). Ciclos: $cycles."
    } else {
        $ui.BatterySummary.Text = 'Bateria detectada; capacidade de projeto não informada pelo fabricante.'
    }
    $script:diagnostics = @($script:diagnostics | Where-Object { $_.Area -ne 'Bateria' }) + @($rows | ForEach-Object { [pscustomobject]@{ Area='Bateria'; Item=$_.Item; Value=$_.Value } })
}
function Update-DiskView {
    if ($null -eq $script:disks) { return }
    $ui.DiskGrid.ItemsSource = @($script:disks.Disks)
    $ui.VolumeGrid.ItemsSource = @($script:disks.Volumes)
    $diskRows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($disk in @($script:disks.Disks)) {
        $diskRows.Add([pscustomobject]@{ Area='Discos'; Item=[string]$disk.Device; Value=('{0} • {1} • {2} • {3} • Horas: {4} • Desgaste: {5}' -f $disk.Media, $disk.Rating, $disk.Size, $disk.Temperature, $disk.PowerOnHours, $disk.Wear) })
    }
    foreach ($volume in @($script:disks.Volumes)) {
        $diskRows.Add([pscustomobject]@{ Area='Discos'; Item=('Volume ' + $volume.Letter); Value=('Livre {0} de {1} • {2}' -f $volume.Free, $volume.Total, $volume.Health) })
    }
    if ($script:disks.Note) { $diskRows.Add([pscustomobject]@{ Area='Discos'; Item='Observação'; Value=$script:disks.Note }) }
    $script:diagnostics = @($script:diagnostics | Where-Object { $_.Area -ne 'Discos' }) + $diskRows.ToArray()
    $ui.HealthNote.Text = if ($script:disks.Note) { $script:disks.Note } else { 'Contadores SMART variam por fabricante e controladora. Ausência de leitura não significa disco saudável. SMART completo (temperatura/horas) requer administrador.' }
}
function Update-AppxGrid {
    $rows = if ($ui.AppxBloatOnly.IsChecked) { @($script:appx | Where-Object Suggested) } else { @($script:appx) }
    $ui.AppxGrid.ItemsSource = $rows
    if (@($script:appx).Count -eq 0) {
        $ui.AppxSummary.Text = 'Nenhum inventário carregado. Clique em "Listar aplicativos instalados".'
    } else {
        $suggested = @($script:appx | Where-Object Suggested).Count
        $ui.AppxSummary.Text = "$(@($rows).Count) aplicativos exibidos • $suggested sugestões de remoção • reavalie antes de remover."
    }
}
function Update-ConnectionNote {
    if ($script:isAdmin) {
        $ui.OptimizationNote.Text = 'Executando como administrador: todas as ações abaixo estão disponíveis. Ainda assim, cada uma exige confirmação.'
    } else {
        $ui.OptimizationNote.Text = 'Sem elevação: remover aplicativos do usuário funciona; ações marcadas com Admin falham com explicação e nada é alterado.'
    }
}
function Start-Work([string]$Operation, $Payload) {
    if ($null -ne $script:worker) { return }
    $script:operation = $Operation
    $script:state.Cancel = $false; $script:state.Error = $null; $script:state.Result = $null; $script:state.Message = 'Preparando...'; $script:state.Processed = 0; $script:state.Total = 0
    $script:worker = [PowerShell]::Create()
    [void]$script:worker.AddScript({
        param($ModulePath, $TechnicianPath, $NetworkPath, $EventsPath, $PrivacyPath, $TweaksPath, $AgentPath, $Operation, $Payload, $State)
        try {
            Import-Module $ModulePath -Force -ErrorAction Stop
            Import-Module $TechnicianPath -Force -ErrorAction Stop
            Import-Module $NetworkPath -Force -ErrorAction Stop
            Import-Module $EventsPath -Force -ErrorAction Stop
            Import-Module $PrivacyPath -Force -ErrorAction Stop
            Import-Module $TweaksPath -Force -ErrorAction Stop
            Import-Module $AgentPath -Force -ErrorAction Stop
            switch ($Operation) {
                'Scan' {
                    if ($null -ne $Payload -and $null -ne $Payload.Targets) { $State.Result = Get-OptimizerScan -State $State -Targets $Payload.Targets }
                    else { $State.Result = Get-OptimizerScan -State $State }
                }
                'Clean' { $State.Result = Invoke-OptimizerCleanup -Scan $Payload.Scan -CategoryIds $Payload.Ids -State $State -Confirm:$false }
                'Diagnose' { $State.Message = 'Consultando hardware e Windows...'; $State.Result = @(Get-OptimizerDiagnostics) }
                'Health' {
                    $State.Message = 'Lendo bateria...'; $batteryResult = Get-OptimizerBatteryHealth
                    $State.Message = 'Lendo discos e volumes...'; $diskResult = Get-OptimizerDiskHealth
                    $State.Result = [pscustomobject]@{ Battery=$batteryResult; Disks=$diskResult }
                }
                'Drivers' { $State.Message = 'Inventariando drivers...'; $State.Result = @(Get-OptimizerDrivers) }
                'DriverUpdates' { $State.Message = 'Consultando drivers no Windows Update...'; $State.Result = Get-OptimizerDriverUpdates }
                'Appx' { $State.Message = 'Listando aplicativos instalados...'; $State.Result = @(Get-OptimizerAppInventory) }
                'Inspect' { $State.Result = @(Get-OptimizerTechnicalInventory -Area ([string]$Payload.Area) -State $State) }
                'NetworkSnapshot' { $State.Result = @(Get-OptimizerNetworkSnapshot -IncludeAddresses:([bool]$Payload.Reveal) -State $State) }
                'NetworkProbe' { $State.Result = @(Invoke-OptimizerConnectivityCheck -Target ([string]$Payload.Host) -DnsName ([string]$Payload.Host) -Port ([int]$Payload.Port) -State $State) }
                'Events' { $State.Result = Get-OptimizerEventSummary -Days 14 -State $State }
                'RemoveAppx' { $State.Message = 'Removendo aplicativos selecionados...'; $State.Result = @(Invoke-OptimizerAppRemoval -PackageFullNames $Payload.Names -Confirm:$false) }
                'Optimize' { $State.Message = 'Aplicando otimizações selecionadas...'; $State.Result = @(Invoke-OptimizerOptimization -Ids $Payload.Ids -Confirm:$false) }
                'ApplyPrivacy' {
                    $State.Message = 'Aplicando configurações de privacidade...'
                    $list = New-Object System.Collections.Generic.List[object]
                    foreach ($act in $Payload.Ids) {
                        $list.Add((Invoke-OptimizerPrivacyAction -Action $act -Confirm:$false))
                    }
                    $State.Result = $list.ToArray()
                }
                'ApplyTweaks' {
                    $State.Message = 'Aplicando ajustes de sistema selecionados...'
                    $list = New-Object System.Collections.Generic.List[object]
                    foreach ($act in $Payload.Ids) {
                        $list.Add((Invoke-OptimizerTweak -Action $act -Confirm:$false))
                    }
                    $State.Result = $list.ToArray()
                }
                'Agent' {
                    $State.Message = 'Assistente local analisando diagnóstico, saúde, limpeza e aplicativos...'
                    $State.Result = @(Get-OptimizerAgentRecommendations -Diagnostics $Payload.Diagnostics -Health $Payload.Health -Scan $Payload.Scan -AppInventory $Payload.AppInventory -IsAdmin $Payload.IsAdmin)
                }
            }
        } catch { $State.Error = $_.Exception.Message }
    }).AddArgument($script:modulePath).AddArgument($script:technicianPath).AddArgument($script:networkPath).AddArgument($script:eventsPath).AddArgument($script:privacyPath).AddArgument($script:tweaksPath).AddArgument($script:agentPath).AddArgument($Operation).AddArgument($Payload).AddArgument($script:state)
    $script:handle = $script:worker.BeginInvoke()
    Set-Busy $true
    $timer.Start()
}
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(200)
$timer.Add_Tick({
    $ui.Status.Text = $script:state.Message
    if ($script:operation -eq 'Clean' -and $script:state.Total -gt 0) { $ui.Progress.Value = [math]::Min(100, [math]::Round(100 * $script:state.Processed / $script:state.Total)) }
    if (-not $script:handle.IsCompleted) { return }
    $timer.Stop()
    try {
        [void]$script:worker.EndInvoke($script:handle)
        if ($script:state.Error) { throw $script:state.Error }
        switch ($script:operation) {
            'Scan' {
                $script:scan = $script:state.Result
                $ui.Categories.ItemsSource = @($script:scan.Categories)
                Restore-OptimizerCategorySelection $script:scan
                $ui.ScanWarnings.Text = $script:scan.Warnings -join "`n"
                $ui.ScanMetric.Text = Format-OptimizerSize $script:scan.Bytes
                $ui.Status.Text = if ($script:scan.Cancelled) { 'Análise interrompida. Analise novamente para liberar a limpeza.' } else { 'Análise concluída. Revise as categorias e a lista de arquivos.' }
            }
            'Clean' {
                $script:cleanup = $script:state.Result
                $ui.CleanMetric.Text = Format-OptimizerSize $script:cleanup.RemovedBytes
                $ui.CleanupSummary.Text = '{0} liberados • {1} removidos • {2} ignorados • Interrompido: {3}' -f (Format-OptimizerSize $script:cleanup.RemovedBytes), $script:cleanup.RemovedCount, $script:cleanup.SkippedCount, $script:cleanup.Cancelled
                $ui.Status.Text = 'Resultado registrado. Faça uma nova análise antes de outra limpeza.'
                $ui.ScanWarnings.Text = (@($script:cleanup.Results | Where-Object Status -eq 'Ignorado' | Select-Object -First 30 | ForEach-Object { "$($_.Path): $($_.Detail)" }) -join "`n")
                $script:scan = $null
                $ui.Categories.ItemsSource = @()
            }
            'Diagnose' { $script:diagnostics = @($script:state.Result); $ui.DiagnosticsGrid.ItemsSource = $script:diagnostics; $ui.Status.Text = 'Diagnóstico concluído. Confira itens indisponíveis e observações.' }
            'Health' {
                $script:battery = $script:state.Result.Battery
                $script:disks = $script:state.Result.Disks
                Update-BatteryView
                Update-DiskView
                $ui.Status.Text = 'Saúde consultada. Confira saúde da bateria, contadores SMART e espaço dos volumes.'
            }
            'Inspect' {
                $rows = @($script:state.Result)
                $ui.WorkbenchGrid.ItemsSource = $rows
                $ui.WorkbenchSummary.Text = ('Consulta concluída: {0} registros • nenhuma alteração.' -f $rows.Count)
                $ui.Status.Text = 'Inventário técnico atualizado.'
            }
            'NetworkSnapshot' {
                $rows = @($script:state.Result)
                $ui.NetworkGrid.ItemsSource = $rows
                $ui.NetworkSummary.Text = ('Configuração local: {0} registros; nenhum teste externo realizado.' -f $rows.Count)
                $ui.Status.Text = 'Consulta local de rede concluída.'
            }
            'NetworkProbe' {
                $rows = @($script:state.Result)
                $ui.NetworkGrid.ItemsSource = $rows
                $ui.NetworkSummary.Text = ('Teste solicitado: {0} resultados; confira avisos.' -f $rows.Count)
                $ui.Status.Text = 'Consulta DNS/TCP concluída.'
            }
            'Events' {
                $summary = $script:state.Result
                $ui.EventsGrid.ItemsSource = @($summary.Categories)
                $warningText = @($summary.Warnings) -join ' • '
                $ui.EventsSummary.Text = ('{0} examinados • {1} classificados • {2} categorias. {3}' -f $summary.Examined, $summary.Matched, @($summary.Categories).Count, $warningText)
                $ui.Status.Text = if ($summary.Available) { 'Histórico consultado; eventos preservados.' } else { 'Consulta do log indisponível.' }
            }
            'Drivers' {
                $drivers = @($script:state.Result)
                $ui.DriverGrid.ItemsSource = $drivers
                $old = @($drivers | Where-Object Status -eq 'Driver antigo').Count
                $unsigned = @($drivers | Where-Object Status -eq 'Não assinado').Count
                $ui.DriverSummary.Text = "$($drivers.Count) drivers listados • $($old) para verificação • $($unsigned) não assinados. A consulta não instala nada."
                $ui.Status.Text = 'Inventário de drivers concluído.'
            }
            'DriverUpdates' {
                $script:driverUpdates = $script:state.Result
                if ($script:driverUpdates.Error) {
                    $ui.DriverUpdateGrid.ItemsSource = @()
                    $ui.DriverSummary.Text = $script:driverUpdates.Error
                    $ui.Status.Text = 'Consulta de drivers indisponível.'
                } else {
                    $ui.DriverUpdateGrid.ItemsSource = @($script:driverUpdates.Updates)
                    $count = @($script:driverUpdates.Updates).Count
                    $ui.DriverSummary.Text = if ($count -eq 0) { 'Nenhuma atualização de driver pendente no Windows Update.' } else { "$count atualizações de driver encontradas. Instale pelo Windows Update após revisar." }
                    $ui.Status.Text = 'Consulta de drivers concluída. Nada foi instalado.'
                }
            }
            'Appx' {
                $script:appx = @($script:state.Result)
                Update-AppxGrid
                $ui.Status.Text = 'Aplicativos listados. Marque somente o que deseja remover.'
            }
            'RemoveAppx' {
                $results = @($script:state.Result)
                $removed = @($results | Where-Object Status -eq 'Removido')
                $names = @($removed | ForEach-Object { $_.PackageFullName })
                if ($names.Count -gt 0) { $script:appx = @($script:appx | Where-Object { $_.PackageFullName -notin $names }) }
                Update-AppxGrid
                $failed = @($results | Where-Object Status -eq 'Falhou')
                $ui.Status.Text = "$($removed.Count) aplicativos removidos • $($failed.Count) falhas. Reinstale pela Microsoft Store se necessário."
                if ($failed.Count -gt 0) { $ui.AppxNote.Text = (@($failed | Select-Object -First 6 | ForEach-Object { "$($_.Name): $($_.Detail)" }) -join ' | ') }
            }
            'Optimize' {
                $results = @($script:state.Result)
                foreach ($result in $results) {
                    $entry = @($script:optimizations | Where-Object { $_.Id -eq $result.Id }) | Select-Object -First 1
                    if ($null -ne $entry) { $entry.Selected = $false }
                }
                $ui.OptimizationGrid.Items.Refresh()
                $applied = @($results | Where-Object Status -eq 'Aplicado').Count
                $failed = @($results | Where-Object Status -eq 'Falhou')
                $details = @($results | ForEach-Object { "$($_.Name): $($_.Status)" }) -join ' • '
                $ui.OptimizationSummary.Text = "$applied aplicadas • $($failed.Count) falhas. $details"
                if ($failed.Count -gt 0) { $ui.OptimizationNote.Text = (@($failed | ForEach-Object { "$($_.Name): $($_.Detail)" }) -join ' | ') }
                $ui.Status.Text = 'Otimizações concluídas. Revise o resultado antes de repetir.'
            }
            'ApplyPrivacy' {
                $results = @($script:state.Result)
                $applied = @($results | Where-Object Success).Count
                $failed = @($results | Where-Object { -not $_.Success })
                foreach ($res in $results) {
                    $entry = @($script:privacyCatalog | Where-Object { $_.Id -eq $res.Action }) | Select-Object -First 1
                    if ($null -ne $entry) { $entry.Selected = $false }
                }
                $ui.PrivacyGrid.Items.Refresh()
                $ui.Status.Text = "$applied ações de privacidade aplicadas • $($failed.Count) falhas."
                $ui.PrivacySummary.Text = "$applied de $($results.Count) configurações de privacidade aplicadas com sucesso."
                if ($failed.Count -gt 0) { $ui.PrivacyNote.Text = (@($failed | ForEach-Object { "$($_.Action): $($_.Message)" }) -join ' | ') }
            }
            'ApplyTweaks' {
                $results = @($script:state.Result)
                $applied = @($results | Where-Object Success).Count
                $failed = @($results | Where-Object { -not $_.Success })
                foreach ($res in $results) {
                    $entry = @($script:tweaksCatalog | Where-Object { $_.Id -eq $res.Action }) | Select-Object -First 1
                    if ($null -ne $entry) { $entry.Selected = $false }
                }
                $ui.TweaksGrid.Items.Refresh()
                $ui.Status.Text = "$applied ajustes aplicados • $($failed.Count) falhas."
                $ui.TweaksSummary.Text = "$applied de $($results.Count) ajustes do sistema aplicados com sucesso."
                if ($failed.Count -gt 0) { $ui.TweaksNote.Text = (@($failed | ForEach-Object { "$($_.Action): $($_.Message)" }) -join ' | ') }
            }
            'Agent' {
                $script:agentRecommendations = @($script:state.Result)
                $top = @($script:agentRecommendations | Select-Object -First 3 | ForEach-Object { $_.Title }) -join ' • '
                $ui.AgentSummary.Text = "Recomendações: $top. Use Pré-selecionar para marcar os itens; nada foi aplicado."
                $ui.Status.Text = 'Assistente local concluiu. Revise as recomendações antes de aplicar.'
            }
        }
    } catch {
        $ui.Status.Text = 'Falha: ' + $_.Exception.Message
        if ($script:operation -eq 'Clean') { $script:scan = $null }
        if (-not $ValidateUI) { [void][Windows.MessageBox]::Show($window, $_.Exception.Message, 'Operação não concluída', 'OK', 'Warning') }
    } finally { $script:worker.Dispose(); $script:worker = $null; Set-Busy $false }
})

# Sidebar navigation shares the existing Pages/MaintenanceTabs selection, not a second page state.
function Update-SidebarSelection {
    $current = 'NavOverview'
    switch ([int]$ui.Pages.SelectedIndex) {
        0 { $current = 'NavOverview' }
        1 { $current = 'NavCleanup' }
        2 { $current = 'NavDiagnose' }
        3 { $current = 'NavHealth' }
        4 {
            if ([int]$ui.MaintenanceTabs.SelectedIndex -eq 4) { $current = 'NavBench' }
            elseif ([int]$ui.MaintenanceTabs.SelectedIndex -eq 5) { $current = 'NavPrivacy' }
            elseif ([int]$ui.MaintenanceTabs.SelectedIndex -eq 6) { $current = 'NavTweaks' }
            else { $current = 'NavMaintenance' }
        }
        5 { $current = 'NavReport' }
        6 { $current = 'NavSettings' }
    }
    foreach ($name in @('NavOverview','NavDiagnose','NavHealth','NavCleanup','NavMaintenance','NavBench','NavPrivacy','NavTweaks','NavReport','NavSettings')) {
        $ui[$name].Background = if ($name -eq $current) { $window.Resources['UiColor0E887A'] } else { [Windows.Media.Brushes]::Transparent }
    }
}
function Open-OptimizerSection([int]$PageIndex, [int]$MaintenanceIndex = -1) {
    if ($PageIndex -eq 4 -and $MaintenanceIndex -ge 0) { $ui.MaintenanceTabs.SelectedIndex = $MaintenanceIndex }
    $ui.Pages.SelectedIndex = $PageIndex
    Update-SidebarSelection
}
foreach ($navigation in @(
    @('NavOverview',0,-1),@('NavDiagnose',2,-1),@('NavHealth',3,-1),
    @('NavCleanup',1,-1),@('NavMaintenance',4,0),@('NavBench',4,4),
    @('NavPrivacy',4,5),@('NavTweaks',4,6),
    @('NavReport',5,-1),@('NavSettings',6,-1)
)) {
    $ui[$navigation[0]].Tag = @([int]$navigation[1],[int]$navigation[2])
    $ui[$navigation[0]].Add_Click({
        param($navigationSender)
        $target = @($navigationSender.Tag)
        Open-OptimizerSection -PageIndex ([int]$target[0]) -MaintenanceIndex ([int]$target[1])
    })
}
$ui.Pages.Add_SelectionChanged({ Update-SidebarSelection })
$ui.MaintenanceTabs.Add_SelectionChanged({ Update-SidebarSelection })
Update-SidebarSelection
try {
    Set-OptimizerVisualPreferences -Preferences (Read-OptimizerPreferences)
} catch {
    Set-OptimizerVisualPreferences -Preferences (Get-OptimizerPreferenceDefaults)
    $ui.PreferenceStatus.Text = 'Preferências indisponíveis; modo padrão aplicado.'
}
$ui.ScanButton.Add_Click({ Start-Work 'Scan' $null })
$ui.ElevateButton.Add_Click({
    if ($script:isAdmin) { return }
    $answer = [Windows.MessageBox]::Show($window, "Reabrir o PC Optimizer como administrador?`n`nCategorias de sistema (Temp do Windows, Windows Update, Otimização de Entrega, Prefetch, despejos e WER da máquina) só aparecem com elevação.`n`nUse a mesma conta do cliente: credenciais de outro usuário mudam o perfil analisado.", 'Abrir como administrador', 'YesNo', 'Warning', 'No')
    if ($answer -ne 'Yes') { return }
    try {
        $scriptPath = Join-Path $PSScriptRoot 'Otimizador-GUI.ps1'
        $arguments = @('-NoLogo','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $scriptPath))
        Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -Verb RunAs
        $window.Close()
    } catch {
        $ui.Status.Text = 'Elevação cancelada ou indisponível. Nenhuma alteração foi feita.'
    }
})
$ui.GoClean.Add_Click({ $ui.Pages.SelectedIndex = 1; Start-Work 'Scan' $null })
$ui.DiagnoseHome.Add_Click({ $ui.Pages.SelectedIndex = 2; Start-Work 'Diagnose' $null })
$ui.DiagnoseButton.Add_Click({ Start-Work 'Diagnose' $null })
$ui.CancelButton.Add_Click({ $script:state.Cancel = $true; $ui.CancelButton.IsEnabled = $false; $ui.Status.Text = 'Interrompendo após o arquivo atual...' })
$ui.CloseButton.Add_Click({ $window.Close() })
$ui.HealthAnalyzeButton.Add_Click({ Start-Work 'Health' $null })
$ui.HealthHome.Add_Click({ $ui.Pages.SelectedIndex = 3; Start-Work 'Health' $null })
$ui.HealthShortcut.Add_Click({ $ui.Pages.SelectedIndex = 3 })
$ui.MaintenanceShortcut.Add_Click({ $ui.Pages.SelectedIndex = 4 })
$ui.WorkbenchShortcut.Add_Click({ Open-OptimizerSection -PageIndex 4 -MaintenanceIndex 4; $ui.WorkbenchTabs.SelectedIndex = 0 })
$ui.PrivacyShortcut.Add_Click({ Open-OptimizerSection -PageIndex 4 -MaintenanceIndex 5 })
$ui.TweaksShortcut.Add_Click({ Open-OptimizerSection -PageIndex 4 -MaintenanceIndex 6 })
$ui.AgentButton.Add_Click({
    if ($null -ne $script:worker) { return }
    $health = $null
    if ($null -ne $script:battery -or $null -ne $script:disks) {
        $health = [pscustomobject]@{ Battery=$script:battery; Disks=$script:disks }
    }
    Start-Work 'Agent' @{
        Diagnostics=@($script:diagnostics)
        Health=$health
        Scan=$script:scan
        AppInventory=@($script:appx)
        IsAdmin=[bool]$script:isAdmin
    }
})
$ui.AgentApplyButton.Add_Click({
    if ($script:agentRecommendations.Count -eq 0) {
        $ui.AgentSummary.Text = 'Clique primeiro em Recomendar melhores opções.'
        $ui.Status.Text = 'Nenhuma recomendação do assistente nesta sessão.'
        return
    }
    $optimizationIds = @()
    $privacyIds = @()
    $tweakIds = @()
    $cleanupIds = @()
    foreach ($recommendation in $script:agentRecommendations) {
        $optimizationIds += @($recommendation.OptimizationIds)
        $privacyIds += @($recommendation.PrivacyIds)
        $tweakIds += @($recommendation.TweakIds)
        $cleanupIds += @($recommendation.CleanupCategoryIds)
    }
    foreach ($entry in $script:optimizations) { $entry.Selected = $entry.Id -in $optimizationIds }
    foreach ($entry in $script:privacyCatalog) { $entry.Selected = $entry.Id -in $privacyIds }
    foreach ($entry in $script:tweaksCatalog) { $entry.Selected = $entry.Id -in $tweakIds }
    if ($null -ne $script:scan) {
        foreach ($category in @($script:scan.Categories)) { $category.Selected = [string]$category.Id -in $cleanupIds }
    }
    $ui.OptimizationGrid.Items.Refresh()
    $ui.PrivacyGrid.Items.Refresh()
    $ui.TweaksGrid.Items.Refresh()
    if ($null -ne $script:scan) { $ui.Categories.Items.Refresh() }
    $ui.AgentSummary.Text = 'Itens recomendados pré-selecionados. Reveja cada aba e confirme antes de aplicar ou limpar.'
    $ui.Status.Text = 'Pré-seleção do assistente aplicada. Nada foi executado.'
})

# Independent technician modules: only explicit commands are run; all inventory stays read-only.
foreach ($entry in @(
    @('InvProcessesButton','Processes'),@('InvStartupButton','Startup'),@('InvSoftwareButton','Software'),
    @('InvNetworkButton','Network'),@('InvUpdatesButton','Updates'),@('InvStorageButton','Storage')
)) {
    $ui[$entry[0]].Tag = [string]$entry[1]
    $ui[$entry[0]].Add_Click({
        param($inspectionSender)
        if ($null -eq $script:worker) { Start-Work 'Inspect' @{Area=[string]$inspectionSender.Tag} }
    })
}
$ui.NetworkSnapshotButton.Add_Click({
    if ($null -eq $script:worker) { Start-Work 'NetworkSnapshot' @{Reveal=$false} }
})
$ui.NetworkRevealButton.Add_Click({
    if ($null -ne $script:worker) { return }
    $warning = 'Mostrar IPs, gateway, DNS e nomes de perfis locais? Evite incluir esses valores em relatórios de clientes.'
    $response = [Windows.MessageBox]::Show($window,$warning,'Privacidade da rede','YesNo','Question','No')
    if ($response -eq 'Yes') { Start-Work 'NetworkSnapshot' @{Reveal=$true} }
})
$ui.NetworkProbeButton.Add_Click({
    if ($null -ne $script:worker) { return }
    $destination = $ui.NetworkTarget.Text.Trim()
    $port = 0
    if (-not [int]::TryParse($ui.NetworkPort.Text,[ref]$port) -or $port -lt 1 -or $port -gt 65535 -or -not $destination) {
        $ui.NetworkSummary.Text = 'Informe um nome de host/IP e uma porta entre 1 e 65535.'
        return
    }
    try {
        Import-Module $script:networkPath -Force -ErrorAction Stop
        if (-not (Test-OptimizerEndpointInput -HostName $destination -Port $port)) { throw 'Host/IP inválido: não informe URL ou caracteres especiais.' }
    } catch {
        $ui.NetworkSummary.Text = $_.Exception.Message
        return
    }
    $targetName = $destination + ':' + $port
    $message = 'Autoriza resolver DNS e testar TCP em ' + $targetName + '?' + [Environment]::NewLine + [Environment]::NewLine +
        'Isso envia tráfego externo ao destino solicitado, que poderá registrá-lo.'
    $answer = [Windows.MessageBox]::Show($window,$message,'Autorização de rede','YesNo','Question','No')
    if ($answer -eq 'Yes') { Start-Work 'NetworkProbe' @{Host=$destination;Port=$port} }
})
$ui.EventsAnalyzeButton.Add_Click({
    if ($null -eq $script:worker) { Start-Work 'Events' $null }
})
$repairModes = @{
    SfcVerifyButton='SFC-Verify'
    DismScanButton='DISM-Scan'
    ChkdskScanButton='CHKDSK-Scan'
    SfcRepairButton='SFC-Repair'
    DismRepairButton='DISM-Repair'
}
foreach ($buttonName in $repairModes.Keys) {
    $ui[$buttonName].Tag = [string]$repairModes[$buttonName]
    $ui[$buttonName].Add_Click({
        param($repairSender)
        if ($null -ne $script:worker) { return }
        $mode = [string]$repairSender.Tag
        $action = if ($mode.EndsWith('Repair')) { 'REPARAR arquivos do sistema' } else { 'VERIFICAR integridade do Windows' }
        $message = 'Executar ' + $mode + ' para ' + $action + '?' + [Environment]::NewLine +
            'Confira backup, autorização do proprietário e energia estável. O Windows solicitará UAC.'
        $answer = [Windows.MessageBox]::Show($window,$message,'Confirmar operação técnica','YesNo','Warning','No')
        if ($answer -ne 'Yes') { return }
        try {
            $executable = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $repairScript = Join-Path $PSScriptRoot 'Modules\Repair.Tools.ps1'
            $launchArgs = '-NoProfile -NoExit -File "{0}" -Mode {1}' -f $repairScript.Replace('"',''),$mode
            Start-Process -FilePath $executable -ArgumentList $launchArgs -Verb RunAs -ErrorAction Stop | Out-Null
            $ui.Status.Text = 'Console técnico aberto: ' + $mode
        } catch {
            [void][Windows.MessageBox]::Show($window,$_.Exception.Message,'Falha ao iniciar console','OK','Warning')
        }
    })
}
$ui.ExportResultsButton.Add_Click({
    if ($null -eq $script:cleanup) { return }
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter = 'Resultado CSV (*.csv)|*.csv'
    $dialog.FileName = 'Resultado-Limpeza-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.csv'
    Set-OptimizerDialogDirectory $dialog
    if (-not $dialog.ShowDialog($window)) { return }
    Save-OptimizerDialogDirectory $dialog
    $warning = 'Este CSV detalhado contém caminhos de arquivos do computador. Salve somente em local autorizado.'
    $answer = [Windows.MessageBox]::Show($window,$warning,'Privacidade dos dados','YesNo','Warning','No')
    if ($answer -ne 'Yes') { return }
    try {
        @($script:cleanup.Results | Select-Object Category,Status,Bytes,Detail,Path) |
            Export-Csv -LiteralPath $dialog.FileName -NoTypeInformation -Encoding UTF8
        $ui.Status.Text = 'CSV salvo no local escolhido.'
    } catch {
        [void][Windows.MessageBox]::Show($window,$_.Exception.Message,'Erro ao exportar CSV','OK','Error')
    }
})
$ui.BatteryReportButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter = 'Relatório de bateria (*.html)|*.html'
    $dialog.FileName = 'Bateria-' + $env:COMPUTERNAME + '-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.html'
    Set-OptimizerDialogDirectory $dialog
    if ($dialog.ShowDialog($window)) {
        Save-OptimizerDialogDirectory $dialog
        try {
            $saved = Save-OptimizerBatteryReport -Path $dialog.FileName
            $ui.Status.Text = 'Relatório de bateria salvo: ' + $saved
        } catch { [void][Windows.MessageBox]::Show($window, $_.Exception.Message, 'Relatório não gerado', 'OK', 'Warning') }
    }
})
$ui.DriverScanButton.Add_Click({ $ui.Pages.SelectedIndex = 4; $ui.MaintenanceTabs.SelectedIndex = 0; Start-Work 'Drivers' $null })
$ui.DriverUpdatesButton.Add_Click({ $ui.Pages.SelectedIndex = 4; $ui.MaintenanceTabs.SelectedIndex = 0; Start-Work 'DriverUpdates' $null })
$ui.AppxScanButton.Add_Click({ $ui.Pages.SelectedIndex = 4; $ui.MaintenanceTabs.SelectedIndex = 1; Start-Work 'Appx' $null })
$ui.AppxBloatOnly.Add_Checked({ Update-AppxGrid })
$ui.AppxBloatOnly.Add_Unchecked({ Update-AppxGrid })
$ui.AppxRemoveButton.Add_Click({
    [void]$ui.AppxGrid.CommitEdit([Windows.Controls.DataGridEditingUnit]::Cell, $true)
    [void]$ui.AppxGrid.CommitEdit([Windows.Controls.DataGridEditingUnit]::Row, $true)
    $selected = @($script:appx | Where-Object Selected)
    if ($selected.Count -eq 0) { $ui.Status.Text = 'Marque pelo menos um aplicativo para remover.'; return }
    $preview = (@($selected | Select-Object -First 8 | ForEach-Object { $_.Label }) -join ', ')
    if ($selected.Count -gt 8) { $preview += ", +$($selected.Count - 8)" }
    $answer = [Windows.MessageBox]::Show($window, "Remover $($selected.Count) aplicativos do usuário atual?`n`n$preview`n`nA remoção não apaga arquivos pessoais. Você pode reinstalar pela Microsoft Store.", 'Confirmar remoção', 'YesNo', 'Warning', 'No')
    if ($answer -eq 'Yes') { Start-Work 'RemoveAppx' @{ Names=@($selected | ForEach-Object PackageFullName) } }
})
$ui.OptimizationRunButton.Add_Click({
    [void]$ui.OptimizationGrid.CommitEdit([Windows.Controls.DataGridEditingUnit]::Cell, $true)
    [void]$ui.OptimizationGrid.CommitEdit([Windows.Controls.DataGridEditingUnit]::Row, $true)
    $selected = @($script:optimizations | Where-Object Selected)
    if ($selected.Count -eq 0) { $ui.Status.Text = 'Marque pelo menos uma otimização.'; return }
    $preview = (@($selected | ForEach-Object { $_.Name }) -join "`n")
    $answer = [Windows.MessageBox]::Show($window, "Aplicar as ações abaixo?`n`n$preview`n`nAções que exigem administrador podem falhar sem elevação.", 'Confirmar otimizações', 'YesNo', 'Warning', 'No')
    if ($answer -eq 'Yes') { Start-Work 'Optimize' @{ Ids=@($selected | ForEach-Object Id) } }
})
$ui.PrivacyApplyButton.Add_Click({
    [void]$ui.PrivacyGrid.CommitEdit([Windows.Controls.DataGridEditingUnit]::Cell, $true)
    [void]$ui.PrivacyGrid.CommitEdit([Windows.Controls.DataGridEditingUnit]::Row, $true)
    $selected = @($script:privacyCatalog | Where-Object Selected)
    if ($selected.Count -eq 0) { $ui.Status.Text = 'Selecione ao menos uma opção de privacidade.'; return }
    $preview = (@($selected | ForEach-Object { $_.Name }) -join "`n")
    $answer = [Windows.MessageBox]::Show($window, "Aplicar as $($selected.Count) ações de privacidade abaixo?`n`n$preview`n`nAções marcadas com 'Admin: Sim' requerem privilégios de administrador.", 'Confirmar Privacidade', 'YesNo', 'Warning', 'No')
    if ($answer -eq 'Yes') { Start-Work 'ApplyPrivacy' @{ Ids=@($selected | ForEach-Object Id) } }
})
$ui.PrivacyPresetBasicButton.Add_Click({
    $preset = @(Get-OptimizerPrivacyPreset -Preset 'Basic')
    foreach ($item in $script:privacyCatalog) { $item.Selected = ($preset -contains $item.Id) }
    $ui.PrivacyGrid.Items.Refresh()
    $ui.Status.Text = "Predefinição Básica aplicada ($($preset.Count) ações marcadas)."
})
$ui.PrivacyPresetStrictButton.Add_Click({
    $preset = @(Get-OptimizerPrivacyPreset -Preset 'Strict')
    foreach ($item in $script:privacyCatalog) { $item.Selected = ($preset -contains $item.Id) }
    $ui.PrivacyGrid.Items.Refresh()
    $ui.Status.Text = "Predefinição Rígida aplicada ($($preset.Count) ações marcadas)."
})
$ui.PrivacyPresetExtremeButton.Add_Click({
    $preset = @(Get-OptimizerPrivacyPreset -Preset 'Extreme')
    foreach ($item in $script:privacyCatalog) { $item.Selected = ($preset -contains $item.Id) }
    $ui.PrivacyGrid.Items.Refresh()
    $ui.Status.Text = "Predefinição Extrema aplicada ($($preset.Count) ações marcadas)."
})
$ui.PrivacySelectNoneButton.Add_Click({
    foreach ($item in $script:privacyCatalog) { $item.Selected = $false }
    $ui.PrivacyGrid.Items.Refresh()
    $ui.Status.Text = 'Todas as opções de privacidade foram desmarcadas.'
})
$ui.TweaksApplyButton.Add_Click({
    [void]$ui.TweaksGrid.CommitEdit([Windows.Controls.DataGridEditingUnit]::Cell, $true)
    [void]$ui.TweaksGrid.CommitEdit([Windows.Controls.DataGridEditingUnit]::Row, $true)
    $selected = @($script:tweaksCatalog | Where-Object Selected)
    if ($selected.Count -eq 0) { $ui.Status.Text = 'Selecione ao menos um ajuste para aplicar.'; return }
    $preview = (@($selected | ForEach-Object { $_.Name }) -join "`n")
    $answer = [Windows.MessageBox]::Show($window, "Aplicar os $($selected.Count) ajustes abaixo?`n`n$preview`n`nAções marcadas com 'Admin: Sim' requerem privilégios de administrador.", 'Confirmar Ajustes', 'YesNo', 'Warning', 'No')
    if ($answer -eq 'Yes') { Start-Work 'ApplyTweaks' @{ Ids=@($selected | ForEach-Object Id) } }
})
$ui.TweaksSelectAllButton.Add_Click({
    foreach ($item in $script:tweaksCatalog) { $item.Selected = $true }
    $ui.TweaksGrid.Items.Refresh()
    $ui.Status.Text = 'Todos os ajustes foram marcados.'
})
$ui.TweaksSelectNoneButton.Add_Click({
    foreach ($item in $script:tweaksCatalog) { $item.Selected = $false }
    $ui.TweaksGrid.Items.Refresh()
    $ui.Status.Text = 'Todos os ajustes foram desmarcados.'
})
$ui.TweaksDnsGoogleButton.Add_Click({
    foreach ($item in $script:tweaksCatalog) { $item.Selected = ($item.Id -eq 'SetDnsGoogle') }
    $ui.TweaksGrid.Items.Refresh()
    $ui.Status.Text = 'DNS Google marcado.'
})
$ui.TweaksDnsCloudflareButton.Add_Click({
    foreach ($item in $script:tweaksCatalog) { $item.Selected = ($item.Id -eq 'SetDnsCloudflare') }
    $ui.TweaksGrid.Items.Refresh()
    $ui.Status.Text = 'DNS Cloudflare marcado.'
})
$ui.CleanButton.Add_Click({
    [void]$ui.Categories.CommitEdit([Windows.Controls.DataGridEditingUnit]::Cell, $true)
    [void]$ui.Categories.CommitEdit([Windows.Controls.DataGridEditingUnit]::Row, $true)
    $selected = @($script:scan.Categories | Where-Object Selected)
    if ($selected.Count -eq 0) { $ui.Status.Text = 'Selecione pelo menos uma categoria.'; return }
    Save-OptimizerCategorySelection
    $size = Format-OptimizerSize (($selected | Measure-Object Bytes -Sum).Sum)
    $risk = @($selected | Where-Object { $_.Risk -eq 'Médio' -or $_.Risk -eq 'Alto' })
    $riskNote = if ($risk.Count -gt 0) { "`n`nAtenção: $($risk.Count) categoria(s) de risco médio/alto. Confira a coluna Observação." } else { '' }
    $answer = [Windows.MessageBox]::Show($window, "Excluir permanentemente os arquivos analisados das $($selected.Count) categorias selecionadas ($size)?$riskNote`n`nA exclusão não passa pela Lixeira. Arquivos em uso ou alterados serão ignorados.", 'Confirmar limpeza', 'YesNo', 'Warning', 'No')
    if ($answer -eq 'Yes') { Start-Work 'Clean' @{Scan=$script:scan; Ids=@($selected | ForEach-Object Id)} }
})
$ui.SelectAllButton.Add_Click({
    if ($null -eq $script:scan) { return }
    foreach ($category in $script:scan.Categories) { $category.Selected = $true }
    $ui.Categories.Items.Refresh()
    Save-OptimizerCategorySelection
})
$ui.SelectNoneButton.Add_Click({
    if ($null -eq $script:scan) { return }
    foreach ($category in $script:scan.Categories) { $category.Selected = $false }
    $ui.Categories.Items.Refresh()
    Save-OptimizerCategorySelection
})
$ui.DetailsButton.Add_Click({
    $detail = New-Object Windows.Window
    $detail.Title = if ($null -ne $script:scan) { 'Arquivos candidatos - prévia sem exclusão' } else { 'Resultado detalhado da limpeza' }
    $detail.Width = 1000; $detail.Height = 560; $detail.Owner = $window; $detail.WindowStartupLocation = 'CenterOwner'
    $panel = New-Object Windows.Controls.DockPanel
    $panel.LastChildFill = $true
    $filterPanel = New-Object Windows.Controls.StackPanel
    $filterPanel.Orientation = 'Horizontal'
    $filterPanel.Margin = New-Object Windows.Thickness(0,0,0,10)
    $filterLabel = New-Object Windows.Controls.TextBlock
    $filterLabel.Text = 'Filtrar:'
    $filterLabel.VerticalAlignment = 'Center'
    $filterLabel.Margin = New-Object Windows.Thickness(0,0,8,0)
    $filterBox = New-Object Windows.Controls.TextBox
    $filterBox.Width = 420
    $filterBox.Height = 28
    [Windows.Automation.AutomationProperties]::SetName($filterBox, 'Filtrar resultado por categoria, caminho, status ou detalhe')
    $filterButton = New-Object Windows.Controls.Button
    $filterButton.Content = 'Aplicar filtro'
    $filterButton.Margin = New-Object Windows.Thickness(8,0,0,0)
    $filterButton.Padding = New-Object Windows.Thickness(12,2,12,2)
    [Windows.Automation.AutomationProperties]::SetName($filterButton, 'Aplicar filtro ao resultado detalhado')
    $clearButton = New-Object Windows.Controls.Button
    $clearButton.Content = 'Limpar filtro'
    $clearButton.Margin = New-Object Windows.Thickness(8,0,0,0)
    $clearButton.Padding = New-Object Windows.Thickness(12,2,12,2)
    [Windows.Automation.AutomationProperties]::SetName($clearButton, 'Limpar filtro do resultado detalhado')
    [void]$filterPanel.Children.Add($filterLabel)
    [void]$filterPanel.Children.Add($filterBox)
    [void]$filterPanel.Children.Add($filterButton)
    [void]$filterPanel.Children.Add($clearButton)
    [Windows.Controls.DockPanel]::SetDock($filterPanel, 'Top')
    [void]$panel.Children.Add($filterPanel)
    $grid = New-Object Windows.Controls.DataGrid
    $grid.IsReadOnly = $true; $grid.AutoGenerateColumns = $false; $grid.CanUserAddRows = $false
    [Windows.Automation.AutomationProperties]::SetName($grid, 'Resultado detalhado filtrado')
    $rows = if ($null -ne $script:scan) { @($script:scan.Files) } else { @($script:cleanup.Results) }
    $cols = if ($null -ne $script:scan) {
        @(@('Categoria','CategoryName',210), @('Caminho','Path',620), @('Bytes','Bytes',100))
    } else {
        @(@('Categoria','Category',180), @('Caminho','Path',460), @('Status','Status',100), @('Bytes','Bytes',90), @('Detalhe','Detail',180))
    }
    foreach ($column in $cols) {
        $c = New-Object Windows.Controls.DataGridTextColumn
        $c.Header = $column[0]; $c.Binding = New-Object Windows.Data.Binding $column[1]
        $c.Width = $column[2]; [void]$grid.Columns.Add($c)
    }
    $grid.ItemsSource = $rows
    [void]$panel.Children.Add($grid)
    $script:detailFilter = [pscustomobject]@{ Rows=$rows; Grid=$grid; Box=$filterBox }
    $filterButton.Add_Click({
        $context = $script:detailFilter
        $term = ([string]$context.Box.Text).Trim()
        if ([string]::IsNullOrWhiteSpace($term)) { $context.Grid.ItemsSource = $context.Rows; return }
        $context.Grid.ItemsSource = @($context.Rows | Where-Object {
            $text = @($_.PSObject.Properties | ForEach-Object { [string]$_.Value }) -join ' '
            $text.IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -ge 0
        })
    })
    $clearButton.Add_Click({ $script:detailFilter.Box.Text = ''; $script:detailFilter.Grid.ItemsSource = $script:detailFilter.Rows })
    $filterBox.Add_KeyDown({
        param($keySender, $keyArgs)
        if ($keyArgs.Key -ne [Windows.Input.Key]::Enter) { return }
        $context = $script:detailFilter
        $term = ([string]$context.Box.Text).Trim()
        if ([string]::IsNullOrWhiteSpace($term)) { $context.Grid.ItemsSource = $context.Rows }
        else {
            $context.Grid.ItemsSource = @($context.Rows | Where-Object {
                $text = @($_.PSObject.Properties | ForEach-Object { [string]$_.Value }) -join ' '
                $text.IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -ge 0
            })
        }
        $keyArgs.Handled = $true
    })
    $detail.Content = $panel
    [void]$detail.ShowDialog()
    $script:detailFilter = $null
})
$ui.ExportButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter = 'Relatório HTML (*.html)|*.html|Dados JSON (*.json)|*.json'; $dialog.FileName = 'Manutencao-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.html'
    Set-OptimizerDialogDirectory $dialog
    if ($dialog.ShowDialog($window)) {
        Save-OptimizerDialogDirectory $dialog
        try {
            $format = if ($dialog.FilterIndex -eq 2) { 'JSON' } else { 'HTML' }
            $extension = if ($format -eq 'JSON') { '.json' } else { '.html' }
            $outputPath = [IO.Path]::ChangeExtension($dialog.FileName, $extension)
            Export-OptimizerReport -Path $outputPath -Customer $ui.Customer.Text -Notes $ui.Notes.Text -Diagnostics $script:diagnostics -Cleanup $script:cleanup -Format $format
            $ui.Status.Text = 'Relatório salvo: ' + $outputPath
        } catch { [void][Windows.MessageBox]::Show($window, $_.Exception.Message, 'Não foi possível salvar', 'OK', 'Error') }
    }
})
$window.Add_PreviewKeyDown({
    param($keySender, $keyArgs)
    if ($keyArgs.Key -eq [Windows.Input.Key]::F5 -and $ui.ScanButton.IsEnabled) {
        $keyArgs.Handled = $true; Start-Work 'Scan' $null
    } elseif ($keyArgs.Key -eq [Windows.Input.Key]::Escape -and $ui.CancelButton.IsEnabled) {
        $keyArgs.Handled = $true; $script:state.Cancel = $true; $ui.CancelButton.IsEnabled = $false
        $ui.Status.Text = 'Interrompendo após o arquivo atual...'
    } elseif ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control -and $keyArgs.Key -eq [Windows.Input.Key]::B) {
        $keyArgs.Handled = $true
        Open-OptimizerSection -PageIndex 4 -MaintenanceIndex 4
        $ui.WorkbenchTabs.SelectedIndex = 0
    } elseif ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control -and $keyArgs.Key -eq [Windows.Input.Key]::P) {
        $keyArgs.Handled = $true
        Open-OptimizerSection -PageIndex 4 -MaintenanceIndex 5
    } elseif ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control -and $keyArgs.Key -eq [Windows.Input.Key]::T) {
        $keyArgs.Handled = $true
        Open-OptimizerSection -PageIndex 4 -MaintenanceIndex 6
    } elseif ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control -and $keyArgs.Key -in @([Windows.Input.Key]::D1,[Windows.Input.Key]::D2,[Windows.Input.Key]::D3,[Windows.Input.Key]::D4,[Windows.Input.Key]::D5,[Windows.Input.Key]::D6,[Windows.Input.Key]::D7)) {
        $keyArgs.Handled = $true
        $keyMap = @{D1=0;D2=2;D3=3;D4=1;D5=4;D6=5;D7=6}
        Open-OptimizerSection -PageIndex ([int]$keyMap[$keyArgs.Key.ToString()])
    } elseif ($keyArgs.Key -eq [Windows.Input.Key]::E -and [Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control -and $ui.ExportButton.IsEnabled) {
        $keyArgs.Handled = $true
        $ui.Pages.SelectedIndex = 5
        $ui.ExportButton.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    }
})
$toolActions = @{
    StartupTool='ms-settings:startupapps'; AppsTool='ms-settings:appsfeatures'; StorageTool='ms-settings:storagesense'; SecurityTool='windowsdefender:'
    DiskTool='dfrgui.exe'; RestoreTool='SystemPropertiesProtection.exe'; EventsTool='eventvwr.msc'; TaskTool='taskmgr.exe'
    OptionalFeaturesTool='optionalfeatures.exe'; WindowsUpdateTool='ms-settings:windowsupdate'; PowerOptionsTool='powercfg.cpl'
    SystemInfoTool='msinfo32.exe'; DriverUpdateTool='ms-settings:windowsupdate'; DeviceManagerTool='devmgmt.msc'
}
foreach ($name in $toolActions.Keys) {
    $ui[$name].Tag = $toolActions[$name]
    $ui[$name].Add_Click({
        param($clickSender)
        try { Start-Process -FilePath $clickSender.Tag -ErrorAction Stop }
        catch { [void][Windows.MessageBox]::Show($window, $_.Exception.Message, 'Ferramenta indisponível', 'OK', 'Warning') }
    })
}
$script:optimizations = @(Get-OptimizerOptimizations | ForEach-Object {
    [pscustomobject]@{ Id=$_.Id; Name=$_.Name; Description=$_.Description; Admin=if ($_.RequiresAdmin) { 'Sim' } else { 'Não' }; Selected=$false }
})
$ui.OptimizationGrid.ItemsSource = $script:optimizations

$script:privacyCatalog = @(Get-OptimizerPrivacyCatalog | ForEach-Object {
    [pscustomobject]@{
        Selected = $false
        Id = $_.Id
        Category = $_.Category
        Name = $_.Name
        Description = $_.Description
        Admin = if ($_.RequiresElevation) { 'Sim' } else { 'Não' }
    }
})
$ui.PrivacyGrid.ItemsSource = $script:privacyCatalog

$script:tweaksCatalog = @(Get-OptimizerTweakCatalog | ForEach-Object {
    [pscustomobject]@{
        Selected = $false
        Id = $_.Id
        Category = $_.Category
        Name = $_.Name
        Description = $_.Description
        Admin = if ($_.RequiresElevation) { 'Sim' } else { 'Não' }
    }
})
$ui.TweaksGrid.ItemsSource = $script:tweaksCatalog
Update-ConnectionNote
$window.Add_Closing({
    param($closeSender, $closeArgs)
    Save-OptimizerCategorySelection
    if ($null -eq $closeSender -or $null -eq $script:worker) { return }
    $answer = [Windows.MessageBox]::Show($window, 'Há uma operação em andamento. Deseja interromper e fechar?', 'Fechar PC Optimizer', 'YesNo', 'Warning', 'No')
    if ($answer -ne 'Yes') { $closeArgs.Cancel = $true; return }
    $script:state.Cancel = $true
    $timer.Stop()
    try { $script:worker.Stop(); $script:worker.Dispose() } catch { Write-Verbose 'Falha ao encerrar o runspace.' }
    $script:worker = $null
})
if ($ValidateUI) {
    if ($PreviewPath) {
        $surface = $window.Content
        $surface.Measure((New-Object Windows.Size(1160, 760)))
        $surface.Arrange((New-Object Windows.Rect(0, 0, 1160, 760)))
        $surface.UpdateLayout()
        $bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap(1160, 760, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($surface)
        $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
        $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $stream = [IO.File]::Create($PreviewPath)
        try { $encoder.Save($stream) } finally { $stream.Dispose() }
    }
    foreach ($required in @('NavOverview','NavDiagnose','NavHealth','NavCleanup','NavMaintenance','NavBench','NavReport','NavSettings','WorkbenchTabs','PreferenceHighContrast','PreferenceTextScale','PreferenceApplyButton','PreferenceResetButton')) {
        if ($null -eq $ui[$required]) { throw "Navegação não encontrada: $required" }
    }
    $ui.NavBench.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    if ($ui.Pages.SelectedIndex -ne 4 -or $ui.MaintenanceTabs.SelectedIndex -ne 4) { throw 'Sidebar did not open the workbench.' }
    $ui.WorkbenchTabs.SelectedIndex = 3
    if ([string]$ui.WorkbenchTabs.SelectedItem.Header -ne 'Reparos') { throw 'Workbench tab selection failed.' }
    $ui.NavReport.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    if ($ui.Pages.SelectedIndex -ne 5) { throw 'Sidebar report navigation failed.' }
    $ui.NavOverview.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    if ($ui.Pages.SelectedIndex -ne 0) { throw 'Sidebar overview navigation failed.' }
    # Exercise real runspace + Dispatcher flow using only a disposable profile.
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('optimizer-ui-' + [guid]::NewGuid().ToString('N'))
    $previousLocalAppData = $env:LOCALAPPDATA
    try {
        [void](New-Item -ItemType Directory -Path (Join-Path $fixture 'Temp') -Force)
        $sample = Join-Path $fixture 'Temp/sample.tmp'
        [IO.File]::WriteAllText($sample, 'UI test fixture')
        (Get-Item $sample).LastWriteTimeUtc = [DateTime]::UtcNow.AddDays(-10)
        $env:LOCALAPPDATA = $fixture
        # Validação usa somente a pasta descartável, sem varrer o Windows real.
        $fixtureTargets = @([pscustomobject]@{ Id='temp'; Name='Temporários do usuário'; Path=(Join-Path $fixture 'Temp'); Process=''; RequiresAdmin=$false; Risk='Baixo'; Note=''; Patterns=@(); AllowedExtensions=@() })
        Start-Work 'Scan' @{ Targets=$fixtureTargets }
        $deadline = [DateTime]::UtcNow.AddSeconds(20)
        while ($null -ne $script:worker -and [DateTime]::UtcNow -lt $deadline) {
            $window.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [Action]{})
            Start-Sleep -Milliseconds 20
        }
        if ($null -ne $script:worker -or $null -eq $script:scan -or @($script:scan.Files).Count -ne 1 -or -not $ui.CleanButton.IsEnabled) { throw 'UI scan/runspace integration failed.' }
        Start-Work 'Clean' @{Scan=$script:scan; Ids=@('temp')}
        $deadline = [DateTime]::UtcNow.AddSeconds(20)
        while ($null -ne $script:worker -and [DateTime]::UtcNow -lt $deadline) {
            $window.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [Action]{})
            Start-Sleep -Milliseconds 20
        }
        if ($null -ne $script:worker -or (Test-Path $sample) -or $script:cleanup.RemovedCount -ne 1 -or $ui.CleanButton.IsEnabled -or -not $ui.ExportResultsButton.IsEnabled) { throw 'UI cleanup/result integration failed.' }
        Start-Work 'Inspect' @{Area='Processes'}
        $deadline = [DateTime]::UtcNow.AddSeconds(20)
        while ($null -ne $script:worker -and [DateTime]::UtcNow -lt $deadline) {
            $window.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [Action]{})
            Start-Sleep -Milliseconds 20
        }
        if ($null -ne $script:worker -or @($ui.WorkbenchGrid.ItemsSource).Count -lt 1) { throw 'WPF integrated technician inventory/runspace failed.' }
        Start-Work 'Health' $null
        $deadline = [DateTime]::UtcNow.AddSeconds(60)
        while ($null -ne $script:worker -and [DateTime]::UtcNow -lt $deadline) {
            $window.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [Action]{})
            Start-Sleep -Milliseconds 20
        }
        if ($null -ne $script:worker -or @($ui.BatteryGrid.ItemsSource).Count -lt 1 -or @($ui.DiskGrid.ItemsSource).Count -lt 1 -or @($ui.VolumeGrid.ItemsSource).Count -lt 1) { throw 'WPF health/battery/disk runspace failed.' }
        Start-Work 'Agent' @{ Diagnostics=@($script:diagnostics); Health=([pscustomobject]@{ Battery=$script:battery; Disks=$script:disks }); Scan=$script:scan; AppInventory=@($script:appx); IsAdmin=[bool]$script:isAdmin }
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while ($null -ne $script:worker -and [DateTime]::UtcNow -lt $deadline) {
            $window.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [Action]{})
            Start-Sleep -Milliseconds 20
        }
        if ($null -ne $script:worker -or @($script:agentRecommendations).Count -lt 1 -or [string]::IsNullOrWhiteSpace([string]$ui.AgentSummary.Text)) { throw 'WPF local agent runspace failed.' }
    } finally {
        $env:LOCALAPPDATA = $previousLocalAppData
        $timer.Stop()
        if ($null -ne $script:worker) { $script:worker.Stop(); $script:worker.Dispose(); $script:worker=$null }
        $window.Close()
        if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
    }
    foreach ($required in @('CloseButton','ElevateButton','BatteryGrid','DiskGrid','VolumeGrid','DriverGrid','DriverUpdateGrid','AppxGrid','OptimizationGrid','PrivacyGrid','TweaksGrid','HealthAnalyzeButton','BatteryReportButton','WorkbenchShortcut','PrivacyShortcut','TweaksShortcut','AgentButton','AgentApplyButton','AgentSummary','NavPrivacy','NavTweaks','WorkbenchGrid','InvProcessesButton','InvSoftwareButton','NetworkGrid','NetworkSnapshotButton','NetworkProbeButton','EventsGrid','EventsAnalyzeButton','SfcVerifyButton','ExportResultsButton')) {
        if ($null -eq $ui[$required]) { throw "Controle ausente na interface: $required" }
    }
    $savedDisplay = $script:activePreferences
    Set-OptimizerVisualPreferences -Preferences ([pscustomobject]@{SchemaVersion=1;HighContrast=$true;TextScale=125})
    if ($window.Resources['UiFont18'] -lt 22.4) { throw '125% font scale was not applied.' }
    if ($window.Resources['UiColorF3F6FA'].Color.ToString() -ne '#FF050505') { throw 'High contrast palette not applied.' }
    Set-OptimizerVisualPreferences -Preferences $savedDisplay
    $ui.NavSettings.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    if ($ui.Pages.SelectedIndex -ne 6) { throw 'Preferences sidebar navigation failed.' }
    $ui.NavOverview.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    if (@($ui.OptimizationGrid.Items).Count -lt 5) { throw 'Catálogo de otimizações não foi carregado.' }
    if (@($ui.PrivacyGrid.Items).Count -lt 20) { throw 'Catálogo de privacidade não foi carregado.' }
    if (@($ui.TweaksGrid.Items).Count -lt 15) { throw 'Catálogo de ajustes não foi carregado.' }
    Write-Output 'WPF layout, accessible sidebar navigation, workbench tabs and async scan/cleanup passed.'
    return
}
try { [void]$window.ShowDialog() } finally { $timer.Stop(); if ($null -ne $script:worker) { $script:worker.Dispose() } }
