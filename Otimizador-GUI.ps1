<#
.SYNOPSIS
    GUI for Windows PC Optimizer.
.DESCRIPTION
    WinForms interface wrapping Otimizar-PC.ps1 functions.
#>
#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "Otimizar-PC.ps1") -LoadOnly

$form = New-Object System.Windows.Forms.Form
$form.Text = "Windows PC Optimizer v$Version"
$form.Size = New-Object System.Drawing.Size(520, 620)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Text = "Selecione as otimizacoes desejadas:"
$label.Location = New-Object System.Drawing.Point(20, 20)
$label.Size = New-Object System.Drawing.Size(480, 20)
$label.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($label)

$options = @(
    @{ Key = "temp";      Text = "Limpeza de temporarios (>=7 dias)" },
    @{ Key = "browser";   Text = "Caches de navegadores (Chrome/Edge)" },
    @{ Key = "packages";  Text = "Caches de pacotes (npm/pnpm/pip)" },
    @{ Key = "startup";   Text = "Otimizar inicializacao (boot)" },
    @{ Key = "system";    Text = "Ajustes de sistema (energia, telemetria, etc.)" },
    @{ Key = "disk";      Text = "Otimizar disco (TRIM/defrag + WinSxS)" },
    @{ Key = "events";    Text = "Limpar logs de eventos" },
    @{ Key = "bgapps";    Text = "Desativar apps em segundo plano" },
    @{ Key = "cleanmgr";  Text = "Limpeza de Disco (cleanmgr)" },
    @{ Key = "dns";       Text = "Flush DNS + reset Winsock" },
    @{ Key = "storage";   Text = "Ativar Storage Sense" },
    @{ Key = "defender";  Text = "Varredura completa do Defender" }
)

$checkboxes = @{}
$y = 50
foreach ($opt in $options) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $opt.Text
    $cb.Location = New-Object System.Drawing.Point(20, $y)
    $cb.Size = New-Object System.Drawing.Size(480, 24)
    $cb.Checked = $true
    $form.Controls.Add($cb)
    $checkboxes[$opt.Key] = $cb
    $y += 28
}

# DryRun checkbox
$cbDry = New-Object System.Windows.Forms.CheckBox
$cbDry.Text = "Modo simulacao (DryRun) - nao executa, apenas mostra"
$cbDry.Location = New-Object System.Drawing.Point(20, $y + 5)
$cbDry.Size = New-Object System.Drawing.Size(480, 24)
$cbDry.Checked = $false
$form.Controls.Add($cbDry)
$y += 35

# Projects path
$lblProj = New-Object System.Windows.Forms.Label
$lblProj.Text = "Pasta de projetos (opcional):"
$lblProj.Location = New-Object System.Drawing.Point(20, $y)
$lblProj.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($lblProj)
$y += 22
$txtProj = New-Object System.Windows.Forms.TextBox
$txtProj.Location = New-Object System.Drawing.Point(20, $y)
$txtProj.Size = New-Object System.Drawing.Size(460, 24)
$form.Controls.Add($txtProj)
$y += 35

# Log box
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, $y)
$txtLog.Size = New-Object System.Drawing.Size(460, 120)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8)
$form.Controls.Add($txtLog)
$y += 125

# Run button
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Executar"
$btnRun.Location = New-Object System.Drawing.Point(20, $y)
$btnRun.Size = New-Object System.Drawing.Size(120, 32)
$btnRun.BackColor = [System.Drawing.Color]::LightGreen
$form.Controls.Add($btnRun)

# Close button
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Fechar"
$btnClose.Location = New-Object System.Drawing.Point(360, $y)
$btnClose.Size = New-Object System.Drawing.Size(120, 32)
$form.Controls.Add($btnClose)

$global:DryRun = $false

$btnRun.Add_Click({
    $script:DryRun = $cbDry.Checked
    $txtLog.Clear()
    $logAction = { param($m) $txtLog.AppendText("$m`r`n"); $txtLog.ScrollToCaret() }
    & $logAction "Iniciando otimizacao..."

    if ($checkboxes["temp"].Checked) { & $logAction ">> Limpeza de temporarios"; Clean-Temp }
    if ($checkboxes["browser"].Checked) { & $logAction ">> Caches navegadores"; Clean-BrowserCaches }
    if ($checkboxes["packages"].Checked) { & $logAction ">> Caches pacotes"; Clean-PackageCaches }
    if ($checkboxes["startup"].Checked) { & $logAction ">> Otimizar startup"; Optimize-Startup }
    if ($checkboxes["system"].Checked) { & $logAction ">> Ajustes sistema"; System-Tweaks }
    if ($checkboxes["disk"].Checked) { & $logAction ">> Otimizar disco"; Optimize-Disk }
    if ($checkboxes["events"].Checked) { & $logAction ">> Limpar logs"; Clear-EventLogs }
    if ($checkboxes["bgapps"].Checked) { & $logAction ">> Apps background"; Disable-BackgroundApps }
    if ($checkboxes["cleanmgr"].Checked) { & $logAction ">> cleanmgr"; Run-CleanMgr }
    if ($checkboxes["dns"].Checked) { & $logAction ">> DNS/Winsock"; Flush-DNS }
    if ($checkboxes["storage"].Checked) { & $logAction ">> Storage Sense"; Enable-StorageSense }
    if ($checkboxes["defender"].Checked) { & $logAction ">> Defender scan"; Run-DefenderScan }
    if ($txtProj.Text) { & $logAction ">> Lixo de projetos"; Clean-ProjectJunk -RootPath $txtProj.Text }

    & $logAction "=== CONCLUIDO ==="
    [System.Windows.Forms.MessageBox]::Show("Otimizacao concluida!", "OK", "OK", "Information")
})

$btnClose.Add_Click({ $form.Close() })

[void]$form.ShowDialog()
