# 🌐 PROVEEDORES TURN RECOMENDADOS PARA ORBIT

## 📊 Comparativa Rápida

| Proveedor | Costo | Confiabilidad | Setup | Soporte |
|-----------|-------|--------------|-------|---------|
| **Twilio** | $$$ | Excelente | Fácil | 24/7 |
| **Coturn Self-Hosted** | $ | Alta | Complejo | Comunidad |
| **Metered.ca** | Gratis | Media | Muy Fácil | Email |
| **OpenRelay** | Gratis | Media | Fácil | Comunidad |

---

## 1️⃣ TWILIO (Recomendado para Producción)

### ✅ Ventajas
- Servidor premium dedicado
- 99.95% uptime garantizado
- Soporte técnico 24/7
- Ideal para producción/apps en Play Store

### ❌ Desventajas
- Costo: ~$0.15-0.30 por 1GB de tráfico
- Requiere API key

### 🔧 Configuración

1. **Crear cuenta:**
   - Ir a: https://www.twilio.com/
   - Registrarse (test gratis $15)

2. **Obtener credenciales:**
   ```
   Account SID: ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   Auth Token: your-auth-token-here
   ```

3. **Generar token TURN temporal (recomendado):**
   ```bash
   # Usar API de Twilio para generar tokens
   # Documentación: https://www.twilio.com/docs/stun-turn
   ```

4. **Compilar con Twilio:**
   ```powershell
   .\COMPILE_WITH_TURN.ps1 `
     -TurnUrl "turn:global.twilio.com:3478" `
     -TurnUsername "tu-account-sid" `
     -TurnPassword "tu-auth-token"
   ```

### 📚 Documentación
https://www.twilio.com/docs/stun-turn/stun-turn-configuration

---

## 2️⃣ COTURN SELF-HOSTED (Más Barato)

### ✅ Ventajas
- Gratis o muy barato (VPS $3-5/mes)
- Control total del servidor
- Sin límites de uso
- Ideal para startups

### ❌ Desventajas
- Requiere conocimiento DevOps
- Tú administras disponibilidad
- Necesitas VPS con IP pública

### 🔧 Setup Rápido (Ubuntu/Debian)

```bash
# 1. Instalar Coturn
sudo apt-get update
sudo apt-get install coturn

# 2. Editar configuración
sudo nano /etc/coturn/turnserver.conf

# Cambiar/agregar:
external-ip=YOUR_PUBLIC_IP/YOUR_PRIVATE_IP
user=username:password
realm=your-domain.com
```

### 📝 Ejemplo de configuración

```ini
# /etc/coturn/turnserver.conf
listening-port=3478
listening-ip=0.0.0.0
external-ip=203.0.113.45/10.0.0.5  # Public/Private IP
user=orbitapp:securePass123
realm=orbit.your-domain.com
bps-capacity=100000
max-sessions=1000
verbose
log-file=/var/log/coturn/turnserver.log
```

### 🚀 Iniciar servidor

```bash
sudo systemctl restart coturn
sudo systemctl enable coturn
```

### 📲 Compilar con tu Coturn

```powershell
.\COMPILE_WITH_TURN.ps1 `
  -TurnUrl "turn:your-domain.com:3478" `
  -TurnUsername "orbitapp" `
  -TurnPassword "securePass123"
```

### 📚 Documentación Coturn
https://github.com/coturn/coturn/wiki

---

## 3️⃣ METERED.CA (Gratis - Testing)

### ✅ Ventajas
- Gratis
- Setup instant (sin registro)
- Bueno para MVP/testing
- Directamente con credenciales públicas

### ❌ Desventajas
- **Rate-limited** (~250MB/mes)
- No recomendado para producción
- Conexiones lentas

### 🔧 Uso Inmediato

```powershell
.\COMPILE_WITH_TURN.ps1 `
  -TurnUrl "turn:global.relay.metered.ca:443" `
  -TurnUsername "d3d7fcd2d6ca0d11" `
  -TurnPassword "uQzP2dJrBN8u+XDH"
```

### 📚 Documentación
https://www.metered.ca/tools/openrelay/

---

## 4️⃣ OPENRELAY (Gratis - Alternativa)

### ✅ Ventajas
- Gratis y sin límites de solicitudes
- Bueno para startups
- Servidor público confiable

### ❌ Desventajas
- Capacidad limitada
- Sin soporte
- Aunque está "sin límites", puede ser lento en horas pico

### 🔧 Uso

```powershell
.\COMPILE_WITH_TURN.ps1 `
  -TurnUrl "turn:openrelay.metered.ca:80" `
  -TurnUsername "" `
  -TurnPassword ""

# O con credenciales:
.\COMPILE_WITH_TURN.ps1 `
  -TurnUrl "turn:openrelay.metered.ca:443" `
  -TurnUsername "openrelayproject" `
  -TurnPassword "openrelayproject"
