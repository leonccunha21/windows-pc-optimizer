#Requires -Version 5.1
# Diagnostic-only: reads System events, never modifies logs or Windows settings.
Set-StrictMode -Version 2.0

function Get-OptimizerEventCatalog {
    <#
    .SYNOPSIS
    Allowlist of Windows System events relevant to common PC maintenance.
    .DESCRIPTION
    Categories and guidance are conservative; an event alone is not a hardware diagnosis.
    #>
    [CmdletBinding()]
    param()
    return @(
        [pscustomobject]@{ Pattern='^(?:Microsoft-Windows-)?Kernel-Power$'; Id=41; Category='Desligamento inesperado'; Priority='Alto'; Guidance='Investigue energia, temperatura, travamentos e eventos anteriores; o código 41 não identifica a causa.' }
        [pscustomobject]@{ Pattern='^EventLog$'; Id=6008; Category='Desligamento inesperado'; Priority='Alto'; Guidance='O Windows detectou um encerramento inesperado; confira eventos associados e estabilidade.' }
        [pscustomobject]@{ Pattern='^(?:Microsoft-Windows-)?WHEA-Logger$'; Id=17; Category='Alerta de hardware WHEA'; Priority='Médio'; Guidance='Erro de hardware corrigido. Identifique o componente antes de concluir que há defeito.' }
        [pscustomobject]@{ Pattern='^(?:Microsoft-Windows-)?WHEA-Logger$'; Id=18; Category='Alerta de hardware WHEA'; Priority='Alto'; Guidance='Erro de hardware relatado pelo Windows. Investigue BIOS, CPU, memória e periféricos.' }
        [pscustomobject]@{ Pattern='^(?:Microsoft-Windows-)?WHEA-Logger$'; Id=19; Category='Alerta de hardware WHEA'; Priority='Médio'; Guidance='Erro de hardware corrigido; observe recorrência e componentes envolvidos.' }
        [pscustomobject]@{ Pattern='^disk$'; Id=7; Category='Armazenamento / E/S'; Priority='Alto'; Guidance='Possível bloco defeituoso. Confirme backup e verifique SMART e diagnóstico do fabricante.' }
        [pscustomobject]@{ Pattern='^disk$'; Id=51; Category='Armazenamento / E/S'; Priority='Médio'; Guidance='Erro de entrada/saída detectado; investigue unidade, cabos e controladora.' }
        [pscustomobject]@{ Pattern='^disk$'; Id=153; Category='Armazenamento / E/S'; Priority='Médio'; Guidance='Operação de armazenamento repetida; investigue latência, conexão e controladora.' }
        [pscustomobject]@{ Pattern='^disk$'; Id=157; Category='Armazenamento / E/S'; Priority='Médio'; Guidance='Disco removido inesperadamente; verifique cabos, portas e desconexões.' }
        [pscustomobject]@{ Pattern='^storahci$'; Id=129; Category='Armazenamento / E/S'; Priority='Médio'; Guidance='Reset do controlador de armazenamento; verifique drivers, energia e unidade.' }
        [pscustomobject]@{ Pattern='^(?:Microsoft-Windows-)?Ntfs$'; Id=55; Category='Sistema de arquivos'; Priority='Alto'; Guidance='Possível corrupção NTFS. Confirme backup e faça diagnóstico de unidade antes de reparar.' }
        [pscustomobject]@{ Pattern='^(?:Microsoft-Windows-)?Ntfs$'; Id=98; Category='Sistema de arquivos'; Priority='Médio'; Guidance='Volume pode requerer verificação; confirme estado e backup antes de qualquer alteração.' }
        [pscustomobject]@{ Pattern='^volmgr$'; Id=161; Category='Falha ao gravar despejo'; Priority='Médio'; Guidance='Despejo de memória não foi criado; verifique espaço, configuração e ocorrências relacionadas.' }
        [pscustomobject]@{ Pattern='^BugCheck$'; Id=1001; Category='Tela azul / BugCheck'; Priority='Alto'; Guidance='O Windows registrou tela azul; correlacione com drivers, hardware e análise local de dump.' }
        [pscustomobject]@{ Pattern='^Service Control Manager$'; Id=7000; Category='Falha de serviço'; Priority='Médio'; Guidance='Um serviço falhou ao iniciar; identifique o serviço no Visualizador de Eventos.' }
        [pscustomobject]@{ Pattern='^Service Control Manager$'; Id=7009; Category='Falha de serviço'; Priority='Médio'; Guidance='Tempo de inicialização de serviço excedido; investigue dependências e lentidão.' }
        [pscustomobject]@{ Pattern='^Service Control Manager$'; Id=7031; Category='Falha de serviço'; Priority='Médio'; Guidance='Um serviço encerrou inesperadamente; investigue recorrência e dependências.' }
        [pscustomobject]@{ Pattern='^Service Control Manager$'; Id=7034; Category='Falha de serviço'; Priority='Médio'; Guidance='Um serviço encerrou inesperadamente; confira as informações no Windows.' }
    )
}

