@echo off
rem Development alias. The standalone package uses Iniciar-PC-Optimizer.bat.
setlocal EnableExtensions
cd /d "%~dp0"
echo.
echo This repository launcher is for development.
echo For the standalone portable package, extract the ZIP and run:
echo   Iniciar-PC-Optimizer.bat
echo.
call "%~dp0Executar-Otimizador.bat" %*
exit /b %ERRORLEVEL%
