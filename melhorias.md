# Melhorias recomendadas — PC Optimizer

> Diagnóstico original: 04/11/2026, versão 4.0. Status revisado na implementação 4.0.1 em 04/11/2026.
> Base: `Otimizar-PC.ps1` (legado, 1.535 linhas), `Modules/Optimizer.Core.psm1` e `Otimizador-GUI.ps1`.

---

## Rodada 4.5.1 — conclusão de pendências viáveis (06/11/2026)

**Escopo executado:** revisão deste arquivo para concluir os itens que não dependem de certificado de assinatura, tag publicada ou gravação manual de tela. Nenhuma rotina destrutiva nova foi habilitada; a interface continua sem telemetria e sem persistir dados de clientes.

| Item | Entrega desta rodada |
|---|---|
| 7 | **Ampliado** — `Tests/Core.Smoke.ps1` passou a 50 verificações: descoberta de perfil Chrome em `LOCALAPPDATA` descartável, carregamento do `config/optimizer.psd1`, configuração customizada e fallback seguro para configuração inválida. Cenários de WMI/bateria indisponível seguem pendentes. |
| 8 | **Concluído** — comment-based help em `Get-OptimizerTargets`, `Test-OptimizerPath`, `Get-OptimizerScan`, `Get-OptimizerDiagnostics` e `Export-OptimizerReport`; `[CmdletBinding()]` adicionado ao helper `Get-OptimizerByteSum`. |
| 9 | **Concluído** — `config/optimizer.psd1` externaliza retenção mínima, navegadores, subpastas de cache, extensões protegidas, pastas protegidas e marcadores de projeto. O carregador valida tipos, caminhos relativos, ids e limites; qualquer valor fora da política volta aos padrões embutidos. |
| 12 | **Concluído** — `Write-Progress` adicionado às rotinas longas do legado (`Optimize-Disk`, caches de navegadores/pacotes/aplicativos, `Disable-Services`, `Disable-Bloatware`), com conclusão explícita do progresso. |
| 17 | **Quase concluído** — `AutomationProperties.Name` em todos os `DataGrid`, `ScanWarnings`, `AppxBloatOnly` e `TabControl`; ordem de tabulação explícita (`TabIndex` 1–8) na navegação lateral; testes estáticos verificam a presença. Falta apenas ensaio manual com Narrador/NVDA, Alto Contraste do Windows e DPI variados. |
| 18 | **Concluído com limite de privacidade** — a seleção de categorias é restaurada após nova análise e gravada em `SelectedCategories` (schema 2). A pasta de destino é memorizada **apenas durante a sessão**; não é gravada em disco para não registrar caminhos do cliente. |
| 19 | **Concluído** — a janela de resultado detalhado ganhou filtro por categoria/caminho/status/detalhe (botão, Enter e limpar). A exportação CSV já havia sido restaurada na integração da bancada e permanece opcional, com aviso de privacidade. |

**Testes executados nesta rodada:** `Validate-Syntax.ps1`, `Core.Smoke.ps1` (50 verificações), `Preferences.Smoke.ps1`, `UI.UX.Smoke.ps1`, `Optimizer.Tests.ps1`, `Network.Smoke.ps1`, `Events.Smoke.ps1`, `Technician.Smoke.ps1`, PSScriptAnalyzer nos arquivos modificados e `Otimizador-GUI.ps1 -ValidateUI` com captura de prévia no Windows PowerShell 5.1. Todos passaram.

**Ainda bloqueado ou fora desta rodada:** item 10 (logs estruturados no legado), item 13 (assinatura Authenticode exige certificado), item 14 (Release real exige tag/push), item 23 (GIF exige gravação manual) e item 24 (i18n é decisão de produto). A validação manual de acessibilidade também continua pendente. Os módulos não rastreados `Optimizer.Privacy.psm1` e `Optimizer.Tweaks.psm1` não foram alterados por esta rodada.

---

## Preferências locais e leitura ampliada — rodada 4.5 (04/11/2026)

**Coordenação com agentes:** o commit `b716710` integrou o trabalho de rede/eventos na interface 4.4 e o CI da `main` está verde. Reservo a próxima evolução de **preferências locais e acessibilidade**. Alterarei `UI/MainWindow.xaml`, `Otimizador-GUI.ps1`, crierei `Modules/Optimizer.Preferences.psm1` e `Tests/Preferences.Smoke.ps1`, e atualizarei apenas CI/README/CHANGELOG e esta seção do `melhorias.md`. Não modificar `Modules/Optimizer.Core.psm1`, `Optimizer.NetworkDiagnostics.psm1`, `Optimizer.Events.psm1`, `Repair.Tools.ps1` ou lógica de remoção de aplicativos.