function ConvertTo-OptimizerEventFinding {
    <#
    .SYNOPSIS
    Classifies one Event Log metadata record without using its potentially private Message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProviderName,
        [Parameter(Mandatory)][int]$EventId,
        [Parameter(Mandatory)][datetime]$TimeCreated
    )
    foreach ($rule in @(Get-OptimizerEventCatalog)) {
        if ($EventId -eq $rule.Id -and $ProviderName -match $rule.Pattern) {
            return [pscustomobject]@{
                Category=[string]$rule.Category
                Priority=[string]$rule.Priority
                EventId=$EventId
                TimeCreated=$TimeCreated
                Guidance=[string]$rule.Guidance
            }
        }
    }
    return $null
}

function Get-OptimizerEventSummary {
    <#
    .SYNOPSIS
    Aggregates allowlisted System events without exporting messages or user paths.
    .PARAMETER Records
    Optional synthetic records for deterministic/offline tests; bypasses log access.
    .PARAMETER Days
    Time range for actual Windows event-log consultation.
    .PARAMETER MaxEvents
    Hard upper limit of events examined from the System log.
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(1,90)][int]$Days=14,
        [ValidateRange(100,5000)][int]$MaxEvents=1500,
        [object[]]$Records=$null,
        [hashtable]$State=@{Cancel=$false;Message=''}
    )
    $State.Message='Lendo indicadores do histórico de falhas...'
    $warnings=New-Object 'System.Collections.Generic.List[string]'
    $available=$true
    $truncated=$false
    if ($PSBoundParameters.ContainsKey('Records')) {
        $items=@($Records | Where-Object { $null -ne $_ } | Select-Object -First ($MaxEvents+1))
    } else {
        if ($env:OS -ne 'Windows_NT') { throw 'A consulta de eventos reais requer Windows.' }
        try {
            $filter=@{LogName='System';StartTime=(Get-Date).AddDays(-$Days);Level=@(1,2,3)}
            $items=@(Get-WinEvent -FilterHashtable $filter -MaxEvents ($MaxEvents+1) -ErrorAction Stop)
        } catch {
            $items=@()
            $available=$false
            $warnings.Add('Não foi possível consultar o log System. Verifique permissões e disponibilidade do histórico.')
        }
    }
    if ($items.Count -gt $MaxEvents) {
        $truncated=$true
        $warnings.Add('Limite de eventos atingido. O resumo pode não abranger toda a janela solicitada.')
        $items=@($items | Select-Object -First $MaxEvents)
    }
    $findings=New-Object 'System.Collections.Generic.List[object]'
    $processed=0
    foreach ($entry in $items) {
        if ($State.Cancel) { break }
        $processed++
        $providerProperty=$entry.PSObject.Properties['ProviderName']
        $idProperty=$entry.PSObject.Properties['Id']
        $dateProperty=$entry.PSObject.Properties['TimeCreated']
        if ($null -eq $providerProperty -or $null -eq $idProperty -or $null -eq $dateProperty) { continue }
        $dateValue=$dateProperty.Value
        if ($null -eq $dateValue -or -not ($dateValue -is [datetime])) { continue }
        $eventId=0
        if (-not [int]::TryParse([string]$idProperty.Value,[ref]$eventId)) { continue }
        $finding=ConvertTo-OptimizerEventFinding -ProviderName ([string]$providerProperty.Value) -EventId $eventId -TimeCreated $dateValue
        if ($null -ne $finding) { $findings.Add($finding) }
    }
    $summary=New-Object 'System.Collections.Generic.List[object]'
    foreach ($group in @($findings.ToArray() | Group-Object -Property Category)) {
        $latest=@($group.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1)[0]
        $high=@($group.Group | Where-Object { $_.Priority -eq 'Alto' }).Count
        $summary.Add([pscustomobject]@{
            Category=[string]$group.Name
            Count=[int]$group.Count
            HighPriorityCount=[int]$high
            LastSeen=$latest.TimeCreated
            Guidance=[string]$latest.Guidance
        })
    }
    if ($findings.Count -eq 0 -and $available -and -not $State.Cancel) {
        $warnings.Add('Nenhum evento da lista monitorada foi encontrado. Isso não comprova ausência de falhas.')
    }
    $State.Message=if ($State.Cancel) { 'Consulta interrompida.' } else { 'Consulta concluída.' }
    return [pscustomobject]@{
        Source='Windows System'
        Days=$Days
        Available=$available
        Cancelled=[bool]$State.Cancel
        Truncated=$truncated
        Examined=$processed
        Matched=$findings.Count
        Warnings=$warnings.ToArray()
        Categories=@($summary.ToArray() | Sort-Object HighPriorityCount,Count -Descending)
        Findings=@($findings.ToArray() | Sort-Object TimeCreated -Descending | Select-Object -First 60)
    }
}

Export-ModuleMember -Function Get-OptimizerEventCatalog,ConvertTo-OptimizerEventFinding,Get-OptimizerEventSummary
