# Sibelius Ultimate Auto Reset

Automatiza el reset de Sibelius Ultimate en macOS cada 29 días.

## Instalación

1. **Abre la Terminal** (puedes buscarla en Spotlight con `Cmd + Espacio`)

2. **Descarga el instalador:**
   ```
   curl -O https://raw.githubusercontent.com/Chugeno/Sibelius-Auto-Reset/main/sibelius_installer.sh
   ```

3. **Ejecuta el instalador:**
   ```
   sudo bash sibelius_installer.sh
   ```
   Te pedirá tu contraseña de administrador.

4. **¡Listo!** El script instalador se borra automáticamente después de la instalación.

## Uso

```bash
# Ejecutar reset manualmente
~/.local/bin/sibelius_reset.sh

# Ver logs
tail -f ~/.local/sibelius_reset.log

# Verificar estado
launchctl list | grep sibelius
```

## Desinstalación

```bash
~/.local/bin/sibelius_uninstall.sh
```

---

⚠️ **Advertencia:** Este script elimina archivos del sistema. Úsalo bajo tu propia responsabilidad.
