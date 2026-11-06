#Requires -Version 5.1
Set-StrictMode -Version 2.0

<#
.SYNOPSIS
Módulo de Privacidade, Telemetria e Desativação de IA (Engenharia Reversa WinScript).
.DESCRIPTION
Fornece catálogo declarativo e execução segura de ajustes de privacidade,
bloqueio de telemetria do Windows e terceiros, restrição de acesso de apps e remoção de IA.
Todas as ações suportam ShouldProcess (-WhatIf) e respeitam execução offline/segura.
#>

function Get-OptimizerPrivacyCatalog {
    [CmdletBinding()]
    param()

    return @(
        # --- IA & Copilot ---
        [pscustomobject]@{ Id = 'RemoveCopilot'; Category = 'DebloatAI'; Name = 'Remover / Desativar Copilot'; Description = 'Desativa integração do Copilot no sistema e explorador, e remove pacote AppX se presente.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'RemoveRecall'; Category = 'DebloatAI'; Name = 'Desativar Windows Recall'; Description = 'Desativa recurso opcional Recall e encerra tarefas de análise de IA.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'RemoveAIPackages'; Category = 'DebloatAI'; Name = 'Remover Pacotes AppX de IA'; Description = 'Remove provedores de IA Copilot e Foundation para todos os usuários.'; Risk = 'Médio'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableNotepadAI'; Category = 'DebloatAI'; Name = 'Desativar IA no Bloco de Notas'; Description = 'Desativa ferramentas generativas e botão de reescrita no Notepad.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisablePaintAI'; Category = 'DebloatAI'; Name = 'Desativar IA no Paint'; Description = 'Desativa Cocreator, preenchimento e borracha generativa no Paint.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'HideCopilotButton'; Category = 'DebloatAI'; Name = 'Ocultar Botão do Copilot na Barra'; Description = 'Oculta o ícone do Copilot na barra de tarefas e no Explorer.'; Risk = 'Baixo'; RequiresElevation = $false }

        # --- Telemetria Windows ---
        [pscustomobject]@{ Id = 'DisableWindowsTelemetry'; Category = 'Telemetria'; Name = 'Desativar Telemetria Geral do Windows'; Description = 'Desativa DiagTrack, tarefas CEIP, relatório de erros e diagnósticos.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableSearchTelemetry'; Category = 'Telemetria'; Name = 'Desativar Telemetria da Pesquisa'; Description = 'Desativa Bing na pesquisa do menu Iniciar, Cortana e rastreamento de busca.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableOfficeTelemetry'; Category = 'Telemetria'; Name = 'Desativar Telemetria do Office'; Description = 'Desativa logs de diagnóstico e coleta de uso de Word, Excel e Outlook.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'DisableTargetedAds'; Category = 'Telemetria'; Name = 'Desativar Anúncios e Conteúdo Promocional'; Description = 'Desativa ID de publicidade, sugestões no Iniciar e conteúdo sugerido da MS.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'DisableAppExperience'; Category = 'Telemetria'; Name = 'Desativar Experiência de Aplicativos'; Description = 'Desativa tarefas de avaliação de compatibilidade e inventário de apps.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableWindowsFeedback'; Category = 'Telemetria'; Name = 'Desativar Notificações de Feedback'; Description = 'Desativa perguntas de feedback frequentes do Windows.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableHandwritingData'; Category = 'Telemetria'; Name = 'Desativar Coleta de Escrita e Digitação'; Description = 'Impede o envio de amostras de escrita à mão e digitação para a Microsoft.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableWindowsDRM'; Category = 'Telemetria'; Name = 'Desativar Acesso Web do Windows DRM'; Description = 'Impede verificações de rede não solicitadas do subsistema DRM.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableCloudSpeech'; Category = 'Telemetria'; Name = 'Desativar Reconhecimento de Voz na Nuvem'; Description = 'Limita comandos de voz para processamento estritamente local.'; Risk = 'Baixo'; RequiresElevation = $false }

        # --- Telemetria Aplicativos Terceiros ---
        [pscustomobject]@{ Id = 'DisableNvidiaTelemetry'; Category = 'TelemetriaApps'; Name = 'Desativar Telemetria da NVIDIA'; Description = 'Desativa contêineres e tarefas agendadas de telemetria de drivers NVIDIA.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableVsCodeTelemetry'; Category = 'TelemetriaApps'; Name = 'Desativar Telemetria do VS Code / Visual Studio'; Description = 'Desativa coleta SQM e envio de dados em IDEs Microsoft.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'DisablePowerShellTelemetry'; Category = 'TelemetriaApps'; Name = 'Desativar Telemetria do PowerShell 7+'; Description = 'Define variável de ambiente POWERSHELL_TELEMETRY_OPTOUT=1.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'DisableCCleanerTelemetry'; Category = 'TelemetriaApps'; Name = 'Desativar Telemetria do CCleaner'; Description = 'Desativa monitoramento e envio de dados do CCleaner no registro.'; Risk = 'Baixo'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'DisableGoogleUpdates'; Category = 'TelemetriaApps'; Name = 'Desativar Atualização em 2º Plano Google'; Description = 'Coloca serviços gupdate e gupdatem em modo Desativado.'; Risk = 'Médio'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableAdobeUpdates'; Category = 'TelemetriaApps'; Name = 'Desativar Atualizações em 2º Plano Adobe'; Description = 'Desativa tarefas e serviços automáticos do Adobe Updater.'; Risk = 'Médio'; RequiresElevation = $true }

        # --- Acesso de Aplicativos (Permissões) ---
        [pscustomobject]@{ Id = 'DenyLocationAccess'; Category = 'AcessoApps'; Name = 'Restringir Acesso à Localização'; Description = 'Nega acesso global de aplicativos à localização geográfica.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DenyCameraAccess'; Category = 'AcessoApps'; Name = 'Restringir Acesso à Câmera'; Description = 'Nega acesso de aplicativos UWP/Store à câmera do dispositivo.'; Risk = 'Médio'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DenyMicrophoneAccess'; Category = 'AcessoApps'; Name = 'Restringir Acesso ao Microfone'; Description = 'Nega acesso de aplicativos UWP/Store ao microfone.'; Risk = 'Médio'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DenyFileSystemAccess'; Category = 'AcessoApps'; Name = 'Restringir Acesso ao Sistema de Arquivos'; Description = 'Nega acesso direto de apps a Documentos, Imagens e Vídeos.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DenyAccountInfoAccess'; Category = 'AcessoApps'; Name = 'Restringir Acesso a Dados da Conta'; Description = 'Impede que apps leiam nome, imagem e conta do usuário logado.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DenyDiagnosticsAccess'; Category = 'AcessoApps'; Name = 'Restringir Acesso aos Dados de Diagnóstico'; Description = 'Nega acesso de apps terceiros às informações de diagnóstico.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DenyAIGenerationAccess'; Category = 'AcessoApps'; Name = 'Restringir Acesso a Modelos de IA do Sistema'; Description = 'Impede que apps acessem recursos de IA embarcados no Windows.'; Risk = 'Baixo'; RequiresElevation = $true }

        # --- Privacidade Geral ---
        [pscustomobject]@{ Id = 'DisableCloudSync'; Category = 'Privacidade'; Name = 'Desativar Sincronização na Nuvem'; Description = 'Desativa sincronização de senhas, temas e configurações entre dispositivos.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableActivityFeed'; Category = 'Privacidade'; Name = 'Desativar Linha do Tempo e Feed de Atividades'; Description = 'Desativa histórico de atividades e sincronização de linha do tempo.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableNotificationTray'; Category = 'Privacidade'; Name = 'Desativar Central de Notificações'; Description = 'Desativa central de ações e histórico de notificações na barra.'; Risk = 'Médio'; RequiresElevation = $false }
        [pscustomobject]@{ Id = 'DisableAutoMapDownloads'; Category = 'Privacidade'; Name = 'Desativar Download Automático de Mapas'; Description = 'Impede tráfego não solicitado do serviço de mapas offline.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableLockScreenCamera'; Category = 'Privacidade'; Name = 'Desativar Câmera na Tela de Bloqueio'; Description = 'Impede abertura da câmera sem desbloquear a sessão.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'ExtendUpdatePauseLimit'; Category = 'Privacidade'; Name = 'Estender Pausa do Windows Update (20 anos)'; Description = 'Permite pausar o Windows Update por até 7.300 dias nas configurações.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableWPBT'; Category = 'Privacidade'; Name = 'Desativar WPBT (Platform Binary Table)'; Description = 'Bloqueia execução de binários forçados por fabricantes na UEFI/BIOS.'; Risk = 'Baixo'; RequiresElevation = $true }

        # --- Windows Update & Entrega ---
        [pscustomobject]@{ Id = 'DisableDeliveryOptimization'; Category = 'Updates'; Name = 'Desativar Otimização de Entrega P2P'; Description = 'Impede compartilhamento de banda de internet para enviar updates a terceiros.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'DisableDriverUpdates'; Category = 'Updates'; Name = 'Bloquear Drivers no Windows Update'; Description = 'Impede que o Windows Update substitua drivers de vídeo e hardware.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'SetSecurityOnlyUpdates'; Category = 'Updates'; Name = 'Pausar Atualizações de Recursos por 1 Ano'; Description = 'Mantém apenas atualizações de segurança cumulativas.'; Risk = 'Baixo'; RequiresElevation = $true }
        [pscustomobject]@{ Id = 'SetDefaultUpdates'; Category = 'Updates'; Name = 'Restaurar Políticas Padrão do Windows Update'; Description = 'Remove restrições aplicadas nas políticas de grupo do Windows Update.'; Risk = 'Baixo'; RequiresElevation = $true }
    )
}

function Get-OptimizerPrivacyPreset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Basic', 'Strict', 'Extreme')]
        [string]$Preset
    )

    switch ($Preset) {
        'Basic' {
            return @(
                'DisableWindowsTelemetry',
                'DisableSearchTelemetry',
                'DisableTargetedAds',
                'DisableAppExperience',
                'DisableWindowsFeedback',
                'DisableHandwritingData',
                'DisableNvidiaTelemetry',
                'DisableDeliveryOptimization',
                'ExtendUpdatePauseLimit',
                'DisableWPBT',
                'HideCopilotButton',
                'DisableNotepadAI'
            )
        }
        'Strict' {
            return @(
                'RemoveCopilot',
                'RemoveRecall',
                'RemoveAIPackages',
                'DisableNotepadAI',
                'DisablePaintAI',
                'HideCopilotButton',
                'DisableWindowsTelemetry',
                'DisableSearchTelemetry',
                'DisableOfficeTelemetry',
                'DisableTargetedAds',
                'DisableAppExperience',
                'DisableWindowsFeedback',
                'DisableHandwritingData',
                'DisableWindowsDRM',
                'DisableCloudSpeech',
                'DisableNvidiaTelemetry',
                'DisableVsCodeTelemetry',
                'DisablePowerShellTelemetry',
                'DisableCCleanerTelemetry',
                'DenyLocationAccess',
                'DenyDiagnosticsAccess',
                'DenyAIGenerationAccess',
                'DenyAccountInfoAccess',
                'DisableCloudSync',
                'DisableActivityFeed',
                'DisableAutoMapDownloads',
                'DisableLockScreenCamera',
                'ExtendUpdatePauseLimit',
                'DisableWPBT',
                'DisableDeliveryOptimization',
                'DisableDriverUpdates'
            )
        }
        'Extreme' {
            return @(
                'RemoveCopilot',
                'RemoveRecall',
                'RemoveAIPackages',
                'DisableNotepadAI',
                'DisablePaintAI',
                'HideCopilotButton',
                'DisableWindowsTelemetry',
                'DisableSearchTelemetry',
                'DisableOfficeTelemetry',
                'DisableTargetedAds',
                'DisableAppExperience',
                'DisableWindowsFeedback',
                'DisableHandwritingData',
                'DisableWindowsDRM',
                'DisableCloudSpeech',
                'DisableNvidiaTelemetry',
                'DisableVsCodeTelemetry',
                'DisablePowerShellTelemetry',
                'DisableCCleanerTelemetry',
                'DisableGoogleUpdates',
                'DisableAdobeUpdates',
                'DenyLocationAccess',
                'DenyCameraAccess',
                'DenyMicrophoneAccess',
                'DenyFileSystemAccess',
                'DenyAccountInfoAccess',
                'DenyDiagnosticsAccess',
                'DenyAIGenerationAccess',
                'DisableCloudSync',
                'DisableActivityFeed',
                'DisableNotificationTray',
                'DisableAutoMapDownloads',
                'DisableLockScreenCamera',
                'ExtendUpdatePauseLimit',
                'DisableWPBT',
                'DisableDeliveryOptimization',
                'DisableDriverUpdates',
                'SetSecurityOnlyUpdates'
            )
        }
    }
}

