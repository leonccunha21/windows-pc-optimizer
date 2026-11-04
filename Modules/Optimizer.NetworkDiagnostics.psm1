#Requires -Version 5.1
# Read-only Windows networking diagnostics; no outbound traffic unless explicitly requested.
Set-StrictMode -Version 2.0

function Test-OptimizerEndpointInput {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$HostName,
          [ValidateRange(1,65535)][int]$Port = 443)
    $value = $HostName.Trim()
    if (-not $value -or $value.Length -gt 253 -or $value -match '[\s/\\@?&#;\x00-\x1f]' -or $value.Contains('://')) { return $false }
    $ip = $null
    if ([Net.IPAddress]::TryParse($value, [ref]$ip)) { return $true }
    if ($value.EndsWith('.') -or $value.Contains('..')) { return $false }
    foreach ($part in $value.Split('.')) {
        if ($part.Length -lt 1 -or $part.Length -gt 63 -or $part -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$') { return $false }
    }
    return $true
}

function Get-OptimizerAdapterAdvice {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$AdapterStatus = '',
          [AllowEmptyString()][string]$IPv4Address = '',
          [bool]$GatewayPresent = $false,
          [bool]$DnsPresent = $false)
    if ($AdapterStatus -ne 'Up') {
        return [pscustomobject]@{Level='Info';Finding='Conexão não ativa';Advice='Verifique cabo, Wi-Fi e status do adaptador.'}
    }
    if (-not $IPv4Address) {
        return [pscustomobject]@{Level='Warning';Finding='IPv4 não informado';Advice='Confira DHCP/IP; redes somente IPv6 podem funcionar normalmente.'}
    }
    if ($IPv4Address -like '169.254.*') {
        return [pscustomobject]@{Level='Warning';Finding='Endereço APIPA';Advice='Possível falha na obtenção de DHCP. Verifique roteador e servidor DHCP.'}
    }
    if (-not $GatewayPresent) {
        return [pscustomobject]@{Level='Warning';Finding='Gateway ausente';Advice='Verifique rota padrão; redes locais isoladas podem funcionar sem gateway.'}
    }
    if (-not $DnsPresent) {
        return [pscustomobject]@{Level='Warning';Finding='DNS IPv4 ausente';Advice='Verifique DNS; redes IPv6 podem operar com DNS alternativo.'}
    }
    return [pscustomobject]@{Level='Info';Finding='Configuração IPv4 disponível';Advice='Não confirma acesso à Internet; faça teste de destino somente com autorização.'}
}

function Get-OptimizerNetworkSnapshot {
    <#
    .SYNOPSIS
    Inventory of adapter link, IPv4, DNS, gateway, profiles and IPv4 default routes.
    .PARAMETER IncludeAddresses
    Displays actual local IP, DNS and gateway values (hidden by default).
    #>
    [CmdletBinding()]
    param([switch]$IncludeAddresses,
          [hashtable]$State = @{Cancel=$false;Message=''})
    if ($env:OS -ne 'Windows_NT') { throw 'O inventário de rede requer Windows.' }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    $add = {
        param([string]$Area,[string]$Item,[string]$Value,[string]$Level)
        [void]$rows.Add([pscustomobject]@{Area=$Area;Item=$Item;Value=$Value;Level=$Level})
    }
    $State.Message = 'Consultando adaptadores...'
    try { $adapters = @(Get-NetAdapter -ErrorAction Stop | Sort-Object Name) }
    catch {
        & $add 'Rede' 'Adaptadores' 'Consulta indisponível; verifique permissões e serviços.' 'Warning'
        return $rows.ToArray()
    }
    if ($adapters.Count -eq 0) {
        & $add 'Rede' 'Adaptadores' 'Nenhum adaptador retornado pelo Windows.' 'Warning'
    }
    foreach ($adapter in $adapters) {
        if ($State.Cancel) { break }
        $area = [string]$adapter.Name
        $linkState = [string]$adapter.Status
        & $add $area 'Estado do link' $linkState 'Info'
        if ($adapter.LinkSpeed) { & $add $area 'Velocidade do link' ([string]$adapter.LinkSpeed) 'Info' }
        $ipv4 = ''; $gateway = ''; $servers = @()
        try {
            $config = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex -ErrorAction Stop
            $ipRows = @($config.IPv4Address | Where-Object { $null -ne $_ -and $_.IPAddress })
            if ($ipRows.Count -gt 0) { $ipv4 = [string]$ipRows[0].IPAddress }
            $gateways = @($config.IPv4DefaultGateway | Where-Object { $null -ne $_ -and $_.NextHop })
            if ($gateways.Count -gt 0) { $gateway = [string]$gateways[0].NextHop }
            $dns = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction Stop
            $servers = @($dns.ServerAddresses | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        } catch {
            & $add $area 'Configuração IP' 'Consulta parcial/indisponível.' 'Info'
        }
        if ($IncludeAddresses) {
            & $add $area 'IPv4' $(if ($ipv4) { $ipv4 } else { 'Não informado' }) 'Info'
            & $add $area 'Gateway' $(if ($gateway) { $gateway } else { 'Não informado' }) 'Info'
            & $add $area 'DNS IPv4' $(if ($servers.Count) { $servers -join ', ' } else { 'Não informado' }) 'Info'
        } else {
            & $add $area 'IPv4' $(if ($ipv4) { 'Configurado (oculto)' } else { 'Não informado' }) 'Info'
            & $add $area 'Gateway' $(if ($gateway) { 'Configurado (oculto)' } else { 'Não informado' }) 'Info'
            & $add $area 'DNS IPv4' $(if ($servers.Count) { 'Configurado (oculto)' } else { 'Não informado' }) 'Info'
        }
        $advice = Get-OptimizerAdapterAdvice -AdapterStatus $linkState -IPv4Address $ipv4 -GatewayPresent ([bool]$gateway) -DnsPresent ($servers.Count -gt 0)
        & $add $area $advice.Finding $advice.Advice $advice.Level
    }
    if (-not $State.Cancel) {
        try {
            foreach ($profile in @(Get-NetConnectionProfile -ErrorAction Stop)) {
                if ($State.Cancel) { break }
                & $add 'Perfis' ([string]$profile.Name) ([string]$profile.NetworkCategory) 'Info'
            }
        } catch { & $add 'Perfis' 'Estado' 'Consulta indisponível.' 'Info' }
    }
    if (-not $State.Cancel) {
        try {
            $defaultRoutes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop)
            & $add 'Roteamento' 'Rotas IPv4 padrão' ([string]$defaultRoutes.Count) 'Info'
        } catch { & $add 'Roteamento' 'Rotas IPv4 padrão' 'Consulta indisponível.' 'Info' }
    }
    $State.Message = if ($State.Cancel) { 'Consulta interrompida.' } else { 'Inventário concluído.' }
    return $rows.ToArray()
}