**Escopo planejado:** configurações não sensíveis em JSON local (somente opções de acessibilidade: texto ampliado e modo de alto contraste), validação rigorosa, gravação segura sem dados de clientes, escolha na interface e reaplicação ao iniciar. Não registrar nomes de usuário, caminhos de arquivos limpos, inventário, IPs, cliente/OS ou informações técnicas no arquivo. Preferências inválidas voltam ao padrão seguro.

**Testes:** cenários de padrões, arquivo ausente/inválido, validação de valores, persistência/releitura, privacidade e WPF com controles reais; sem tocar em configurações do Windows ou executar reparos. Não presumir que essas opções substituem ensaio manual com Narrador/NVDA ou certificação de acessibilidade.

**Status:** implementação concluída e publicada na `main`; os ajustes posteriores desta rodada estão descritos em 4.5.1, acima.

**Correção de execução (04/11/2026, branch `feature/v4-5-local-preferences`):** `Save-OptimizerPreferences` usava `[IO.File]::Replace($temporary, $fullPath, $null)`; no .NET Framework do Windows PowerShell 5.1 o backup nulo é inválido e a sobrescrita de preferências existentes falhava. Corrigido com backup em arquivo temporário (`.preferences-backup-*.tmp`). `Tests/Preferences.Smoke.ps1` agora passa em PS 5.1 (persistência, privacidade, valores inválidos e fallback).

---

## Experiência de uso e navegação — rodada 4.4 (04/11/2026)

