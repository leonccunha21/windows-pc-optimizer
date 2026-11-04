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
$script:state = [hashtable]::Synchronized(@{Cancel=$false; Message=''; Result=$null; Error=$null})
$script:modulePath = Join-Path $PSScriptRoot 'Modules\Optimizer.Core.psm1'

function Set-Busy([bool]$Busy) {
    foreach ($name in @('ScanButton','DiagnoseButton','DiagnoseHome','GoClean','ExportButton')) { $ui[$name].IsEnabled = -not $Busy }
    $ui.CleanButton.IsEnabled = -not $Busy -and $null -ne $script:scan -and -not $script:scan.Cancelled -and @($script:scan.Files).Count -gt 0
    $ui.DetailsButton.IsEnabled = -not $Busy -and $null -ne $script:scan
    $ui.Categories.IsEnabled = -not $Busy
    $ui.CancelButton.IsEnabled = $Busy -and $script:operation -ne 'Diagnose'
    $ui.Progress.IsIndeterminate = $Busy
}
function Start-Work([string]$Operation, $Payload) {
    if ($null -ne $script:worker) { return }
    $script:operation = $Operation
    $script:state.Cancel = $false; $script:state.Error = $null; $script:state.Result = $null; $script:state.Message = 'Préparando...'
    $script:worker = [PowerShell]::Create()
    [void]$script:worker.AddScript({
        param($ModulePath, $Operation, $Payload, $State)
        try {
            Import-Module $ModulePath -Force -ErrorAction Stop
            switch ($Operation) {
                'Scan' { $State.Result = Get-OptimizerScan -State $State }
                'Clean' { $State.Result = Invoke-OptimizerCleanup -Scan $Payload.Scan -CategoryIds $Payload.Ids -State $State -Confirm:$false }
                'Diagnose' { $State.Message = 'Consultando hardware e Windows...'; $State.Result = @(Get-OptimizerDiagnostics) }
            }
        } catch { $State.Error = $_.Exception.Message }
    }).AddArgument($script:modulePath).AddArgument($Operation).AddArgument($Payload).AddArgument($script:state)
    $script:handle = $script:worker.BeginInvoke()
    Set-Busy $true
    $timer.Start()
}
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(200)
$timer.Add_Tick({
    $ui.Status.Text = $script:state.Message
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
        }
    } catch {
        $ui.Status.Text = 'Falha: ' + $_.Exception.Message
        if ($script:operation -eq 'Clean') { $script:scan = $null }
        if (-not $ValidateUI) { [void][Windows.MessageBox]::Show($window, $_.Exception.Message, 'Operação não concluída', 'OK', 'Warning') }
    } finally { $script:worker.Dispose(); $script:worker = $null; Set-Busy $false }
})
$ui.ScanButton.Add_Click({ Start-Work 'Scan' $null })
$ui.GoClean.Add_Click({ $ui.Pages.SelectedIndex = 1; Start-Work 'Scan' $null })
$ui.DiagnoseHome.Add_Click({ $ui.Pages.SelectedIndex = 2; Start-Work 'Diagnose' $null })
$ui.DiagnoseButton.Add_Click({ Start-Work 'Diagnose' $null })
$ui.CancelButton.Add_Click({ $script:state.Cancel = $true; $ui.CancelButton.IsEnabled = $false; $ui.Status.Text = 'Interrompendo após o arquivo atual...' })
$ui.CleanButton.Add_Click({
    [void]$ui.Categories.CommitEdit([Windows.Controls.DataGridEditingUnit]::Cell, $true)
    [void]$ui.Categories.CommitEdit([Windows.Controls.DataGridEditingUnit]::Row, $true)
    $selected = @($script:scan.Categories | Where-Object Selected)
    if ($selected.Count -eq 0) { $ui.Status.Text = 'Selecione pelo menos uma categoria.'; return }
    $size = Format-OptimizerSize (($selected | Measure-Object Bytes -Sum).Sum)
    $answer = [Windows.MessageBox]::Show($window, "Excluir permanentemente os arquivos analisados das $($selected.Count) categorias selecionadas ($size)?`n`nA exclusão não passa pela Lixeira. Arquivos em uso ou alterados serão ignorados.", 'Confirmar limpeza', 'YesNo', 'Warning', 'No')
    if ($answer -eq 'Yes') { Start-Work 'Clean' @{Scan=$script:scan; Ids=@($selected | ForEach-Object Id)} }
})
$ui.DetailsButton.Add_Click({
    $detail = New-Object Windows.Window
    $detail.Title = 'Arquivos candidatos — prévia sem exclusão'; $detail.Width = 960; $detail.Height = 560; $detail.Owner = $window; $detail.WindowStartupLocation = 'CenterOwner'
    $grid = New-Object Windows.Controls.DataGrid
    $grid.IsReadOnly = $true; $grid.AutoGenerateColumns = $false; $grid.CanUserAddRows = $false
    foreach ($column in @(@('Categoria','CategoryName',220), @('Caminho','Path',550), @('Bytes','Bytes',100))) {
        $c = New-Object Windows.Controls.DataGridTextColumn; $c.Header = $column[0]; $c.Binding = New-Object Windows.Data.Binding $column[1]; $c.Width = $column[2]; [void]$grid.Columns.Add($c)
    }
    $grid.ItemsSource = @($script:scan.Files); $detail.Content = $grid; [void]$detail.ShowDialog()
})
$ui.ExportButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter = 'Relatório HTML (*.html)|*.html'; $dialog.FileName = 'Manutencao-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.html'
    if ($dialog.ShowDialog($window)) {
        try {
            Export-OptimizerReport -Path $dialog.FileName -Customer $ui.Customer.Text -Notes $ui.Notes.Text -Diagnostics $script:diagnostics -Cleanup $script:cleanup
            $ui.Status.Text = 'Relatório salvo: ' + $dialog.FileName
        } catch { [void][Windows.MessageBox]::Show($window, $_.Exception.Message, 'Não foi possível salvar', 'OK', 'Error') }
    }
})
$toolActions = @{
    StartupTool='ms-settings:startupapps'; AppsTool='ms-settings:appsfeatures'; StorageTool='ms-settings:storagesense'; SecurityTool='windowsdefender:'
    DiskTool='dfrgui.exe'; RestoreTool='SystemPropertiesProtection.exe'; EventsTool='eventvwr.msc'; TaskTool='taskmgr.exe'
}
foreach ($name in $toolActions.Keys) {
    $ui[$name].Tag = $toolActions[$name]
    $ui[$name].Add_Click({
        param($sender, $eventArgs)
        try { Start-Process -FilePath $sender.Tag -ErrorAction Stop }
        catch { [void][Windows.MessageBox]::Show($window, $_.Exception.Message, 'Ferramenta indisponível', 'OK', 'Warning') }
    })
}
$window.Add_Closing({
    param($sender, $eventArgs)
    if ($null -ne $script:worker) { $eventArgs.Cancel = $true; $script:state.Cancel = $true; $ui.Status.Text = 'Aguarde a operação terminar antes de fechar. A interrupção foi solicitada.' }
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
        if ($null -ne $script:worker -or (Test-Path $sample) -or $script:cleanup.RemovedCount -ne 1 -or $ui.CleanButton.IsEnabled) { throw 'UI cleanup/result integration failed.' }
    } finally {
        $env:LOCALAPPDATA = $previousLocalAppData
        $timer.Stop()
        if ($null -ne $script:worker) { $script:worker.Stop(); $script:worker.Dispose(); $script:worker=$null }
        $window.Close()
        if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
    }
    Write-Output 'WPF layout, bindings, asynchronous scan and cleanup passed.'
    return
}
try { [void]$window.ShowDialog() } finally { $timer.Stop(); if ($null -ne $script:worker) { $script:worker.Dispose() } }
