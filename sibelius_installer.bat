@echo off
:: ============================================================
:: Instalador - Reset automatico de Sibelius Ultimate (29 dias)
:: Debe ejecutarse con permisos de Administrador
:: Version 2.0 - Reset en PowerShell (sin limitaciones de CMD)
:: ============================================================
setlocal EnableDelayedExpansion

net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Ejecutar como Administrador (clic derecho ^> Ejecutar como administrador^)
    timeout /t 10 /nobreak >nul
    exit /b 1
)

if not exist "%ProgramFiles%\Avid\Sibelius" (
    if not exist "%ProgramFiles(x86)%\Avid\Sibelius" (
        echo [WARNING] Sibelius no encontrado en Program Files.
        set /p CONTINUE="^¿Continuar de todos modos? (s/n): "
        if /i "!CONTINUE!" neq "s" (
            echo [INFO] Cancelado.
            exit /b 0
        )
    )
)

echo.
echo [INFO] Instalando reset automatico de Sibelius Ultimate v2.0...
echo.

set "INSTALL_DIR=%ProgramData%\Avid\SibeliusReset"
set "RESET_PS1=%INSTALL_DIR%\sibelius_reset.ps1"
set "UNINSTALL_SCRIPT=%INSTALL_DIR%\sibelius_uninstall.bat"
set "LOG_FILE=%INSTALL_DIR%\logs\sibelius_reset.log"
set "TASK_NAME=SibeliusAutoReset"
set "SCRIPT_DIR=%~dp0"

if not exist "%SCRIPT_DIR%sibelius_reset.ps1" (
    echo [ERROR] No se encontro sibelius_reset.ps1 en la misma carpeta que este instalador.
    timeout /t 15 /nobreak >nul
    exit /b 1
)

mkdir "%INSTALL_DIR%\logs" 2>nul
echo [SUCCESS] Directorio: %INSTALL_DIR%

copy /y "%SCRIPT_DIR%sibelius_reset.ps1" "%RESET_PS1%" >nul
echo [SUCCESS] Script de reset instalado: %RESET_PS1%

:: Registrar tarea (ejecuta powershell con el .ps1)
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

powershell -NoProfile -Command ^
    "try {" ^
    "  $ps1 = '%RESET_PS1%';" ^
    "  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NonInteractive -ExecutionPolicy Bypass -File \"' + $ps1 + '\"');" ^
    "  $trigger = New-ScheduledTaskTrigger -Daily -At '03:00AM';" ^
    "  $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable:$false -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries;" ^
    "  $principal = New-ScheduledTaskPrincipal -UserId ($env:USERDOMAIN + '\' + $env:USERNAME) -RunLevel Limited;" ^
    "  Register-ScheduledTask -TaskName '%TASK_NAME%' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop | Out-Null;" ^
    "  Write-Host ('[SUCCESS] Tarea registrada para usuario: ' + $env:USERNAME);" ^
    "  exit 0" ^
    "} catch {" ^
    "  Write-Host ('[ERROR] Fallo: ' + $_.Exception.Message);" ^
    "  exit 1" ^
    "}"

if %ERRORLEVEL% neq 0 (
    echo [ERROR] No se pudo registrar la tarea.
    timeout /t 15 /nobreak >nul
    exit /b 1
)

:: Script de desinstalacion
(
echo @echo off
echo net session ^>nul 2^>^&1
echo if %%ERRORLEVEL%% neq 0 ^( echo [ERROR] Ejecutar como Administrador. ^& pause ^& exit /b 1 ^)
echo schtasks /delete /tn %TASK_NAME% /f
echo rd /s /q "%INSTALL_DIR%"
echo echo [SUCCESS] Desinstalado.
echo pause
) > "%UNINSTALL_SCRIPT%"
echo [SUCCESS] Desinstalador: %UNINSTALL_SCRIPT%

echo.
echo ============================================================
echo   INSTALACION COMPLETADA v2.0
echo ============================================================
echo.
echo   * Reset cada 29 dias (chequeo diario a las 3:00 AM)
echo   * Corre al encender si la PC estuvo apagada ^>29 dias
echo   * Script: %RESET_PS1%
echo   * Log: %LOG_FILE%
echo   * Desinstalar: %UNINSTALL_SCRIPT%
echo.

set /p RUN_NOW="^¿Ejecutar el reset ahora? (s/n): "
if /i "%RUN_NOW%"=="s" (
    echo.
    echo [INFO] Ejecutando...
    powershell -NonInteractive -ExecutionPolicy Bypass -File "%RESET_PS1%"
    echo.
    echo [INFO] Contenido del log:
    echo ----------------------------------------
    type "%LOG_FILE%"
    echo ----------------------------------------
    echo.
    echo Presiona cualquier tecla para continuar...
    pause >nul
)

echo [INFO] Comandos utiles:
echo   * Ver tarea:    schtasks /query /tn %TASK_NAME% /v
echo   * Ejecutar:     powershell -ExecutionPolicy Bypass -File "%RESET_PS1%"
echo   * Ver log:      type "%LOG_FILE%"
echo   * Forzar reset: del "%INSTALL_DIR%\last_reset.txt" ^&^& powershell -ExecutionPolicy Bypass -File "%RESET_PS1%"
echo.
echo Presiona cualquier tecla para cerrar...
pause >nul
endlocal
