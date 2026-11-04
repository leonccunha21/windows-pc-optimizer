#Requires -Version 5.1
<#
.SYNOPSIS
View a privacy-safe summary of relevant Windows System log failures.
.EXAMPLE
powershell.exe -NoProfile -File .\Tools\Diagnostico-Eventos.ps1
.EXAMPLE
powershell.exe -NoProfile -File .\Tools\Diagnostico-Eventos.ps1 -Days 30 -ExportPath C:\Temp\falhas-resumo.json
#>
[CmdletBinding()]
param(
    [ValidateRange(1,90)][int]$Days=14,
    [ValidateRange(100,5000)][int]$MaxEvents=1500,
    [string]$ExportPath='',
    [switch]$ValidateOnly
)
$ErrorActionPreference='Stop'
$modulePath=Join-Path $PSScriptRoot '../Modules/Optimizer.Events.psm1'
Import-Module $modulePath -Force -ErrorAction Stop
if ($ValidateOnly) {
    foreach ($name in @('Get-OptimizerEventCatalog','ConvertTo-OptimizerEventFinding','Get-OptimizerEventSummary')) {
        if (-not (Get-Command -Name $name -ErrorAction SilentlyContinue)) { throw "Comando ausente: $name" }
    }
    Write-Output 'Diagnóstico de eventos: comandos carregados, sem consulta a logs.'
    return
}
if ($env:OS -ne 'Windows_NT') { throw 'O diagnóstico de eventos reais requer Windows.' }
if ($ExportPath) {
    if ([IO.Path]::GetExtension($ExportPath) -ne '.json') { throw 'Informe um caminho de relatório com extensão .json.' }
    if (Test-Path -LiteralPath $ExportPath) { throw 'O relatório já existe; informe outro nome para não sobrescrever dados.' }
    $directory=Split-Path -Parent ([IO.Path]::GetFullPath($ExportPath))
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { throw 'A pasta do relatório não existe.' }
}
Write-Host 'PC Optimizer | Histórico de falhas do Windows' -ForegroundColor Cyan
Write-Host 'Consulta local, somente leitura. Nenhuma mensagem bruta de eventos será exportada.' -ForegroundColor Gray
$result=Get-OptimizerEventSummary -Days $Days -MaxEvents $MaxEvents
Write-Host ("Log: {0} | Janela: {1} dias | Eventos consultados: {2} | Reconhecidos: {3}" -f $result.Source,$result.Days,$result.Examined,$result.Matched)
if ($result.Categories.Count -gt 0) {
    $result.Categories | Format-Table Category,Count,HighPriorityCount,LastSeen,Guidance -Wrap -AutoSize | Out-Host
}
foreach ($warningText in $result.Warnings) { Write-Warning $warningText }
if ($ExportPath) {
    $payload=[ordered]@{
        SchemaVersion=1
        GeneratedAt=(Get-Date).ToString('o')
        Source=$result.Source
        Days=$result.Days
        Available=$result.Available
        Cancelled=$result.Cancelled
        Truncated=$result.Truncated
        Examined=$result.Examined
        Matched=$result.Matched
        Warnings=$result.Warnings
        Categories=$result.Categories
        Findings=$result.Findings
        Privacy='Sem mensagens brutas, caminhos, nomes de usuário ou conteúdo dos eventos.'
    }
    $json=ConvertTo-Json -InputObject $payload -Depth 6
    [IO.File]::WriteAllText(([IO.Path]::GetFullPath($ExportPath)),$json,(New-Object Text.UTF8Encoding($true)))
    Write-Host 'Resumo sem mensagens brutas salvo no arquivo escolhido.' -ForegroundColor Green
}
