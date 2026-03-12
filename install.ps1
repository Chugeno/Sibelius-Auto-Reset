# ============================================================
# Bootstrap installer para Sibelius Auto-Reset
# Descarga los archivos necesarios desde GitHub y ejecuta el installer
#
# Uso (pegar en PowerShell):
#   irm https://raw.githubusercontent.com/Chugeno/Sibelius-Auto-Reset/main/install.ps1 | iex
# ============================================================

# --- Auto-elevar a Administrador si no lo es ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Solicitando permisos de administrador..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy Bypass",
        "-Command",
        "iex ((Invoke-WebRequest 'https://raw.githubusercontent.com/Chugeno/Sibelius-Auto-Reset/main/install.ps1' -UseBasicParsing).Content)"
    )
    exit
}

# --- Descargar archivos a carpeta temporal ---
$base = "https://raw.githubusercontent.com/Chugeno/Sibelius-Auto-Reset/main"
$tmp  = "$env:TEMP\SibeliusAutoReset"

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Sibelius Auto-Reset - Instalador Bootstrap"   -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Descargando archivos desde GitHub..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $tmp | Out-Null

try {
    Invoke-WebRequest "$base/sibelius_installer.bat" -OutFile "$tmp\sibelius_installer.bat" -UseBasicParsing -ErrorAction Stop
    Write-Host "[OK] sibelius_installer.bat" -ForegroundColor Green

    Invoke-WebRequest "$base/sibelius_reset.ps1" -OutFile "$tmp\sibelius_reset.ps1" -UseBasicParsing -ErrorAction Stop
    Write-Host "[OK] sibelius_reset.ps1" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] No se pudo descargar: $_" -ForegroundColor Red
    Write-Host "Verifica tu conexion a internet e intenta de nuevo." -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host ""
Write-Host "Ejecutando instalador..." -ForegroundColor Cyan
Write-Host ""

# Ejecutar el instalador .bat en la misma ventana
& "$tmp\sibelius_installer.bat"
