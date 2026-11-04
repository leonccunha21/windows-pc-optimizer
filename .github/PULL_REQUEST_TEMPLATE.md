## Objetivo

Descreva qual problema foi resolvido, os arquivos alterados e qualquer mudança na compatibilidade.

## Checklist de segurança

- [ ] Não removi a allowlist de diretórios nem a retenção mínima de 7 dias
- [ ] A exclusão só ocorre após revisão e confirmação
- [ ] Scripts não executam download de código remoto nem publicação automática Git
- [ ] Sem coleta ou envio de dados pessoais
- [ ] Não alterei serviços, Registro, rede ou pagefile a partir da interface
- [ ] Atualizei documentação quando necessário

## Validação

- [ ] `Tests/Validate-Syntax.ps1`
- [ ] `Tests/Optimizer.Tests.ps1`
- [ ] `Tests/Core.Smoke.ps1` no Windows PowerShell 5.1 e PowerShell 7
- [ ] `Otimizador-GUI.ps1 -ValidateUI` com perfil descartável
- [ ] Revisão manual na bancada (quando necessário)
