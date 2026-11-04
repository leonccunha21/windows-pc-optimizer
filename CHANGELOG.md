# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.1] - 2026-11-04

### Security
- Desativadas a atualização de código sem assinatura e a publicação Git automática no console legado.
- `-Auto` legado bloqueado por executar alterações de alto impacto sem revisão.
- Elevação exigida somente ao executar o console legado; `-LoadOnly` permanece disponível sem administrador.
- Relatório legado passa a escapar conteúdo do log e valores de identificação do sistema.

### Fixed
- Removida opção duplicada do menu legado; histórico de versões reorganizado.

## [4.0.0] - 2026-11-04

### Added
- Nova interface WPF com painel, prévia de limpeza, diagnóstico, ferramentas e relatório de atendimento.
- Núcleo independente com raízes permitidas, retenção, proteção de projetos, rejeição de links e revalidação antes da exclusão.
- Trabalho em segundo plano, interrupção cooperativa e resultado baseado em exclusões confirmadas.
- Relatório HTML local com escape de dados e sem caminhos pessoais.
- BAT abre a interface sem exigir administrador; console antigo exige `-Legacy` explícito.
- Removidas 255 definições duplicadas do legado, sem trocar as implementações efetivas.
- Testes de segurança isolados e validação Windows PowerShell 5.1/WPF no CI.


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