function Set-OptimizerRegistryValueSafely {
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

function Invoke-OptimizerPrivacyAction {
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

    if (-not $PSCmdlet.ShouldProcess("Sistema", "Executar ação de privacidade '$Action'")) {
        $result.Success = $true
        $result.Message = 'Simulado com sucesso (-WhatIf)'
        return $result
    }

    try {
        switch ($Action) {
            # --- IA e Copilot ---
            'RemoveCopilot' {
                try {
                    Get-AppxPackage -Name '*Microsoft.CoPilot*' -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                } catch {}
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Copilot desativado nas políticas e removido dos componentes.'
            }
            'RemoveRecall' {
                if (Get-Command 'dism.exe' -ErrorAction SilentlyContinue) {
                    Start-Process -FilePath 'dism.exe' -ArgumentList '/Online /Disable-Feature /NoRestart /FeatureName:Recall' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                }
                $tasks = @('\Microsoft\Windows\WindowsAI\*', '\Microsoft\Windows\Recall\*')
                foreach ($t in $tasks) {
                    try {
                        Get-ScheduledTask -TaskPath $t -ErrorAction SilentlyContinue | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
                    } catch {}
                }
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Windows Recall desativado.'
            }
            'RemoveAIPackages' {
                $packages = @('Microsoft.Windows.Ai.Copilot.Provider','Microsoft.Copilot','Microsoft.WindowsAiFoundation','Microsoft.Windows.Recall')
                foreach ($pkg in $packages) {
                    Get-AppxPackage -Name "*$pkg*" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                }
                $result.Success = $true
                $result.Message = 'Pacotes de IA AppX removidos.'
            }
            'DisableNotepadAI' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\WindowsNotepad' 'DisableAIFeatures' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKCU:\Software\Microsoft\Notepad' 'ShowRewriteButton' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'IA do Bloco de Notas desativada.'
            }
            'DisablePaintAI' {
                $p = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'
                Set-OptimizerRegistryValueSafely $p 'DisableCocreator' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $p 'DisableGenerativeFill' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $p 'DisableImageCreator' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $p 'DisableGenerativeErase' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $p 'DisableRemoveBackground' 1 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Recursos de IA do Paint desativados.'
            }
            'HideCopilotButton' {
                Set-OptimizerRegistryValueSafely 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Botão Copilot ocultado.'
            }

            # --- Telemetria Windows ---
            'DisableWindowsTelemetry' {
                $tasks = @(
                    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
                    '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
                    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
                    '\Microsoft\Windows\Autochk\Proxy',
                    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
                    '\Microsoft\Windows\Feedback\Siuf\DmClient',
                    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
                    '\Microsoft\Windows\Windows Error Reporting\QueueReporting'
                )
                foreach ($t in $tasks) {
                    try { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null } catch {}
                }
                foreach ($s in @('DiagTrack', 'diagsvc', 'WerSvc', 'wercplsupport')) {
                    try { Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue; Stop-Service -Name $s -Force -ErrorAction SilentlyContinue } catch {}
                }
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DisableOneSettingsDownloads' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'Disabled' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Telemetria do sistema e tarefas agendadas desativadas.'
            }
            'DisableSearchTelemetry' {
                $sp = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
                Set-OptimizerRegistryValueSafely $sp 'ConnectedSearchPrivacy' 3 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $sp 'AllowSearchToUseLocation' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $sp 'ConnectedSearchUseWeb' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $sp 'DisableWebSearch' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $sp 'AllowCortana' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'CortanaEnabled' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Telemetria e busca na web do menu Iniciar desativadas.'
            }
            'DisableOfficeTelemetry' {
                foreach ($ver in @('15.0', '16.0')) {
                    Set-OptimizerRegistryValueSafely "HKCU:\SOFTWARE\Microsoft\Office\$ver\Common\ClientTelemetry" 'DisableTelemetry' 1 'DWord' | Out-Null
                    Set-OptimizerRegistryValueSafely "HKCU:\SOFTWARE\Microsoft\Office\$ver\Common" 'QMEnable' 0 'DWord' | Out-Null
                    Set-OptimizerRegistryValueSafely "HKCU:\SOFTWARE\Microsoft\Office\$ver\Common\Feedback" 'Enabled' 0 'DWord' | Out-Null
                }
                $tasks = @(
                    '\Microsoft\Office\OfficeTelemetryAgentFallBack',
                    '\Microsoft\Office\OfficeTelemetryAgentLogOn',
                    '\Microsoft\Office\OfficeTelemetryAgentFallBack2016',
                    '\Microsoft\Office\OfficeTelemetryAgentLogOn2016'
                )
                foreach ($t in $tasks) {
                    try { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null } catch {}
                }
                $result.Success = $true
                $result.Message = 'Telemetria e coleta de dados do Office desativadas.'
            }
            'DisableTargetedAds' {
                $cdm = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
                Set-OptimizerRegistryValueSafely $cdm 'SubscribedContentEnabled' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $cdm 'SilentInstalledAppsEnabled' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $cdm 'SystemPaneSuggestionsEnabled' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightFeatures' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Anúncios direcionados e aplicativos patrocinados desativados.'
            }
            'DisableAppExperience' {
                $tasks = @(
                    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
                    '\Microsoft\Windows\Application Experience\StartupAppTask',
                    '\Microsoft\Windows\Application Experience\PcaPatchDbTask',
                    '\Microsoft\Windows\Application Experience\MareBackup'
                )
                foreach ($t in $tasks) {
                    try { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null } catch {}
                }
                $result.Success = $true
                $result.Message = 'Tarefas de compatibilidade e experiência de apps desativadas.'
            }
            'DisableWindowsFeedback' {
                Set-OptimizerRegistryValueSafely 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Notificações de feedback do Windows desativadas.'
            }
            'DisableHandwritingData' {
                $ip = 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization'
                Set-OptimizerRegistryValueSafely $ip 'RestrictImplicitInkCollection' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $ip 'RestrictImplicitTextCollection' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $ip 'AllowInputPersonalization' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Coleta de dados de digitação e escrita desativada.'
            }
            'DisableWindowsDRM' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\WMDRM' 'DisableOnline' 1 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Acesso online do Windows DRM desativado.'
            }
            'DisableCloudSpeech' {
                Set-OptimizerRegistryValueSafely 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Reconhecimento de voz em nuvem desativado.'
            }

            # --- Telemetria Apps Terceiros ---
            'DisableNvidiaTelemetry' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client' 'OptInOrOutPreference' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\Startup' 'SendTelemetryData' 0 'DWord' | Out-Null
                try {
                    Disable-ScheduledTask -TaskName 'NvTmMon*' -ErrorAction SilentlyContinue | Out-Null
                    Disable-ScheduledTask -TaskName 'NvTmRep*' -ErrorAction SilentlyContinue | Out-Null
                    Set-Service -Name 'NvTelemetryContainer' -StartupType Disabled -ErrorAction SilentlyContinue
                } catch {}
                $result.Success = $true
                $result.Message = 'Telemetria NVIDIA desativada.'
            }
            'DisableVsCodeTelemetry' {
                foreach ($v in @('14.0','15.0','16.0','17.0')) {
                    Set-OptimizerRegistryValueSafely "HKLM:\SOFTWARE\Wow6432Node\Microsoft\VSCommon\$v\SQM" 'OptIn' 0 'DWord' | Out-Null
                }
                Set-OptimizerRegistryValueSafely 'HKCU:\Software\Microsoft\VisualStudio\Telemetry' 'TurnOffSwitch' 1 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Telemetria do VS Code e Visual Studio desativada.'
            }
            'DisablePowerShellTelemetry' {
                [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'User')
                [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')
                $result.Success = $true
                $result.Message = 'Variável POWERSHELL_TELEMETRY_OPTOUT definida para 1.'
            }
            'DisableCCleanerTelemetry' {
                $cc = 'HKCU:\Software\Piriform\CCleaner'
                Set-OptimizerRegistryValueSafely $cc 'Monitoring' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $cc 'HelpImproveCCleaner' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $cc 'SystemMonitoring' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Telemetria do CCleaner desativada.'
            }
            'DisableGoogleUpdates' {
                foreach ($s in @('gupdate', 'gupdatem')) {
                    try { Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue } catch {}
                }
                $result.Success = $true
                $result.Message = 'Serviços de atualização do Google desativados.'
            }
            'DisableAdobeUpdates' {
                try {
                    Disable-ScheduledTask -TaskName '*Adobe Acrobat Update Task*' -ErrorAction SilentlyContinue | Out-Null
                    Set-Service -Name 'AdobeARMservice' -StartupType Disabled -ErrorAction SilentlyContinue
                } catch {}
                $result.Success = $true
                $result.Message = 'Serviços de atualização da Adobe desativados.'
            }

            # --- Acesso de Aplicativos (Permissões) ---
            'DenyLocationAccess' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'String' | Out-Null
                $result.Success = $true
                $result.Message = 'Acesso à localização negado para aplicativos.'
            }
            'DenyCameraAccess' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam' 'Value' 'Deny' 'String' | Out-Null
                $result.Success = $true
                $result.Message = 'Acesso à câmera negado para aplicativos.'
            }
            'DenyMicrophoneAccess' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone' 'Value' 'Deny' 'String' | Out-Null
                $result.Success = $true
                $result.Message = 'Acesso ao microfone negado para aplicativos.'
            }
            'DenyFileSystemAccess' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\broadFileSystemAccess' 'Value' 'Deny' 'String' | Out-Null
                $result.Success = $true
                $result.Message = 'Acesso amplo ao sistema de arquivos negado para aplicativos.'
            }
            'DenyAccountInfoAccess' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation' 'Value' 'Deny' 'String' | Out-Null
                $result.Success = $true
                $result.Message = 'Acesso a dados da conta negado.'
            }
            'DenyDiagnosticsAccess' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics' 'Value' 'Deny' 'String' | Out-Null
                $result.Success = $true
                $result.Message = 'Acesso a diagnósticos negado para aplicativos.'
            }
            'DenyAIGenerationAccess' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\systemAIModels' 'Value' 'Deny' 'String' | Out-Null
                $result.Success = $true
                $result.Message = 'Acesso a modelos locais de IA negado para aplicativos.'
            }

            # --- Privacidade Geral ---
            'DisableCloudSync' {
                $ss = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'
                Set-OptimizerRegistryValueSafely $ss 'DisableSettingSync' 2 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $ss 'DisableSettingSyncUserOverride' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $ss 'DisableCredentialsSettingSync' 2 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Sincronização na nuvem desativada.'
            }
            'DisableActivityFeed' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Histórico e feed de atividades desativados.'
            }
            'DisableNotificationTray' {
                Set-OptimizerRegistryValueSafely 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableNotificationCenter' 1 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Central de notificações desativada.'
            }
            'DisableAutoMapDownloads' {
                $mp = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Maps'
                Set-OptimizerRegistryValueSafely $mp 'AllowUntriggeredNetworkTrafficOnSettingsPage' 0 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely $mp 'AutoDownloadAndUpdateMapData' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Download automático de mapas desativado.'
            }
            'DisableLockScreenCamera' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' 'NoLockScreenCamera' 1 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Câmera na tela de bloqueio desativada.'
            }
            'ExtendUpdatePauseLimit' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'FlightSettingsMaxPauseDays' 7300 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Limite de pausa do Windows Update estendido para 20 anos.'
            }
            'DisableWPBT' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'DisableWpbtExecution' 1 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Execução de binários WPBT bloqueada.'
            }

            # --- Updates & Entrega ---
            'DisableDeliveryOptimization' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 99 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Otimização de Entrega P2P desativada.'
            }
            'DisableDriverUpdates' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate' 1 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' 'SearchOrderConfig' 0 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Drivers excluídos do Windows Update.'
            }
            'SetSecurityOnlyUpdates' {
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'BranchReadinessLevel' 20 'DWord' | Out-Null
                Set-OptimizerRegistryValueSafely 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'DeferFeatureUpdatesPeriodInDays' 365 'DWord' | Out-Null
                $result.Success = $true
                $result.Message = 'Atualizações de recursos adiadas por 1 ano (apenas segurança).'
            }
            'SetDefaultUpdates' {
                $paths = @(
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU',
                    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
                )
                foreach ($p in $paths) {
                    if (Test-Path -LiteralPath $p) {
                        try { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue } catch {}
                    }
                }
                foreach ($s in @('bits', 'wuauserv', 'usosvc')) {
                    try { Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue } catch {}
                }
                $result.Success = $true
                $result.Message = 'Configurações do Windows Update restauradas ao padrão.'
            }
            default {
                $result.Message = "Ação desconhecida: $Action"
            }
        }
    } catch {
        $result.Message = "Erro ao executar $Action : $($_.Exception.Message)"
    }

    return $result
}

Export-ModuleMember -Function Get-OptimizerPrivacyCatalog, Get-OptimizerPrivacyPreset, Invoke-OptimizerPrivacyAction
