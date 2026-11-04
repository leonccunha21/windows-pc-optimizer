# Melhorias recomendadas — PC Optimizer

> Atualizado em 04/11/2026 após o pull da **v4.0** (commit `a8158cf`).
> Base: `Otimizar-PC.ps1` (legado, 1.536 linhas), `Modules/Optimizer.Core.psm1` e `Otimizador-GUI.ps1`.

---

## Status: o que a v4.0 já resolveu

| Item anterior | Situação |
|---|---|
| ~255 definições duplicadas | **Resolvido** — 72 funções, 72 nomes únicos, zero duplicatas |
| GUI síncrona / congelando | **Resolvido** — runspace separado + `DispatcherTimer` + cancelamento cooperativo |
| Relatório HTML sem escape | **Resolvido no núcleo** — `WebUtility::HtmlEncode` em cliente, observações e diagnóstico |
| Testes só verificavam existência | **Melhorado** — suíte de segurança com arquivos descartáveis, links, retenção, expiração e cancelamento |
| CI sem matriz | **Resolvido** — Ubuntu/Windows, Windows PowerShell 5.1 e validação WPF real |
| Exigir admin para abrir a interface | **Resolvido** — BAT abre a UI sem elevação; console legado exige `-Legacy` |
| Docs desalinhadas | **Resolvido** — README, LEIA-ME e CONTRIBUTING reescritos para a 4.0 |

O projeto mudou de "script gigante" para uma arquitetura com núcleo separado e interface WPF. O backlog abaixo é o que **ainda** vale implementar.

---

## P0 — Correções rápidas

### 1. Remover a linha duplicada "23" do menu legado

`Otimizar-PC.ps1` linha **1344** repete "23. Ferramentas externas recomendadas" (já aparece na linha 1318).

**Ação:** apagar a linha duplicada. Opcional: gerar o menu a partir de um array para impedir novas divergências.

### 2. Reestruturar o `CHANGELOG.md`

A entrada `# 4.0.0` está **antes** do título `# Changelog` e usa heading diferente do padrão Keep a Changelog.

**Ação:** mover a 4.0 para baixo do cabeçalho e padronizar:

```markdown
## [4.0.0] - 2026-11-04

### Added
- ...
```

### 3. Endurecer `Invoke-SelfUpdate` e `Push-ToGitHub` (legado)

Ainda presentes em `Otimizar-PC.ps1` (linhas 828 e 844) com os mesmos riscos:

- `Invoke-SelfUpdate` baixa o raw do GitHub e **sobrescreve o próprio script** sem validar versão, assinatura ou checksum. Como compara hash do arquivo local com o conteúdo remoto, qualquer diferença de CRLF/LF força atualização.
- `Push-ToGitHub` faz `git add -A` e commit com identidade fixa `leo@example.com`, podendo publicar arquivos não intencionais.

**Ações:**
- Self-update: comparar `$Version` com a versão remota; baixar para temporário; validar SHA-256 publicado no release; só substituir após confirmação.
- Auto-push: remover `-A`, listar arquivos explicitamente, respeitar `user.name`/`user.email` do repositório e exigir confirmação.
- Ideal: remover as duas rotinas do legado e manter atualização/publicação fora do produto.

### 4. Escapar o log no `Generate-Report` legado

O relatório do **núcleo** já escapa tudo, mas o `Generate-Report` do legado (linha 820) ainda injeta `Get-Content $LogFile -Raw` dentro de `<pre>`, sem `HtmlEncode`.

**Ação:** aplicar `[System.Net.WebUtility]::HtmlEncode(...)` ou remover o gerador legado, já que a UI 4.0 tem relatório próprio.

### 5. Decidir o destino do `#Requires -RunAsAdministrator`

`Otimizar-PC.ps1` linha 51 ainda exige admin **antes** do `param`, então `-LoadOnly` também exige. Os testes atuais contornam isso via AST (não executam o script), mas qualquer ferramenta que tente dot-sourcing falha sem elevação.

