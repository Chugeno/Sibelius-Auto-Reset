# ============================================================
# Instalador de Sibelius Ultimate Auto-Reset para Windows
# Compatible con Windows 10 y Windows 11
#
# Uso en PowerShell:
#   irm https://raw.githubusercontent.com/Chugeno/Sibelius-Auto-Reset/main/install.ps1 | iex
# ============================================================

# --- 1. Auto-elevar a Administrador si no lo es ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Solicitando permisos de administrador..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy Bypass",
        "-Command",
        "iex ((Invoke-WebRequest 'https://raw.githubusercontent.com/Chugeno/Sibelius-Auto-Reset/main/install.ps1' -UseBasicParsing).Content)"
    )
    exit
}

# Desbloquear ejecución de scripts para el proceso actual
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "     Sibelius Ultimate Auto-Reset - Instalador Windows      " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$installDir    = "C:\ProgramData\Avid\SibeliusReset"
$logDir        = "$installDir\logs"
$resetPs1      = "$installDir\sibelius_reset.ps1"
$uninstBat     = "$installDir\sibelius_uninstall.bat"
$uninstPs1     = "$installDir\sibelius_uninstall.ps1"
$taskName      = "SibeliusAutoReset"
$rawBaseUrl    = "https://raw.githubusercontent.com/Chugeno/Sibelius-Auto-Reset/main"

# --- 2. Limpieza de versiones y tareas previas ---
Write-Host "[1/5] Limpiando residuos y versiones previas..." -ForegroundColor Yellow
try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    schtasks /delete /tn $taskName /f 2>$null | Out-Null
} catch { }

# Crear directorios de instalacion
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Write-Host "[OK] Directorio preparado: $installDir" -ForegroundColor Green

# --- 3. Instalar o copiar sibelius_reset.ps1 ---
Write-Host "[2/5] Instalando script de reseteo..." -ForegroundColor Yellow

$scriptInstalled = $false

# Verificar si se esta ejecutando desde un archivo local (.ps1 en disco)
if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $localScript = Join-Path $PSScriptRoot "sibelius_reset.ps1"
    if (Test-Path -Path $localScript) {
        Copy-Item -Path $localScript -Destination $resetPs1 -Force
        Write-Host "[OK] Script copiado desde directorio local" -ForegroundColor Green
        $scriptInstalled = $true
    }
}

if (-not $scriptInstalled) {
    # Descargar desde GitHub
    try {
        Invoke-WebRequest "$rawBaseUrl/sibelius_reset.ps1" -OutFile $resetPs1 -UseBasicParsing -ErrorAction Stop
        Write-Host "[OK] Script descargado desde GitHub" -ForegroundColor Green
        $scriptInstalled = $true
    } catch {
        Write-Host "[ERROR] No se pudo descargar sibelius_reset.ps1: $_" -ForegroundColor Red
        Write-Host "Verifica tu conexion a internet e intenta nuevamente." -ForegroundColor Yellow
        Read-Host "Presiona Enter para salir..."
        exit 1
    }
}

if (-not (Test-Path -Path $resetPs1)) {
    Write-Host "[ERROR] No se encontro el archivo instalado en: $resetPs1" -ForegroundColor Red
    Read-Host "Presiona Enter para salir..."
    exit 1
}

# --- 4. Generar Scripts de Desinstalacion ---
Write-Host "[3/5] Generando desinstaladores..." -ForegroundColor Yellow

# A) Desinstalador Batch (.bat) para doble clic
$batUninstallContent = @"
@echo off
setlocal
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Solicitando permisos de Administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)
echo Desinstalando Sibelius Auto Reset...
schtasks /delete /tn "$taskName" /f >nul 2>&1
timeout /t 1 /nobreak >nul
rd /s /q "$installDir" >nul 2>&1
echo.
echo [SUCCESS] Sibelius Auto Reset ha sido desinstalado correctamente.
echo.
pause
"@
Set-Content -Path $uninstBat -Value $batUninstallContent -Encoding ASCII

# B) Desinstalador PowerShell (.ps1)
$ps1UninstallContent = @"
# ============================================================
# Desinstalador de Sibelius Ultimate Auto-Reset
# ============================================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile", "-ExecutionPolicy Bypass", "-File `"`$PSCommandPath`""
    exit
}
Write-Host "Desinstalando Sibelius Auto Reset..." -ForegroundColor Yellow
Unregister-ScheduledTask -TaskName "$taskName" -Confirm:`$false -ErrorAction SilentlyContinue | Out-Null
schtasks /delete /tn "$taskName" /f 2>`$null | Out-Null
Remove-Item -Path "$installDir" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[SUCCESS] Sibelius Auto Reset ha sido desinstalado correctamente." -ForegroundColor Green
Read-Host "Presiona Enter para cerrar..."
"@
Set-Content -Path $uninstPs1 -Value $ps1UninstallContent -Encoding UTF8

Write-Host "[OK] Desinstalador creado en: $uninstBat" -ForegroundColor Green

# --- 5. Registrar Tarea Programada (compatible con Windows 10 y 11) ---
Write-Host "[4/5] Registrando tarea programada en Windows..." -ForegroundColor Yellow
try {
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$resetPs1`""

    $trigger = New-ScheduledTaskTrigger -Daily -At "03:00AM"

    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1)

    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    Write-Host "[OK] Tarea programada registrada exitosamente ($taskName)" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Fallo al registrar la tarea programada: $_" -ForegroundColor Red
    Read-Host "Presiona Enter para salir..."
    exit 1
}

# --- 6. Ejecutar Reset Inicial Inmediato ---
Write-Host "[5/5] Ejecutando reseteo inicial de Sibelius..." -ForegroundColor Yellow
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$resetPs1" -Force

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "                 INSTALACION COMPLETADA                     " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host " * Reset automatico cada 29 dias (chequeo diario a las 3:00 AM)" -ForegroundColor White
Write-Host " * Se ejecutara al encender la PC si estuvo apagada" -ForegroundColor White
Write-Host " * Logs guardados en: $installDir\logs\sibelius_reset.log" -ForegroundColor White
Write-Host " * Desinstalar en cualquier momento ejecutando:" -ForegroundColor White
Write-Host "   $uninstBat" -ForegroundColor Cyan
Write-Host ""
Read-Host "Presiona Enter para finalizar..."

