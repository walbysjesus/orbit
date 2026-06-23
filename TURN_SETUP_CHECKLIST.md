# ✅ CHECKLIST: CONFIGURACIÓN TURN PARA ORBIT

## 🔍 Fase 1: Verificar Código

### En `lib/services/call_service.dart`:
- [x] ✅ Import `turn_stun_config.dart` agregado (línea 9)
- [x] ✅ Validación TURN en `initiateCall()` (línea ~75)
- [x] ✅ Lanza excepción si TURN no configurado

### En `lib/services/turn_stun_config.dart`:
- [x] ✅ Variables de entorno definidas (líneas 7-12)
  - `TURN_URL`
  - `TURN_USERNAME`
  - `TURN_CREDENTIAL`
- [x] ✅ Método `isTurnConfigured()` funciona
- [x] ✅ Método `shouldBlockCallInRelease()` retorna error
- [x] ✅ Método `buildIceServers()` construye lista correcta

### En `lib/screens/communication/call_initiate_screen.dart`:
- [x] ✅ Error handling mejorado en `_initiateCall()` (línea ~83)
- [x] ✅ Mensajes específicos para errores TURN

### En `lib/services/webrtc_service.dart`:
- [x] ✅ Usa `TurnStunConfig.buildIceServers()` (línea ~20)
- [x] ✅ ICE servers configurados en `initConnection()` (línea ~30)

---

## 🌐 Fase 2: Elegir Proveedor TURN

### Opción A: Metered (⭐ Rápido para Testing)
```
URL:       turn:global.relay.metered.ca:443
Username:  d3d7fcd2d6ca0d11
Password:  uQzP2dJrBN8u+XDH
Setup:     ⚡ 1 minuto
Costo:     Gratis (rate-limited)
```
**Usar para:** MVP, testing rápido, desarrollo

### Opción B: Twilio (⭐⭐ Recomendado para Producción)
```
URL:       turn:global.twilio.com:3478
Username:  ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Password:  your-auth-token
Setup:     10-15 minutos
Costo:     $$$ (~$0.15-0.30/GB)
```
**Usar para:** Play Store, producción, apps profesionales

### Opción C: Coturn Self-Hosted (⭐⭐⭐ Más Barato)
```
URL:       turn:your-domain.com:3478
Username:  orbitapp
Password:  strongPassword123
Setup:     30-60 minutos (requiere VPS)
Costo:     $ (~$3-5/mes VPS)
```
**Usar para:** Startups, presupuesto limitado, control total

### ✅ Seleccionar: _______________________

---

## 🔧 Fase 3: Obtener Credenciales

### Si elegiste Metered:
- [ ] Copiar URL: `turn:global.relay.metered.ca:443`
- [ ] Copiar Username: `d3d7fcd2d6ca0d11`
- [ ] Copiar Password: `uQzP2dJrBN8u+XDH`
- [ ] ✅ Listo para compilar

### Si elegiste Twilio:
- [ ] Ir a: https://www.twilio.com/
- [ ] [ ] Crear cuenta/Iniciar sesión
- [ ] [ ] Obtener Account SID (ACxxxxx...)
- [ ] [ ] Obtener Auth Token
- [ ] [ ] Generar token TURN (ver docs)
- [ ] [ ] Verificar conectividad:
  ```powershell
  Test-NetConnection -ComputerName global.twilio.com -Port 3478
  ```

### Si elegiste Coturn:
- [ ] Alquilar VPS (DigitalOcean, Linode, AWS)
- [ ] Instalar Coturn: `sudo apt-get install coturn`
- [ ] Editar `/etc/coturn/turnserver.conf`:
  - external-ip = IP pública
  - user = username:password
  - realm = tu-dominio.com
- [ ] Iniciar: `sudo systemctl restart coturn`
- [ ] Verificar conectividad:
  ```powershell
  Test-NetConnection -ComputerName your-domain.com -Port 3478
  ```

---

## 🔐 Fase 4: Almacenar Credenciales (Seguro)

### ❌ NUNCA en Git:
```bash
git add COMPILE_WITH_TURN.ps1  # ❌ MAL - expone credentials
```

### ✅ Variables de Entorno Windows:
```powershell
# PowerShell como Administrador:
[Environment]::SetEnvironmentVariable('TURN_URL', 'turn:server.com:3478', 'User')
[Environment]::SetEnvironmentVariable('TURN_USERNAME', 'user', 'User')
[Environment]::SetEnvironmentVariable('TURN_CREDENTIAL', 'pass', 'User')
```

### ✅ En CI/CD (GitHub Actions):
```yaml
jobs:
  build:
    steps:
      - run: flutter build apk --release \
          --dart-define=TURN_URL=${{ secrets.TURN_URL }} \
          --dart-define=TURN_USERNAME=${{ secrets.TURN_USERNAME }} \
          --dart-define=TURN_CREDENTIAL=${{ secrets.TURN_PASSWORD }}
```

### ✅ Archivo .env local (nunca commitear):
```bash
TURN_URL=turn:server.com:3478
TURN_USERNAME=user
TURN_CREDENTIAL=pass
```

---

## 🚀 Fase 5: Compilar APK

### Opción A: Usar Script PowerShell (Recomendado)

```powershell
cd C:\Users\Usuario\Documents\orbit

.\COMPILE_WITH_TURN.ps1 `
  -TurnUrl "turn:global.relay.metered.ca:443" `
  -TurnUsername "d3d7fcd2d6ca0d11" `
  -TurnPassword "uQzP2dJrBN8u+XDH" `
  -BuildType "optimized"
```

