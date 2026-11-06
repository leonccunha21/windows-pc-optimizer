# Smoke test para Optimizer.Privacy.psm1
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot '../Modules/Optimizer.Privacy.psm1'
Import-Module $modulePath -Force

# Verifica funções exportadas
foreach ($cmd in @('Get-OptimizerPrivacyCatalog', 'Get-OptimizerPrivacyPreset', 'Invoke-OptimizerPrivacyAction')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "Comando esperado '$cmd' não está exportado."
    }
}

# Valida catálogo
$catalog = @(Get-OptimizerPrivacyCatalog)
if ($catalog.Count -lt 20) {
    throw "Catálogo de privacidade contém menos itens do que o esperado ($($catalog.Count))."
}

foreach ($item in $catalog) {
    if ([string]::IsNullOrWhiteSpace($item.Id)) { throw "Item no catálogo sem Id." }
    if ([string]::IsNullOrWhiteSpace($item.Category)) { throw "Item no catálogo sem Category: $($item.Id)." }
    if ([string]::IsNullOrWhiteSpace($item.Name)) { throw "Item no catálogo sem Name: $($item.Id)." }
}

# Valida presets
foreach ($presetName in @('Basic', 'Strict', 'Extreme')) {
    $presetItems = @(Get-OptimizerPrivacyPreset -Preset $presetName)
    if ($presetItems.Count -eq 0) { throw "Preset '$presetName' retornou vazio." }
    foreach ($actionId in $presetItems) {
        $found = $catalog | Where-Object { $_.Id -eq $actionId }
        if (-not $found) { throw "Ação '$actionId' do preset '$presetName' não existe no catálogo." }
    }
}

# Valida execução em modo -WhatIf (nenhuma alteração real deve ser feita)
$simulated = Invoke-OptimizerPrivacyAction -Action 'DisableWindowsTelemetry' -WhatIf
if (-not $simulated.Success) {
    throw "Simulação -WhatIf falhou para DisableWindowsTelemetry."
}

Write-Output "Módulo Optimizer.Privacy validado com sucesso ($($catalog.Count) ações catalogadas)."