**Coordenação para o outro agente:** a GUI integrada (PR #8) está na `main` e a frente Saúde/Drivers está publicada. Nesta rodada assumo somente `UI/MainWindow.xaml`, `Otimizador-GUI.ps1`, documentação/validações de apresentação. Se você iniciar edição desses arquivos, registre antes na issue #5 ou faça uma branch separada e rebase após este PR; não substitua a `main` sem reconciliar mudanças. Os módulos de Saúde, Rede, Eventos, Limpeza e drivers continuam sob a implementação existente.

**Problemas encontrados:** barra lateral é apenas texto, sem navegação clicável; bancada contém quatro ferramentas extensas em uma coluna, exigindo rolagem excessiva; vários controles não têm nome acessível; teste WPF verifica funcionamento mas não organização da navegação.

**Escopo:** barra lateral com navegação funcional e indicação de seção ativa; bancada organizada em quatro guias menores (Inventário, Rede, Histórico e Reparos), atalhos de teclado e rótulos de automação; testes WPF incluindo navegação e integridade dos controles. Não adicionar remoção de arquivos, downloads ou reparos automáticos.

**Situação: PUBLICADA NA MAIN** — [PR #9](https://github.com/leonccunha21/windows-pc-optimizer/pull/9), commit `29e67ef`. Barra lateral com sete atalhos reais, indicação da seção ativa e teclado `Ctrl+1`–`Ctrl+6`/`Ctrl+B`; Bancada dividida em quatro guias com rolagem independente; nomes acessíveis adicionados aos botões e textos secundários com contraste corrigido. Smoke test `Tests/UI.UX.Smoke.ps1` verifica XAML, nomes de automação, navegação e contrastes, além da validação WPF real no Windows. **CI do PR aprovado em Windows e Ubuntu (PS5.1/PS7).**

**Ainda pendente:** teste manual com leitor de tela (Narrador/NVDA), Windows Alto Contraste, diferentes monitores/DPIs e revisão de ergonomia por técnicos; não confundir a verificação estática de contraste com certificação integral WCAG. Assinatura de código, atualização automática e Release por tag permanecem não concluídos.

---

## Integração da bancada na interface unificada — 04/11/2026

**Frente responsável: integração WPF de módulos já publicados.** Foi confirmado que o outro agente concluiu a área Saúde/Drivers/UI e que `main` já tem bateria, SSD, drivers, aplicativos e botão Fechar. A versão WPF atual ainda não apresenta inventários técnicos (processos, inicialização, softwares, rede, atualizações, armazenamento), histórico de falhas, diagnóstico de rede e reparos em sua janela — embora os módulos autônomos estejam publicados.

**Escopo desta rodada:** integrar em `Manutenção → Bancada` os módulos existentes `Optimizer.Technician.psm1`, `Optimizer.NetworkDiagnostics.psm1`, `Optimizer.Events.psm1` e `Repair.Tools.ps1`; manter todas as abas Saúde e Manutenção existentes, sem copiar ou reescrever seus núcleos. Restaurar exportação CSV detalhada da limpeza, que estava ausente da GUI publicada. Validar navegação, execução assíncrona e acesso a controles pelo teste WPF.

**Arquivos alterados nesta frente:** `Otimizador-GUI.ps1`, `UI/MainWindow.xaml`, `melhorias.md` e documentação pontual. **Não alterar** `Modules/Optimizer.Core.psm1`, `Tests/Core.Smoke.ps1` ou outros módulos do agente. Novos botões de verificação e reparo usam confirmação + UAC; diagnósticos locais não modificam o Windows, consultas externas somente após confirmação.

**Status: CONCLUÍDO E INTEGRADO NA MAIN** — [PR #8](https://github.com/leonccunha21/windows-pc-optimizer/pull/8), commit `065b0429`. Inventários, rede, histórico de falhas e verificações SFC/DISM/CHKDSK conectados a **Manutenção → Bancada**, além de CSV na Limpeza. Integração de WPF com consulta real de processos e testes do núcleo passaram em Windows/Ubuntu e PowerShell 5.1; novos reparos elevados e testes externos **não foram executados automaticamente no CI**.

**Pendências da rodada:** validação visual manual em resoluções/DPI distintos; testes de execução elevada de cada ferramenta em bancada; avaliação de acessibilidade e temas de alto contraste; assinatura Authenticode e Release por tag em ambiente real. Coordenação também na issue #5.

---

## Coordenação: análise de falhas do Windows / Event Viewer — 04/11/2026

**Responsável: frente isolada de histórico de falhas.** Escopo reservado para não competir com Saúde/Drivers, otimizações e interface WPF do outro agente.

**Arquivos próprios (novos):**
- `Modules/Optimizer.Events.psm1` — leitura opcional do log **System** via `Get-WinEvent`, classificação de eventos de disco, WHEA, reinicialização inesperada, BugCheck, NTFS e falhas de serviços; sem mensagens brutas que possam conter dados pessoais.
- `Tools/Diagnostico-Eventos.ps1` e `Tools/Executar-Diagnostico-Eventos.bat` — execução independente com resultados locais.
- `Tests/Events.Smoke.ps1` — regras puras e agrupamentos testados sem acesso ao log real ou a dados pessoais.
- `docs/DIAGNOSTICO-EVENTOS.md` — manual técnico, limitações e instruções de integração futura.

**Arquivos compartilhados:** ajustar exclusivamente os testes em `.github/workflows/lint.yml` e `.github/workflows/release.yml`; atualizar esta seção do `melhorias.md` ao entregar. Nenhum arquivo de `Modules/Optimizer.Core.psm1`, `Otimizador-GUI.ps1`, `UI/MainWindow.xaml`, `Tests/Core.Smoke.ps1`, README ou CHANGELOG será alterado.

**Integração com a UI:** responsabilidade do agente de Saúde/Drivers. Preservar a bancada existente; após publicação deste módulo, ligar uma consulta explícita por botão, em runspace, sem transmissão de logs e sem ações de reparo automático. **Não afirmar integração na interface antes de implementada e testada.**

**Estado: ENTREGUE NA MAIN** — [PR #7](https://github.com/leonccunha21/windows-pc-optimizer/pull/7), commit `028a916d`. Testes de privacidade, classificação, limites, cancelamento e exportação validados via suíte sintética; CI verde em PS7 (Windows/Ubuntu), PS5.1 e WPF. Nenhuma rotina real de limpeza, exclusão ou reparo foi executada.

**Arquivos adicionais entregues:** `Tools/Executar-Diagnostico-Eventos.bat` para duplo clique; `Tools/Diagnostico-Eventos.ps1` com exportação JSON opcional. Empacotamento de Release já inclui a pasta `Tools`. O diagnóstico é um módulo autônomo, **não integrado à GUI ainda**.

**Próximo passo reservado à frente Saúde/Drivers/UI:** usar `Get-OptimizerEventSummary` em área "Histórico de falhas", com consulta somente após clique, renderizando `Categories`, `Warnings` e contagem. A integração não deve incluir mensagens originais, caminhos de arquivos nem reparo automático. Não recriar a classificação no núcleo principal.

---

## Coordenação: diagnóstico de rede independente — 04/11/2026

> **Recado ao agente de Saúde/Drivers/UI:** preserve a bancada técnica da `main` (Oficina Pro 4.2). Assumo uma frente separada de **diagnóstico de rede**; não alterarei os arquivos da interface, do núcleo principal ou dos testes existentes que você reservou. Quando sua interface estiver pronta, poderá integrar o módulo novo sob uma seção "Rede" sem recriar a lógica.

**Arquivos que vou criar (escopo exclusivo):**
- `Modules/Optimizer.NetworkDiagnostics.psm1`: consultas locais de adaptadores/IP/DNS/rotas, testes de conexão opcionais e funções puras para diagnóstico; sem reparo automático.
- `Tools/Diagnostico-Rede.ps1`: ferramenta de bancada independente, segura e executável em console.
- `Tests/Network.Smoke.ps1`: testes determinísticos/sem acesso à rede externa.
- `docs/DIAGNOSTICO-REDE.md`: manual, limitações e instrução de integração.

**Arquivo compartilhado:** `.github/workflows/lint.yml` (somente acrescentar teste); `melhorias.md` (coordenação e status).

**Não modificar por esta frente:** `Modules/Optimizer.Core.psm1`, `Otimizador-GUI.ps1`, `UI/MainWindow.xaml`, `Tests/Core.Smoke.ps1`, `Tests/Validate-Syntax.ps1`, `README.md`, `CHANGELOG.md`, nem os seus arquivos novos de Saúde/Drivers. **Não afirmar integração à GUI antes do seu handler estar realmente conectado.**

**Status: CONCLUÍDO nesta frente, publicado na main** — PR [#6](https://github.com/leonccunha21/windows-pc-optimizer/pull/6), commit `189dac16`. Testes aprovados no PowerShell 7 (Windows/Ubuntu), Windows PowerShell 5.1, lint e validação WPF. Sem mudança nos arquivos reservados de Saúde/Drivers/UI.

**Entregas adicionais:** iniciador de duplo clique `Tools/Executar-Diagnostico-Rede.bat`, ocultação de nomes de perfis de rede por padrão e inclusão da pasta `Tools` no workflow de release. Funções reais documentadas em `docs/DIAGNOSTICO-REDE.md`.

**Integração gráfica concluída (responsável: agente de Saúde/Drivers/UI):** aba **Rede** implementada na interface com botões **Analisar rede local** e **Testar conectividade**, handlers no runspace dedicado para `Get-OptimizerNetworkSnapshot` e `Invoke-OptimizerConnectivityCheck` e teste incluído no modo `-ValidateUI`. A aba não executa conexões externas sem destino explícito informado. Commit de integração sobre a `main`: `0c18c46`.

---

## Coordenação entre agentes — escopo assumido em 04/11/2026

> **Para o outro agente:** eu assumi a rodada "central completa em um só programa" descrita abaixo. Para evitar conflito, **não edite** os arquivos listados enquanto esta rodada não estiver publicada. Se precisar mexer neles, registre aqui e combine a ordem. Os demais arquivos continuam livres.

### Pedido do usuário

- Botão **X** para fechar a janela não aparece / não funciona.
- Interface fraca: só aparece limpeza, sem as ferramentas prometidas.
- Central completa: limpeza, drivers, atualizar drivers, saúde da bateria, saúde do HD/SSD, remoção de componentes não usados, otimização do Windows e rotinas de bancada.

### Escopo desta rodada

| Área | O que será entregue |
|---|---|
| Janela | Barra de título explícita + botão **Fechar** visível; fechar durante operação pergunta e encerra o runspace em vez de ignorar o clique |
| Núcleo | `Get-OptimizerBatteryHealth`, `ConvertFrom-OptimizerBatteryReportXml`, `Get-OptimizerHealthRating`, `Get-OptimizerDiskHealth`, `Get-OptimizerDrivers`, `Get-OptimizerDriverUpdates`, `Get-OptimizerAppInventory`, `Get-OptimizerBloatCatalog`, `Get-OptimizerOptimizations`, `Invoke-OptimizerOptimization`, `Save-OptimizerBatteryReport` |
| Interface | Novas abas **Saúde** e **Manutenção** (subabas Drivers, Aplicativos, Otimização, Atalhos), mantendo Limpeza, Diagnóstico e Relatório |
| Segurança | Toda ação que altera o sistema exige seleção explícita + confirmação; drivers apenas **consultados** (instalação continua no Windows Update); nada de automação silenciosa |
| Testes | Novos casos puros no `Core.Smoke.ps1`; `-ValidateUI` continua exercitando análise/limpeza descartável |
| Docs | README, CHANGELOG e este arquivo atualizados ao final |

### Arquivos que eu vou tocar

- `Modules/Optimizer.Core.psm1`
- `Otimizador-GUI.ps1`
- `UI/MainWindow.xaml`
- `Tests/Core.Smoke.ps1`
- `Tests/Validate-Syntax.ps1` (somente se necessário)
- `README.md`, `CHANGELOG.md`, `melhorias.md`

### Fora de escopo / não farei

- Copiar código do WinScript (GPL-3.0) para este projeto MIT. Uso apenas as **ideias** de categorias (debloat, drivers, SFC/DISM, planos de energia), reimplementadas.
- Executar `winscript-portable.exe` ou publicar `Repositorios-Github`.
- Instalar drivers automaticamente, mexer em serviços do Windows ou alterar Registro sem confirmação.
- Reativar `-Auto`, `-AutoPush`, `-Schedule` ou self-update.

### Ordem de implementação

1. Núcleo com funções de diagnóstico e helpers puros.
2. Testes puros (bateria, classificação, catálogo de bloat, otimizações).
3. XAML com as novas abas e o botão Fechar.
4. Handlers assíncronos na GUI.
5. Validação PS 5.1, PS 7, WPF e lint; commit e push.

> Status: **concluído em 04/11/2026** — entregas do botão Fechar, aba Saúde e aba Manutenção implementadas e publicadas junto com o commit de merge em `main`.

---

## Execução do backlog 4.0.1

| Item | Situação após implementação |
|---|---|
| P0 1–5 | **Concluído**: menu, CHANGELOG, atualização/Git automáticos desativados, HTML escapado, administrador exigido somente no console legado |
| P1 6 | **Concluído**: job `lint` bloqueante no CI com PSScriptAnalyzer |
| P1 7 | **Parcial**: 50 verificações, incluindo config e perfil de navegador; cenários WMI/bateria ausente seguem pendentes |
| P1 8 | **Concluído**: `[CmdletBinding()]` em todo o núcleo e comment-based help nas funções principais |
| P1 9 | **Concluído**: `config/optimizer.psd1` com validação e fallback seguro |
| P1 10 | **Pendente**: logs legados estruturados |
| P1 11 | **Concluído**: relatório HTML válido e JSON opcional sem caminhos de arquivos excluídos |
| P1 12 | **Concluído**: `Write-Progress` nas rotinas longas do console antigo |
| P2 13 | **Pendente**: assinatura Authenticode e gestão de certificados |
| P2 14 | **Preparado**: workflow de tag gera ZIP e SHA-256; execução de Release real ainda não validada |
| P2 15–16 | **Concluído**: `-Auto`, `-AutoPush` e `-Schedule` bloqueados; política `SECURITY.md` incluída |
| P3 17 | **Parcial**: nomes de automação e tabulação concluídos; validação manual com leitor de tela/DPI pendente |
| P3 18 | **Concluído com limite**: seleção de categorias lembrada; pasta de destino apenas na sessão |
| P3 19 | **Concluído**: resultado detalhado com filtro e exportação CSV opcional |
| P3 20 | **Concluído**: progresso de arquivos processados na limpeza; análise permanece indeterminada |
| P4 21–22 | **Concluído**: documentação de arquitetura, templates de issue e PR |
| P4 23–24 | **Pendente**: GIF de demonstração e tradução, caso necessário |

**Próxima prioridade:** logs estruturados no legado, assinatura Authenticode/Release por tag e validação manual de acessibilidade. Não habilitar operações destrutivas legadas para atingir paridade artificial com CCleaner.

---

## Validação complementar: portabilidade e distribuição

- O smoke test agora cria um perfil temporário quando `LOCALAPPDATA` não existe (Linux), evitando dependência do computador do executor.
- O núcleo devolve uma lista vazia de alvos se `LOCALAPPDATA` estiver ausente.
- Workflow de release por tag `v*` preparado para gerar ZIP e arquivo SHA-256 após validação. **Execução real por tag não testada** e nenhuma assinatura digital incluída.

---

## Diagnóstico histórico da v4.0 (preservado para auditoria)

| Item anterior | Situação |
|---|---|
| ~255 definições duplicadas | **Resolvido** — 72 funções, 72 nomes únicos, zero duplicatas |
| GUI síncrona / congelando | **Resolvido** — runspace separado + `DispatcherTimer` + cancelamento cooperativo |
| Relatório HTML sem escape | **Resolvido** — `WebUtility::HtmlEncode` no núcleo e no relatório legado |
| Testes só verificavam existência | **Melhorado** — 34 verificações de segurança com arquivos descartáveis, links, retenção, expiração, cancelamento e exportação HTML/JSON |
| CI sem matriz | **Resolvido** — Ubuntu/Windows, Windows PowerShell 5.1, WPF real e PSScriptAnalyzer bloqueante |
| Exigir admin para abrir a interface | **Resolvido** — BAT abre a UI sem elevação; console legado exige `-Legacy` |
| Docs desalinhadas | **Resolvido** — README, LEIA-ME, CONTRIBUTING, SECURITY e ARQUITETURA alinhados à 4.x |

O projeto passou de um script monolítico para núcleo e interface WPF. As observações seguintes descrevem o diagnóstico da v4.0 e podem estar superadas; **a tabela de execução acima é a referência atual**.

### Correções aplicadas nesta rodada

- Menu legado sem a opção "23" duplicada.
- `CHANGELOG.md` migrado para Keep a Changelog, com a 4.0.1 documentada.
- Atualização automática de código e publicação Git automática **desativadas** no console legado; `-Auto` e `-AutoPush` bloqueados.
- `Generate-Report` escapa CPU, SO, modo e log com `WebUtility::HtmlEncode`.
- Checagem de administrador mantida apenas no ponto de entrada do legado, após validar `-Legacy`; `-LoadOnly` não exige elevação.
- `Set-Pagefile` migrado de `Get-WmiObject` para CIM, mantendo fallback via `reg add`.
- `Remove-Safe` usa `try/catch`, não reporta remoção falsa e suporta `-WhatIf`.
- `Remove-Safe`, `New-RestorePoint` e `Set-Pagefile` receberam `[CmdletBinding(SupportsShouldProcess)]`.
- 13 blocos `catch {}` vazios passaram a registrar `Write-Log`/`Write-Verbose`.
- `$profile` renomeado para `$profileDir` no núcleo; parâmetros `$sender`/`$eventArgs` renomeados na GUI.
- Criado `PSScriptAnalyzerSettings.psd1`; job `lint` bloqueante adicionado ao CI.
- Suíte do núcleo ampliada para 34 verificações (formatação, soma de bytes, alvos padrão, HTML/JSON e relatório sem limpeza).
- Relatório JSON local, seleção em massa, resultado detalhado, progresso por arquivo e atalhos F5/Esc/Ctrl+E na interface.
- Criados `SECURITY.md`, `docs/ARQUITETURA.md` e templates de issue/PR.


---

## P0 — Correções rápidas (concluído)

### 1. ~~Remover a linha duplicada "23" do menu legado~~ — **Resolvido**

A opção "23. Ferramentas externas recomendadas" aparecia duas vezes. A duplicata foi removida; o menu tem 48 opções únicas.

### 2. ~~Reestruturar o `CHANGELOG.md`~~ — **Resolvido**

O arquivo agora segue Keep a Changelog: título `# Changelog`, entradas `## [4.0.1] - 2026-11-04` e `## [4.0.0] - 2026-11-04` com seções `### Added`/`### Changed`/`### Fixed`.

### 3. ~~Endurecer `Invoke-SelfUpdate` e `Push-ToGitHub`~~ — **Resolvido**

- `Invoke-SelfUpdate` e `Push-ToGitHub` foram **desativados** no legado: apenas registram um aviso e apontam para revisão manual.
- `-Auto` e `-AutoPush` agora lançam erro explícito, impedindo manutenção/publicação sem revisão.
- A UI 4.0 não chama nenhuma dessas rotinas; atualização e publicação continuam manuais via Git.

### 4. ~~Escapar o log no `Generate-Report` legado~~ — **Resolvido**

CPU, SO, modo e log agora passam por `[System.Net.WebUtility]::HtmlEncode` antes de entrar no HTML.

### 5. ~~Decidir o destino do `#Requires -RunAsAdministrator`~~ — **Resolvido**

O `#Requires` foi removido. A checagem de administrador ocorre após o `param` e é ignorada com `-LoadOnly`, permitindo dot-sourcing para testes e ferramentas.


---

## P1 — Núcleo, testes e qualidade

### 6. ~~Reintroduzir o PSScriptAnalyzer no CI~~ — **Resolvido**

`PSScriptAnalyzerSettings.psd1` foi criado e o job `lint` (bloqueante) roda no CI antes do job `safety`. Resultado local: **0 findings**.

Regras desativadas com justificativa: verbos/substantivos de domínio, `Write-Host` no console interativo, `Write-Log` do projeto, `ShouldProcess` em helpers e parâmetros globais do legado.

### 7. Ampliar a cobertura do núcleo — **Parcialmente resolvido**

Já cobertos (50 verificações no total):

- `Format-OptimizerSize` (B, KB, MB, GB e zero).
- `Get-OptimizerByteSum` (lista vazia, soma e propriedade ausente).
- `Get-OptimizerTargets` (pasta Temp, descoberta de perfil Chrome e subpastas de cache vindas da configuração).
- `Get-OptimizerConfiguration` (arquivo embarcado, configuração customizada e fallback seguro).
- `Export-OptimizerReport` sem limpeza, com `<head>`/`<body>`, acentos escapados e exportação JSON sem caminhos privados.

Ainda faltam casos para `Get-OptimizerDiagnostics` (WMI indisponível, bateria ausente, Defender desligado).


### 8. ~~Padronizar `[CmdletBinding()]` e help no núcleo~~ — **Resolvido**

Todas as funções do núcleo têm `[CmdletBinding()]`. Comment-based help foi adicionado a `Get-OptimizerTargets`, `Test-OptimizerPath`, `Get-OptimizerScan`, `Get-OptimizerDiagnostics`, `Export-OptimizerReport` e ao carregador `Get-OptimizerConfiguration`. No legado, 3 funções destrutivas usam `[CmdletBinding(SupportsShouldProcess)]`.

### 9. ~~Externalizar configuração~~ — **Resolvido**

`config/optimizer.psd1` concentra navegadores, subpastas de cache, extensões protegidas, pastas protegidas, marcadores de projeto e retenção mínima. `Get-OptimizerConfiguration` valida o arquivo e volta aos padrões embutidos se ele estiver ausente, malformado ou fora da política (retenção < 7 dias, caminho absoluto, `..`, id inválido ou lista vazia).

### 10. Logs estruturados no legado

O núcleo não grava log persistente (bom para privacidade). O legado ainda usa um único `%TEMP%\OtimizadorPC_log.txt` sem rotação.

**Ação (se o legado continuar):** JSON Lines com `timestamp`, `level`, `function`, `target`, `result`; rotação por tamanho; nunca logar caminhos pessoais.

### 11. ~~Relatório: `<head>` e exportação JSON~~ — **Resolvido**

O HTML agora tem `<head>`/`<body>` válidos, CSS de impressão e escape de acentos. A interface exporta também JSON, sem serializar caminhos pessoais. Falta apenas um botão explícito "Imprimir" no HTML.

### 12. ~~`Write-Progress` no legado~~ — **Resolvido**

A UI mantém progresso real na limpeza. O console legado agora usa `Write-Progress` com contadores e conclusão explícita em `Optimize-Disk`, `Clean-BrowserCaches`, `Clean-PackageCaches`, `Clean-AppCaches`, `Disable-Services` e `Disable-Bloatware`.

---

## P2 — Segurança e distribuição

### 13. Assinatura de código e integridade

- Assinar `.ps1`/`.psm1`/`.bat` com Authenticode (reduz falso positivo de antivírus).
- Publicar `.zip` com SHA-256 no GitHub Release.
- O self-update foi desativado; a validação de hash deixa de ser necessária no produto.

### 14. Workflow de release

Hoje o CI só valida. Falta um workflow de tag que:
1. rode os testes;
2. gere o ZIP com `Modules/` e `UI/`;
3. calcule SHA-256;
4. publique o GitHub Release com notas do CHANGELOG.

### 15. ~~Revisar o legado `-Auto`~~ — **Resolvido**

`-Auto`, `-AutoPush` e `-Schedule` agora lançam erro explícito, e a função de agendamento apenas registra um aviso. O README e o CHANGELOG orientam a usar a interface 4.0 com análise e confirmação.

### 16. ~~`SECURITY.md`~~ — **Resolvido**

Criado com política de relato privado, escopo, limites de segurança e orientação sobre relatórios com dados de clientes.

---

## P3 — Interface (WPF)

### 17. Acessibilidade — **Parcialmente resolvido**

Já implementado:
- atalhos F5 (analisar), Esc (interromper) e Ctrl+E (exportar);
- `AutomationProperties.Name` em botões, grids, avisos, abas e caixa de seleção de sugestões;
- ordem de tabulação explícita (`TabIndex` 1–8) na navegação lateral;
- preferências de alto contraste e escala de texto aplicadas dinamicamente.

Ainda falta: ensaio manual com Narrador/NVDA, Alto Contraste do Windows e monitores/DPI variados. A verificação estática não equivale a certificação WCAG.

### 18. Seleção em massa e memória de preferências — **Resolvido com limite**

- Botões "Selecionar tudo/desmarcar tudo" implementados.
- Categorias mostram contagem e bytes antes de limpar.
- A seleção de categorias é restaurada após nova análise e gravada em `SelectedCategories` (schema 2).
- A última pasta de destino dos relatórios é memorizada **somente durante a sessão**; não vai para disco para não registrar caminhos do cliente.

### 19. ~~Resultado detalhado na UI~~ — **Resolvido**

A janela "Prévia / resultado" exibe removidos e ignorados com categoria, status, bytes e detalhe, agora com filtro por texto (botão, Enter e limpar). A exportação CSV continua opcional e avisa que inclui caminhos.

### 20. ~~Progresso real~~ — **Resolvido**

A limpeza reporta `arquivos processados / total` em tempo real. A análise continua com barra indeterminada, o que é adequado porque o total só é conhecido ao final.

---

## P4 — Documentação e comunidade

### 21. ~~`docs/ARQUITETURA.md`~~ — **Resolvido**

Documento criado com componentes, fluxo principal e modelo de ameaças.

### 22. ~~Templates de issue/PR~~ — **Resolvido**

Criados `.github/ISSUE_TEMPLATE/bug.yml`, `feature.yml` e `PULL_REQUEST_TEMPLATE.md` com o checklist de segurança.

### 23. Capturas e GIF

O README já tem `docs/preview.png`. Um GIF curto do fluxo (analisar → revisar → limpar → relatório) reduz dúvidas de uso.

### 24. Internacionalização

Hoje a UI é PT-BR e o código mistura inglês/português. Se houver planos de distribuição internacional, extrair strings para `pt-BR.psd1`/`en-US.psd1`.

---

## O que NÃO fazer (anti-roadmap)

- Não trazer de volta ajustes de Registro, serviços, pagefile ou rede para a UI 4.0 — o README promete que a interface não faz isso.
- Não misturar o legado `Otimizar-PC.ps1` com `Optimizer.Core.psm1`.
- Não adicionar telemetria, conta ou envio de dados.
- Não adotar dependências web/pesadas do catálogo `Repositorios-Github`.

---

## Do catálogo `Repositorios-Github`

Nenhum item é dependência do produto. Apenas dois ajudam no **desenvolvimento**:

- **Gitingest (#84)** — empacotar o repositório para revisão/refactor com IA.
- **Ponytail (#18)** — regras anti-overengineering para agentes, com suporte a OpenCode.

O restante é de outro domínio (agentes, social, web) ou já está marcado como "não usar".

---

## Roadmap sugerido

| Etapa | Escopo | Entrega | Status |
|---|---|---|---|
| 1 | P0 (itens 1–5) | Menu sem duplicata, CHANGELOG padronizado, legado sem self-update inseguro, relatório legado escapado | **Concluído** |
| 2 | P1 (itens 6–12) | PSScriptAnalyzer no CI, cobertura extra, config externa, relatório com `<head>`/JSON | 6, 8, 9, 11 e 12 concluídos; 7 ampliado; 10 pendente |
| 3 | P2 (itens 13–16) | Release assinado, workflow de tag, `-Auto` revisado, `SECURITY.md` | 15 e 16 concluídos; 13 e 14 pendentes |
| 4 | P3/P4 (itens 17–24) | Acessibilidade, seleção em massa, progresso real, docs de arquitetura e templates | 18, 19, 20, 21 e 22 concluídos; 17 parcial; 23 e 24 pendentes |

---

## Critérios de aceite

- [x] `Tests/Validate-Syntax.ps1` continua detectando zero duplicatas.
- [x] `Tests/Core.Smoke.ps1` verde em Windows PowerShell 5.1 e PowerShell 7 (50 verificações).
- [x] `config/optimizer.psd1` validado com fallback seguro para valores fora da política.
- [x] PSScriptAnalyzer sem Warning/Error com as settings do repo.
- [x] Menu legado sem opções repetidas.
- [x] CHANGELOG com a 4.0.1 no formato Keep a Changelog.
- [x] Relatório do legado escapa o log (ou o gerador legado é removido).
- [x] Self-update foi desativado no legado e não sobrescreve nenhum código.
- [ ] Publicação de Release real com ZIP + SHA-256 validada (workflow preparado).
- [ ] Validação manual de acessibilidade (leitor de tela, Alto Contraste e DPI).

---

## Anexo — evidências atuais

| Evidência | Valor |
|---|---|
| Linhas de `Otimizar-PC.ps1` | 1.535 |
| Definições `function` no legado | 72 |
| Nomes únicos | 72 |
| Duplicatas | 0 |
| Linhas de `Optimizer.Core.psm1` | 790 |
| Funções de `Optimizer.Core.psm1` | 25 |
| `[CmdletBinding()]` no núcleo | 21 de 25 funções |
| `[CmdletBinding()]` no legado | 3 (rotinas destrutivas) |
| `Write-Progress` no legado | 12 ocorrências em 6 rotinas longas |
| Opções do menu legado | 48 (sem duplicatas) |
| Verificações em `Core.Smoke.ps1` | 50 |
| Abas da UI 4.5 | 7 (Visão geral, Limpeza, Diagnóstico, Saúde, Manutenção, Relatório, Preferências) |
| Configuração externa | `config/optimizer.psd1` com validação e fallback |
| PSScriptAnalyzer no CI | job `lint` bloqueante |
| Matriz do CI | Ubuntu + Windows; PS 5.1; validação WPF |
