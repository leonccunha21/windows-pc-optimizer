@echo off
:: Launcher para Otimizar-PC.ps1
:: Execute como Administrador
title Otimizador de PC
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Otimizar-PC.ps1"
pause
