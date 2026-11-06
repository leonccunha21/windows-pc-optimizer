@echo off
setlocal EnableExtensions
title PC Optimizer - Portable Helper
cd /d "%~dp0"

:menu
cls
echo =====================================================
echo   PC Optimizer - Portable Helper
echo =====================================================
echo.
echo   [1] Run the interface from this repository
echo   [2] Build the standalone portable ZIP
echo   [3] Open portable documentation
echo   [4] Exit
echo.
set "CHOICE="
set /p CHOICE=Choose an option (1-4): 

if "%CHOICE%"=="1" goto :run
if "%CHOICE%"=="2" goto :build
if "%CHOICE%"=="3" goto :docs
if "%CHOICE%"=="4" goto :end
echo.
echo Invalid option.
pause
goto :menu

:run
echo.
call "%~dp0Executar-Otimizador.bat" %*
goto :menu

:build
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Tools\Build-Portable.ps1"
echo.
pause
goto :menu

:docs
echo.
if exist "%~dp0README-PORTABLE.md" (
    start "" "%~dp0README-PORTABLE.md"
) else (
    echo README-PORTABLE.md not found.
)
pause
goto :menu

:end
endlocal
exit /b 0
