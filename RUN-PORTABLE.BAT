@echo off
REM ========================================
REM Windows PC Optimizer - Portable Launcher
REM ========================================

TITLE Windows PC Optimizer - Portable Version

ECHO.
ECHO =====================================================
ECHO   Windows PC Optimizer - Portable Version
ECHO   Execute by: %USERPROFILE%
ECHO   Date: %DATE% %TIME%
ECHO =====================================================
ECHO.

REM Check if we're running from the correct location
if not exist "%~dp0Otimizador-GUI.ps1" (
    echo ERRO: Otimizador-GUI.ps1 n�o encontrado em %~dp0
    echo Certifique-se de que este script est� sendo executado a partir da pasta do otimizador.
    echo.
    echo Instru��es:
    echo 1. Extraia este conte�do para uma pasta chamada "windows-pc-optimizer"
    echo 2. Clique duas vezes neste script a partir dessa pasta
    echo 3. Ou execute o "Executar-Otimizador.bat" a partir dessa pasta
    echo.
    pause
    exit /b 1
)

REM Check for PowerShell availability
powershell.exe -NoProfile -Command "Write-Host 'PowerShell encontrado'" >nul 2>&1
if errorlevel 1 (
    echo ERRO: PowerShell n�o est� dispon�vel neste sistema.
    echo Por favor, certifique-se de que o Windows 10 ou superior est� instalado.
    echo.
    pause
    exit /b 1
)

REM Set PowerShell execution policy
powershell.exe -NoProfile -Command "
    try {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Write-Host 'Pol�tica de execu��o configurada para Bypass'
    } catch {
        Write-Host 'Aviso: N�o foi poss�vel definir a pol�tica de execu��o'
    }
" >nul 2>&1

REM Clear any existing PowerShell processes that might interfere
powershell.exe -NoProfile -Command "
    Get-Process -Name pwsh, powershell -ErrorAction SilentlyContinue | Where-Object { \$_.Id -ne \$PID } | Stop-Process -Force -ErrorAction SilentlyContinue
" >nul 2>&1

ECHO.
ECHO Iniciando Windows PC Optimizer...
ECHO.

REM Run the main GUI application
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Otimizador-GUI.ps1"

if errorlevel 1 (
    echo.
    echo ERRO: O otimizador encontrou um erro durante a execu��o.
    echo Verifique a sa�da acima para mais detalhes.
    echo.
    pause
) else (
    echo.
    echo Otimizador finalizado com sucesso!
    echo.
    pause
)

exit /b 0