# Melhorias recomendadas — PC Optimizer

> Atualizado em 04/11/2026 após a rodada de correções da **v4.0** (commit `232b4ba` + alterações locais).
> Base: `Otimizar-PC.ps1` (legado, 1.585 linhas), `Modules/Optimizer.Core.psm1` e `Otimizador-GUI.ps1`.

---

## Status: o que a v4.0 já resolveu

| Item anterior | Situação |
|---|---|
| ~255 definições duplicadas | **Resolvido** — 72 funções, 72 nomes únicos, zero duplicatas |
| GUI síncrona / congelando | **Resolvido** — runspace separado + `DispatcherTimer` + cancelamento cooperativo |
| Relatório HTML sem escape | **Resolvido** — `WebUtility::HtmlEncode` no núcleo e no relatório legado |
| Testes só verificavam existência | **Melhorado** — 30 verificações de segurança com arquivos descartáveis, links, retenção, expiração e cancelamento |
| CI sem matriz | **Resolvido** — Ubuntu/Windows, Windows PowerShell 5.1, WPF real e PSScriptAnalyzer bloqueante |
| Exigir admin para abrir a interface | **Resolvido** — BAT abre a UI sem elevação; console legado exige `-Legacy` |
| Docs desalinhadas | **Resolvido** — README, LEIA-ME e CONTRIBUTING reescritos para a 4.0 |

O projeto mudou de "script gigante" para uma arquitetura com núcleo separado e interface WPF. O backlog abaixo é o que **ainda** vale implementar.

### Correções aplicadas nesta rodada

- Menu legado sem a opção "23" duplicada.
- `CHANGELOG.md` migrado para Keep a Changelog, com a 4.0 sob `## [4.0.0]`.
- `Invoke-SelfUpdate` compara versões, baixa para arquivo temporário, exige confirmação e não substitui o script em `-Auto`/`-Silent`.
- `Push-ToGitHub` usa `git add -u`, lista arquivos não rastreados, respeita a identidade configurada e pede confirmação.
- `Generate-Report` escapa CPU, SO, modo e log com `WebUtility::HtmlEncode`.
- Checagem de administrador movida para depois do `param` e ignorada em `-LoadOnly`; `#Requires -RunAsAdministrator` removido.
- `Set-Pagefile` migrado de `Get-WmiObject` para CIM, mantendo fallback via `reg add`.
- `Remove-Safe` usa `try/catch`, não reporta remoção falsa e suporta `-WhatIf`.
- `New-RestorePoint`, `Set-Pagefile`, `Invoke-SelfUpdate` e `Push-ToGitHub` receberam `[CmdletBinding(SupportsShouldProcess)]`.
- 13 blocos `catch {}` vazios passaram a registrar `Write-Log`/`Write-Verbose`.
- `$profile` renomeado para `$profileDir` no núcleo; parâmetros `$sender`/`$eventArgs` renomeados na GUI.
- Criado `PSScriptAnalyzerSettings.psd1`; job `lint` bloqueante adicionado ao CI.
- Suíte do núcleo ampliada para 30 verificações (formatação, soma de bytes, alvos padrão e relatório sem limpeza).


---

## P0 — Correções rápidas (concluído)

### 1. ~~Remover a linha duplicada "23" do menu legado~~ — **Resolvido**

A opção "23. Ferramentas externas recomendadas" aparecia duas vezes. A duplicata foi removida; o menu tem 48 opções únicas.

### 2. ~~Reestruturar o `CHANGELOG.md`~~ — **Resolvido**

O arquivo agora segue Keep a Changelog: título `# Changelog`, entrada `## [4.0.0] - 2026-11-04` e seções `### Added`/`### Changed`.

### 3. ~~Endurecer `Invoke-SelfUpdate` e `Push-ToGitHub`~~ — **Resolvido**

- `Invoke-SelfUpdate` compara `$Version` local com a remota, baixa para `.new`, grava backup `.bak`, exige confirmação e não substitui o script em `-Auto`/`-Silent`.
- `Push-ToGitHub` usa `git add -u`, avisa sobre arquivos não rastreados, não fixa identidade e exige confirmação antes de commit/push.
- As rotinas continuam no legado por compatibilidade; a UI 4.0 não as usa.

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

Já cobertos (30 verificações no total):

- `Format-OptimizerSize` (zero, MB, GB).
- `Get-OptimizerByteSum` (lista vazia e soma).
- `Get-OptimizerTargets` (inclui a pasta Temp do usuário).
- `Export-OptimizerReport` sem limpeza (`Cleanup = $null`).

Ainda faltam casos para `Get-OptimizerDiagnostics` (WMI indisponível, bateria ausente, Defender desligado) e para perfis `Default`/`Profile N` com navegador ausente.


### 8. Padronizar `[CmdletBinding()]` e help no núcleo

`Optimizer.Core.psm1` tem apenas **1** `[CmdletBinding()]` (em `Invoke-OptimizerCleanup`). As demais funções não têm `-Verbose`, `-Debug` nem help. No legado, 5 funções destrutivas já receberam `[CmdletBinding(SupportsShouldProcess)]`.

**Ação:** adicionar `[CmdletBinding()]` e comment-based help em `Get-OptimizerScan`, `Get-OptimizerTargets`, `Test-OptimizerPath`, `Export-OptimizerReport` e `Get-OptimizerDiagnostics`.

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

