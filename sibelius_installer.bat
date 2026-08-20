@echo off
:: ============================================================
:: Lanzador - Reset automatico de Sibelius Ultimate
:: Compatible con Windows 10 y Windows 11
:: ============================================================
setlocal

:: Auto-elevar a Administrador si es necesario
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Solicitando permisos de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

:: Ejecutar install.ps1 con ExecutionPolicy Bypass
if exist "%~dp0install.ps1" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "iex ((Invoke-WebRequest 'https://raw.githubusercontent.com/Chugeno/Sibelius-Auto-Reset/main/install.ps1' -UseBasicParsing).Content)"
)

exit /b

