@echo off
REM ========================================
REM Windows PC Optimizer - Portable Demo
REM ========================================

TITLE Windows PC Optimizer - Portable Version Demo

ECHO.
ECHO =====================================================
ECHO   Windows PC Optimizer - Portable Version Demo
ECHO   Versão: 4.0 Portable Edition
ECHO   Lançamento: 2026-11-04
ECHO =====================================================
ECHO.

ECHO Este é um DEMONSTRATION do novo Windows PC Optimizer
ECHO Versão Portátil - Funciona a partir de qualquer unidade USB!
ECHO.
ECHO TODOS os passos para começar:
ECHO.
ECHO 1. Extraia este ZIP para um pen drive USB
ECHO 2. Clique duas vezes neste script a partir da pasta extraída
ECHO 3. Siga as instruções na tela
ECHO.
ECHO Características principais da versão portátil:
ECHO   ✅ Sem instalação - apenas copie e execute
ECHO   ✅ Funciona em qualquer computador
ECHO   ✅ Sem alterações no registro
ECHO   ✅ Sem configurações persistentes
ECHO   ✅ Interface gráfica completa
ECHO   ✅ Todas as otimizações disponíveis
ECHO.
ECHO PARA COMEÇAR AGORA:
ECHO.
ECHO [1] Executar o otimizador portátil
ECHO [2] Ver documentação de ajuda
ECHO [3] Sair
ECHO.
SET /P CHOICE=Escolha uma opção (1-3): 

IF "%CHOICE%"=="1" (
    ECHO.
    ECHO Executando o otimizador portátil...
    ECHO.
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Otimizador-GUI.ps1"
    ECHO.
    ECHO Otimizador finalizado!
    PAUSE
    EXIT /B 0
)

IF "%CHOICE%"=="2" (
    ECHO.
    ECHO Abrindo documentação...
    ECHO.
    if exist "README-PORTABLE.md" (
        start "README-PORTABLE.md" "README-PORTABLE.md"
    ) else (
        echo README-PORTABLE.md não encontrado!
    )
    PAUSE
    EXIT /B 0
)

IF "%CHOICE%"=="3" (
    ECHO.
    ECHO Obrigado por experimentar o Windows PC Optimizer Portátil!
    ECHO.
    EXIT /B 0
)

ECHO.
ECHO Opção inválida. Por favor, execute novamente.
PAUSE
EXIT /B 1