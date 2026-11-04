# Diagnóstico de rede — Oficina Pro

Ferramenta separada para uso de técnicos, desenhada para integrar posteriormente à interface WPF sem conflitar com o agente responsável por Saúde/Drivers.

## Funcionalidades disponíveis

- Inventário local de adaptadores, estados, velocidades de link, presença de IPv4, gateway, servidores DNS, perfis e rotas padrão. Dados coletados de comandos nativos, sem alterar configurações.
- Avaliação orientativa para cabo/Wi-Fi desconectado, IPv4 ausente, APIPA (possível problema DHCP), gateway ausente e DNS ausente. Nenhum resultado isolado certifica acesso à Internet ou falha física.
- Testes remotos **opt-in**: resolução DNS e conexão TCP apenas ao hostname/IP escolhido pelo técnico.
- Endereços locais são ocultos por padrão; não há coleta de MAC address, histórico, telemetria ou armazenamento automático.

## Executar agora

No Windows PowerShell 5.1, dentro do repositório:

    powershell.exe -NoProfile -File .\Tools\Diagnostico-Rede.ps1
    powershell.exe -NoProfile -File .\Tools\Diagnostico-Rede.ps1 -IncludeAddresses
    powershell.exe -NoProfile -File .\Tools\Diagnostico-Rede.ps1 -DnsName example.com
    powershell.exe -NoProfile -File .\Tools\Diagnostico-Rede.ps1 -Target example.com -Port 443

**Atenção:** os dois últimos exemplos enviam consultas externas deliberadamente. Nunca testar o destino sem autorização do proprietário. O inventário padrão é local.

## Como integrar quando a nova interface estiver pronta

O agente que reservar os arquivos UI/MainWindow.xaml e Otimizador-GUI.ps1 deve importar o novo módulo Modules/Optimizer.NetworkDiagnostics.psm1 no runspace assíncrono e chamar Get-OptimizerNetworkSnapshot. Renderizar os campos Area, Item, Value e Level em uma aba Rede.

Preservar a separação entre "Consultar configuração" (sem tráfego externo), "Exibir endereços locais" (opt-in por privacidade) e "Testar destino" (tráfego externo somente após consentimento explícito). Estado de cancelamento é cooperativo via hashtable State.

**Status:** este pacote é integrado ao repositório e pode ser executado pelo script independente. Não afirmar que existe botão correspondente na interface WPF antes de conectá-lo e testá-lo.

## Limitações

- Link ativo e IPv4 completo não garantem acesso à Internet. Ausência de IPv4 não é falha em redes que utilizam IPv6.
- A leitura dos adaptadores pode exigir serviços do Windows ou permissões conforme a política da máquina.
- Teste TCP verifica somente a porta solicitada; falha pode ocorrer por firewall, política ou indisponibilidade de servidor.
- Não há varredura de portas, renovação de DHCP, reset Winsock, ajuste de DNS, alteração de Registro ou firewall.
- Os testes CI não acessam Internet nem alteram a configuração de rede.
