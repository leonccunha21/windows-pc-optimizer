# Smoke test para Optimizer.Tweaks.psm1
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot '../Modules/Optimizer.Tweaks.psm1'
Import-Module $modulePath -Force

# Verifica funções exportadas
foreach ($cmd in @(
    'Get-OptimizerTweakCatalog',
    'Invoke-OptimizerTweak',
    'Get-OptimizerTweakPreset',
    'Test-OptimizerTweakAction',
    'Get-OptimizerTweakStatus',
    'Undo-OptimizerTweakAction',
    'Export-OptimizerTweakProfile',
    'Import-OptimizerTweakProfile'
)) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "Comando esperado '$cmd' não está exportado."
    }
}

# Valida catálogo
$catalog = @(Get-OptimizerTweakCatalog)
if ($catalog.Count -lt 15) {
    throw "Catálogo de ajustes contém menos itens do que o esperado ($($catalog.Count))."
}

foreach ($item in $catalog) {
    if ([string]::IsNullOrWhiteSpace($item.Id)) { throw "Item no catálogo sem Id." }
    if ([string]::IsNullOrWhiteSpace($item.Category)) { throw "Item no catálogo sem Category: $($item.Id)." }
    if ([string]::IsNullOrWhiteSpace($item.Name)) { throw "Item no catálogo sem Name: $($item.Id)." }
}

# Valida presets
foreach ($presetName in @('Gamer', 'Recommended')) {
    $presetItems = @(Get-OptimizerTweakPreset -Preset $presetName)
    if ($presetItems.Count -eq 0) { throw "Preset '$presetName' retornou vazio." }
    foreach ($actionId in $presetItems) {
        $found = $catalog | Where-Object { $_.Id -eq $actionId }
        if (-not $found) { throw "Ação '$actionId' do preset '$presetName' não existe no catálogo." }
    }
}

# Valida detecção de status
$status = Get-OptimizerTweakStatus
if ($status.Keys.Count -ne $catalog.Count) {
    throw "Get-OptimizerTweakStatus não retornou status para todos os itens do catálogo."
}

# Valida execução em modo -WhatIf (sem alterações reais)
$simulated = Invoke-OptimizerTweak -Action 'DisableTransparency' -WhatIf
if (-not $simulated.Success) {
    throw "Simulação -WhatIf falhou para DisableTransparency."
}

# Valida reversão em modo -WhatIf
$undoSim = Undo-OptimizerTweakAction -Action 'DisableTransparency' -WhatIf
if (-not $undoSim.Success) {
    throw "Simulação -WhatIf falhou para Undo-OptimizerTweakAction."
}

# Valida exportação e importação de perfil
$tmpProfile = Join-Path ([IO.Path]::GetTempPath()) ("tweak-profile-test-" + [guid]::NewGuid().ToString() + ".json")
try {
    $sampleActions = @('DisableMultiplaneOverlay', 'DisableMouseDelay')
    Export-OptimizerTweakProfile -Path $tmpProfile -ActionIds $sampleActions
    $imported = @(Import-OptimizerTweakProfile -Path $tmpProfile)
    if ($imported.Count -ne 2 -or $imported[0] -ne 'DisableMultiplaneOverlay') {
        throw "Import-OptimizerTweakProfile não restaurou o perfil de ajustes esperado."
    }
} finally {
    if (Test-Path -LiteralPath $tmpProfile) { Remove-Item -LiteralPath $tmpProfile -Force }
}

Write-Output "Módulo Optimizer.Tweaks validado com sucesso ($($catalog.Count) ajustes catalogados, detecção, reversão e perfis)."
