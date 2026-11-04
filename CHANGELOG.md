# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.4] - 2026-11-04

### Added
- Preferências locais de leitura, com modo de alto contraste e escala de texto 100/115/125%, aplicadas sem reiniciar.
- Recursos visuais WPF dinâmicos para cores/fontes e respeito ao Alto Contraste do Windows.
- Tela Preferências, atalho Ctrl+7 e smoke tests de JSON/persistência/privacidade em PS5.1/PS7.
- Barra lateral funcional com indicação de seção ativa, comandos de teclado Ctrl+1–Ctrl+6 e Ctrl+B.
- Bancada reorganizada em guias de Inventário, Rede, Histórico e Reparos para reduzir rolagem vertical.
- Nomes de automação em botões, indicação de foco via teclado, melhoria do contraste de texto e smoke tests portáteis da estrutura/contraste.
- Integração real da bancada na interface **Manutenção → Bancada**: módulos de inventário técnico, rede e eventos conectados a runspaces, com botões e resultados na própria janela.
- Consentimento explícito para testes externos DNS/TCP, exibição opcional de endereços locais e classificação de falhas do log System sem mensagens privadas.
- Comandos de integridade SFC/DISM/CHKDSK em console com confirmação e UAC; exportação CSV restaurada na limpeza.
- Teste de inventário via interface WPF com processo em segundo plano.
- Nova bancada técnica com inventários Windows realmente consultados (processos, inicialização, programas, rede, atualizações e discos).
- Comandos nativos SFC, DISM e CHKDSK via console com confirmação e UAC, sem execução automática.
- Exportação CSV detalhada de resultados após aviso de privacidade e navegação lateral funcional.
- Testes do módulo técnico e da allowlist de reparos.

### Changed
- Layout com dimensões mínimas mais flexíveis e ajuste de arredormento de pixels em diferentes DPIs; testes manuais em monitores variados permanecem pendentes.
- Nova organização visual "Oficina Pro", distinguindo consultas, reparos elevados e atalhos. O subpainel de bancada integra as ferramentas diretamente ao lado das abas Saúde, Drivers, Aplicativos e Otimização.

## [4.1] - 2026-11-04

### Added
- Nova aba **Saúde**: bateria com relatório oficial (powercfg /batteryreport), capacidade de projeto, ciclos e avaliação; discos físicos com status SMART, temperatura, desgaste e contadores; volumes com espaço livre.
- Nova aba **Manutenção**: inventário de drivers instalados com situação de assinatura e verificação; consulta de atualizações de driver via Windows Update; listagem de aplicativos com sugestões de remoção; remoção de aplicativos com confirmação explícita; ações seguras de otimização (plano de energia, Sensor de Armazenamento, cache de Otimização de Entrega, Lixeira, inicialização rápida).
- Funções no núcleo: Get-OptimizerBatteryHealth, Save-OptimizerBatteryReport, ConvertFrom-OptimizerBatteryReportXml, Get-OptimizerHealthRating, Get-OptimizerDiskHealth, Get-OptimizerDrivers, Get-OptimizerDriverUpdates, Get-OptimizerBloatCatalog, Get-OptimizerAppInventory, Invoke-OptimizerAppRemoval, Get-OptimizerOptimizations, Invoke-OptimizerOptimization.
- Novos atalhos dentro da aba **Manutenção** para ferramentas nativas do Windows (recursos opcionais, dispositivos, energia, Windows Update, informações de sistema).

### Fixed
- Janela WPF passa a declarar WindowStyle explícito e exibe botão Fechar no cabeçalho; durante operação ativa o fechamento pergunta antes de encerrar o runspace.

---

## [4.0.1] - 2026-11-04

### Added
- Relatório JSON local, sem caminhos de arquivos excluídos, ao lado da exportação HTML.
- Ações em massa na limpeza, resultado detalhado, progresso por arquivo e atalhos F5/Esc/Ctrl+E.
- `PSScriptAnalyzerSettings.psd1` e job `lint` bloqueante no CI, executado antes do job `safety`.
- Cobertura do núcleo ampliada com formatação de tamanho, soma de bytes, alvos padrão, HTML/JSON e relatório sem limpeza.
- `[CmdletBinding(SupportsShouldProcess)]` em `Remove-Safe`, `New-RestorePoint` e `Set-Pagefile`.
- `SECURITY.md`, `docs/ARQUITETURA.md` e templates de issue/PR.

### Security
- Atualização automática de código e publicação Git automática desativadas no console legado.
- `-Auto` e `-AutoPush` legados bloqueados por executarem alterações de alto impacto sem revisão.
- Agendamento automático do console legado desativado; tarefas antigas devem ser revisadas manualmente.
- Elevação exigida somente ao executar o console legado; `-LoadOnly` permanece disponível sem administrador.
- Relatório legado passa a escapar log, CPU, SO, modo e demais identificações do sistema.

