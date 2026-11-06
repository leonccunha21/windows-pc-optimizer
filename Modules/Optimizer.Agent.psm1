#Requires -Version 5.1
<#
.SYNOPSIS
Local recommendation agent for the PC Optimizer.

.DESCRIPTION
This module never changes the computer. It combines read-only diagnostics,
health, cleanup scan, disk health and app inventory into ranked, explainable
recommendations. The interface can preselect the suggested items, but every
apply/cleanup action still requires explicit confirmation.

No telemetry, network calls or cloud AI are used. The "agent" is deterministic
and auditable: same inputs always produce the same recommendations.
#>
Set-StrictMode -Version 2.0

function Get-AgentValue {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function New-AgentRecommendation {
    param(
        [Parameter(Mandatory)][string]$Area,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Reason,
        [string]$Risk = 'Baixo',
        [string]$Confidence = 'Média',
        [int]$Priority = 50,
        [string[]]$OptimizationIds = @(),
        [string[]]$PrivacyIds = @(),
        [string[]]$TweakIds = @(),
        [string[]]$CleanupCategoryIds = @(),
        [bool]$AdminRequired = $false
    )
    return [pscustomobject]@{
        Area = $Area
        Title = $Title
        Reason = $Reason
        Risk = $Risk
        Confidence = $Confidence
        Priority = $Priority
        OptimizationIds = @($OptimizationIds)
        PrivacyIds = @($PrivacyIds)
        TweakIds = @($TweakIds)
        CleanupCategoryIds = @($CleanupCategoryIds)
        AdminRequired = [bool]$AdminRequired
        RequiresConfirmation = $true
        AutoApply = $false
    }
}

function Test-AgentDiagnosticValue {
    param([object[]]$Diagnostics, [string]$Area, [string]$Item)
    if ($null -eq $Diagnostics) { return $null }
    foreach ($row in @($Diagnostics)) {
        if ([string]$row.Area -eq $Area -and [string]$row.Item -eq $Item) {
            return [string]$row.Value
        }
    }
    return $null
}

function Get-OptimizerAgentRecommendations {
    [CmdletBinding()]
    param(
        [object[]]$Diagnostics = @(),
        [object]$Health = $null,
        [object]$Scan = $null,
        [object[]]$AppInventory = @(),
        [bool]$IsAdmin = $false
    )

    $recommendations = New-Object 'System.Collections.Generic.List[object]'

    # Cleanup: recommend only categories with meaningful reclaimable space.
    if ($null -eq $Scan) {
        $recommendations.Add((New-AgentRecommendation -Area 'Limpeza' -Title 'Executar análise de limpeza' -Reason 'Sem análise recente, o agente não consegue estimar o espaço recuperável sem varrer o disco.' -Risk 'Baixo' -Confidence 'Alta' -Priority 80))
    } else {
        $categories = @($Scan.Categories)
        $candidateIds = @($categories |
            Where-Object { [long]$_.Bytes -ge 100MB -and [string]$_.Risk -ne 'Alto' } |
            Sort-Object Bytes -Descending |
            Select-Object -First 12 |
            ForEach-Object { [string]$_.Id })
        $totalBytes = [long]$Scan.Bytes
        if ($candidateIds.Count -gt 0) {
            $sizeText = if ($totalBytes -ge 1GB) { ('{0:N2} GB' -f ($totalBytes / 1GB)) } else { ('{0:N0} MB' -f ($totalBytes / 1MB)) }
            $recommendations.Add((New-AgentRecommendation -Area 'Limpeza' -Title "Limpar categorias com mais ganho ($sizeText)" -Reason 'Categorias com pelo menos 100 MB recuperáveis e risco diferente de Alto foram priorizadas. A prévia continua obrigatória antes da exclusão.' -Risk 'Baixo' -Confidence 'Alta' -Priority 95 -CleanupCategoryIds $candidateIds))
        } elseif ($totalBytes -gt 0) {
            $recommendations.Add((New-AgentRecommendation -Area 'Limpeza' -Title 'Revisar limpeza mesmo com ganho pequeno' -Reason 'Há espaço recuperável, mas nenhuma categoria passa do limiar de 100 MB. A revisão manual decide se vale limpar.' -Risk 'Baixo' -Confidence 'Média' -Priority 35 -CleanupCategoryIds @($categories | Sort-Object Bytes -Descending | Select-Object -First 5 | ForEach-Object { [string]$_.Id })))
        }
    }

    # Disk health: low free space or unhealthy disks deserve attention before tweaks.
    $volumes = @()
    $disks = @()
    if ($null -ne $Health) {
        $volumes = @(Get-AgentValue $Health 'Volumes')
        $disks = @(Get-AgentValue $Health 'Disks')
    }
    $lowVolume = $null
    foreach ($volume in $volumes) {
        $freeText = [string](Get-AgentValue $volume 'Free')
        $totalText = [string](Get-AgentValue $volume 'Total')
        # Health rows are display strings; use the diagnostic free-space row when available.
        if ($freeText -and $totalText) {
            $lowVolume = $volume
            break
        }
    }
    if ($null -ne $lowVolume) {
        $recommendations.Add((New-AgentRecommendation -Area 'Armazenamento' -Title 'Priorizar espaço em disco antes de ajustes agressivos' -Reason 'Com o inventário de volumes carregado, o agente recomenda validar espaço livre e Sensor de Armazenamento antes de tweaks de desempenho.' -Risk 'Baixo' -Confidence 'Média' -Priority 70 -OptimizationIds @('storage-sense')))
    }
    foreach ($disk in $disks) {
        $rating = [string](Get-AgentValue $disk 'Rating')
        if ($rating -in @('Atenção', 'Crítica')) {
            $recommendations.Add((New-AgentRecommendation -Area 'Saúde do disco' -Title 'Investigar disco com atenção/crítica' -Reason "O disco relatou avaliação '$rating'. Faça backup e avalie SFC/DISM/CHKDSK antes de otimizações." -Risk 'Médio' -Confidence 'Alta' -Priority 98))
            break
        }
    }

    # Battery health on laptops.
    $battery = if ($null -ne $Health) { Get-AgentValue $Health 'Battery' } else { $null }
    if ($null -ne $battery) {
        $healthPercent = Get-AgentValue $battery 'HealthPercent'
        if ($null -ne $healthPercent -and [double]$healthPercent -lt 80) {
            $recommendations.Add((New-AgentRecommendation -Area 'Bateria' -Title 'Plano equilibrado para bateria degradada' -Reason "Saúde estimada em $healthPercent%. O plano equilibrado tende a reduzir calor e consumo em comparação com alto desempenho." -Risk 'Baixo' -Confidence 'Alta' -Priority 65 -OptimizationIds @('power-balanced')))
        }
    }

    # Diagnostics: RAM size and Defender rows are display strings; use conservative hints.
    $ram = Test-AgentDiagnosticValue $Diagnostics 'Computador' 'Memória RAM'
    if ($ram -and $ram -match 'GB') {
        $recommendations.Add((New-AgentRecommendation -Area 'Desempenho' -Title 'Evitar desativação ampla do SysMain sem teste' -Reason 'A desativação do SysMain só faz sentido com evidência de uso alto de disco. Sem esse sinal, o agente não recomenda o tweak.' -Risk 'Médio' -Confidence 'Média' -Priority 20))
    }
    $defender = Test-AgentDiagnosticValue $Diagnostics 'Segurança' 'Defender em tempo real'
    if ($defender -eq 'False') {
        $recommendations.Add((New-AgentRecommendation -Area 'Segurança' -Title 'Verificar proteção em tempo real' -Reason 'O diagnóstico informou Defender em tempo real desativado ou indisponível. Confira o antivírus antes de otimizar.' -Risk 'Alto' -Confidence 'Alta' -Priority 99))
    }

    # App inventory: bloat suggestions are only a starting point.
    $suggestedApps = @($AppInventory | Where-Object { [bool]$_.Suggested })
    if ($suggestedApps.Count -gt 0) {
        $recommendations.Add((New-AgentRecommendation -Area 'Aplicativos' -Title "Revisar $($suggestedApps.Count) aplicativos sugeridos para remoção" -Reason 'A lista de bloatware é uma indicação, não uma ordem. Remova somente o que você confirma não usar.' -Risk 'Médio' -Confidence 'Média' -Priority 55))
    }

    # Privacy: basic protections first, extreme only on explicit choice.
    $recommendations.Add((New-AgentRecommendation -Area 'Privacidade' -Title 'Aplicar proteções básicas de telemetria' -Reason 'Telemetria geral, pesquisa, anúncios e feedback têm baixo risco e alto benefício de privacidade.' -Risk 'Baixo' -Confidence 'Alta' -Priority 60 -PrivacyIds @('DisableWindowsTelemetry', 'DisableSearchTelemetry', 'DisableTargetedAds', 'DisableWindowsFeedback')))
    $recommendations.Add((New-AgentRecommendation -Area 'Privacidade' -Title 'Remover IA invasiva (Copilot/Recall)' -Reason 'Reduz superfícies de IA e telemetria do Windows. Alguns recursos podem desaparecer do menu e da barra de tarefas.' -Risk 'Médio' -Confidence 'Média' -Priority 45 -PrivacyIds @('RemoveCopilot', 'HideCopilotButton', 'RemoveRecall')))

    # Performance tweaks: conservative, explainable presets.
    $recommendations.Add((New-AgentRecommendation -Area 'Ajustes' -Title 'DNS rápido e latência leve' -Reason 'DNS de provedor público e pequenos ajustes de latência são reversíveis e não exigem reinstalação.' -Risk 'Baixo' -Confidence 'Média' -Priority 40 -TweakIds @('SetDnsCloudflare', 'DisableTransparency', 'DisableMouseDelay')))
    if ($IsAdmin) {
        $recommendations.Add((New-AgentRecommendation -Area 'Ajustes' -Title 'Desativar inicialização rápida somente se houver motivo' -Reason 'Útil para dupla inicialização, drivers instáveis ou hibernação indesejada. Não é recomendado por padrão para todos.' -Risk 'Médio' -Confidence 'Média' -Priority 25 -TweakIds @('DisableFastStartup') -AdminRequired $true))
    } else {
        $recommendations.Add((New-AgentRecommendation -Area 'Elevação' -Title 'Reabrir como administrador para categorias de sistema' -Reason 'Sem elevação, categorias de sistema e alguns ajustes ficam indisponíveis. O agente não aplica nada silenciosamente.' -Risk 'Baixo' -Confidence 'Alta' -Priority 30))
    }

    # Optimizations: safe defaults.
    $recommendations.Add((New-AgentRecommendation -Area 'Otimização' -Title 'Sensor de Armazenamento e plano equilibrado' -Reason 'Combinação segura para uso diário: manutenção automática do Windows e equilíbrio entre desempenho e consumo.' -Risk 'Baixo' -Confidence 'Alta' -Priority 58 -OptimizationIds @('storage-sense', 'power-balanced')))

    return @($recommendations | Sort-Object Priority -Descending)
}

Export-ModuleMember -Function Get-OptimizerAgentRecommendations
