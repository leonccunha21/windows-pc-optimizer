# Windows PC Optimizer

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6.svg)](https://www.microsoft.com/windows)
[![Version](https://img.shields.io/badge/version-3.1.0-brightgreen.svg)](CHANGELOG.md)

> Ferramenta completa de otimização e manutenção de PC para Windows 10/11.
> Limpa lixo, otimiza desempenho, diagnostica hardware e gera relatórios — **sem tocar em projetos, código-fonte ou arquivos do Epic Games/Fortnite**.

---

## ✨ Destaques

- 🛡️ **Seguro**: nunca remove projetos, código-fonte, `.git`, Epic Games ou Fortnite
- 🎨 **GUI moderna** (WinForms) com tema escuro e barra de progresso
- 📊 **Relatório HTML** com métricas de disco, sistema e log
- 🔧 **28 opções** de otimização + modo "Executar TUDO"
- 🧪 **22 testes automatizados** (Pester) — todos passando
- 🔄 **Self-update** e **auto-push** para GitHub
- 📅 **Agendamento semanal** via Task Scheduler
- 🖥️ **Diagnóstico profissional** (SMART, drivers, updates, portas, tarefas suspeitas)

---

## 📦 O que faz

### Limpeza
- Temporários (≥7 dias)
- Caches de navegadores (Chrome, Edge, Firefox, Brave, Opera, Vivaldi)
- Caches de pacotes (npm, pnpm, pip, Gradle, Maven, Cargo, Go, NuGet, Playwright, Cypress)
- Caches de aplicativos (Spotify, Discord, Slack, Teams, OneDrive, VS Code)
- Caches de sistema (Store, OneDrive logs)
- Caches de disco (WinSxS, prefetch, ícones, miniaturas, fontes)
- Logs de eventos do Windows

### Otimização
- Plano de energia → Alto Desempenho
- Desativa telemetria, SysMain, Delivery Optimization
- Efeitos visuais → melhor desempenho
- Transparência, Cortana, sugestões desativadas
- Pagefile fixo em 8 GB
- TRIM (SSD) / Desfragmentação (HDD) — auto-detecta
- TCP auto-tuning (modo agressivo)

### Diagnóstico e reparo
- Informações de hardware (CPU, RAM, GPU, placa-mãe, BIOS)
- Saúde do disco (SMART)
- Drivers com problemas
- Atualizações pendentes do Windows
- Portas abertas e tarefas agendadas suspeitas
- Reparo do Windows Update, Store e rede

### Manutenção avançada
- Desinstalar bloatware UWP (lista segura)
- Busca de arquivos duplicados, grandes e antigos
- Backup de drivers e registro
- Agendamento semanal
- Relatório HTML

---

## 🚀 Como usar

1. Copie a pasta (ou o `.zip`) para o PC alvo.
2. Clique com o **botão direito** em `Executar-Otimizador.bat` → **"Executar como administrador"**.
3. Escolha a opção **25 (Executar TUDO)** ou opções individuais.

### GUI
Execute `Otimizador-GUI.ps1` como administrador para interface gráfica com checkboxes, barra de progresso e tema escuro.

### Linha de comando
```powershell
.\Otimizar-PC.ps1 -Auto                              # tudo, sem perguntas
.\Otimizar-PC.ps1 -Auto -Mode Aggressive             # modo agressivo
.\Otimizar-PC.ps1 -Auto -DryRun                      # simulação (seguro)
.\Otimizar-PC.ps1 -Auto -SkipLong                    # pula SFC/DISM
.\Otimizar-PC.ps1 -Auto -Report -AutoPush            # gera relatório e envia ao GitHub
.\Otimizar-PC.ps1 -Schedule                          # agenda limpeza semanal
.\Otimizar-PC.ps1 -SelfUpdate                        # atualiza o script
```

---

## 🛡️ Garantias de segurança

- ✅ **Epic Games / Fortnite**: nunca removidos
- ✅ **Projetos / código-fonte**: nunca tocados
- ✅ **`.git`**: nunca removido
- ✅ **Downloads protegidos** (Storage Sense não limpa Downloads)
- ✅ **Backup automático** de registro antes de mudanças
- ✅ **Ponto de restauração** automático
- ✅ **DryRun** para simular antes de executar
- ✅ **Logs** de todas as ações em `%TEMP%\OtimizadorPC_log.txt`

---

## 📁 Estrutura do projeto

```
windows-pc-optimizer/
├── Otimizar-PC.ps1          # Script principal (menu + auto + CLI)
├── Otimizador-GUI.ps1       # Interface gráfica (WinForms)
├── Executar-Otimizador.bat  # Launcher (executar como admin)
├── README.md
├── LEIA-ME.txt
├── LICENSE                  # MIT
├── CHANGELOG.md
├── CONTRIBUTING.md
├── .editorconfig
├── .github/workflows/lint.yml
└── Tests/Optimizer.Tests.ps1
```

---

## 🧪 Testes

```powershell
Invoke-Pester -Path './Tests'
# Passed: 22 Failed: 0
```

---

## 🔗 Links

- **Repositório:** https://github.com/leonccunha21/windows-pc-optimizer
- **Último commit:** v3.1.0

---

## 📝 Licença

MIT — veja [LICENSE](LICENSE).

---

## 🤝 Contribuindo

Veja [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 🔗 Ferramentas externas recomendadas

| Ferramenta | Link |
|---|---|
| AdwCleaner | https://www.malwarebytes.com/adwcleaner |
| Malwarebytes | https://www.malwarebytes.com/ |
| CrystalDiskInfo | https://crystalmark.info/en/software/crystaldiskinfo/ |
| HWiNFO | https://www.hwinfo.com/ |
| BleachBit | https://www.bleachbit.org/ |
| Revo Uninstaller | https://www.revouninstaller.com/ |
| Everything | https://www.voidtools.com/ |
| CCleaner | https://www.ccleaner.com/ |
