@echo off
:: ============================================================
:: Instalador - Reset automatico de Sibelius Ultimate (29 dias)
:: Debe ejecutarse con permisos de Administrador
:: Version 1.1 - Fix generacion de script con logica de fechas
:: ============================================================
setlocal EnableDelayedExpansion

:: Verificar si se ejecuta como Administrador
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Este script debe ejecutarse como Administrador.
    echo Clic derecho ^> "Ejecutar como administrador".
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

mkdir "%INSTALL_DIR%\logs" 2>nul
echo [SUCCESS] Directorio de instalacion: %INSTALL_DIR%

:: ============================================================
:: Crear sibelius_reset.bat
:: NOTA: Se usa redirección línea a línea para evitar problemas
::       con el heredoc y la sintaxis de FOR con PowerShell.
:: ============================================================
(
echo @echo off
echo setlocal EnableDelayedExpansion
echo.
echo set "LOG_FILE=%LOG_FILE%"
echo set "TIMESTAMP_FILE=%TIMESTAMP_FILE%"
echo set "INSTALL_DIR=%INSTALL_DIR%"
echo set "DO_RESET=false"
echo.
echo echo %%DATE%% %%TIME%% - Iniciando chequeo ^>^> "%%LOG_FILE%%"
echo.
echo :: --- Logica de 29 dias ---
echo if not exist "%%TIMESTAMP_FILE%%" (
echo     echo %%DATE%% %%TIME%% - Primer run, forzando reset ^>^> "%%LOG_FILE%%"
echo     set "DO_RESET=true"
echo ^) else (
echo     :: Calcular dias usando PowerShell, escribir resultado a archivo temp
echo     powershell -NoProfile -Command "$last=[datetime]::ParseExact((Get-Content '%%TIMESTAMP_FILE%%').Trim(),'yyyyMMdd',$null); ((Get-Date)-$last).Days" ^> "%%TEMP%%\sib_days.tmp" 2^>^&1
echo     set /p DAYS_SINCE= ^< "%%TEMP%%\sib_days.tmp"
echo     del "%%TEMP%%\sib_days.tmp" 2^>nul
echo     echo %%DATE%% %%TIME%% - Dias desde ultimo reset: %%DAYS_SINCE%% ^>^> "%%LOG_FILE%%"
echo     if !DAYS_SINCE! GEQ 29 (
echo         set "DO_RESET=true"
echo         echo %%DATE%% %%TIME%% - Ejecutando reset (%%DAYS_SINCE%% dias transcurridos^) ^>^> "%%LOG_FILE%%"
echo     ^) else (
echo         set /a DAYS_LEFT=29-!DAYS_SINCE!
echo         echo %%DATE%% %%TIME%% - No es necesario aun. Proximo reset en !DAYS_LEFT! dias ^>^> "%%LOG_FILE%%"
echo         exit /b 0
echo     ^)
echo ^)
echo.
echo :: --- Ejecutar reset ---
echo if "!DO_RESET!"=="true" (
echo     :: Guardar fecha de hoy
echo     powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd'" ^> "%%TIMESTAMP_FILE%%"
echo.
echo     :: Borrar carpetas del sistema (compartidas, requieren admin^)
echo     if exist "%ProgramFiles(x86)%\APi1"                               rd /s /q "%ProgramFiles(x86)%\APi1" 2^>^&1
echo     if exist "%ProgramData%\Avid\Sibelius\_manuscript\ACr2"           rd /s /q "%ProgramData%\Avid\Sibelius\_manuscript\ACr2" 2^>^&1
echo     if exist "%ProgramData%\Avid\Sibelius\_manuscript\Plugins_v2"     rd /s /q "%ProgramData%\Avid\Sibelius\_manuscript\Plugins_v2" 2^>^&1
echo.
echo     :: Borrar carpeta del perfil del usuario actual
echo     if exist "%%APPDATA%%\Avid\Sibelius\_manuscript\HEa3"             rd /s /q "%%APPDATA%%\Avid\Sibelius\_manuscript\HEa3" 2^>^&1
echo.
echo     :: Resetear clave de registro del usuario actual
echo     REG ADD "HKCU\Software\Avid\Sibelius\SibeliusTierSelection" /v TrialDialogSavedChoice /t REG_DWORD /d 3 /f ^>nul 2^>^&1
echo.
echo     echo %%DATE%% %%TIME%% - Reset completado exitosamente ^>^> "%%LOG_FILE%%"
echo     echo [SUCCESS] Reset de Sibelius completado.
echo ^) else (
echo     echo [INFO] No se requiere reset aun.
echo ^)
echo endlocal
) > "%RESET_SCRIPT%"

echo [SUCCESS] Script de reset creado: %RESET_SCRIPT%

:: ============================================================
:: Registrar tarea en Task Scheduler
:: ============================================================
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

powershell -NoProfile -Command ^
    "try {" ^
    "  $action = New-ScheduledTaskAction -Execute '%RESET_SCRIPT%';" ^
    "  $trigger = New-ScheduledTaskTrigger -Daily -At '03:00AM';" ^
    "  $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable:$false -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1);" ^
    "  $principal = New-ScheduledTaskPrincipal -UserId ($env:USERDOMAIN + '\' + $env:USERNAME) -RunLevel Limited;" ^
    "  Register-ScheduledTask -TaskName '%TASK_NAME%' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop | Out-Null;" ^
    "  Write-Host '[SUCCESS] Tarea registrada para usuario: ' + $env:USERNAME;" ^
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
echo if %%ERRORLEVEL%% neq 0 (
echo     echo [ERROR] Ejecutar como Administrador.
echo     pause ^& exit /b 1
echo ^)
echo echo Desinstalando reset automatico de Sibelius...
echo schtasks /delete /tn "%TASK_NAME%" /f ^>nul 2^>^&1
echo rd /s /q "%INSTALL_DIR%" 2^>nul
echo echo [SUCCESS] Desinstalacion completada.
echo pause
) > "%UNINSTALL_SCRIPT%"

echo [SUCCESS] Script de desinstalacion: %UNINSTALL_SCRIPT%

:: ============================================================
:: Resumen
:: ============================================================
echo.
echo ============================================================
echo   INSTALACION COMPLETADA v1.1
echo ============================================================
echo.
echo   * Reset cada 29 dias (chequeo diario a las 3:00 AM)
echo   * Corre al encender la PC si estuvo apagada mas de 29 dias
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
    echo [INFO] Proceso terminado. Log completo:
    echo   %LOG_FILE%
    echo.
    pause
) else (
    echo [INFO] Podes ejecutarlo manualmente:
    echo   "%RESET_SCRIPT%"
)

echo.
echo [INFO] Comandos utiles:
echo   * Ver tarea:       schtasks /query /tn %TASK_NAME% /v
echo   * Ejecutar reset:  "%RESET_SCRIPT%"
echo   * Ver log:         type "%LOG_FILE%"
echo   * Forzar reset:    del "%TIMESTAMP_FILE%" ^&^& "%RESET_SCRIPT%"
echo.

pause
endlocal
