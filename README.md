# PC Optimizer — Central de manutenção

Interface desktop em português para o dia a dia de manutenção de computadores e notebooks. PowerShell 5.1 + WPF, sem instalação de dependências, conta, publicidade ou envio de dados.

![Interface da Central de manutenção](docs/preview.png)

## Abrir

1. Baixe o **pacote portátil** `PC-Optimizer-Portable-4.5.zip` na página de releases ou o [ZIP do projeto](https://github.com/leonccunha21/windows-pc-optimizer/archive/refs/heads/main.zip) para desenvolvimento.
2. **Extraia a pasta inteira**, mantendo `Modules`, `Data` e `UI` ao lado dos scripts.
3. Abra `PC-Optimizer.exe` (pacote portátil) ou `Executar-Otimizador.bat` (repositório). A interface comum **não exige administrador**.
4. Faça o diagnóstico, analise a limpeza, revise os arquivos e confirme as categorias desejadas.

O pacote portátil não precisa do repositório, de instalação ou de rede. Preferências e logs ficam em `Dados/` quando a pasta é gravável; em mídia somente leitura, o fallback é `%TEMP%\PCOptimizer-Portable`. Consulte [README-PORTABLE.md](README-PORTABLE.md).

## Assinatura de código

Assinatura gratuita preparada via SignPath Foundation para open source. Consulte [CODE_SIGNING.md](CODE_SIGNING.md). Até a aprovação, o pacote local usa self-signed apenas para integridade de desenvolvimento.

Use na conta do cliente: elevar com credenciais de outro usuário muda o perfil analisado. Em computadores gerenciados, respeite a política de execução da organização. Não execute o programa dentro do ZIP sem extrair a pasta. Windows 10/11 com interface desktop; a compatibilidade do aplicativo não altera o ciclo de suporte do Windows.

## O que a edição 4.5 oferece

| Área | Recursos |
|---|---|
| Visão geral | Fluxo de atendimento, espaço analisado, resultado real da última limpeza e assistente local que recomenda as melhores opções com motivo e prioridade |
| Limpeza | Prévia por categoria e arquivo, seleção/desmarcação em massa, resultado detalhado, CSV opcional (com aviso de privacidade) e progresso por arquivo; caches Chrome, Edge, Brave, Firefox, Opera, Vivaldi e Chromium (por perfil); catálogo declarativo de caches do Windows e de aplicativos, com risco e observação por categoria; botão para reabrir a interface como administrador; retenção mínima de 7 dias |
| Diagnóstico | Sistema, fabricante/modelo, CPU, RAM, discos, espaço livre, bateria e estado do Defender quando disponível |
| Rede | Diagnóstico local de adaptadores, IPv4, gateway, DNS e perfis; testes DNS/TCP com destino explícito |
| Saúde | Bateria com relatório oficial do Windows (powercfg), capacidade de projeto e ciclos; discos físicos com contadores SMART, temperatura, desgaste e volumes |
| Manutenção | Drivers instalados com status (assinatura/idosidade), atualizações de driver via Windows Update; aplicativos instalados com sugestões de remoção e exclusão confirmada; otimizações seguras (plano de energia, Sensor de Armazenamento, cache de entrega, Lixeira) |
| Privacidade & IA | Desativação de Copilot, Recall e pacotes de IA; bloqueio de telemetria do Windows/Office e de apps de terceiros (NVIDIA, VS Code, PowerShell, CCleaner); restrição de permissões (localização, microfone, câmera) e predefinições Básica, Rígida e Extrema baseadas no WinScript |
| Ajustes do sistema | Troca rápida de perfis DNS (Google, Cloudflare, Quad9, AdGuard), redução de latência/mouse delay, desativação de MPO para evitar stuttering em jogos, modo escuro e restauração do menu de contexto clássico |
| Bancada integrada | Inventário de processos, inicialização, programas, adaptadores, atualizações e unidades; diagnóstico local de rede; testes DNS/TCP autorizados; histórico de falhas de disco/WHEA/NTFS/desligamento; ferramentas SFC, DISM e CHKDSK com confirmação e UAC |
| Atalhos do Windows | Inicialização, aplicativos, armazenamento, segurança, otimização de unidades, restauração, eventos, tarefas, recursos opcionais, dispositivos, energia, Windows Update, informações de sistema |
| Relatório | Cliente/OS, observações, diagnóstico e resultado; HTML imprimível em PDF ou JSON sem caminhos de arquivos excluídos |

Análise e limpeza rodam em um runspace separado. A janela permanece disponível e permite solicitar interrupção entre arquivos. A consulta de hardware termina antes de fechar a janela. Relatórios são salvos apenas por escolha do usuário; não há histórico persistente automático com dados de clientes.

## Interface e acessibilidade

A partir da edição 4.4, a barra lateral é **navegável por clique** e indica a área ativa, em vez de apenas descrever um roteiro. Em **Manutenção → Bancada**, as ferramentas foram separadas em quatro guias: **Inventário**, **Rede**, **Histórico** e **Reparos**. A reorganização não altera as regras de segurança dos módulos.

Atalhos para navegar: **Ctrl+1** Visão geral, **Ctrl+2** Diagnóstico, **Ctrl+3** Saúde, **Ctrl+4** Limpeza, **Ctrl+5** Manutenção, **Ctrl+6** Relatório, **Ctrl+7** Preferências e **Ctrl+B** Bancada. Permanecem **F5** para análise de limpeza, **Esc** para solicitar interrupção e **Ctrl+E** para relatório.

Todos os botões visíveis, grids, abas e avisos receberam rótulos de automação, e a navegação lateral possui ordem de tabulação explícita e destaque para foco de teclado. As principais combinações de texto/fundo foram ajustadas para contraste mínimo de 4,5:1; uma validação estática é executada no CI. Isso **não equivale a certificação completa de acessibilidade**: leitor de tela, temas de alto contraste e resoluções com DPI acima de 100% ainda exigem testes manuais no Windows.

## Preferências de leitura (4.5)

Abra **Preferências** na barra lateral (ou **Ctrl+7**). Ative o modo de alto contraste e escolha texto em 100%, 115% ou 125%. **Aplicar e salvar** mantém a escolha nas próximas aberturas; **Restaurar padrão** retorna ao tema convencional e à escala de 100%. O Alto Contraste do Windows tem prioridade quando ativo.

Somente as chaves `SchemaVersion`, `HighContrast`, `TextScale` e `SelectedCategories` são gravadas em `%LOCALAPPDATA%\PCOptimizer\preferences.json`. `SelectedCategories` guarda apenas identificadores genéricos de categoria (por exemplo, `temp`), nunca caminhos de arquivos. Nenhum dado de cliente, ordem de serviço, IP, inventário, caminho analisado ou resultado de limpeza é armazenado. Arquivos JSON inválidos, ausentes ou grandes demais retornam ao padrão. Não há telemetria nem sincronização externa.

A seleção de categorias é restaurada na próxima análise, e a última pasta usada para salvar relatórios é lembrada apenas durante a sessão — ela não é gravada em disco. A janela de resultado detalhado permite filtrar por categoria, caminho, status ou detalhe.

A paleta WPF usa recursos dinâmicos para botões, cartões, tabelas e textos, e o dimensionamento amplia também as linhas da grade. Testes automáticos cobrem a persistência, privacidade e aplicação visual. **Narrador/NVDA, combinações de tema do Windows e vários níveis de DPI ainda precisam validação manual.**

## Configuração externa (4.5)

A allowlist de limpeza fica em `config/optimizer.psd1`: retenção mínima, navegadores, subpastas de cache, extensões protegidas, pastas protegidas e marcadores de projeto. O arquivo é opcional; se estiver ausente, malformado ou fora da política (retenção abaixo de 7 dias, caminho absoluto, `..`, id inválido ou lista vazia), o núcleo usa os padrões seguros embutidos. Editar a configuração não amplia a limpeza para Documents, Downloads, Registro ou outras contas — apenas ajusta os limites já permitidos.

## Saúde e manutenção

A aba **Saúde** consolida as consultas de bateria e de disco. A bateria é medida pelo relatório oficial do Windows (`powercfg /batteryreport`); quando o relatório não existe ou não informa capacidade de projeto, o estado permanece como informação do sistema. O desgaste e temperatura vêm dos contadores SMART do subsistema de armazenamento; contas ausentes são exibidas sem notas de saúde inventadas.

A aba **Manutenção** reúne drivers, aplicativos e ajustes. Tudo é consultado primeiro; nada é instalado, alterado ou removido automaticamente. A remoção de aplicativos é sempre confirmada e remove somente pacotes não marcados como não removíveis para o usuário atual.

As ações de ajuste (plano de energia, Sensor de Armazenamento, cache de Otimização de Entrega, esvaziar Lixeira, desativar inicialização rápida) pedem confirmação explícita. Ações que exigem administrador falham com explicação quando a interface roda sem elevação.


## Janela

A janela WPF define o estilo de borda (`SingleBorderWindow`) com `ResizeMode` ajustável e exibe o botão **Fechar** na barra de título do aplicativo, no cabeçalho da janela. Durante uma operação em andamento, o fechamento é perguntado ao usuário e encerra o runspace em vez de ser ignorado. Atalhos: **F5** analisa, **Esc** solicita interrupção e **Ctrl+E** abre a exportação do relatório.

## Bancada técnica

Na interface, abra **Manutenção → Bancada** (ou o atalho na visão geral). Os botões estão conectados aos módulos locais publicados, não são apenas atalhos: inventário de processos, inicialização, programas, interfaces, atualizações e armazenamento; rede local; histórico de falhas; e comandos de integridade.

As consultas rodam em segundo plano. A rede **não** acessa destinos externos na consulta local; o técnico deve informar um host/IP e consentir antes de testar DNS e TCP. IPs, gateway, DNS e nomes de perfis locais são ocultos por padrão. O histórico usa IDs e provedores do log System sem exibir mensagens originais, nomes de usuário ou caminhos.

SFC /verifyonly, DISM /ScanHealth e CHKDSK /scan verificam o sistema; SFC /scannow e DISM /RestoreHealth podem repará-lo. A execução ocorre num novo console Windows, com confirmação e UAC, **nunca automaticamente**. Verificações e resultados dependem do Windows, drivers e permissões; ausência de avisos não certifica saúde.

Os relatórios HTML/JSON não incluem caminhos de arquivos excluídos; o CSV detalhado **inclui**, por isso é salvo apenas mediante escolha do técnico e aviso de privacidade. As ferramentas independentes em `Tools/` continuam disponíveis.

Para mais detalhes, leia `docs/DIAGNOSTICO-REDE.md` e `docs/DIAGNOSTICO-EVENTOS.md`.

## Rede e conectividade

A aba **Rede** consolida o diagnóstico local. A consulta usa apenas o ambiente local do Windows (adaptadores, IPv4, gateway, DNS e perfis) e não envia dados. O teste de DNS/TCP só roda com o destino explícito informado pelo usuário; nada é testado sem essa autorização.

## Critérios de limpeza

- Somente raízes permitidas do perfil atual. Não percorre Documents, Downloads ou outras contas.
- Não apaga senhas, cookies ou histórico de navegação.
- Navegadores abertos são ignorados na análise e verificados novamente na exclusão.
- Preserva arquivos recentes, extensões comuns de código/documentos/mídia/arquivos compactados e pastas com marcadores de projeto (`.git`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`). As listas vêm de `config/optimizer.psd1` e são revalidadas a cada arquivo.
- Um arquivo vazio chamado `.optimizer-protect` protege a pasta e seus descendentes.
- Não percorre junctions ou links simbólicos. Antes de excluir, verifica novamente os ancestrais, tamanho e data de modificação.
- O catálogo em `Data/cleanup-rules.json` declara pasta, processo, risco e observação de cada categoria. Categorias que exigem administrador são ignoradas sem elevação e informadas no aviso da análise.
- O botão **Abrir como administrador** reabre a interface elevada após confirmação; ele desaparece quando a sessão já está elevada.
- Perfis de navegador são descobertos por um segmento `*` no caminho (por exemplo, `Profiles\*\cache2`). A expansão é limitada a 64 pastas por regra, não atravessa junctions/links e não aceita curingas parciais.
- Categorias com filtro de padrão só aceitam os arquivos declarados (por exemplo, `thumbcache_*.db`); o restante continua sujeito à lista de extensões preservadas.
- Apaga arquivos individuais, nunca diretórios recursivamente. Arquivos em uso ou sem permissão são registrados como ignorados.
- A análise expira em 30 minutos. Após uma limpeza, uma nova análise é obrigatória.
- A exclusão é permanente: revise a prévia. Um ponto de restauração não recupera arquivos pessoais excluídos.

O formato do catálogo, as fontes públicas usadas e o passo a passo para novas categorias estão em [docs/CATALOGO-LIMPEZA.md](docs/CATALOGO-LIMPEZA.md). Não há limpeza de Registro, alteração automática de serviços, pagefile, rede ou exclusão de logs na nova interface. Espaço liberado representa os bytes dos arquivos cuja exclusão foi confirmada; não é promessa de ganho de velocidade nem medição de alocação física em discos comprimidos.

## Fluxo de oficina

1. Confirme o backup e registre os sintomas nas observações do atendimento.
2. Consulte o diagnóstico. Status de disco via WMI não substitui SMART completo, e o estado do Defender não certifica ausência de malware.
3. Feche os navegadores, analise e confira os candidatos.
4. Limpe somente as categorias autorizadas e confira removidos/ignorados.
5. Utilize as ferramentas nativas conforme a necessidade e registre o serviço.
6. Salve o relatório. Para PDF, abra o HTML no navegador e escolha **Imprimir → Salvar como PDF**.

## Desenvolvimento e validação

```powershell
./Tests/Validate-Syntax.ps1
./Tests/Optimizer.Tests.ps1
./Tests/Core.Smoke.ps1
./Tests/CleanupCatalog.Smoke.ps1
./Tests/Technician.Smoke.ps1
./Tests/Network.Smoke.ps1
powershell.exe -NoProfile -STA -File ./Otimizador-GUI.ps1 -ValidateUI
```

Atalhos: **F5** analisa, **Esc** solicita interrupção e **Ctrl+E** abre a exportação do relatório. O progresso da limpeza reflete a contagem de arquivos processados; na análise a barra permanece indeterminada.

Os testes de segurança usam uma pasta temporária própria; nunca executam a limpeza real do computador. CI valida o núcleo no Linux/Windows, Windows PowerShell 5.1 e o fluxo real de análise/limpeza pela interface WPF com arquivos de teste. A validação visual em bancada (DPI, leitores de tela e diferentes versões do Windows) segue o [roteiro de testes](docs/VALIDACAO.md).

## Console legado 3.3

`Otimizar-PC.ps1` permanece para compatibilidade técnica, com 255 definições duplicadas removidas, preservando a última implementação de cada função. O console exige agora **`-Legacy` explícito**. Agendamentos antigos devem ser revisados e desativados: o `-Auto` legado foi bloqueado por segurança. O console legado exige administrador; `-LoadOnly` permite carregar definições sem elevação.

As rotinas legadas não têm as garantias do novo núcleo e **não são chamadas pela interface 4.0**. Incluem mudanças de serviços/pagefile e limpeza de logs; `-Auto`, `-AutoPush`, `-Schedule` e a atualização automática de código estão desativados. Para atualizar, revise o código publicado no GitHub e substitua manualmente após validação. `-LoadOnly` não cria nem sobrescreve logs.

Licença MIT. Projeto independente; não afiliado ao CCleaner. A versão 4.0 melhora a base de uso profissional, sem alegar equivalência de cobertura ou superioridade comprovada a produtos comerciais.
