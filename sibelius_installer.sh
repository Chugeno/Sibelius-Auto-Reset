#!/bin/bash
# Instalador para reset automático de Sibelius Ultimate cada 29 días
# Requiere ejecutarse con sudo inicialmente para configurar sudoers
# Versión actualizada: Usa StartCalendarInterval + contador para fiabilidad

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function msg_error {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}
function msg_success {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}
function msg_info {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}
function msg_warning {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   msg_error "Este script debe ejecutarse con sudo"
   echo "Uso: sudo $0"
   exit 1
fi

# Obtener el usuario real (no root)
REAL_USER=$(logname)
REAL_HOME=$(eval echo ~$REAL_USER)
msg_info "Configurando reset automático de Sibelius Ultimate para usuario: $REAL_USER"

# 1. Crear el directorio para scripts si no existe
SCRIPTS_DIR="$REAL_HOME/.local/bin"
mkdir -p "$SCRIPTS_DIR"
chown $REAL_USER:staff "$SCRIPTS_DIR"

# 2. Crear el script de reset (con contador de 29 días)
RESET_SCRIPT="$SCRIPTS_DIR/sibelius_reset.sh"
cat > "$RESET_SCRIPT" << 'EOF'
#!/bin/bash
# Script para reset de Sibelius Ultimate (solo cada 29 días)
# Creado automáticamente por el instalador

function msg {
    printf "\e[1;32m>\e[m %s\n" "$1"
}
function msg2 {
    printf "\e[1;34m>\e[m %s\n" "$1"
}

# Log del proceso
LOG_FILE="$HOME/.local/sibelius_reset.log"
echo "$(date): Iniciando chequeo de reset de Sibelius Ultimate" >> "$LOG_FILE"

# Contador de 29 días
LAST_RUN_FILE="$HOME/.local/.sibelius_last_run"
DO_RESET=false

if [[ ! -f "$LAST_RUN_FILE" ]]; then
    # Primer run: forzar reset y guardar fecha actual
    date +%s > "$LAST_RUN_FILE"
    DO_RESET=true
    msg2 "Primer ejecución: forzando reset inicial"
    echo "$(date): Primer run, forzando reset" >> "$LOG_FILE"
else
    LAST_RUN=$(cat "$LAST_RUN_FILE")
    NOW=$(date +%s)
    DIFF=$(( (NOW - LAST_RUN) / 86400 ))  # Días transcurridos
    if [[ $DIFF -ge 29 ]]; then
        DO_RESET=true
        date +%s > "$LAST_RUN_FILE"  # Actualizar fecha
        msg2 "Han pasado $DIFF días: ejecutando reset"
        echo "$(date): Reset ejecutado ($DIFF días desde último)" >> "$LOG_FILE"
    else
        DO_RESET=false
        msg2 "Solo han pasado $DIFF días, no se resetea aún (próximo en $((29 - DIFF)) días)"
        echo "$(date): Solo pasaron $DIFF días, no se resetea aún" >> "$LOG_FILE"
        exit 0
    fi
fi

if [[ "$DO_RESET" == true ]]; then
    msg "Reset Sibelius Ultimate iniciado..."
    # Eliminar archivos (sin sudo gracias a sudoers)
    sudo rm -Rf /Applications/APi1 2>/dev/null || true
    sudo rm -Rf "/Library/Application Support/Avid/Sibelius/_manuscript/ACr2" 2>/dev/null || true
    sudo rm -Rf "/Library/Application Support/Avid/Sibelius/_manuscript/Plugins_v2" 2>/dev/null || true
    sudo rm -Rf "$HOME/Library/Application Support/Avid/Sibelius/_manuscript/HEa3" 2>/dev/null || true
    msg "Reset completado!"
    echo "$(date): Reset de Sibelius Ultimate completado exitosamente" >> "$LOG_FILE"
fi
EOF

# Hacer ejecutable el script
chmod +x "$RESET_SCRIPT"
chown $REAL_USER:staff "$RESET_SCRIPT"
msg_success "Script de reset creado en: $RESET_SCRIPT"

# 3. Configurar sudoers (con comillas y paths completos)
SUDOERS_FILE="/etc/sudoers.d/sibelius_reset"
cat > "$SUDOERS_FILE" << EOF
# Permitir al usuario ejecutar comandos específicos sin contraseña para reset de Sibelius
$REAL_USER ALL=(ALL) NOPASSWD: /bin/rm -Rf /Applications/APi1
$REAL_USER ALL=(ALL) NOPASSWD: /bin/rm -Rf "/Library/Application Support/Avid/Sibelius/_manuscript/ACr2"
$REAL_USER ALL=(ALL) NOPASSWD: /bin/rm -Rf "/Library/Application Support/Avid/Sibelius/_manuscript/Plugins_v2"
$REAL_USER ALL=(ALL) NOPASSWD: /bin/rm -Rf "$REAL_HOME/Library/Application Support/Avid/Sibelius/_manuscript/HEa3"
EOF
chmod 440 "$SUDOERS_FILE"
msg_success "Configuración sudoers creada en: $SUDOERS_FILE"

# 4. Crear el plist para launchd (diario a las 3:00 AM + RunAtLoad)
PLIST_FILE="$REAL_HOME/Library/LaunchAgents/com.sibelius.reset.plist"
mkdir -p "$REAL_HOME/Library/LaunchAgents"
cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.sibelius.reset</string>
    <key>ProgramArguments</key>
    <array>
        <string>$RESET_SCRIPT</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$REAL_HOME/.local/sibelius_reset_out.log</string>
    <key>StandardErrorPath</key>
    <string>$REAL_HOME/.local/sibelius_reset_err.log</string>
</dict>
</plist>
EOF
chown $REAL_USER:staff "$PLIST_FILE"
msg_success "Tarea programada creada en: $PLIST_FILE (diaria a las 3:00 AM)"

# 5. Cargar la tarea en launchd
sudo -u $REAL_USER launchctl load "$PLIST_FILE"
msg_success "Tarea cargada en launchd"

# 6. Crear script de desinstalación
UNINSTALL_SCRIPT="$SCRIPTS_DIR/sibelius_uninstall.sh"
cat > "$UNINSTALL_SCRIPT" << EOF
#!/bin/bash
# Script de desinstalación para reset automático de Sibelius
echo "Desinstalando reset automático de Sibelius..."
# Descargar tarea de launchd
launchctl unload "$PLIST_FILE" 2>/dev/null || true
# Eliminar archivos
rm -f "$PLIST_FILE"
rm -f "$RESET_SCRIPT"
rm -f "$HOME/.local/.sibelius_last_run" 2>/dev/null || true
sudo rm -f "$SUDOERS_FILE"
rm -f "$UNINSTALL_SCRIPT"
echo "Desinstalación completada"
EOF
chmod +x "$UNINSTALL_SCRIPT"
chown $REAL_USER:staff "$UNINSTALL_SCRIPT"
msg_success "Script de desinstalación creado en: $UNINSTALL_SCRIPT"

# 7. Crear directorio de logs
mkdir -p "$REAL_HOME/.local"
chown $REAL_USER:staff "$REAL_HOME/.local"

echo
msg_success "INSTALACIÓN COMPLETADA"
echo
msg_info "Configuración:"
echo " • Reset automático cada 29 días (chequeo diario a las 3:00 AM)"
echo " • Script principal: $RESET_SCRIPT"
echo " • Logs en: $REAL_HOME/.local/sibelius_reset.log"
echo " • Desinstalar con: $UNINSTALL_SCRIPT"
echo
msg_info "¿Quieres ejecutar el reset de Sibelius ahora? (y/n)"
read -p "Respuesta: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    msg_info "Ejecutando reset de Sibelius..."
    sudo -u $REAL_USER "$RESET_SCRIPT"
    msg_success "Reset ejecutado exitosamente!"
else
    msg_info "Reset no ejecutado. Puedes ejecutarlo manualmente cuando quieras:"
    echo " $RESET_SCRIPT"
fi
echo
msg_info "Comandos útiles:"
echo " • Ver estado: launchctl list | grep sibelius"
echo " • Ejecutar manualmente: $RESET_SCRIPT"
echo " • Ver logs: tail -f $REAL_HOME/.local/sibelius_reset.log"
echo
msg_warning "NOTA: El próximo reset automático será en 29 días desde ahora."