Pasos del script:
- [ ] Limpia proyecto (`flutter clean`)
- [ ] Descarga dependencias (`flutter pub get`)
- [ ] Compila APK con `--dart-define`
- [ ] Muestra ubicación del APK
- [ ] Tiempo: 20-40 minutos en 4GB RAM

### Opción B: Comando Manual

```powershell
cd C:\Users\Usuario\Documents\orbit

flutter build apk --release `
  --dart-define=TURN_URL=turn:global.relay.metered.ca:443 `
  --dart-define=TURN_USERNAME=d3d7fcd2d6ca0d11 `
  --dart-define=TURN_CREDENTIAL=uQzP2dJrBN8u+XDH
```

### Verificar Compilación:
- [ ] Output incluye: `✓ Built build/app/outputs/apk/release/app-release.apk`
- [ ] No hay errores de TURN
- [ ] Tiempo de compilación: 20-40 min (normal)

---

## 📲 Fase 6: Instalar y Probar en Dispositivo

### Instalar APK:

```powershell
# Conectar dispositivo via USB (con USB Debug activado)
adb devices

# Instalar APK
adb install -r build\app\outputs\apk\release\app-release.apk

# Ver logs (en otra terminal):
adb logcat | grep -i "TURN\|STUN\|Production"
```

### Probar Llamada de Audio:
- [ ] Abrir app
- [ ] Iniciar sesión
- [ ] Ir a "Llamadas" → seleccionar usuario
- [ ] Hacer click en botón de llamada (audio)
- [ ] Ver en logcat: `✅ [TURN] Production TURN configured`
- [ ] Llamada se completa exitosamente

### Probar Llamada de Video:
- [ ] Desde "Llamadas" → seleccionar usuario
- [ ] Hacer click en botón de vídeo
- [ ] Permitir permisos de cámara
- [ ] Ver en logcat: `✅ [TURN] Production TURN configured`
- [ ] Vídeo debe funcionar incluso en WiFi público

### Probar en Red Diferente:
- [ ] Cambiar a WiFi diferente (hotspot, público, etc.)
- [ ] Repetir llamada de audio
- [ ] Repetir llamada de vídeo
- [ ] ✅ Ambas deben funcionar (TURN está funcionando)

---

## 🧪 Fase 7: Diagnóstico (Si hay Problemas)

### Verificar que TURN se cargó:

```bash
adb logcat | grep "TURN\|STUN"

# Esperado:
# ✅ [TURN] Production TURN configured: turn:global.relay.metered.ca:443
# ✅ [STUN] Added 5 public STUN servers
```

### Si no aparece TURN:

**Causa probable:** No pasaste `--dart-define` en compilación

```powershell
# ❌ Esto NO funciona:
flutter build apk --release

# ✅ Debe ser:
flutter build apk --release `
  --dart-define=TURN_URL=turn:... `
  --dart-define=TURN_USERNAME=... `
  --dart-define=TURN_CREDENTIAL=...
```

**Solución:** Recompilar con `--dart-define`

### Si TURN se cargó pero llamadas fallan:

**Posibles causas:**

1. **Servidor TURN no responde**
   ```powershell
   Test-NetConnection -ComputerName global.relay.metered.ca -Port 443
   # Si falla: cambiar a Twilio o Coturn
   ```

2. **Credenciales incorrectas**
   - [ ] Verificar TURN_USERNAME y TURN_CREDENTIAL
   - [ ] No copiar espacios extras
   - [ ] Usar las credenciales correctas del proveedor

3. **Firewall bloqueando puerto**
   - [ ] En Windows Defender Firewall: permitir Flutter
   - [ ] En red corporativa: pedir a IT que abra puerto 3478/443

---

## ✨ Fase 8: Verificación Final (Pre-Producción)

### Checklist Final:
- [ ] APK compilado sin errores
- [ ] APK instalado en dispositivo
- [ ] Logcat muestra: `✅ [TURN] Production TURN configured`
- [ ] Llamada de audio funciona
- [ ] Llamada de vídeo funciona
- [ ] Llamada funciona en WiFi diferente
- [ ] No hay errores de conexión en logcat

### ¿Listo para Play Store?
- [ ] ✅ TURN está configurado
- [ ] ✅ Llamadas funcionan en cualquier red
- [ ] ✅ No hay dependencias innecesarias
- [ ] ✅ APK ~40-50MB
- [ ] 🟢 LISTO PARA PUBLICAR

---

## 📝 Comandos Rápidos

```powershell
# Compilar con Metered (testing):
.\COMPILE_WITH_TURN.ps1 -TurnUrl "turn:global.relay.metered.ca:443" -TurnUsername "d3d7fcd2d6ca0d11" -TurnPassword "uQzP2dJrBN8u+XDH"

# Compilar con Twilio (producción):
.\COMPILE_WITH_TURN.ps1 -TurnUrl "turn:global.twilio.com:3478" -TurnUsername "ACxxxxx" -TurnPassword "token"

# Ver logs de TURN:
adb logcat | grep -i "TURN\|STUN\|Production"

# Instalar APK:
adb install -r build\app\outputs\apk\release\app-release.apk

# Verificar conectividad:
Test-NetConnection -ComputerName global.relay.metered.ca -Port 443
```

---

## 🎯 Estado Actual

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  ✅ CÓDIGO MODIFICADO                 ┃
┃  ✅ SCRIPTS CREADOS                   ┃
┃  ✅ DOCUMENTACIÓN COMPLETA            ┃
┃                                    ┃
┃  Próximo paso: Elegir TURN provider ┃
┃  y compilar APK                     ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

---

**Fecha:** 2026-06-21  
**Status:** 🟢 READY TO IMPLEMENT  
**Última actualización:** Junio 2026
