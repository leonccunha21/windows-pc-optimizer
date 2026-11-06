# Pacote portátil — resumo técnico

Este repositório gera um pacote autônomo do PC Optimizer que pode ser executado
sem instalar nada e sem baixar o repositório na máquina de destino.

## Entradas do pacote

| Arquivo | Função |
|---|---|
| `PC-Optimizer.exe` | Entrada principal nativa; detecta PowerShell, aplica Bypass só ao processo e abre a interface |
| `Iniciar-PC-Optimizer.ps1` | Motor interno do launcher; valida arquivos, prepara `Dados/`, aplica modo STA e oferece `-SelfTest` |
| `Otimizador-GUI.ps1` | Interface WPF |
| `Otimizar-PC.ps1` | Console legado/avançado |
| `Modules/` | Núcleo, limpeza, catálogo, preferências, privacidade, ajustes e diagnósticos |
| `UI/MainWindow.xaml` | Layout da interface |
| `Data/cleanup-rules.json` | Catálogo declarativo de limpeza |
| `config/optimizer.psd1` | Políticas de retenção e proteção |
| `Tools/` | Diagnósticos de rede e eventos |
| `Dados/` | Preferências, logs e estado local |

## Build

```powershell
pwsh -NoProfile -File .\Tools\Build-Portable.ps1
```

Saídas:

```text
dist/PC-Optimizer-Portable-4.5/
dist/PC-Optimizer-Portable-4.5.zip
dist/PC-Optimizer-Portable-4.5.zip.sha256
```

O script:

1. valida sintaxe PowerShell e XAML (`Tests/Validate-Syntax.ps1`);
2. copia uma lista explícita de runtime, sem `Tests/`, `.git/`, arquivos `.bat` ou artefatos locais;
3. compila o `PC-Optimizer.exe` a partir de `Tools/Portable/Launcher` no Windows;
4. gera `VERSION.txt` e `SHA256SUMS.txt`;
5. valida a árvore e executa o self-test do pacote no Windows;
6. cria o ZIP e o checksum SHA-256.

## CI e release

- `Tests/Portable.Smoke.ps1` valida estrutura, hashes, ZIP e self-test.
- O job `lint` executa esse smoke em cada push/PR.
- O workflow de release usa `Tools/Build-Portable.ps1` e publica
  `PC-Optimizer-Portable-<versão>.zip` com o `.sha256` correspondente.

## Modo portátil de dados

O launcher define:

```text
PC_OPTIMIZER_PORTABLE=1
PC_OPTIMIZER_PORTABLE_DATA=<pacote>\Dados
PC_OPTIMIZER_LOG_DIR=<pacote>\Dados\Logs
PC_OPTIMIZER_HOME=<pacote>
```

`Modules/Optimizer.Preferences.psm1` usa `PC_OPTIMIZER_PORTABLE_DATA` quando
presente. Se `Dados/` não for gravável, o launcher muda para
`%TEMP%\PCOptimizer-Portable`. Nenhum caminho de cliente é persistido nas
preferências ou nos logs estruturados.

## Limitações

- O pacote não é assinado com Authenticode; o Windows pode exibir SmartScreen.
- Recursos que alteram o sistema continuam exigindo confirmação e, em alguns
  casos, elevação.
- A pasta `dist/` é ignorada pelo Git e não deve ser versionada.
