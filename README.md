# Sibelius Ultimate Auto Reset

Automatiza el reset de Sibelius Ultimate cada 29 días para que nunca expire. Compatible con **macOS** y **Windows**.

☕️ **¿Sale cafecito?** [cafecito.app/chugeno](https://cafecito.app/chugeno)

---

## 🍏 macOS

### Instalación Rápida
Copia y pega esto en tu Terminal y presiona Enter:
```bash
curl -fsSL https://raw.githubusercontent.com/Chugeno/Sibelius-Auto-Reset/main/sibelius_installer.sh | sudo bash
```

### Uso Manual
- **Ejecutar reset ahora:** `~/.local/bin/sibelius_reset.sh`
- **Ver logs:** `tail -f ~/.local/sibelius_reset.log`
- **Desinstalar:** `~/.local/bin/sibelius_uninstall.sh`

---

## 🪟 Windows

### Instalación Rápida
Abre **PowerShell** como administrador, copia y pega esto y presiona Enter:
```powershell
irm https://raw.githubusercontent.com/Chugeno/Sibelius-Auto-Reset/main/install.ps1 | iex
```

### Uso Manual
- **Ejecutar reset ahora:** Ejecuta el archivo `C:\ProgramData\Avid\SibeliusReset\sibelius_reset.ps1` con PowerShell.
- **Ver logs:** `type "C:\ProgramData\Avid\SibeliusReset\logs\sibelius_reset.log"`
- **Desinstalar:** Ejecuta como admin: `C:\ProgramData\Avid\SibeliusReset\sibelius_uninstall.bat`

---

## 📺 Instrucciones en Video
[youtube.com/watch?v=yoEpCc1OVRA](https://youtu.be/yoEpCc1OVRA)

---

⚠️ **Advertencia:** Este script elimina archivos de configuración y registro. Úsalo bajo tu propia responsabilidad. Solo para fines educativos.
