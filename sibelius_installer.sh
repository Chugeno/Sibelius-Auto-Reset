#!/bin/bash

# Instalador para reset automático de Sibelius Ultimate cada 29 días
# Requiere ejecutarse con sudo inicialmente para configurar sudoers

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

# 2. Crear el script de reset
RESET_SCRIPT="$SCRIPTS_DIR/sibelius_reset.sh"
cat > "$RESET_SCRIPT" << 'EOF'
#!/bin/bash

# Script para reset de Sibelius Ultimate
# Creado automáticamente por el instalador

function msg {
    printf "\e[1;32m>\e[m %s\n" "$1"
}

function msg2 {
    printf "\e[1;34m>\e[m %s\n" "$1"
}

# Log del proceso
LOG_FILE="$HOME/.local/sibelius_reset.log"
echo "$(date): Iniciando reset de Sibelius Ultimate" >> "$LOG_FILE"

msg "Reset Sibelius Ultimate iniciado..."

# Eliminar archivos (ahora sin sudo gracias a sudoers)
sudo rm -Rf /Applications/APi1 2>/dev/null || true
sudo rm -Rf "/Library/Application Support/Avid/Sibelius/_manuscript/ACr2" 2>/dev/null || true
sudo rm -Rf "/Library/Application Support/Avid/Sibelius/_manuscript/Plugins_v2" 2>/dev/null || true
sudo rm -Rf "$HOME/Library/Application Support/Avid/Sibelius/_manuscript/HEa3" 2>/dev/null || true

msg "Reset completado!"
echo "$(date): Reset de Sibelius Ultimate completado exitosamente" >> "$LOG_FILE"

# Notificación usando AppleScript
osascript << EOT
tell application "System Events"
    display notification "Sibelius Ultimate ha sido reseteado automáticamente" with title "Reset Sibelius" sound name "Glass"
end tell
EOT

EOF

# Hacer ejecutable el script
chmod +x "$RESET_SCRIPT"
chown $REAL_USER:staff "$RESET_SCRIPT"

msg_success "Script de reset creado en: $RESET_SCRIPT"

# 3. Configurar sudoers para que no pida contraseña
SUDOERS_FILE="/etc/sudoers.d/sibelius_reset"
cat > "$SUDOERS_FILE" << EOF
# Permitir al usuario ejecutar comandos específicos sin contraseña para reset de Sibelius
$REAL_USER ALL=(ALL) NOPASSWD: /bin/rm -Rf /Applications/APi1
$REAL_USER ALL=(ALL) NOPASSWD: /bin/rm -Rf /Library/Application\ Support/Avid/Sibelius/_manuscript/ACr2
$REAL_USER ALL=(ALL) NOPASSWD: /bin/rm -Rf /Library/Application\ Support/Avid/Sibelius/_manuscript/Plugins_v2
$REAL_USER ALL=(ALL) NOPASSWD: /bin/rm -Rf /Library/Application\ Support/Avid/Sibelius/_manuscript/HEa3
EOF

chmod 440 "$SUDOERS_FILE"
msg_success "Configuración sudoers creada en: $SUDOERS_FILE"

# 4. Crear el plist para launchd (método moderno en macOS)
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
    <key>StartInterval</key>
    <integer>2505600</integer>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$REAL_HOME/.local/sibelius_reset_out.log</string>
    <key>StandardErrorPath</key>
    <string>$REAL_HOME/.local/sibelius_reset_err.log</string>
</dict>
</plist>
EOF

chown $REAL_USER:staff "$PLIST_FILE"
msg_success "Tarea programada creada en: $PLIST_FILE"

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
msg_success "🎉 INSTALACIÓN COMPLETADA 🎉"
echo
msg_info "Configuración:"
echo "  • Reset automático cada 29 días (2,505,600 segundos)"
echo "  • Script principal: $RESET_SCRIPT"
echo "  • Logs en: $REAL_HOME/.local/sibelius_reset.log"
echo "  • Desinstalar con: $UNINSTALL_SCRIPT"
echo
msg_info "Comandos útiles:"
echo "  • Ver estado: launchctl list | grep sibelius"
echo "  • Ejecutar manualmente: $RESET_SCRIPT"
echo "  • Ver logs: tail -f $REAL_HOME/.local/sibelius_reset.log"
echo
msg_warning "NOTA: El primer reset será en 29 días. Si quieres probar ahora, ejecuta manualmente el script."
