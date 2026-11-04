@echo off
setlocal
cd /d "%~dp0.."
title PC Optimizer - Historico de Falhas
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Diagnostico-Eventos.ps1"
echo.
echo Pressione qualquer tecla para fechar.
pause >nul
