# Smoke test para Optimizer.Tweaks.psm1
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot '../Modules/Optimizer.Tweaks.psm1'
Import-Module $modulePath -Force

# Verifica funções exportadas
foreach ($cmd in @('Get-OptimizerTweakCatalog', 'Invoke-OptimizerTweak')) {
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

# Valida execução em modo -WhatIf (sem alterações reais)
$simulated = Invoke-OptimizerTweak -Action 'DisableTransparency' -WhatIf
if (-not $simulated.Success) {
    throw "Simulação -WhatIf falhou para DisableTransparency."
}

Write-Output "Módulo Optimizer.Tweaks validado com sucesso ($($catalog.Count) ajustes catalogados)."
