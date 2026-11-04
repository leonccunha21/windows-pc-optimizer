<#
.SYNOPSIS
    GUI for Windows PC Optimizer - Modern interface.
.DESCRIPTION
    WinForms interface wrapping Otimizar-PC.ps1 functions.
    Features: dark/light theme, progress bar, tooltips, status bar.
#>
#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "Otimizar-PC.ps1") -LoadOnly

# Theme colors
$DarkMode = $true
if ($DarkMode) {
    $bgColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
    $fgColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
    $accentColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $panelColor = [System.Drawing.Color]::FromArgb(40, 40, 48)
    $btnColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $btnHover = [System.Drawing.Color]::FromArgb(0, 100, 190)
} else {
    $bgColor = [System.Drawing.Color]::FromArgb(245, 245, 250)
    $fgColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
    $accentColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $panelColor = [System.Drawing.Color]::White
    $btnColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $btnHover = [System.Drawing.Color]::FromArgb(0, 100, 190)
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Windows PC Optimizer v$Version"
$form.Size = New-Object System.Drawing.Size(560, 700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = $bgColor
$form.ForeColor = $fgColor
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Header panel
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(560, 60)
$headerPanel.BackColor = $accentColor
$form.Controls.Add($headerPanel)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "⚡ Windows PC Optimizer"
$lblTitle.Location = New-Object System.Drawing.Point(20, 10)
$lblTitle.Size = New-Object System.Drawing.Size(400, 28)
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$headerPanel.Controls.Add($lblTitle)

$lblSubtitle = New-Object System.Windows.Forms.Label
$lblSubtitle.Text = "v$Version  |  Modo: $Mode  |  Protege projetos, codigo e Epic Games"
$lblSubtitle.Location = New-Object System.Drawing.Point(20, 38)
$lblSubtitle.Size = New-Object System.Drawing.Size(520, 16)
$lblSubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 230)
$headerPanel.Controls.Add($lblSubtitle)

# Options group
$grpOptions = New-Object System.Windows.Forms.GroupBox
$grpOptions.Text = "Otimizações"
$grpOptions.Location = New-Object System.Drawing.Point(15, 70)
$grpOptions.Size = New-Object System.Drawing.Size(525, 260)
$grpOptions.ForeColor = $fgColor
$grpOptions.BackColor = $panelColor
$form.Controls.Add($grpOptions)

$options = @(
    @{ Key = "temp";      Text = "🧹 Limpeza de temporários (≥7 dias)" },
    @{ Key = "browser";   Text = "🌐 Caches de navegadores (Chrome, Edge, Firefox...)" },
    @{ Key = "packages";  Text = "📦 Caches de pacotes (npm, pip, gradle...)" },
    @{ Key = "appcaches"; Text = "📱 Caches de aplicativos (Spotify, Discord, VS Code...)" },
    @{ Key = "startup";   Text = "🚀 Otimizar inicialização (boot)" },
    @{ Key = "system";    Text = "⚙️ Ajustes de sistema (energia, telemetria, etc.)" },
    @{ Key = "disk";      Text = "💾 Otimizar disco (TRIM/defrag, WinSxS)" },
    @{ Key = "events";    Text = "📋 Limpar logs de eventos" },
    @{ Key = "bgapps";    Text = "🔇 Desativar apps em segundo plano" },
    @{ Key = "cleanmgr";  Text = "🗑️ Limpeza de Disco (cleanmgr)" },
    @{ Key = "dns";       Text = "🌍 Flush DNS + reset Winsock" },
    @{ Key = "storage";   Text = "📦 Ativar Storage Sense" },
    @{ Key = "defender";  Text = "🛡️ Varredura completa do Defender" }
)

$checkboxes = @{}
$y = 22
$col = 0
foreach ($opt in $options) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $opt.Text
    $cb.Location = New-Object System.Drawing.Point(12 + ($col * 260), $y)
    $cb.Size = New-Object System.Drawing.Size(255, 22)
    $cb.Checked = $true
    $cb.ForeColor = $fgColor
    $cb.BackColor = $panelColor
    $grpOptions.Controls.Add($cb)
    $checkboxes[$opt.Key] = $cb
    $col++
    if ($col -ge 2) { $col = 0; $y += 24 }
}

# DryRun checkbox
$cbDry = New-Object System.Windows.Forms.CheckBox
$cbDry.Text = "🔍 Modo simulação (DryRun) — não executa, apenas mostra"
$cbDry.Location = New-Object System.Drawing.Point(15, 335)
$cbDry.Size = New-Object System.Drawing.Size(525, 22)
$cbDry.ForeColor = $fgColor
$cbDry.BackColor = $bgColor
$form.Controls.Add($cbDry)

# Projects path
$lblProj = New-Object System.Windows.Forms.Label
$lblProj.Text = "Pasta de projetos (opcional, apenas análise):"
$lblProj.Location = New-Object System.Drawing.Point(15, 362)
$lblProj.Size = New-Object System.Drawing.Size(300, 18)
$lblProj.ForeColor = $fgColor
$form.Controls.Add($lblProj)

$txtProj = New-Object System.Windows.Forms.TextBox
$txtProj.Location = New-Object System.Drawing.Point(15, 382)
$txtProj.Size = New-Object System.Drawing.Size(525, 24)
$txtProj.BackColor = $panelColor
$txtProj.ForeColor = $fgColor
$form.Controls.Add($txtProj)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(15, 412)
$progressBar.Size = New-Object System.Drawing.Size(525, 18)
$progressBar.Style = "Continuous"
$progressBar.Value = 0
$form.Controls.Add($progressBar)

