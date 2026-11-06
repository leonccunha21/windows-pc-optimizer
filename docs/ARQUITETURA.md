# Arquitetura do PC Optimizer 4.x

## Componentes

- `Executar-Otimizador.bat`: entrada da aplicação, inicia WPF sem solicitar administrador.
- `Otimizador-GUI.ps1`: interface WPF; execução assíncrona com runspace e cancelamento cooperativo.
- `UI/MainWindow.xaml`: layout, navegação e elementos acessíveis.
- `Modules/Optimizer.Core.psm1`: núcleo de análise, validação de caminhos, limpeza confirmada, diagnóstico e exportação HTML/JSON.
- `Modules/Optimizer.CleanupCatalog.psm1`: lê o catálogo declarativo, resolve tokens de ambiente, expande perfis por segmento `*` e devolve apenas pastas existentes.
- `Data/cleanup-rules.json`: regras próprias de limpeza (pasta, processo, risco e observação), sem definições extraídas de produtos comerciais.
- `Otimizar-PC.ps1`: console legado **isolado** da interface. Pode conter ações de alto impacto e exige `-Legacy` e administrador. As opções automáticas não são recomendadas.
- `Tests/`: verificações de sintaxe, regressões de compatibilidade e segurança com arquivos fictícios.

## Fluxo principal

1. **Análise**: identifica apenas diretórios permitidos; ignora navegadores em uso, arquivos recentes, documentos, projetos e links. Categorias marcadas como `RequiresAdmin` são omitidas sem elevação, com aviso explícito.
2. **Revisão**: mostra categorias, contagem e lista de arquivos candidatos. Seleção em massa é opcional.
3. **Confirmação**: exige consentimento explícito antes da exclusão permanente.
4. **Execução**: revalida caminhos, datas, tamanhos e permissões. O progresso corresponde a arquivos avaliados. Cancelamento interrompe entre itens.
5. **Resultado**: computa somente bytes confirmadamente removidos, guarda removidos/ignorados em memória e exige uma nova análise para outra limpeza.
6. **Relatório**: exportação local HTML ou JSON sob comando do usuário, sem serializar a lista de caminhos pessoais removidos.

## Modelo de ameaças

A ferramenta protege contra seleção acidental de caminhos fora das raízes, navegação por junction/symlink, limpeza de arquivos alterados após a análise e vazamento de paths em relatórios. Não é uma fronteira de segurança contra processos maliciosos locais com capacidade de alterar arquivos ou permissões. A checagem e a exclusão são operações separadas, então condições de corrida não podem ser eliminadas apenas com PowerShell. Execute somente com privilégios necessários e tenha backup verificado.

## Compatibilidade e qualidade

Windows 10/11 com Windows PowerShell 5.1, WPF e .NET Framework presentes. CI verifica PowerShell 7 em Windows/Linux, PowerShell 5.1 em Windows e integração WPF com dados descartáveis. Testes manuais de DPI, leitor de tela, proteção de endpoints e versões de Windows permanecem essenciais.
