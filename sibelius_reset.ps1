# ============================================================
# Script de reset de Sibelius Ultimate (cada 29 dias)
# Instalado automaticamente en C:\ProgramData\Avid\SibeliusReset\
# No modificar manualmente.
# ============================================================

$InstallDir    = "C:\ProgramData\Avid\SibeliusReset"
$LogFile       = "$InstallDir\logs\sibelius_reset.log"
$TimestampFile = "$InstallDir\last_reset.txt"
$PF86          = ${env:ProgramFiles(x86)}

function Write-Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Host $line
}

Write-Log "Iniciando chequeo de reset de Sibelius Ultimate"

# ---- Logica de 29 dias ----
$doReset = $false

if (-not (Test-Path $TimestampFile)) {
    Write-Log "Primer run: forzando reset inicial"
    $doReset = $true
} else {
    $lastStr = (Get-Content $TimestampFile -Raw).Trim()
    try {
        $last = [datetime]::ParseExact($lastStr, "yyyyMMdd", $null)
        $daysSince = ((Get-Date) - $last).Days
        Write-Log "Dias desde ultimo reset: $daysSince"

        if ($daysSince -ge 29) {
            Write-Log "Ejecutando reset ($daysSince dias transcurridos)"
            $doReset = $true
        } else {
            $daysLeft = 29 - $daysSince
            Write-Log "No es necesario aun. Proximo reset en $daysLeft dias"
            exit 0
        }
    } catch {
        Write-Log "Error leyendo timestamp, forzando reset: $_"
        $doReset = $true
    }
}

# ---- Ejecutar reset ----
if ($doReset) {
    # Guardar fecha de hoy
    Get-Date -Format "yyyyMMdd" | Set-Content $TimestampFile -Encoding UTF8

    # Borrar carpetas del sistema (compartidas)
    $systemPaths = @(
        "$PF86\APi1",
        "$env:ProgramData\Avid\Sibelius\_manuscript\ACr2",
        "$env:ProgramData\Avid\Sibelius\_manuscript\Plugins_v2"
    )
    foreach ($p in $systemPaths) {
        if (Test-Path $p) {
            Remove-Item -Recurse -Force $p -ErrorAction SilentlyContinue
            Write-Log "Borrado: $p"
        }
    }

    # Borrar carpeta del perfil del usuario actual
    $userPath = "$env:APPDATA\Avid\Sibelius\_manuscript\HEa3"
    if (Test-Path $userPath) {
        Remove-Item -Recurse -Force $userPath -ErrorAction SilentlyContinue
        Write-Log "Borrado: $userPath"
    }

    # Resetear clave de registro del usuario actual
    $regPath = "HKCU:\Software\Avid\Sibelius\SibeliusTierSelection"
    try {
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "TrialDialogSavedChoice" -Value 3 -Type DWord
        Write-Log "Registro actualizado correctamente"
    } catch {
        Write-Log "Advertencia al escribir registro: $_"
    }

    Write-Log "Reset completado exitosamente"
    Write-Host "[SUCCESS] Reset de Sibelius completado."
}