**Ação:** mover a checagem para o ponto de entrada, ignorando `-LoadOnly`; ou documentar explicitamente que o legado só carrega como admin.

---

## P1 — Núcleo, testes e qualidade

### 6. Reintroduzir o PSScriptAnalyzer no CI

A v4.0 removeu o PSScriptAnalyzer do workflow (0 referências). Hoje o CI valida sintaxe, duplicatas e XAML, mas não estilo/regras.

**Ação:**
- Criar `PSScriptAnalyzerSettings.psd1`.
- Rodar `Invoke-ScriptAnalyzer -Settings ... -Severity Warning,Error` no job `safety`.
- Começar como advisory (não bloquear) e depois tornar bloqueante.

### 7. Ampliar a cobertura do núcleo

A suíte atual cobre muito bem limpeza e relatório. Faltam casos para:

- `Format-OptimizerSize` (bytes, MB, GB, zero).
- `Get-OptimizerByteSum` (lista vazia, propriedade ausente).
- `Get-OptimizerTargets` (perfis `Default`/`Profile N`, navegador ausente).
- `Get-OptimizerDiagnostics` (WMI indisponível, bateria ausente, Defender desligado).
- `Export-OptimizerReport` sem limpeza (`Cleanup = $null`) e com acentos.

Manter o estilo dependency-free atual ou migrar para Pester 5 — o importante é cobrir esses caminhos.

### 8. Padronizar `[CmdletBinding()]` e help no núcleo

`Optimizer.Core.psm1` tem apenas **1** `[CmdletBinding()]` (em `Invoke-OptimizerCleanup`). As demais funções não têm `-Verbose`, `-Debug` nem help.

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

| Etapa | Escopo | Entrega |
|---|---|---|
| 1 | P0 (itens 1–5) | Menu sem duplicata, CHANGELOG padronizado, legado sem self-update inseguro, relatório legado escapado |
| 2 | P1 (itens 6–12) | PSScriptAnalyzer no CI, cobertura extra, config externa, relatório com `<head>`/JSON |
| 3 | P2 (itens 13–16) | Release assinado, workflow de tag, `-Auto` revisado, `SECURITY.md` |
| 4 | P3/P4 (itens 17–24) | Acessibilidade, seleção em massa, progresso real, docs de arquitetura e templates |

---

## Critérios de aceite

- [ ] `Tests/Validate-Syntax.ps1` continua detectando zero duplicatas.
- [ ] `Tests/Core.Smoke.ps1` verde em Windows PowerShell 5.1 e PowerShell 7.
- [ ] PSScriptAnalyzer sem Warning/Error com as settings do repo.
- [ ] Menu legado sem opções repetidas.
- [ ] CHANGELOG com a 4.0 no formato Keep a Changelog.
- [ ] Relatório do legado escapa o log (ou o gerador legado é removido).
- [ ] Self-update não sobrescreve sem validar versão/checksum.
- [ ] Release publica ZIP + SHA-256.

---

## Anexo — evidências da v4.0

| Evidência | Valor |
|---|---|
| Linhas de `Otimizar-PC.ps1` | 1.536 |
| Definições `function` no legado | 72 |
| Nomes únicos | 72 |
| Duplicatas | 0 |
| Linhas de `Optimizer.Core.psm1` | ~180 |
| `[CmdletBinding()]` no núcleo | 1 (`Invoke-OptimizerCleanup`) |
| `[CmdletBinding()]` no legado | 0 |
| `Write-Progress` no projeto | 0 |
| Opções do menu legado | 48 (com "23" duplicada na linha 1344) |
| Abas da UI 4.0 | 5 (Visão geral, Limpeza, Diagnóstico, Ferramentas, Relatório) |
| PSScriptAnalyzer no CI | 0 referências |
| Matriz do CI | Ubuntu + Windows; PS 5.1; validação WPF |
