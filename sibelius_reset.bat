@echo off
:: ============================================================
:: Script de reset de Sibelius Ultimate (cada 29 dias)
:: Instalado automaticamente en C:\ProgramData\Avid\SibeliusReset\
:: No modificar manualmente.
:: ============================================================
setlocal EnableDelayedExpansion

set "INSTALL_DIR=%ProgramData%\Avid\SibeliusReset"
set "LOG_FILE=%INSTALL_DIR%\logs\sibelius_reset.log"
set "TIMESTAMP_FILE=%INSTALL_DIR%\.last_reset"
set "DO_RESET=false"

echo %DATE% %TIME% - Iniciando chequeo >> "%LOG_FILE%"

:: ============================================================
:: Logica de 29 dias
:: ============================================================
if not exist "%TIMESTAMP_FILE%" (
    echo %DATE% %TIME% - Primer run: forzando reset >> "%LOG_FILE%"
    set "DO_RESET=true"
) else (
    :: PowerShell calcula los dias y escribe el resultado a un archivo temp
    powershell -NoProfile -Command "$ts=Get-Content '%TIMESTAMP_FILE%' | Out-String; $last=[datetime]::ParseExact($ts.Trim(),'yyyyMMdd',$null); $d=((Get-Date)-$last).Days; Write-Output $d" > "%TEMP%\sib_days.tmp" 2>&1
    set /p DAYS_SINCE= < "%TEMP%\sib_days.tmp"
    del "%TEMP%\sib_days.tmp" 2>nul

    echo %DATE% %TIME% - Dias desde ultimo reset: %DAYS_SINCE% >> "%LOG_FILE%"

    if !DAYS_SINCE! GEQ 29 (
        set "DO_RESET=true"
        echo %DATE% %TIME% - Ejecutando reset (!DAYS_SINCE! dias transcurridos) >> "%LOG_FILE%"
    ) else (
        set /a DAYS_LEFT=29-!DAYS_SINCE!
        echo %DATE% %TIME% - No es necesario aun. Proximo reset en !DAYS_LEFT! dias >> "%LOG_FILE%"
        exit /b 0
    )
)

:: ============================================================
:: Ejecutar reset
:: ============================================================
if "!DO_RESET!"=="true" (

    :: Guardar fecha de hoy (formato yyyyMMdd)
    powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd'" > "%TIMESTAMP_FILE%"

    :: Borrar carpetas del sistema (compartidas)
    if exist "%ProgramFiles(x86)%\APi1"                               rd /s /q "%ProgramFiles(x86)%\APi1"
    if exist "%ProgramData%\Avid\Sibelius\_manuscript\ACr2"           rd /s /q "%ProgramData%\Avid\Sibelius\_manuscript\ACr2"
    if exist "%ProgramData%\Avid\Sibelius\_manuscript\Plugins_v2"     rd /s /q "%ProgramData%\Avid\Sibelius\_manuscript\Plugins_v2"

    :: Borrar carpeta del perfil del usuario actual
    if exist "%APPDATA%\Avid\Sibelius\_manuscript\HEa3"               rd /s /q "%APPDATA%\Avid\Sibelius\_manuscript\HEa3"

    :: Resetear clave de registro del usuario actual
    REG ADD "HKCU\Software\Avid\Sibelius\SibeliusTierSelection" /v TrialDialogSavedChoice /t REG_DWORD /d 3 /f >nul 2>&1

    echo %DATE% %TIME% - Reset completado exitosamente >> "%LOG_FILE%"
    echo [SUCCESS] Reset de Sibelius completado.
) else (
    echo [INFO] No se requiere reset aun.
)

endlocal