# Log box
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(15, 436)
$txtLog.Size = New-Object System.Drawing.Size(525, 160)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8)
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 25)
$txtLog.ForeColor = [System.Drawing.Color]::FromArgb(0, 220, 120)
$form.Controls.Add($txtLog)

# Buttons
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "▶ Executar"
$btnRun.Location = New-Object System.Drawing.Point(15, 602)
$btnRun.Size = New-Object System.Drawing.Size(130, 36)
$btnRun.BackColor = $btnColor
$btnRun.ForeColor = [System.Drawing.Color]::White
$btnRun.FlatStyle = "Flat"
$btnRun.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnRun)

$btnAll = New-Object System.Windows.Forms.Button
$btnAll.Text = "⚡ Tudo"
$btnAll.Location = New-Object System.Drawing.Point(155, 602)
$btnAll.Size = New-Object System.Drawing.Size(100, 36)
$btnAll.BackColor = [System.Drawing.Color]::FromArgb(46, 204, 113)
$btnAll.ForeColor = [System.Drawing.Color]::White
$btnAll.FlatStyle = "Flat"
$btnAll.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnAll)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "🗑️ Limpar log"
$btnClear.Location = New-Object System.Drawing.Point(265, 602)
$btnClear.Size = New-Object System.Drawing.Size(120, 36)
$btnClear.BackColor = [System.Drawing.Color]::FromArgb(149, 165, 166)
$btnClear.ForeColor = [System.Drawing.Color]::White
$btnClear.FlatStyle = "Flat"
$form.Controls.Add($btnClear)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "✕ Fechar"
$btnClose.Location = New-Object System.Drawing.Point(395, 602)
$btnClose.Size = New-Object System.Drawing.Size(145, 36)
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(231, 76, 60)
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.FlatStyle = "Flat"
$form.Controls.Add($btnClose)

# Tooltip
$tooltip = New-Object System.Windows.Forms.ToolTip
$tooltip.SetToolTip($btnRun, "Executa as opções selecionadas")
$tooltip.SetToolTip($btnAll, "Executa todas as otimizações")
$tooltip.SetToolTip($cbDry, "Simula sem executar (seguro)")

# Status bar
$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Pronto"
$statusBar.Items.Add($statusLabel) | Out-Null
$statusBar.BackColor = $accentColor
$statusLabel.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($statusBar)

function Update-Status($text) {
    $statusLabel.Text = $text
    $form.Refresh()
}

function Log($msg) {
    $txtLog.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $msg`r`n")
    $txtLog.ScrollToCaret()
}

$btnRun.Add_Click({
    $script:DryRun = $cbDry.Checked
    $txtLog.Clear()
    $progressBar.Value = 0
    Update-Status "Executando..."

    $steps = @()
    if ($checkboxes["temp"].Checked) { $steps += { Log ">> Limpeza de temporários"; Clean-Temp } }
    if ($checkboxes["browser"].Checked) { $steps += { Log ">> Caches navegadores"; Clean-BrowserCaches } }
    if ($checkboxes["packages"].Checked) { $steps += { Log ">> Caches pacotes"; Clean-PackageCaches } }
    if ($checkboxes["appcaches"].Checked) { $steps += { Log ">> Caches apps"; Clean-AppCaches } }
    if ($checkboxes["startup"].Checked) { $steps += { Log ">> Otimizar startup"; Optimize-Startup } }
    if ($checkboxes["system"].Checked) { $steps += { Log ">> Ajustes sistema"; System-Tweaks } }
    if ($checkboxes["disk"].Checked) { $steps += { Log ">> Otimizar disco"; Optimize-Disk } }
    if ($checkboxes["events"].Checked) { $steps += { Log ">> Limpar logs"; Clear-EventLogs } }
    if ($checkboxes["bgapps"].Checked) { $steps += { Log ">> Apps background"; Disable-BackgroundApps } }
    if ($checkboxes["cleanmgr"].Checked) { $steps += { Log ">> cleanmgr"; Run-CleanMgr } }
    if ($checkboxes["dns"].Checked) { $steps += { Log ">> DNS/Winsock"; Flush-DNS } }
    if ($checkboxes["storage"].Checked) { $steps += { Log ">> Storage Sense"; Enable-StorageSense } }
    if ($checkboxes["defender"].Checked) { $steps += { Log ">> Defender scan"; Run-DefenderScan } }

    $total = $steps.Count
    $i = 0
    foreach ($step in $steps) {
        & $step
        $i++
        $progressBar.Value = [math]::Min(100, [math]::Round(($i / $total) * 100))
        $form.Refresh()
    }

    Log "=== CONCLUIDO ==="
    Update-Status "Concluído!"
    [System.Windows.Forms.MessageBox]::Show("Otimização concluída com sucesso!", "OK", "OK", "Information")
})

$btnAll.Add_Click({
    $script:DryRun = $cbDry.Checked
    foreach ($cb in $checkboxes.Values) { $cb.Checked = $true }
    $btnRun.PerformClick()
})

$btnClear.Add_Click({ $txtLog.Clear() })

$btnClose.Add_Click({ $form.Close() })

[void]$form.ShowDialog()
