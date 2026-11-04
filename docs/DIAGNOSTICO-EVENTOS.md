# Histórico de falhas do Windows — diagnóstico de bancada

Este módulo identifica **sinais no log System do Windows** que podem ajudar a investigar problemas de computadores e notebooks. Não executa limpeza, reparo, exclusão de eventos, alteração do Registro ou download.

## Como utilizar

1. Baixe o repositório completo e extraia sua pasta.
2. Dê dois cliques em **Tools/Executar-Diagnostico-Eventos.bat** para consultar os últimos 14 dias.
3. Para especificar período e exportar o resumo JSON (sem mensagens brutas), execute:

       powershell.exe -NoProfile -File .\Tools\Diagnostico-Eventos.ps1 -Days 30 -ExportPath C:\Temp\eventos-resumo.json

O arquivo JSON não sobrescreve arquivo existente. No console, nada é gravado automaticamente.

## Interpretação — o que é e o que não é

| Tipo de evento | O que sugere investigar | Não é prova de |
|---|---|---|
| Kernel-Power 41 / EventLog 6008 | Desligamento inesperado, travamento ou queda de energia | Fonte ou bateria defeituosa necessariamente |
| WHEA 17/18/19 | Registro de erro de hardware, às vezes corrigido | CPU ou RAM comprovadamente com defeito |
| disk 7/51/153/157, storahci 129 | E/S, conexão, controladora ou unidade | SSD/HD condenado sem confirmação |
| Ntfs 55/98 | Potencial problema no sistema de arquivos | Corrupção irrecuperável sem testes |
| BugCheck 1001 | Reinicialização por tela azul | Causa específica sem analisar o dump |
| Service Control Manager 7000/7009/7031/7034 | Erro de serviço | Necessidade de desabilitar serviços |
| volmgr 161 | Possível falha ao gravar despejo | Defeito físico confirmado |

A ausência dos eventos monitorados **não comprova que a máquina está saudável**. A consulta está limitada por padrão a 1.500 eventos de níveis Crítico/Erro/Aviso do log System nos últimos 14 dias. O limite pode atingir somente a parte mais recente dos eventos; em caso de truncamento, o programa informa isso.

## Privacidade e segurança

O Windows Event Viewer pode conter nomes de usuário, caminhos de pastas e informações sigilosas nas **mensagens** originais. Este módulo **não serializa nem apresenta essas mensagens**. Em vez disso, classifica apenas IDs conhecidos por provedor, agrupa por categoria e retorna timestamps, contagens e orientações genéricas.

Nenhum log é apagado. Não há consultas externas, telemetria, agendamentos, reparos automáticos ou envio de dados. A exportação JSON precisa ser solicitada, e uma saída existente não é sobrescrita.

O módulo disponibiliza:
- Get-OptimizerEventCatalog
- ConvertTo-OptimizerEventFinding
- Get-OptimizerEventSummary

Para testar sem tocar no computador, execute Tests/Events.Smoke.ps1. A função Get-OptimizerEventSummary suporta o parâmetro Records com registros sintéticos; nesse modo nenhum evento real é consultado.

## Integração futura com a interface

A frente Saúde/Drivers/UI está trabalhando em Otimizador-GUI.ps1 e UI/MainWindow.xaml. Ela poderá conectar Get-OptimizerEventSummary a uma área **Histórico de falhas** mediante botão e runspace, depois da validação. Recomenda-se exibir categorias, contagens, última ocorrência e orientações, sem mensagens de eventos. **O botão ainda não existe na interface; não anunciar como integrado.**
