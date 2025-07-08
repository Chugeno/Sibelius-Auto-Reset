# Sibelius Ultimate Auto Reset

Automatiza el reset de Sibelius Ultimate en macOS cada 29 días sin intervención manual.

## ¿Qué hace?

- 🔄 **Reset automático** cada 29 días
- 🚫 **Sin contraseñas** después de la instalación
- 📝 **Logs detallados** de cada ejecución
- 🛠️ **Ejecución manual** cuando sea necesario
- 🗑️ **Desinstalador** incluido

## Instalación

1. **Descargar** el script:
   ```bash
   curl -O https://raw.githubusercontent.com/Chugeno/Sibelius-Auto-Reset/main/sibelius_installer.sh
   ```
   
2. **Ejecutar** una sola vez:
   ```bash
   sudo bash sibelius_installer.sh
   ```

¡Listo! El reset se ejecutará automáticamente cada 29 días.

## Uso

```bash
# Ejecutar reset manualmente (no afecta el contador automático)
~/.local/bin/sibelius_reset.sh

# Ver logs
tail -f ~/.local/sibelius_reset.log

# Verificar que está activo
launchctl list | grep sibelius

# Desinstalar todo
~/.local/bin/sibelius_uninstall.sh
```

## Archivos que elimina

- `/Applications/APi1`
- `/Library/Application Support/Avid/Sibelius/_manuscript/ACr2`
- `/Library/Application Support/Avid/Sibelius/_manuscript/Plugins_v2`
- `~/Library/Application Support/Avid/Sibelius/_manuscript/HEa3`

## Requisitos

- macOS 10.10+
- Permisos de administrador (solo para la instalación)

## Cómo funciona

Utiliza `launchd` (el sistema nativo de macOS) para programar la tarea y configura `sudoers` para eliminar la necesidad de contraseñas en los comandos específicos.

## Desinstalación

```bash
~/.local/bin/sibelius_uninstall.sh
```

---

**⚠️ Advertencia:** Este script elimina archivos del sistema. Úsalo bajo tu propia responsabilidad.
