# PC Optimizer — Central de manutenção

Interface desktop em português para o dia a dia de manutenção de computadores e notebooks. PowerShell 5.1 + WPF, sem instalação de dependências, conta, publicidade ou envio de dados.

## Abrir

1. Baixe o [ZIP do projeto](https://github.com/leonccunha21/windows-pc-optimizer/archive/refs/heads/main.zip).
2. **Extraia a pasta inteira**, mantendo `Modules` e `UI` ao lado dos scripts.
3. Abra `Executar-Otimizador.bat`. A interface comum **não exige administrador**.
4. Faça o diagnóstico, analise a limpeza, revise os arquivos e confirme as categorias desejadas.

Use na conta do cliente: elevar com credenciais de outro usuário muda o perfil analisado. Em computadores gerenciados, respeite a política de execução da organização. Não execute o BAT dentro do ZIP. Windows 10/11 com interface desktop; a compatibilidade do aplicativo não altera o ciclo de suporte do Windows.

## O que a edição 4.0 oferece

| Área | Recursos |
|---|---|
| Visão geral | Fluxo de atendimento, espaço analisado e resultado real da última limpeza |
| Limpeza | Prévia por categoria e arquivo; temporários do usuário e caches Chrome, Edge e Brave; retenção mínima de 7 dias |
| Diagnóstico | Sistema, fabricante/modelo, CPU, RAM, discos, espaço livre, bateria e estado do Defender quando disponível |
| Ferramentas | Atalhos para inicialização, aplicativos, armazenamento, segurança, otimização de unidades, restauração, eventos e tarefas |
| Relatório | Cliente/OS, observações, diagnóstico e resultado; HTML local que pode ser impresso em PDF no navegador |

Análise e limpeza rodam em um runspace separado. A janela permanece disponível e permite solicitar interrupção entre arquivos. A consulta de hardware termina antes de fechar a janela. Relatórios são salvos apenas por escolha do usuário; não há histórico persistente automático com dados de clientes.

## Critérios de limpeza

- Somente raízes permitidas do perfil atual. Não percorre Documents, Downloads ou outras contas.
- Não apaga senhas, cookies ou histórico de navegação.
- Navegadores abertos são ignorados na análise e verificados novamente na exclusão.
- Preserva arquivos recentes, extensões comuns de código/documentos/mídia/arquivos compactados e pastas com marcadores de projeto (`.git`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`).
- Um arquivo vazio chamado `.optimizer-protect` protege a pasta e seus descendentes.
- Não percorre junctions ou links simbólicos. Antes de excluir, verifica novamente os ancestrais, tamanho e data de modificação.
- Apaga arquivos individuais, nunca diretórios recursivamente. Arquivos em uso ou sem permissão são registrados como ignorados.
- A análise expira em 30 minutos. Após uma limpeza, uma nova análise é obrigatória.
- A exclusão é permanente: revise a prévia. Um ponto de restauração não recupera arquivos pessoais excluídos.

Não há limpeza de Registro, alteração automática de serviços, pagefile, rede ou exclusão de logs na nova interface. Espaço liberado representa os bytes dos arquivos cuja exclusão foi confirmada; não é promessa de ganho de velocidade nem medição de alocação física em discos comprimidos.

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
./Tests/Core.Smoke.ps1
powershell.exe -NoProfile -STA -File ./Otimizador-GUI.ps1 -ValidateUI
```

Os testes de segurança usam uma pasta temporária própria; nunca executam a limpeza real do computador. CI valida o núcleo no Linux/Windows, Windows PowerShell 5.1 e carregamento WPF. A validação visual em bancada (DPI, leitores de tela e diferentes versões do Windows) segue o [roteiro de testes](docs/VALIDACAO.md).

## Console legado 3.3

`Otimizar-PC.ps1` permanece para compatibilidade técnica, com 255 definições duplicadas removidas, preservando a última implementação de cada função. O console exige agora **`-Legacy` explícito**. Agendamentos antigos devem ser revisados: não acrescente essa opção sem avaliar o que executam.

As rotinas legadas não têm as garantias do novo núcleo e **não são chamadas pela interface 4.0**. Incluem mudanças de serviços/pagefile e limpeza de logs; `-Auto` não é indicado para manutenção rotineira. `-LoadOnly` não cria nem sobrescreve logs.

Licença MIT. Projeto independente; não afiliado ao CCleaner. A versão 4.0 melhora a base de uso profissional, sem alegar equivalência de cobertura ou superioridade comprovada a produtos comerciais.
