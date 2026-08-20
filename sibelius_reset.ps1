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
