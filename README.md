# Windows PC Optimizer

A PowerShell-based PC optimizer for Windows 10/11. Cleans junk, optimizes startup, tweaks system settings, and frees disk space — without touching Epic Games / Fortnite files.

## Features

- **Clean temporary files** (older than 7 days)
- **Clean browser caches** (Chrome / Edge)
- **Clean package manager caches** (npm, pnpm, pip, Playwright, Cypress)
- **Clean project build artifacts** (node_modules, build, dist, .next, .gradle, .venv, __pycache__, and more)
- **Optimize startup** (remove non-essential programs from boot)
- **System tweaks** (High Performance power plan, disable telemetry, SysMain, Delivery Optimization, visual effects, pagefile)
- **SSD TRIM**
- **Clear event logs**
- **Disable background apps**
- **Disk Cleanup (cleanmgr)**
- **Flush DNS + Winsock reset**
- **Enable Storage Sense** (auto cleanup, downloads protected)
- **System integrity check (SFC + DISM)** in background
- **Windows Defender full scan** in background

## Safety

- **Epic Games / Fortnite files are never removed** (protected paths).
- Source code files (`.py`, `.js`, `.ts`, `.cs`, etc.) are preserved.
- Only build artifacts and caches are removed.
- Registry backup is created automatically.
- `DryRun` mode available to preview changes without executing.

## Requirements

- Windows 10 / 11
- PowerShell 5.1+
- Run as Administrator

## Usage

1. Copy the folder to the target PC.
2. Right-click `Executar-Otimizador.bat` → **Run as administrator**.
3. Choose option **15 (Run ALL)** for a full optimization, or individual options.

### Advanced (command line)

```powershell
.\Otimizar-PC.ps1 -Auto                              # all, no prompts
.\Otimizar-PC.ps1 -Auto -ProjectsPath "C:\Users\X\Documents"  # + clean project junk
.\Otimizar-PC.ps1 -Auto -DryRun                      # simulation (safe)
.\Otimizar-PC.ps1 -Auto -SkipLong                     # skip SFC/DISM
```

## Log

All actions are logged to `%TEMP%\OtimizadorPC_log.txt`.

## License

MIT
