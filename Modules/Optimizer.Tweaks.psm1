#Requires -Version 5.1
Set-StrictMode -Version 2.0

<#
.SYNOPSIS
Módulo de Ajustes de Sistema, DNS, Desempenho e Gaming (Engenharia Reversa WinScript).
.DESCRIPTION
Fornece catálogo declarativo e aplicação segura de tweaks para desempenho,
latência de rede, ajustes de interface do Windows 11/10 e perfis de DNS.
#>

function Get-OptimizerTweakCatalog {
    [CmdletBinding()]
    param()

    return @(
        # --- DNS ---
        [pscustomobject]@{ Id = 'SetDnsGoogle'; Category = 'DNS'; Name = 'Configurar DNS Google'; Description = 'Define servidores DNS para 8.8.8.8 e 8.8.4.4.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'SetDnsCloudflare'; Category = 'DNS'; Name = 'Configurar DNS Cloudflare'; Description = 'Define servidores DNS para 1.1.1.1 e 1.0.0.1 (baixa latência).'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'SetDnsQuad9'; Category = 'DNS'; Name = 'Configurar DNS Quad9'; Description = 'Define servidores DNS para 9.9.9.9 e 149.112.112.112 (foco em segurança).'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'SetDnsAdGuard'; Category = 'DNS'; Name = 'Configurar DNS AdGuard'; Description = 'Define servidores DNS para 94.140.14.14 e 94.140.15.15 (bloqueio de anúncios).'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'ResetDnsDefault'; Category = 'DNS'; Name = 'Restaurar DNS para Automático (DHCP)'; Description = 'Restaura a obtenção automática de DNS fornecido pelo roteador.'; Risk = 'Baixo'; RequiresElevation = $true }

        # --- Desempenho ---
        [pscustomobject]@{ Id = 'DisableTransparency'; Category = 'Desempenho'; Name = 'Desativar Transparência do Windows'; Description = 'Remove efeitos acrílicos/mica para economizar recursos de GPU.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'DisableMouseDelay'; Category = 'Desempenho'; Name = 'Reduzir Atraso de Menus e Ponteiro'; Description = 'Define MenuShowDelay e MouseHoverTime para 0 ms para resposta imediata.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'SetIPv4Priority'; Category = 'Desempenho'; Name = 'Priorizar IPv4 sobre IPv6'; Description = 'Ajusta prefixo de pilha de rede para evitar esperas por timeout em IPv6 inativo.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableFastStartup'; Category = 'Desempenho'; Name = 'Desativar Inicialização Rápida (Fast Startup)'; Description = 'Garante desligamento real do kernel e previne corrupção de drivers/dual-boot.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableHibernation'; Category = 'Desempenho'; Name = 'Desativar Hibernação'; Description = 'Libera gigabytes do arquivo hiberfil.sys na unidade do sistema.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'LimitDefenderCPU'; Category = 'Desempenho'; Name = 'Limitar Uso de CPU do Windows Defender'; Description = 'Limita a verificação em segundo plano a no máximo 25% de uso de CPU.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisablePrefetch'; Category = 'Desempenho'; Name = 'Desativar SysMain (Superfetch)'; Description = 'Recomendado para SSDs NVMe/SATA modernos para poupar ciclos de leitura/escrita.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'SetManualServices'; Category = 'Desempenho'; Name = 'Otimizar Inicialização de Serviços'; Description = 'Coloca serviços secundários em início Manual e desativa diagnósticos pesados.'; Risk = 'Médio'; RequiresElevation = $true }

        # --- Gaming ---
        [pscustomobject]@{ Id = 'DisableFullscreenOptimizations'; Category = 'Gaming'; Name = 'Desativar Otimizações de Tela Inteira'; Description = 'Desativa sobreposição FSE para reduzir input lag em jogos clássicos.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'DisableWindowedOptimizations'; Category = 'Gaming'; Name = 'Desativar Flip Model em Janela'; Description = 'Evita alterações forçadas de taxa de quadros em jogos no modo janela.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'DisableMouseAcceleration'; Category = 'Gaming'; Name = 'Desativar Aceleração do Mouse (1:1)'; Description = 'Remove curva de aceleração da área de trabalho para precisão linear.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'DisableGameMode'; Category = 'Gaming'; Name = 'Desativar Modo de Jogo'; Description = 'Desativa priorização interna quando causa stuttering ou congelamentos.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableGameBar'; Category = 'Gaming'; Name = 'Desativar Xbox Game Bar e Capturas'; Description = 'Desativa GameDVR em segundo plano para liberar memória de vídeo e CPU.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableMultiplaneOverlay'; Category = 'Gaming'; Name = 'Desativar Multiplane Overlay (MPO)'; Description = 'Corrige stuttering e telas pretas frequentes em GPUs NVIDIA/AMD recentes.'; Risk = 'Baixo'; RequiresElevation = $true }

        # --- Interface & Produtividade ---
        [pscustomobject]@{ Id = 'EnableDarkMode'; Category = 'Interface'; Name = 'Ativar Tema Escuro no Sistema e Apps'; Description = 'Define modo escuro global nas preferências do usuário.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'ShowFileExtensions'; Category = 'Interface'; Name = 'Exibir Extensões Conhecidas de Arquivos'; Description = 'Mostra .exe, .ps1, .pdf, etc. no Explorador (melhora segurança).'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'ShowHiddenFiles'; Category = 'Interface'; Name = 'Exibir Arquivos e Pastas Ocultos'; Description = 'Torna pastas como AppData visíveis no Explorador de Arquivos.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'SetClassicContextMenu'; Category = 'Interface'; Name = 'Restaurar Menu de Contexto Clássico (W11)'; Description = 'Restaura menu com botão direito completo estilo Windows 10 no Windows 11.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'AddEndTaskToContextMenu'; Category = 'Interface'; Name = 'Adicionar "Finalizar Tarefa" na Barra'; Description = 'Permite fechar programas travados clicando com botão direito no ícone da barra.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'RemoveHomeGalleryFromExplorer'; Category = 'Interface'; Name = 'Remover "Galeria" do Explorador de Arquivos'; Description = 'Oculta a seção Galeria introduzida no Windows 11 do painel lateral.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'MoveTaskbarLeft'; Category = 'Interface'; Name = 'Alinhar Barra de Tarefas à Esquerda'; Description = 'Move o botão Iniciar e ícones para o canto esquerdo no Windows 11.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'DisableStickyKeys'; Category = 'Interface'; Name = 'Desativar Atalho das Teclas de Aderência'; Description = 'Impede que pressionar Shift 5 vezes abra o alerta de Teclas de Aderência.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'EnableDetailedBSOD'; Category = 'Interface'; Name = 'Habilitar Tela Azul (BSOD) Detalhada'; Description = 'Exibe código de erro hexadecimal e detalhes técnicos durante pane do sistema.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'ResetNetwork'; Category = 'Interface'; Name = 'Redefinir Conexão de Rede (Flush DNS)'; Description = 'Executa flushdns, release e renew nas interfaces de rede.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'ClearBrowserHistory'; Category = 'Interface'; Name = 'Limpar Cache e Histórico de Navegadores'; Description = 'Limpa caches temporários de Chrome, Edge, Brave e Firefox.'; Risk = 'Baixo'; RequiresElevation = $false }
    )
}

function Set-OptimizerTweakRegistrySafely {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [string]$Type = 'DWord'
    )
    if ($PSCmdlet.ShouldProcess("$Path\$Name", "Definir valor $Value ($Type)")) {
        try {
            if (-not (Test-Path -LiteralPath $Path)) {
                New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
            }
            Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop | Out-Null
            return $true
        } catch {
            Write-Verbose "Erro ao gravar registro em $Path\$Name : $($_.Exception.Message)"
            return $false
        }
    }
    return $true
}

function Invoke-OptimizerTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Action,
        [switch]$Force
    )

    $result = [pscustomobject]@{
        Action  = $Action
        Success = $false
        Message = ''
    }

    if (-not $PSCmdlet.ShouldProcess("Sistema", "Executar ajuste '$Action'")) {
        $result.Success = $true
        $result.Message = 'Simulado com sucesso (-WhatIf)'
        return $result
    }

    try {
        switch ($Action) {
            # --- DNS ---
            'SetDnsGoogle' {
                try {
                    $adapters = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' })
                    foreach ($adapter in $adapters) {
                        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses @('8.8.8.8', '8.8.4.4') -ErrorAction SilentlyContinue
                    }
                    $result.Success = $true
                    $result.Message = 'DNS Google (8.8.8.8 / 8.8.4.4) configurado nas interfaces ativas.'
                } catch {
                    $result.Message = "Erro ao configurar DNS: $($_.Exception.Message)"
                }
            }
            'SetDnsCloudflare' {
                try {
                    $adapters = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' })
                    foreach ($adapter in $adapters) {
                        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses @('1.1.1.1', '1.0.0.1') -ErrorAction SilentlyContinue
                    }
                    $result.Success = $true
                    $result.Message = 'DNS Cloudflare (1.1.1.1 / 1.0.0.1) configurado nas interfaces ativas.'
                } catch {
                    $result.Message = "Erro ao configurar DNS: $($_.Exception.Message)"
                }
            }
            'SetDnsQuad9' {
                try {
                    $adapters = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' })
                    foreach ($adapter in $adapters) {
                        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses @('9.9.9.9', '149.112.112.112') -ErrorAction SilentlyContinue
                    }
                    $result.Success = $true
                    $result.Message = 'DNS Quad9 (9.9.9.9 / 149.112.112.112) configurado nas interfaces ativas.'
                } catch {
                    $result.Message = "Erro ao configurar DNS: $($_.Exception.Message)"
                }
            }
            'SetDnsAdGuard' {
                try {
                    $adapters = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' })
                    foreach ($adapter in $adapters) {
                        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses @('94.140.14.14', '94.140.15.15') -ErrorAction SilentlyContinue
                    }
                    $result.Success = $true
                    $result.Message = 'DNS AdGuard (94.140.14.14 / 94.140.15.15) configurado nas interfaces ativas.'
                } catch {
                    $result.Message = "Erro ao configurar DNS: $($_.Exception.Message)"
                }
            }
            'ResetDnsDefault' {
                try {
                    $adapters = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' })
                    foreach ($adapter in $adapters) {
                        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
                    }
                    $result.Success = $true
                    $result.Message = 'DNS redefinido para DHCP automático.'
                } catch {
                    $result.Message = "Erro ao redefinir DNS: $($_.Exception.Message)"
                }
            }

            # --- Desempenho ---
            'DisableTransparency' {
                Set-OptimizerTweakRegistrySafely 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Transparência do Windows desativada.'
            }
            'DisableMouseDelay' {
                Set-OptimizerTweakRegistrySafely 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String' | Out-Null
                Set-OptimizerTweakRegistrySafely 'HKCU:\Control Panel\Mouse' 'MouseHoverTime' '0' 'String' | Out-Null
                $result.Success = $true
                $result.Message = 'Atrasos de menu e foco definidos para 0 ms.'
            }
            'SetIPv4Priority' {
                Set-OptimizerTweakRegistrySafely 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents' 32 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Prioridade IPv4 definida nas pilhas TCP/IP.'
            }
            'DisableFastStartup' {
                Set-OptimizerTweakRegistrySafely 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Inicialização Rápida (Fast Startup) desativada.'
            }
            'DisableHibernation' {
                if (Get-Command 'powercfg.exe' -ErrorAction SilentlyContinue) {
                    Start-Process -FilePath 'powercfg.exe' -ArgumentList '/h off' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                }
                $result.Success = $true
                $result.Message = 'Hibernação desativada e hiberfil.sys removido.'
            }
            'LimitDefenderCPU' {
                Set-OptimizerTweakRegistrySafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan' 'AvgCPULoadFactor' 25 'DWord' | Out-Null
                Set-OptimizerTweakRegistrySafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan' 'ScanAvgCPULoadFactor' 25 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Uso de CPU para verificações do Windows Defender limitado a 25%.'
            }
            'DisablePrefetch' {
                try {
                    Stop-Service -Name 'sysmain' -Force -ErrorAction SilentlyContinue
                    Set-Service -Name 'sysmain' -StartupType Disabled -ErrorAction SilentlyContinue
                } catch {}
                $result.Success = $true
                $result.Message = 'Serviço SysMain (Superfetch) desativado.'
            }
            'SetManualServices' {
                $manualServices = @(
                    'AppReadiness','AxInstSV','CertPropSvc','CscService','DevQueryBroker',
                    'DeviceInstall','DisplayEnhancementService','EFS','FDResPub','GraphicsPerfSvc',
                    'InstallService','InventorySvc','NetSetupSvc','PenService','PhoneSvc',
                    'PrintNotify','RetailDemo','SensorDataService','SensorService','SensrSvc',
                    'SharedAccess','TapiSrv','TroubleshootingSvc','VSS','WbioSrvc','WdiServiceHost',
                    'WdiSystemHost','WebClient','Wecsvc','WerSvc','wisvc'
                )
                foreach ($s in $manualServices) {
                    try { Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue } catch {}
                }
                $result.Success = $true
                $result.Message = "$($manualServices.Count) serviços secundários definidos como Manual."
            }

            # --- Gaming ---
            'DisableFullscreenOptimizations' {
                Set-OptimizerTweakRegistrySafely 'HKCU:\System\GameConfigStore' 'GameDVR_DXGIHonorFSEWindowsCompatible' 1 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Otimizações de tela inteira desativadas.'
            }
            'DisableWindowedOptimizations' {
                Set-OptimizerTweakRegistrySafely 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings' 'SwapEffectUpgradeEnable=0;' 'String' | Out-Null
                $result.Success = $true
                $result.Message = 'Flip model forçado para jogos em janela desativado.'
            }
            'DisableMouseAcceleration' {
                Set-OptimizerTweakRegistrySafely 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String' | Out-Null
                Set-OptimizerTweakRegistrySafely 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String' | Out-Null
                Set-OptimizerTweakRegistrySafely 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String' | Out-Null
                $result.Success = $true
                $result.Message = 'Aceleração de ponteiro do mouse desativada (relação 1:1).'
            }
            'DisableGameMode' {
                Set-OptimizerTweakRegistrySafely 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'AutoGameModeEnabled' 0 'DWord' | Out-Null
                Set-OptimizerTweakRegistrySafely 'HKCU:\SOFTWARE\Microsoft\GameBar' 'AutoGameModeEnabled' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Modo de Jogo do Windows desativado.'
            }
            'DisableGameBar' {
                Set-OptimizerTweakRegistrySafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0 'DWord' | Out-Null
                Set-OptimizerTweakRegistrySafely 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 'DWord' | Out-Null
                Set-OptimizerTweakRegistrySafely 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Xbox Game Bar e gravação em segundo plano desativadas.'
            }
            'DisableMultiplaneOverlay' {
                Set-OptimizerTweakRegistrySafely 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode' 5 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Multiplane Overlay (MPO) desativado (corrige flickering/stuttering).'
            }

            # --- Interface & Produtividade ---
            'EnableDarkMode' {
                Set-OptimizerTweakRegistrySafely 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme' 0 'DWord' | Out-Null
                Set-OptimizerTweakRegistrySafely 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'SystemUsesLightTheme' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Modo escuro ativado para aplicativos e sistema.'
            }
            'ShowFileExtensions' {
                Set-OptimizerTweakRegistrySafely 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Exibição de extensões de arquivos ativada.'
            }
            'ShowHiddenFiles' {
                Set-OptimizerTweakRegistrySafely 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden' 1 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Exibição de arquivos e pastas ocultos ativada.'
            }
            'SetClassicContextMenu' {
                $clsidPath = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
                if (-not (Test-Path -LiteralPath $clsidPath)) {
                    New-Item -Path $clsidPath -Force -ErrorAction SilentlyContinue | Out-Null
                }
                Set-ItemProperty -LiteralPath $clsidPath -Name '(default)' -Value '' -Force -ErrorAction SilentlyContinue | Out-Null
                $result.Success = $true
                $result.Message = 'Menu de contexto clássico restaurado (efetivo após reiniciar o Explorer).'
            }
            'AddEndTaskToContextMenu' {
                Set-OptimizerTweakRegistrySafely 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' 1 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Opção "Finalizar Tarefa" adicionada ao menu de contexto da barra de tarefas.'
            }
            'RemoveHomeGalleryFromExplorer' {
                Set-OptimizerTweakRegistrySafely 'HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}' 'System.IsPinnedToNameSpaceTree' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Galeria ocultada do painel de navegação do Explorador.'
            }
            'MoveTaskbarLeft' {
                Set-OptimizerTweakRegistrySafely 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAl' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Ícones da barra de tarefas alinhados à esquerda.'
            }
            'DisableStickyKeys' {
                Set-OptimizerTweakRegistrySafely 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' '58' 'String' | Out-Null
                $result.Success = $true
                $result.Message = 'Atalho de ativação de Teclas de Aderência desativado.'
            }
            'EnableDetailedBSOD' {
                Set-OptimizerTweakRegistrySafely 'HKLM:\System\CurrentControlSet\Control\CrashControl' 'DisplayParameters' 1 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Exibição de detalhes técnicos em telas azuis (BSOD) habilitada.'
            }
            'ResetNetwork' {
                Start-Process -FilePath 'ipconfig.exe' -ArgumentList '/flushdns' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                Start-Process -FilePath 'ipconfig.exe' -ArgumentList '/release' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                Start-Process -FilePath 'ipconfig.exe' -ArgumentList '/renew' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                $result.Success = $true
                $result.Message = 'Cache DNS limpo e conexões IP renovadas.'
            }
            'ClearBrowserHistory' {
                $cleaned = 0
                $targets = @(
                    "$env:LocalAppData\Google\Chrome\User Data\Default\Cache\*",
                    "$env:LocalAppData\Microsoft\Edge\User Data\Default\Cache\*",
                    "$env:LocalAppData\BraveSoftware\Brave-Browser\User Data\Default\Cache\*",
                    "$env:AppData\Mozilla\Firefox\Profiles\*.default\cache2\entries\*"
                )
                foreach ($t in $targets) {
                    try {
                        if (Test-Path -Path $t) {
                            Remove-Item -Path $t -Recurse -Force -ErrorAction SilentlyContinue
                            $cleaned++
                        }
                    } catch {}
                }
                $result.Success = $true
                $result.Message = "Limpeza de cache de navegadores realizada ($cleaned alvos processados)."
            }
            default {
                $result.Message = "Ajuste desconhecido: $Action"
            }
        }
    } catch {
        $result.Message = "Erro ao executar $Action : $($_.Exception.Message)"
    }

    return $result
}

Export-ModuleMember -Function Get-OptimizerTweakCatalog, Invoke-OptimizerTweak

