@echo off
setlocal
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Solicitando permisos de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

if exist "%~dp0sibelius_reset.ps1" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sibelius_reset.ps1" -Force
) else if exist "C:\ProgramData\Avid\SibeliusReset\sibelius_reset.ps1" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\Avid\SibeliusReset\sibelius_reset.ps1" -Force
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "iex ((Invoke-WebRequest 'https://raw.githubusercontent.com/Chugeno/Sibelius-Auto-Reset/main/install.ps1' -UseBasicParsing).Content)"
)

pause
exit /b

