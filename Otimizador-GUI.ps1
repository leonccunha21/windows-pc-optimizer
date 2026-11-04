#Requires -Version 5.1
param([switch]$ValidateUI, [string]$PreviewPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Import-Module (Join-Path $PSScriptRoot 'Modules\Optimizer.Core.psm1') -Force
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
$script:battery = $null; $script:disks = $null; $script:appx = @(); $script:optimizations = @(); $script:driverUpdates = $null
$script:state = [hashtable]::Synchronized(@{Cancel=$false; Message=''; Result=$null; Error=$null; Total=0; Processed=0})
$script:modulePath = Join-Path $PSScriptRoot 'Modules\Optimizer.Core.psm1'
$script:technicianPath = Join-Path $PSScriptRoot 'Modules\Optimizer.Technician.psm1'
$script:networkPath = Join-Path $PSScriptRoot 'Modules\Optimizer.NetworkDiagnostics.psm1'
$script:eventsPath = Join-Path $PSScriptRoot 'Modules\Optimizer.Events.psm1'
$script:isAdmin = $false
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $script:isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { Write-Verbose 'Não foi possível verificar elevação.' }

function Set-Busy([bool]$Busy) {
    foreach ($name in @('ScanButton','DiagnoseButton','DiagnoseHome','GoClean','ExportButton','SelectAllButton','SelectNoneButton','HealthAnalyzeButton','HealthHome','BatteryReportButton','DriverScanButton','DriverUpdatesButton','DriverUpdateTool','DeviceManagerTool','AppxScanButton','AppxRemoveButton','OptimizationRunButton','HealthShortcut','MaintenanceShortcut','WorkbenchShortcut','InvProcessesButton','InvStartupButton','InvSoftwareButton','InvNetworkButton','InvUpdatesButton','InvStorageButton','NetworkSnapshotButton','NetworkRevealButton','NetworkProbeButton','EventsAnalyzeButton','SfcVerifyButton','DismScanButton','ChkdskScanButton','SfcRepairButton','DismRepairButton')) { $ui[$name].IsEnabled = -not $Busy }
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
    $ui.HealthNote.Text = if ($script:disks.Note) { $script:disks.Note } else { 'Contadores SMART variam por fabricante e controladora. Ausência de leitura não significa disco saudável.' }
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
        param($ModulePath, $TechnicianPath, $NetworkPath, $EventsPath, $Operation, $Payload, $State)
        try {
            Import-Module $ModulePath -Force -ErrorAction Stop
            Import-Module $TechnicianPath -Force -ErrorAction Stop
            Import-Module $NetworkPath -Force -ErrorAction Stop
            Import-Module $EventsPath -Force -ErrorAction Stop
            switch ($Operation) {
                'Scan' { $State.Result = Get-OptimizerScan -State $State }
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
            }
        } catch { $State.Error = $_.Exception.Message }
    }).AddArgument($script:modulePath).AddArgument($script:technicianPath).AddArgument($script:networkPath).AddArgument($script:eventsPath).AddArgument($Operation).AddArgument($Payload).AddArgument($script:state)
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
            $current = if ([int]$ui.MaintenanceTabs.SelectedIndex -eq 4) { 'NavBench' } else { 'NavMaintenance' }
        }
        5 { $current = 'NavReport' }
    }
    foreach ($name in @('NavOverview','NavDiagnose','NavHealth','NavCleanup','NavMaintenance','NavBench','NavReport')) {
        $ui[$name].Background = if ($name -eq $current) { [Windows.Media.Brushes]::Teal } else { [Windows.Media.Brushes]::Transparent }
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
    @('NavReport',5,-1)
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
$ui.ScanButton.Add_Click({ Start-Work 'Scan' $null })
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
    if (-not $dialog.ShowDialog($window)) { return }
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
    if ($dialog.ShowDialog($window)) {
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
$ui.CleanButton.Add_Click({
    [void]$ui.Categories.CommitEdit([Windows.Controls.DataGridEditingUnit]::Cell, $true)
    [void]$ui.Categories.CommitEdit([Windows.Controls.DataGridEditingUnit]::Row, $true)
    $selected = @($script:scan.Categories | Where-Object Selected)
    if ($selected.Count -eq 0) { $ui.Status.Text = 'Selecione pelo menos uma categoria.'; return }
    $size = Format-OptimizerSize (($selected | Measure-Object Bytes -Sum).Sum)
    $answer = [Windows.MessageBox]::Show($window, "Excluir permanentemente os arquivos analisados das $($selected.Count) categorias selecionadas ($size)?`n`nA exclusão não passa pela Lixeira. Arquivos em uso ou alterados serão ignorados.", 'Confirmar limpeza', 'YesNo', 'Warning', 'No')
    if ($answer -eq 'Yes') { Start-Work 'Clean' @{Scan=$script:scan; Ids=@($selected | ForEach-Object Id)} }
})
$ui.SelectAllButton.Add_Click({
    if ($null -eq $script:scan) { return }
    foreach ($category in $script:scan.Categories) { $category.Selected = $true }
    $ui.Categories.Items.Refresh()
})
$ui.SelectNoneButton.Add_Click({
    if ($null -eq $script:scan) { return }
    foreach ($category in $script:scan.Categories) { $category.Selected = $false }
    $ui.Categories.Items.Refresh()
})
$ui.DetailsButton.Add_Click({
    $detail = New-Object Windows.Window
    $detail.Title = if ($null -ne $script:scan) { 'Arquivos candidatos - prévia sem exclusão' } else { 'Resultado detalhado da limpeza' }
    $detail.Width = 1000; $detail.Height = 560; $detail.Owner = $window; $detail.WindowStartupLocation = 'CenterOwner'
    $grid = New-Object Windows.Controls.DataGrid
    $grid.IsReadOnly = $true; $grid.AutoGenerateColumns = $false; $grid.CanUserAddRows = $false
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
    $detail.Content = $grid
    [void]$detail.ShowDialog()
})
$ui.ExportButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter = 'Relatório HTML (*.html)|*.html|Dados JSON (*.json)|*.json'; $dialog.FileName = 'Manutencao-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.html'
    if ($dialog.ShowDialog($window)) {
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
    } elseif ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control -and $keyArgs.Key -in @([Windows.Input.Key]::D1,[Windows.Input.Key]::D2,[Windows.Input.Key]::D3,[Windows.Input.Key]::D4,[Windows.Input.Key]::D5,[Windows.Input.Key]::D6)) {
        $keyArgs.Handled = $true
        $keyMap = @{D1=0;D2=2;D3=3;D4=1;D5=4;D6=5}
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
Update-ConnectionNote
$window.Add_Closing({
    param($closeSender, $closeArgs)
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
    foreach ($required in @('NavOverview','NavDiagnose','NavHealth','NavCleanup','NavMaintenance','NavBench','NavReport','WorkbenchTabs')) {
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
        Start-Work 'Scan' $null
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
    } finally {
        $env:LOCALAPPDATA = $previousLocalAppData
        $timer.Stop()
        if ($null -ne $script:worker) { $script:worker.Stop(); $script:worker.Dispose(); $script:worker=$null }
        $window.Close()
        if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
    }
    foreach ($required in @('CloseButton','BatteryGrid','DiskGrid','VolumeGrid','DriverGrid','DriverUpdateGrid','AppxGrid','OptimizationGrid','HealthAnalyzeButton','BatteryReportButton','WorkbenchShortcut','WorkbenchGrid','InvProcessesButton','InvSoftwareButton','NetworkGrid','NetworkSnapshotButton','NetworkProbeButton','EventsGrid','EventsAnalyzeButton','SfcVerifyButton','ExportResultsButton')) {
        if ($null -eq $ui[$required]) { throw "Controle ausente na interface: $required" }
    }
    if (@($ui.OptimizationGrid.Items).Count -lt 5) { throw 'Catálogo de otimizações não foi carregado.' }
    Write-Output 'WPF layout, accessible sidebar navigation, workbench tabs and async scan/cleanup passed.'
    return
}
try { [void]$window.ShowDialog() } finally { $timer.Stop(); if ($null -ne $script:worker) { $script:worker.Dispose() } }