### Changed
- `Set-Pagefile` migrado de `Get-WmiObject` para CIM, mantendo fallback via `reg add`.
- `#Requires -RunAsAdministrator` removido; checagem movida para o ponto de entrada após validar `-Legacy` e `-LoadOnly`.
- `$profile` renomeado para `$profileDir` no núcleo e parâmetros `$sender`/`$eventArgs` renomeados na GUI.
- Menu legado com opções 26/27 renomeadas para refletir a desativação das rotinas automáticas.

### Fixed
- Removida a opção "23" duplicada do menu legado.
- `Remove-Safe` não reporta mais sucesso falso quando a exclusão falha.
- Contador de logs limpos em `Clear-EventLogs` agora reflete as exclusões reais.
- Treze blocos `catch {}` vazios passaram a registrar `Write-Log`/`Write-Verbose`.
- Núcleo passou a aceitar diagnósticos ausentes e propriedades ausentes na soma de bytes.
- `CHANGELOG.md` reorganizado no formato Keep a Changelog.

## [4.0.0] - 2026-11-04

### Added
- Nova interface WPF com painel, prévia de limpeza, diagnóstico, ferramentas e relatório de atendimento.
- Núcleo independente com raízes permitidas, retenção, proteção de projetos, rejeição de links e revalidação antes da exclusão.
- Trabalho em segundo plano, interrupção cooperativa e resultado baseado em exclusões confirmadas.
- Relatório HTML local com escape de dados e sem caminhos pessoais.
- Testes de segurança isolados e validação Windows PowerShell 5.1/WPF no CI.

### Changed
- BAT abre a interface sem exigir administrador; console antigo exige `-Legacy` explícito.
- Removidas 255 definições duplicadas do legado, sem trocar as implementações efetivas.

## [3.3.0] - 2026-11-04

### Added
- Novas funções: Clean-SteamCache, Clean-DockerCache, Clean-GPUCache, Clean-PrinterSpooler, Clean-RecycleBin, Clean-WindowsOld, Optimize-Windows11, Block-Telemetry, Optimize-WindowsSearch, Clean-WindowsUpdateCache, Optimize-Privacy, Analyze-DiskByType, Backup-Bookmarks, Optimize-Services.
- Menu expandido para 48 opções.
- 48 funções de otimização.

## [3.2.0] - 2026-11-04

### Added
- Novas funções: Check-Temperatures, Clean-ExplorerCache, Check-DiskIntegrity, Kill-HighCPU, Analyze-FileTypeSpace, Quick-Maintenance, Full-Maintenance, Show-ToastNotification.
- Menu expandido para 35 opções.
- Manutenção rápida (opção 33) e completa (opção 34).
- Análise de espaço por tipo de arquivo.
- Verificação de integridade do disco (chkdsk).
- Encerramento de processos com alto CPU.

### Changed
- Versão atualizada para 3.2.0.
- Auto mode inclui Clean-ExplorerCache.

## [3.1.0] - 2026-11-04

### Changed
- **REMOVED project cleaning entirely** — no project files, source code, or build artifacts are ever touched. Projects are fully preserved.
- Added professional maintenance: diagnostics (hardware, SMART, drivers, updates, ports, suspicious tasks), backups (drivers, registry), repairs (Windows Update, Store, network), advanced cleaning (duplicates, large/old files), HTML reports, scheduling, external tools links.
- Added Clean-StoreCache and Clean-OneDriveCache.
- Added Check-Memory, Check-OpenPorts, Check-SuspiciousTasks.
- Added Backup-Drivers, Backup-RegistryFull.
- Added Repair-WindowsUpdate, Repair-Store, Repair-Network.
- Added Clean-Duplicates, Clean-LargeFiles, Clean-OldFiles.
- Added Analyze-DiskSpace, Schedule-Task, Generate-Report, Show-ExternalTools.
- 28 menu options.

## [1.1.0] - 2026-11-04

### Added
- MIT LICENSE file.
- CHANGELOG, CONTRIBUTING, .editorconfig.
- GitHub Actions workflow for PSScriptAnalyzer lint and syntax checks.
- New optimizations: WinSxS component cleanup, prefetch cache clean, icon cache rebuild, disable Game Bar/DVR, TCP auto-tuning.
- `-Mode` parameter: `Safe` (default) or `Aggressive`.
- Automatic System Restore Point before changes.
- SSD vs HDD detection (ReTrim on SSD, defrag on HDD).
- Self-update check against GitHub raw.
- Comment-based help for all functions.
- Pester test suite (smoke tests).
- WinForms GUI (`Otimizador-GUI.ps1`).

### Changed
- Improved logging with levels.
- Clean-Temp now respects DryRun.
- Better error handling and idempotency.

### Fixed
- NullReferenceException in directory cleanup.
- Temp files deleted even in DryRun mode.

## [1.0.0] - 2026-11-04

### Added
- Initial release: interactive menu + auto mode.
- 15 optimization options.
- Protection for Epic Games / Fortnite files.
- DryRun mode.
- README and LEIA-ME.
