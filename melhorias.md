# Melhorias recomendadas — PC Optimizer

> Atualizado em 04/11/2026 após integrar a branch `feature/harden-maintenance-backlog` (v4.0.1).
> Base: `Otimizar-PC.ps1` (legado, 1.535 linhas), `Modules/Optimizer.Core.psm1` e `Otimizador-GUI.ps1`.

---

## Status: o que a v4.0 já resolveu

| Item anterior | Situação |
|---|---|
| ~255 definições duplicadas | **Resolvido** — 72 funções, 72 nomes únicos, zero duplicatas |
| GUI síncrona / congelando | **Resolvido** — runspace separado + `DispatcherTimer` + cancelamento cooperativo |
| Relatório HTML sem escape | **Resolvido** — `WebUtility::HtmlEncode` no núcleo e no relatório legado |
| Testes só verificavam existência | **Melhorado** — 34 verificações de segurança com arquivos descartáveis, links, retenção, expiração, cancelamento e exportação HTML/JSON |
| CI sem matriz | **Resolvido** — Ubuntu/Windows, Windows PowerShell 5.1, WPF real e PSScriptAnalyzer bloqueante |
| Exigir admin para abrir a interface | **Resolvido** — BAT abre a UI sem elevação; console legado exige `-Legacy` |
| Docs desalinhadas | **Resolvido** — README, LEIA-ME, CONTRIBUTING, SECURITY e ARQUITETURA alinhados à 4.x |

O projeto mudou de "script gigante" para uma arquitetura com núcleo separado e interface WPF. O backlog abaixo é o que **ainda** vale implementar.

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

Já cobertos (34 verificações no total):

- `Format-OptimizerSize` (B, KB, MB, GB e zero).
- `Get-OptimizerByteSum` (lista vazia, soma e propriedade ausente).
- `Get-OptimizerTargets` (inclui a pasta Temp do usuário).
- `Export-OptimizerReport` sem limpeza, com `<head>`/`<body>`, acentos escapados e exportação JSON sem caminhos privados.

Ainda faltam casos para `Get-OptimizerDiagnostics` (WMI indisponível, bateria ausente, Defender desligado) e para perfis `Default`/`Profile N` com navegador ausente.


### 8. Padronizar `[CmdletBinding()]` e help no núcleo — **Parcialmente resolvido**

Sete das oito funções do núcleo já têm `[CmdletBinding()]`; falta apenas o helper interno `Get-OptimizerByteSum`. No legado, 3 funções destrutivas usam `[CmdletBinding(SupportsShouldProcess)]`.

**Ação restante:** adicionar comment-based help em `Get-OptimizerScan`, `Get-OptimizerTargets`, `Test-OptimizerPath`, `Export-OptimizerReport` e `Get-OptimizerDiagnostics`.

### 9. Externalizar configuração

`Get-OptimizerTargets` fixa Temp + Chrome/Edge/Brave; as extensões preservadas e os marcadores de projeto estão no código.

**Ação:** mover para `config/optimizer.psd1`:
- navegadores e subpastas de cache;
- extensões protegidas;
- marcadores de projeto (`.git`, `package.json`, ...);
- retenção mínima (hoje travada em 7 dias).

Isso permite ajustar sem editar o módulo e facilita testar.

### 10. Logs estruturados no legado

O núcleo não grava log persistente (bom para privacidade). O legado ainda usa um único `%TEMP%\OtimizadorPC_log.txt` sem rotação.

**Ação (se o legado continuar):** JSON Lines com `timestamp`, `level`, `function`, `target`, `result`; rotação por tamanho; nunca logar caminhos pessoais.

### 11. ~~Relatório: `<head>` e exportação JSON~~ — **Resolvido**

O HTML agora tem `<head>`/`<body>` válidos, CSS de impressão e escape de acentos. A interface exporta também JSON, sem serializar caminhos pessoais. Falta apenas um botão explícito "Imprimir" no HTML.

### 12. `Write-Progress` no legado

A UI já tem progresso real na limpeza. O legado continua com **0** ocorrências de `Write-Progress`; SFC/DISM/Defender no console ficam sem feedback por muito tempo.

**Ação (somente se o legado continuar):** adicionar `Write-Progress` nas rotinas longas do console.

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
- `AutomationProperties.Name` nos botões principais, de limpeza, cancelamento e seleção em massa.

Ainda faltam:
- `AutomationProperties.Name` nos grids e campos restantes;
- ordem de tabulação explícita;
- tema de alto contraste validado em bancada.

### 18. Seleção em massa e memória de preferências — **Parcialmente resolvido**

- Botões "Selecionar tudo/desmarcar tudo" implementados.
- Categorias já mostram contagem e bytes antes de limpar.
- Ainda falta lembrar a última seleção e a última pasta de relatório.

### 19. Resultado detalhado na UI — **Parcialmente resolvido**

A janela "Prévia / resultado" agora exibe removidos e ignorados com categoria, status, bytes e detalhe. Ainda faltam filtro e exportação CSV.

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
| 2 | P1 (itens 6–12) | PSScriptAnalyzer no CI, cobertura extra, config externa, relatório com `<head>`/JSON | 6, 7 e 11 concluídos; 8 parcial; 9, 10 e 12 pendentes |
| 3 | P2 (itens 13–16) | Release assinado, workflow de tag, `-Auto` revisado, `SECURITY.md` | 15 e 16 concluídos; 13 e 14 pendentes |
| 4 | P3/P4 (itens 17–24) | Acessibilidade, seleção em massa, progresso real, docs de arquitetura e templates | 20, 21 e 22 concluídos; 17–19 parciais; 23 e 24 pendentes |

---

## Critérios de aceite

- [x] `Tests/Validate-Syntax.ps1` continua detectando zero duplicatas.
- [x] `Tests/Core.Smoke.ps1` verde em Windows PowerShell 5.1 e PowerShell 7 (34 verificações).
- [x] PSScriptAnalyzer sem Warning/Error com as settings do repo.
- [x] Menu legado sem opções repetidas.
- [x] CHANGELOG com a 4.0.1 no formato Keep a Changelog.
- [x] Relatório do legado escapa o log (ou o gerador legado é removido).
- [x] Self-update não sobrescreve sem validar versão/checksum.
- [ ] Release publica ZIP + SHA-256.

---

## Anexo — evidências (atualizado)

| Evidência | Valor |
|---|---|
| Linhas de `Otimizar-PC.ps1` | 1.535 |
| Definições `function` no legado | 72 |
| Nomes únicos | 72 |
| Duplicatas | 0 |
| Linhas de `Optimizer.Core.psm1` | 215 |
| `[CmdletBinding()]` no núcleo | 7 de 8 funções |
| `[CmdletBinding()]` no legado | 3 (rotinas destrutivas) |
| `Write-Progress` no legado | 0 |
| Opções do menu legado | 48 (sem duplicatas) |
| Verificações em `Core.Smoke.ps1` | 34 |
| Abas da UI 4.0 | 5 (Visão geral, Limpeza, Diagnóstico, Ferramentas, Relatório) |
| PSScriptAnalyzer no CI | job `lint` bloqueante |
| Matriz do CI | Ubuntu + Windows; PS 5.1; validação WPF |
