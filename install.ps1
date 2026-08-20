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

# --- 3. Instalar script de reseteo (Embebido, 100% autocontenido) ---
Write-Host "[2/5] Instalando script de reseteo..." -ForegroundColor Yellow

$resetScriptContent = @'
# ============================================================
# Script de reset de Sibelius Ultimate (cada 29 dias)
# Ubicacion: C:\ProgramData\Avid\SibeliusReset\sibelius_reset.ps1
# Compatible con Windows 10 y Windows 11 (Multi-usuario)
# ============================================================
[CmdletBinding()]
param(
    [switch]$Force
)

$InstallDir    = "C:\ProgramData\Avid\SibeliusReset"
$LogDir        = "$InstallDir\logs"
$LogFile       = "$LogDir\sibelius_reset.log"
$TimestampFile = "$InstallDir\last_reset.txt"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}

function Write-Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Host $line
}

Write-Log "Iniciando chequeo de reset de Sibelius Ultimate"

# 1. ---- Logica de 29 dias o Forzado ----
$doReset = $false

if ($Force) {
    Write-Log "Reset forzado explicitamente por parametro -Force"
    $doReset = $true
} elseif (-not (Test-Path $TimestampFile)) {
    Write-Log "Primer run: no existe last_reset.txt, forzando reset inicial"
    $doReset = $true
} else {
    try {
        $lastStr = (Get-Content $TimestampFile -Raw).Trim()
        $last = [datetime]::ParseExact($lastStr, "yyyyMMdd", $null)
        $daysSince = ((Get-Date) - $last).Days
        Write-Log "Dias transcurridos desde ultimo reset: $daysSince"

        if ($daysSince -ge 29) {
            Write-Log "Han transcurrido $daysSince dias (>= 29). Ejecutando reset."
            $doReset = $true
        } else {
            $daysLeft = 29 - $daysSince
            Write-Log "No es necesario aun. Proximo reset automatico en $daysLeft dias."
            exit 0
        }
    } catch {
        Write-Log "Error leyendo fecha de last_reset.txt, forzando reset: $_"
        $doReset = $true
    }
}

if (-not $doReset) {
    exit 0
}

# 2. ---- Cerrar procesos que puedan bloquear archivos ----
Write-Log "Cerrando procesos de Avid y Sibelius..."
$processNames = @("Sibelius*", "AvidLink*", "AvidAppMan*", "AvidBackgroundService*", "AvidCloudClient*")
foreach ($proc in $processNames) {
    Get-Process -Name $proc -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            Write-Log "Proceso detenido: $($_.Name) (PID $($_.Id))"
        } catch {
            Write-Log "No se pudo detener proceso $($_.Name): $_"
        }
    }
}
Start-Sleep -Seconds 1

# 3. ---- Borrar carpetas del sistema (compartidas) ----
$pf86 = ${env:ProgramFiles(x86)}
$pf   = $env:ProgramFiles
$pd   = $env:ProgramData

$systemPaths = @(
    "$pf86\APi1",
    "$pf\APi1",
    "$pd\Avid\Sibelius\_manuscript\ACr2",
    "$pd\Avid\Sibelius\_manuscript\Plugins_v2"
)

foreach ($p in $systemPaths) {
    if (Test-Path -Path $p) {
        try {
            Remove-Item -Path $p -Recurse -Force -ErrorAction Stop
            Write-Log "Borrado archivo/directorio de sistema: $p"
        } catch {
            Write-Log "Advertencia al borrar ${p}: $_"
        }
    }
}

# 4. ---- Borrar carpetas de perfil en TODOS los usuarios ----
# Esto asegura que funcione aunque se ejecute como Administrador o SYSTEM
$userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
foreach ($userDir in $userProfiles) {
    $userPath = Join-Path $userDir.FullName "AppData\Roaming\Avid\Sibelius\_manuscript\HEa3"
    if (Test-Path -Path $userPath) {
        try {
            Remove-Item -Path $userPath -Recurse -Force -ErrorAction Stop
            Write-Log "Borrado rastro de usuario en: $userPath"
        } catch {
            Write-Log "Advertencia al borrar ${userPath}: $_"
        }
    }
}

# 5. ---- Actualizar Registro para forzar Sibelius Ultimate Trial ----
# A) HKCU (Usuario actual)
try {
    $regPathHKCU = "HKCU:\Software\Avid\Sibelius\SibeliusTierSelection"
    if (-not (Test-Path $regPathHKCU)) {
        New-Item -Path $regPathHKCU -Force | Out-Null
    }
    Set-ItemProperty -Path $regPathHKCU -Name "TrialDialogSavedChoice" -Value 3 -Type DWord -Force
    Write-Log "Registro HKCU actualizado: TrialDialogSavedChoice = 3"
} catch {
    Write-Log "Advertencia al escribir en HKCU: $_"
}

# B) HKEY_USERS (Todos los perfiles de usuario activos/cargados)
try {
    $loadedUserSids = Get-ChildItem -Path "Registry::HKEY_USERS" -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^S-1-5-21-[0-9\-]+$' }

    foreach ($sidItem in $loadedUserSids) {
        $sid = $sidItem.PSChildName
        $regPathSid = "Registry::HKEY_USERS\$sid\Software\Avid\Sibelius\SibeliusTierSelection"
        if (-not (Test-Path $regPathSid)) {
            New-Item -Path $regPathSid -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Set-ItemProperty -Path $regPathSid -Name "TrialDialogSavedChoice" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Log "Registro actualizado para SID ${sid}: TrialDialogSavedChoice = 3"
    }
} catch {
    Write-Log "Advertencia al actualizar ramas en HKEY_USERS: $_"
}

# 6. ---- Guardar timestamp actual ----
try {
    Get-Date -Format "yyyyMMdd" | Set-Content -Path $TimestampFile -Encoding UTF8 -Force
    Write-Log "Timestamp guardado exitosamente en: $TimestampFile"
} catch {
    Write-Log "Error guardando timestamp: $_"
}

Write-Log "Reset de Sibelius completado exitosamente."
Write-Host ""
Write-Host "[SUCCESS] Reset de Sibelius Ultimate completado exitosamente." -ForegroundColor Green
'@

Set-Content -Path $resetPs1 -Value $resetScriptContent -Encoding UTF8
Write-Host "[OK] Script de reseteo instalado exitosamente" -ForegroundColor Green

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

