@echo off
:: ============================================================
:: Instalador - Reset automático de Sibelius Ultimate (29 días)
:: Debe ejecutarse con permisos de Administrador
:: Versión 1.0
:: ============================================================
setlocal EnableDelayedExpansion

:: --- Colores via PowerShell (encapsulado en funciones al final) ---

:: Verificar si se ejecuta como Administrador
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Este script debe ejecutarse como Administrador.
    echo Hacé clic derecho sobre el archivo y elegí "Ejecutar como administrador".
    pause
    exit /b 1
)

:: Verificar que Sibelius está instalado
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
echo [INFO] Configurando reset automático de Sibelius Ultimate...
echo.

:: --- Directorios y archivos ---
set "INSTALL_DIR=%ProgramData%\Avid\SibeliusReset"
set "RESET_SCRIPT=%INSTALL_DIR%\sibelius_reset.bat"
set "UNINSTALL_SCRIPT=%INSTALL_DIR%\sibelius_uninstall.bat"
set "LOG_DIR=%INSTALL_DIR%\logs"
set "TASK_NAME=SibeliusAutoReset"

:: Crear directorios
mkdir "%INSTALL_DIR%" 2>nul
mkdir "%LOG_DIR%" 2>nul
echo [SUCCESS] Directorio de instalacion: %INSTALL_DIR%

:: ============================================================
:: Crear el script de reset principal
:: ============================================================
(
echo @echo off
echo :: Script de reset de Sibelius Ultimate ^(cada 29 dias^)
echo :: Generado automaticamente por sibelius_installer.bat v1.0
echo setlocal EnableDelayedExpansion
echo.
echo set "LOG_FILE=%LOG_DIR%\sibelius_reset.log"
echo set "TIMESTAMP_FILE=%INSTALL_DIR%\.last_reset"
echo set "DO_RESET=false"
echo.
echo echo %%DATE%% %%TIME%% - Iniciando chequeo de reset de Sibelius Ultimate ^>^> "%%LOG_FILE%%"
echo.
echo :: --- Lógica de 29 días ---
echo if not exist "%%TIMESTAMP_FILE%%" ^(
echo     echo %%DATE%% %%TIME%% - Primer run, forzando reset ^>^> "%%LOG_FILE%%"
echo     set "DO_RESET=true"
echo ^) else ^(
echo     for /f %%A in ^('powershell -NoProfile -Command "
echo         $last = [datetime]::ParseExact^(^(Get-Content '%%TIMESTAMP_FILE%%'^).Trim^(^), 'yyyyMMdd', $null^);
echo         $diff = ^(^(Get-Date^) - $last^).Days;
echo         Write-Output $diff"'^) do set DAYS_SINCE=%%A
echo.
echo     if !DAYS_SINCE! GEQ 29 ^(
echo         echo %%DATE%% %%TIME%% - Han pasado !DAYS_SINCE! dias: ejecutando reset ^>^> "%%LOG_FILE%%"
echo         set "DO_RESET=true"
echo     ^) else ^(
echo         set /a DAYS_LEFT=29-!DAYS_SINCE!
echo         echo %%DATE%% %%TIME%% - Solo !DAYS_SINCE! dias: proximo reset en !DAYS_LEFT! dias ^>^> "%%LOG_FILE%%"
echo         exit /b 0
echo     ^)
echo ^)
echo.
echo :: --- Ejecutar reset ---
echo if "%%DO_RESET%%"=="true" ^(
echo     echo %%DATE%% %%TIME%% - Ejecutando limpieza... ^>^> "%%LOG_FILE%%"
echo.
echo     :: Guardar fecha de hoy como ultimo reset ^(formato yyyyMMdd^)
echo     powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd'" ^> "%%TIMESTAMP_FILE%%"
echo.
echo     :: Borrar carpetas del sistema ^(compartidas^)
echo     if exist "%ProgramFiles(x86)%\APi1"                                        rd /s /q "%ProgramFiles(x86)%\APi1"
echo     if exist "%ProgramData%\Avid\Sibelius\_manuscript\ACr2"                    rd /s /q "%ProgramData%\Avid\Sibelius\_manuscript\ACr2"
echo     if exist "%ProgramData%\Avid\Sibelius\_manuscript\Plugins_v2"              rd /s /q "%ProgramData%\Avid\Sibelius\_manuscript\Plugins_v2"
echo.
echo     :: Borrar carpeta del perfil del usuario que corre la tarea
echo     if exist "%%APPDATA%%\Avid\Sibelius\_manuscript\HEa3"                      rd /s /q "%%APPDATA%%\Avid\Sibelius\_manuscript\HEa3"
echo.
echo     :: Resetear clave de registro del usuario
echo     REG ADD "HKCU\Software\Avid\Sibelius\SibeliusTierSelection" /v TrialDialogSavedChoice /t REG_DWORD /d 3 /f ^>nul 2^>^&1
echo.
echo     echo %%DATE%% %%TIME%% - Reset completado exitosamente ^>^> "%%LOG_FILE%%"
echo     echo [SUCCESS] Reset de Sibelius completado.
echo ^)
echo endlocal
) > "%RESET_SCRIPT%"

echo [SUCCESS] Script de reset creado: %RESET_SCRIPT%

:: ============================================================
:: Registrar tarea en Task Scheduler
:: Corre diariamente a las 3:00 AM, y si se perdió una ejecución
:: (PC apagada), la corre ni bien el usuario inicia sesión.
:: ============================================================

:: Borrar tarea anterior si existe
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

:: Registrar la tarea bajo el usuario actual (evita el problema de nombre de grupo localizado)
:: UserId con USERDOMAIN\USERNAME funciona en cualquier idioma de Windows
powershell -NoProfile -Command ^
    "try {" ^
    "  $action   = New-ScheduledTaskAction -Execute '%RESET_SCRIPT%';" ^
    "  $trigger  = New-ScheduledTaskTrigger -Daily -At '03:00AM';" ^
    "  $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable:$false -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1);" ^
    "  $principal = New-ScheduledTaskPrincipal -UserId ($env:USERDOMAIN + '\' + $env:USERNAME) -RunLevel Limited;" ^
    "  Register-ScheduledTask -TaskName '%TASK_NAME%' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop | Out-Null;" ^
    "  Write-Host '[SUCCESS] Tarea registrada para usuario: ' + $env:USERNAME;" ^
    "  exit 0" ^
    "} catch {" ^
    "  Write-Host '[ERROR] Fallo al registrar la tarea: ' + $_.Exception.Message;" ^
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
echo     echo [ERROR] Debes ejecutar esto como Administrador.
echo     pause ^& exit /b 1
echo ^)
echo echo Desinstalando reset automatico de Sibelius...
echo schtasks /delete /tn "%TASK_NAME%" /f ^>nul 2^>^&1
echo rd /s /q "%INSTALL_DIR%" 2^>nul
echo echo [SUCCESS] Desinstalacion completada.
echo pause
) > "%UNINSTALL_SCRIPT%"

