# Matriz de validação função por função

Validação executada no Windows 10 (PowerShell 5.1/WPF) contra HEAD `f18f631` e pacote portátil assinado. Operações de aplicação usam confirmação; a validação usa `-WhatIf` ou fixture descartável.

| Função/área | Operação validada | Resultado esperado | Evidência |
|---|---|---|---|
| Diagnóstico | `Get-OptimizerDiagnostics` via GUI `Start-Work 'Diagnose'` | Grids preenchidas com linhas | `ValidateUI` passou; 25 linhas em execução read-only |
| Bateria | `Get-OptimizerBatteryHealth` via GUI `Health` | `BatteryGrid` com linhas | `ValidateUI` passou; nesta máquina saúde 40,5% |
| Disco/HD | `Get-OptimizerDiskHealth` via GUI `Health` | `DiskGrid` e `VolumeGrid` com linhas | `ValidateUI` passou; 3 discos e 3 volumes |
| Drivers | `Get-OptimizerDrivers` via GUI `Drivers` | `DriverGrid` com linhas | `ValidateUI` passou |
| DriverUpdates | `Get-OptimizerDriverUpdates` via GUI `DriverUpdates` | Objeto com `Updates` (pode ser vazio) | `ValidateUI` passou; nesta máquina 0 atualizações |
| Aplicativos | `Get-OptimizerAppInventory` via GUI `Appx` | `AppxGrid` com linhas no PS 5.1 | `ValidateUI` passou; PS 7 retorna vazio sem lançar erro |
| Limpeza scan/clean | `Scan`/`Clean` com fixture temporária | 1 arquivo detectado e removido; botões atualizados | `ValidateUI` passou |
| Bancada | `Inspect` Processos/Startup/Software/Network/Updates/Storage | Linhas por área | `FunctionValidation` e `ValidateUI` passaram |
| Rede snapshot | `NetworkSnapshot` sem revelar endereços | `NetworkGrid` com linhas | `ValidateUI` passou; 20 registros |
| NetworkProbe | `localhost` + `127.0.0.1:135` | Linhas DNS/TCP | Passou em execução read-only local |
| Eventos | `Events` 14 dias | Resumo preenchido | `ValidateUI` passou; 229 examinados |
| Otimizações | Todas com `-WhatIf` | Status `Simulado` | `FunctionValidation` passou |
| Privacidade | Todas com `-WhatIf`; presets Basic/Strict/Extreme conferem com catálogo | Sucesso simulado; IDs conhecidos | `FunctionValidation` passou |
| Ajustes/Tweaks | Todos com `-WhatIf`; botões DNS selecionam apenas o DNS escolhido | Sucesso simulado; seleção exata | `FunctionValidation` + cliques `ValidateUI` passaram |
| Assistente local | `Agent` via GUI | Recomendações e resumo preenchidos; sem auto-apply | `ValidateUI` + `Agent.Smoke` passaram |
| Relatório bateria | `Save-OptimizerBatteryReport` para temp | Arquivo HTML criado | 34.086 bytes nesta máquina |
| Relatório manutenção | `Export-OptimizerReport` HTML/JSON | Arquivos criados; JSON sem caminho de usuário | Passou em temp |
| Repair console | `Repair.Tools.ps1` allowlist/sintaxe e wiring dos botões | Modos mapeados; comandos elevados não executados na validação | `FunctionValidation` + `ValidateUI` wiring passaram |
| Preferências | `Preferences.Smoke` | Defaults/persistência/privacidade | Passou |
| Portable | `Portable.Smoke`, self-test do EXE, `-ValidateUI` no pacote extraído | Estrutura, hashes, ZIP e UI válidos; sem `.bat` | Passou |

Limites conhecidos:

- SMART completo (temperatura/horas) requer administrador; sem elevação esses campos aparecem como `-`, mas mídia/avaliação/tamanho/volumes aparecem.
- `Get-OptimizerAppInventory` no PowerShell 7 pode retornar vazio quando o Appx não está disponível; no Windows PowerShell 5.1 retorna o inventário.
- Repair (`SFC`/`DISM`/`CHKDSK`) exige UAC e não foi executado na validação automática; apenas wiring/allowlist foram validados.
- Assinatura atual é self-signed (`CN=PC Optimizer Portable`); SmartScreen pode mostrar editor desconhecido até usar certificado de CA.
