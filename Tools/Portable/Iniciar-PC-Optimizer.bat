@echo off
setlocal EnableExtensions
title PC Optimizer - Portable
cd /d "%~dp0"

if not exist "%~dp0Iniciar-PC-Optimizer.ps1" goto :missing
if not exist "%~dp0Otimizador-GUI.ps1" goto :missing

set "PS_EXE=powershell.exe"
where powershell.exe >nul 2>&1
if errorlevel 1 (
    set "PS_EXE=pwsh.exe"
    where pwsh.exe >nul 2>&1
    if errorlevel 1 goto :nops
)

"%PS_EXE%" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Iniciar-PC-Optimizer.ps1" %*
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo PC Optimizer encerrou com codigo %RC%.
    echo Consulte a pasta Dados\Logs para detalhes.
    echo.
    pause
)

exit /b %RC%

:missing
echo.
echo ERRO: arquivos do PC Optimizer nao encontrados.
echo Extraia o ZIP completo e execute este arquivo a partir da pasta extraida.
echo.
pause
exit /b 2

:nops
echo.
echo ERRO: PowerShell nao encontrado.
echo O Windows 10/11 inclui o Windows PowerShell 5.1; reative-o ou instale o PowerShell 7.
echo.
pause
exit /b 3