echo [SUCCESS] Script de desinstalacion creado: %UNINSTALL_SCRIPT%

:: ============================================================
:: Resumen final
:: ============================================================
echo.
echo ============================================================
echo   INSTALACION COMPLETADA v1.0
echo ============================================================
echo.
echo   * Reset automatico cada 29 dias
echo   * Tarea diaria a las 3:00 AM (corre aunque la PC haya
echo     estado apagada, al proximo inicio de sesion)
echo   * Script de reset: %RESET_SCRIPT%
echo   * Logs en: %LOG_DIR%\sibelius_reset.log
echo   * Desinstalar: %UNINSTALL_SCRIPT%
echo.

:: Ofrecer ejecutar el reset ahora
set /p RUN_NOW="^¿Ejecutar el reset de Sibelius ahora? (s/n): "
if /i "%RUN_NOW%"=="s" (
    echo [INFO] Ejecutando reset...
    echo.
    call "%RESET_SCRIPT%"
    echo.
    echo [INFO] Reset finalizado. Revisa el resultado arriba.
    echo [INFO] Log completo en: %LOG_DIR%\sibelius_reset.log
    echo.
    pause
) else (
    echo [INFO] Podes ejecutarlo manualmente cuando quieras:
    echo   %RESET_SCRIPT%
)

echo.
echo [INFO] Comandos utiles:
echo   * Ver tarea: schtasks /query /tn %TASK_NAME% /v
echo   * Ejecutar ahora: "%RESET_SCRIPT%"
echo   * Ver log: type "%LOG_DIR%\sibelius_reset.log"
echo   * Forzar reset: del "%INSTALL_DIR%\.last_reset" ^&^& "%RESET_SCRIPT%"
echo.

pause
endlocal
