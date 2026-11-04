@echo off
setlocal
cd /d "%~dp0"
title PC Optimizer - Central de manutencao
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Otimizador-GUI.ps1"
if errorlevel 1 (
  echo.
  echo Nao foi possivel abrir o PC Optimizer. Confira a mensagem acima.
  pause
)
endlocal