function Invoke-OptimizerConnectivityCheck {
    <#
    .SYNOPSIS
    Opt-in outbound DNS query and/or TCP connection check to explicit targets.
    #>
    [CmdletBinding()]
    param([string]$DnsName = '',
          [string]$Target = '',
          [ValidateRange(1,65535)][int]$Port = 443,
          [hashtable]$State = @{Cancel=$false;Message=''})
    if (-not $DnsName -and -not $Target) { throw 'Informe -DnsName ou -Target para autorizar teste externo.' }
    if ($DnsName -and -not (Test-OptimizerEndpointInput -HostName $DnsName)) { throw 'Nome DNS inválido.' }
    if ($Target -and -not (Test-OptimizerEndpointInput -HostName $Target -Port $Port)) { throw 'Destino TCP inválido.' }
    if ($env:OS -ne 'Windows_NT') { throw 'Os testes de rede exigem Windows.' }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    if ($DnsName -and -not $State.Cancel) {
        $State.Message = 'Consulta DNS solicitada...'
        try {
            $answers = @(Resolve-DnsName -Name $DnsName -DnsOnly -ErrorAction Stop)
            $count = @($answers | Where-Object { $_.Type -in @('A','AAAA','CNAME') }).Count
            $level = if ($count -gt 0) { 'Info' } else { 'Warning' }
            [void]$rows.Add([pscustomobject]@{Area='DNS';Item=$DnsName;Value=('{0} respostas' -f $count);Level=$level})
        } catch {
            [void]$rows.Add([pscustomobject]@{Area='DNS';Item=$DnsName;Value='Consulta DNS não concluída.';Level='Warning'})
        }
    }
    if ($Target -and -not $State.Cancel) {
        $State.Message = 'Teste TCP solicitado...'
        try {
            $connection = Test-NetConnection -ComputerName $Target -Port $Port -WarningAction SilentlyContinue -ErrorAction Stop
            $ok = [bool]$connection.TcpTestSucceeded
            $level = if ($ok) { 'Info' } else { 'Warning' }
            $message = if ($ok) { 'Conexão TCP estabelecida' } else { 'Conexão TCP não estabelecida' }
            [void]$rows.Add([pscustomobject]@{Area='TCP';Item=($Target + ':' + $Port);Value=$message;Level=$level})
        } catch {
            [void]$rows.Add([pscustomobject]@{Area='TCP';Item=($Target + ':' + $Port);Value='Teste TCP indisponível.';Level='Warning'})
        }
    }
    $State.Message = if ($State.Cancel) { 'Cancelado.' } else { 'Teste concluído.' }
    return $rows.ToArray()
}

Export-ModuleMember -Function Test-OptimizerEndpointInput,Get-OptimizerAdapterAdvice,Get-OptimizerNetworkSnapshot,Invoke-OptimizerConnectivityCheck
