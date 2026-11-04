# Contribuindo

A interface 4.0 está em `Otimizador-GUI.ps1` e `UI/MainWindow.xaml`. As operações de análise, limpeza e relatório estão em `Modules/Optimizer.Core.psm1`. O console `Otimizar-PC.ps1` é legado e não deve ser importado pela interface.

## Verificar uma mudança

```powershell
./Tests/Validate-Syntax.ps1
./Tests/Optimizer.Tests.ps1
./Tests/Core.Smoke.ps1
powershell.exe -NoProfile -STA -File ./Otimizador-GUI.ps1 -ValidateUI
```

A última etapa requer Windows, testa o fluxo assíncrono com um perfil temporário isolado e não abre uma sessão interativa. Confira também o roteiro de bancada em `docs/VALIDACAO.md`.

## Regras do núcleo de limpeza

- Toda nova categoria precisa de raiz explícita e teste de segurança com dados descartáveis.
- A análise não modifica arquivos; a limpeza exige uma análise recente e confirmação na interface.
- Revalide caminhos, links, marcadores de proteção, tamanho e data antes de excluir.
- Não use exclusão recursiva, eliminação de logs, limpadores de Registro ou desativação indiscriminada de serviços.
- Preserve extensões pessoais/código, pastas de projetos e jogos. Não inclua outras contas nem Downloads.
- Registre remoções confirmadas e motivos de itens ignorados. Nunca apresente simulação como espaço liberado.
- Mantenha `SupportsShouldProcess`/`-WhatIf`, cancelamento cooperativo e testes que não limpam o perfil real.
- Um ponto de restauração não é backup de arquivos: não o apresente como possibilidade de desfazer uma limpeza.
- Não envie dados do cliente para GitHub ou outro serviço. Evite caminhos pessoais em relatórios exportados.

Scripts com texto em português devem usar UTF-8 com BOM, para compatibilidade com Windows PowerShell 5.1.

## Relatar problemas

Informe versão do Windows, `$PSVersionTable.PSVersion`, etapas de reprodução e a mensagem exibida na interface. Remova nomes, caminhos e dados de clientes de capturas/relatórios antes de compartilhar.