### 11. Relatório: `<head>` e exportação JSON

`Export-OptimizerReport` já tem `lang="pt-BR"` e escape, mas o `<meta charset>` está solto sob `<html>`, sem `<head>`.

**Ação:**
- Envolver em `<head>`/`<body>` válidos.
- Adicionar CSS de impressão e botão "Imprimir".
- Exportar JSON ao lado do HTML para automação/arquivo.

### 12. `Write-Progress` no legado

Há **0** ocorrências de `Write-Progress` em todo o projeto. SFC/DISM/Defender no console ficam sem feedback por muito tempo.

**Ação:** adicionar `Write-Progress` nas rotinas longas do legado (a UI já tem barra indeterminada).

---

## P2 — Segurança e distribuição

### 13. Assinatura de código e integridade

- Assinar `.ps1`/`.psm1`/`.bat` com Authenticode (reduz falso positivo de antivírus).
- Publicar `.zip` com SHA-256 no GitHub Release.
- Se o self-update sobreviver, validar esse hash.

### 14. Workflow de release

Hoje o CI só valida. Falta um workflow de tag que:
1. rode os testes;
2. gere o ZIP com `Modules/` e `UI/`;
3. calcule SHA-256;
4. publique o GitHub Release com notas do CHANGELOG.

### 15. Revisar o legado `-Auto`

O README já avisa que `-Auto` não é para manutenção rotineira. Ainda assim, ele executa mudanças de serviços, pagefile e limpeza de logs.

**Ação:** exigir confirmação adicional, limitar a um conjunto seguro ou marcar como deprecated com data de remoção.

### 16. `SECURITY.md`

Adicionar política de relato de vulnerabilidades e escopo (ex.: limpeza não é fronteira de segurança contra processo malicioso — já está em `docs/VALIDACAO.md`).

---

## P3 — Interface (WPF)

### 17. Acessibilidade

`docs/VALIDACAO.md` já prevê teste manual com leitores de tela. Faltam no XAML:
- `AutomationProperties.Name` nos botões e grids;
- ordem de tabulação explícita;
- tema de alto contraste;
- atalhos de teclado (F5 analisar, Esc cancelar, Ctrl+E exportar).

### 18. Seleção em massa e memória de preferências

- Botões "Selecionar tudo/nenhum" para categorias.
- Lembrar última seleção e última pasta de relatório.
- Mostrar contagem/bytes por categoria antes de limpar.

### 19. Resultado detalhado na UI

Hoje a UI mostra apenas os itens ignorados (até 30). Exibir também removidos, com filtro e exportação CSV.

### 20. Progresso real

A barra é indeterminada. Com a lista de arquivos já conhecida, é possível reportar `arquivos processados / total` e bytes liberados em tempo real.

---

## P4 — Documentação e comunidade

### 21. `docs/ARQUITETURA.md`

Explicar a separação núcleo × UI × legado, o fluxo análise → confirmação → limpeza e o modelo de ameaças.

### 22. Templates de issue/PR

Adicionar `.github/ISSUE_TEMPLATE/bug.yml`, `feature.yml` e `PULL_REQUEST_TEMPLATE.md` com o checklist de segurança do `CONTRIBUTING.md`.

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
| 2 | P1 (itens 6–12) | PSScriptAnalyzer no CI, cobertura extra, config externa, relatório com `<head>`/JSON | Itens 6–7 feitos; 8–12 pendentes |
| 3 | P2 (itens 13–16) | Release assinado, workflow de tag, `-Auto` revisado, `SECURITY.md` | Pendente |
| 4 | P3/P4 (itens 17–24) | Acessibilidade, seleção em massa, progresso real, docs de arquitetura e templates | Pendente |

---

## Critérios de aceite

- [x] `Tests/Validate-Syntax.ps1` continua detectando zero duplicatas.
- [x] `Tests/Core.Smoke.ps1` verde em Windows PowerShell 5.1 e PowerShell 7 (30 verificações).
- [x] PSScriptAnalyzer sem Warning/Error com as settings do repo.
- [x] Menu legado sem opções repetidas.
- [x] CHANGELOG com a 4.0 no formato Keep a Changelog.
- [x] Relatório do legado escapa o log (ou o gerador legado é removido).
- [x] Self-update não sobrescreve sem validar versão/checksum.
- [ ] Release publica ZIP + SHA-256.

---

## Anexo — evidências (atualizado)

| Evidência | Valor |
|---|---|
| Linhas de `Otimizar-PC.ps1` | 1.585 |
| Definições `function` no legado | 72 |
| Nomes únicos | 72 |
| Duplicatas | 0 |
| Linhas de `Optimizer.Core.psm1` | 179 |
| `[CmdletBinding()]` no núcleo | 1 (`Invoke-OptimizerCleanup`) |
| `[CmdletBinding()]` no legado | 5 (rotinas destrutivas) |
| `Write-Progress` no projeto | 0 |
| Opções do menu legado | 48 (sem duplicatas) |
| Verificações em `Core.Smoke.ps1` | 30 |
| Abas da UI 4.0 | 5 (Visão geral, Limpeza, Diagnóstico, Ferramentas, Relatório) |
| PSScriptAnalyzer no CI | job `lint` bloqueante |
| Matriz do CI | Ubuntu + Windows; PS 5.1; validação WPF |
