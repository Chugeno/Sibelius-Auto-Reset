@echo off
:: ============================================================
:: Instalador - Reset automatico de Sibelius Ultimate (29 dias)
:: Debe ejecutarse con permisos de Administrador
:: Version 1.2 - Instalador simplificado (copia script separado)
:: ============================================================
setlocal EnableDelayedExpansion

:: Verificar si se ejecuta como Administrador
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Este script debe ejecutarse como Administrador.
    echo Clic derecho sobre el archivo ^> "Ejecutar como administrador".
    pause
    exit /b 1
)

:: Verificar que Sibelius esta instalado
if not exist "%ProgramFiles%\Avid\Sibelius" (
    if not exist "%ProgramFiles(x86)%\Avid\Sibelius" (
        echo [WARNING] Sibelius no encontrado en Program Files.
        set /p CONTINUE="^¿Continuar de todos modos? (s/n): "
        if /i "!CONTINUE!" neq "s" (
            echo [INFO] Instalacion cancelada.
            exit /b 0
        )
    )
)

echo.
echo [INFO] Configurando reset automatico de Sibelius Ultimate...
echo.

:: --- Paths ---
set "INSTALL_DIR=%ProgramData%\Avid\SibeliusReset"
set "RESET_SCRIPT=%INSTALL_DIR%\sibelius_reset.bat"
set "UNINSTALL_SCRIPT=%INSTALL_DIR%\sibelius_uninstall.bat"
set "LOG_FILE=%INSTALL_DIR%\logs\sibelius_reset.log"
set "TIMESTAMP_FILE=%INSTALL_DIR%\.last_reset"
set "TASK_NAME=SibeliusAutoReset"

:: Obtener el directorio donde esta este instalador
set "SCRIPT_DIR=%~dp0"

:: Verificar que sibelius_reset.bat existe junto al instalador
if not exist "%SCRIPT_DIR%sibelius_reset.bat" (
    echo [ERROR] No se encontro sibelius_reset.bat en la misma carpeta que este instalador.
    echo Asegurate de que ambos archivos esten juntos.
    pause
    exit /b 1
)

:: Crear directorios
mkdir "%INSTALL_DIR%\logs" 2>nul
echo [SUCCESS] Directorio de instalacion: %INSTALL_DIR%

:: Copiar el script de reset al directorio de instalacion
copy /y "%SCRIPT_DIR%sibelius_reset.bat" "%RESET_SCRIPT%" >nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] No se pudo copiar sibelius_reset.bat a %RESET_SCRIPT%
    pause
    exit /b 1
)
echo [SUCCESS] Script de reset instalado en: %RESET_SCRIPT%

:: ============================================================
:: Registrar tarea en Task Scheduler
:: ============================================================
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

powershell -NoProfile -Command ^
    "try {" ^
    "  $action   = New-ScheduledTaskAction -Execute '%RESET_SCRIPT%';" ^
    "  $trigger  = New-ScheduledTaskTrigger -Daily -At '03:00AM';" ^
    "  $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable:$false -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1);" ^
    "  $principal = New-ScheduledTaskPrincipal -UserId ($env:USERDOMAIN + '\' + $env:USERNAME) -RunLevel Limited;" ^
    "  Register-ScheduledTask -TaskName '%TASK_NAME%' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop | Out-Null;" ^
    "  Write-Host ('[SUCCESS] Tarea registrada para usuario: ' + $env:USERNAME);" ^
    "  exit 0" ^
    "} catch {" ^
    "  Write-Host ('[ERROR] Fallo al registrar la tarea: ' + $_.Exception.Message);" ^
    "  exit 1" ^
    "}"

if %ERRORLEVEL% neq 0 (
    echo [ERROR] No se pudo registrar la tarea en el Programador de tareas.
    pause
    exit /b 1
)

:: ============================================================
:: Crear script de desinstalacion
:: ============================================================
(
echo @echo off
echo net session ^>nul 2^>^&1
echo if %%ERRORLEVEL%% neq 0 ^(
echo     echo [ERROR] Ejecutar como Administrador.
echo     pause
echo     exit /b 1
echo ^)
echo echo Desinstalando reset automatico de Sibelius...
echo schtasks /delete /tn %TASK_NAME% /f
echo rd /s /q "%INSTALL_DIR%"
echo echo [SUCCESS] Desinstalacion completada.
echo pause
) > "%UNINSTALL_SCRIPT%"
echo [SUCCESS] Script de desinstalacion: %UNINSTALL_SCRIPT%

:: ============================================================
:: Resumen
:: ============================================================
echo.
echo ============================================================
echo   INSTALACION COMPLETADA v1.2
echo ============================================================
echo.
echo   * Reset cada 29 dias (chequeo diario a las 3:00 AM)
echo   * Se ejecuta al encender la PC si estuvo apagada mas de 29 dias
echo   * Script: %RESET_SCRIPT%
echo   * Log: %LOG_FILE%
echo   * Desinstalar: %UNINSTALL_SCRIPT%
echo.

:: Ofrecer ejecutar el reset ahora
set /p RUN_NOW="^¿Ejecutar el reset de Sibelius ahora? (s/n): "
if /i "%RUN_NOW%"=="s" (
    echo.
    echo [INFO] Ejecutando reset...
    echo.
    call "%RESET_SCRIPT%"
    echo.
    echo [INFO] Proceso terminado.
    echo [INFO] Log: %LOG_FILE%
    echo.
    pause
) else (
    echo [INFO] Podes ejecutarlo manualmente:
    echo   "%RESET_SCRIPT%"
)

echo.
echo [INFO] Comandos utiles:
echo   * Ver tarea:      schtasks /query /tn %TASK_NAME% /v
echo   * Ejecutar reset: "%RESET_SCRIPT%"
echo   * Ver log:        type "%LOG_FILE%"
echo   * Forzar reset:   del "%TIMESTAMP_FILE%" ^&^& "%RESET_SCRIPT%"
echo.

pause
endlocal