```

### 📚 Documentación
https://www.metered.ca/tools/openrelay/

---

## 🎯 RECOMENDACIÓN POR CASO

### 📱 MVP / Desarrollo
```powershell
# Usar Metered (gratis, rápido de setup)
.\COMPILE_WITH_TURN.ps1 `
  -TurnUrl "turn:global.relay.metered.ca:443" `
  -TurnUsername "d3d7fcd2d6ca0d11" `
  -TurnPassword "uQzP2dJrBN8u+XDH"
```

### 🚀 Producción / Play Store
```powershell
# Usar Twilio (confiable, profesional)
.\COMPILE_WITH_TURN.ps1 `
  -TurnUrl "turn:global.twilio.com:3478" `
  -TurnUsername "AC5your-account-sid" `
  -TurnPassword "your-auth-token"
```

### 💻 Startup / Presupuesto Limitado
```bash
# Setup Coturn en VPS ($5/mes)
# Luego compilar con:
.\COMPILE_WITH_TURN.ps1 `
  -TurnUrl "turn:your-vps.com:3478" `
  -TurnUsername "orbitapp" `
  -TurnPassword "strongPassword"
```

---

## 🧪 PROBAR CONEXIÓN TURN

### Verificar que TURN responde (PowerShell)

```powershell
# Instalar herramienta:
choco install telnet

# Probar Twilio
Test-NetConnection -ComputerName global.twilio.com -Port 3478

# Probar Metered
Test-NetConnection -ComputerName global.relay.metered.ca -Port 443

# Probar tu Coturn
Test-NetConnection -ComputerName your-domain.com -Port 3478
```

### En Linux
```bash
nc -zv global.relay.metered.ca 443
nc -zv your-domain.com 3478
```

---

## 🔐 SEGURIDAD - CREDENCIALES TURN

### ⚠️ NUNCA commits credenciales en Git

```bash
# ❌ MAL - expone credenciales
git add COMPILE_WITH_TURN.ps1
git commit -m "Add TURN credentials"

# ✅ BIEN - usar .env o --dart-define en CI/CD
flutter build apk --release \
  --dart-define=TURN_URL=$TURN_URL \
  --dart-define=TURN_USERNAME=$TURN_USERNAME \
  --dart-define=TURN_CREDENTIAL=$TURN_PASSWORD
```

### Variables de entorno (CI/CD - GitHub Actions)

```yaml
name: Build APK with TURN

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter build apk --release \
          --dart-define=TURN_URL=${{ secrets.TURN_URL }} \
          --dart-define=TURN_USERNAME=${{ secrets.TURN_USERNAME }} \
          --dart-define=TURN_CREDENTIAL=${{ secrets.TURN_PASSWORD }}
```

---

## 🚀 COMPILACIÓN FINAL

### Con Twilio (Ejemplo completo)

```powershell
# 1. Windows PowerShell
cd C:\Users\Usuario\Documents\orbit

# 2. Ejecutar script
.\COMPILE_WITH_TURN.ps1 `
  -TurnUrl "turn:global.twilio.com:3478" `
  -TurnUsername "ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" `
  -TurnPassword "your-auth-token-here" `
  -BuildType "optimized"

# 3. Esperar 20-40 minutos

# 4. APK listo en:
#    build/app/outputs/apk/release/app-release.apk
```

### Con Metered (Inmediato)

```powershell
.\COMPILE_WITH_TURN.ps1 `
  -TurnUrl "turn:global.relay.metered.ca:443" `
  -TurnUsername "d3d7fcd2d6ca0d11" `
  -TurnPassword "uQzP2dJrBN8u+XDH"
```

---

## ✅ VERIFICAR TURN EN APP

Una vez compilado e instalado, ver logs:

```bash
# Conectar dispositivo
adb devices

# Ver logs
adb logcat | grep -i "TURN\|STUN\|ICE"

# Esperar inicio de llamada, verás:
# ✅ [TURN] Production TURN configured: turn:global.twilio.com:3478
# ✅ [STUN] Added 5 public STUN servers
```

---

## 📞 SOPORTE

- **Twilio:** https://support.twilio.com
- **Coturn:** https://github.com/coturn/coturn/issues
- **Metered:** support@metered.ca
- **OpenRelay:** https://www.metered.ca/contact/

---

**Fecha:** 2026-06-21  
**Estado:** 🟢 READY TO USE  
**Última actualización:** Junio 2026
