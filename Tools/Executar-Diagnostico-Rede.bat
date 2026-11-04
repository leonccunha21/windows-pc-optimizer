@echo off
setlocal
cd /d "%~dp0.."
title PC Optimizer - Diagnostico de Rede
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Diagnostico-Rede.ps1"
echo.
echo Pressione qualquer tecla para fechar.
pause >nul
