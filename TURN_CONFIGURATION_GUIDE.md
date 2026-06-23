# 🔴 GUÍA COMPLETA: CONFIGURACIÓN TURN/STUN EN ORBIT

## 📍 UBICACIÓN DEL ERROR

### Mensaje de Error:
```
🔴 PRODUCTION BLOCKED: TURN server not configured.

Required for satellite networks and double-NAT.
```

### Archivo que valida el error:
📄 **`lib/services/turn_stun_config.dart`** (líneas 114-134)

Método responsable:
```dart
static String? shouldBlockCallInRelease() {
  if (!kReleaseMode) return null;
  if (!isTurnConfigured()) {
    return '''🔴 PRODUCTION BLOCKED: TURN server not configured...'''
  }
}
```

---

## 🔍 DÓNDE SE LLAMA LA VALIDACIÓN

### 1. **call_service.dart** → `initiateCall()` método
- **Línea:** ~65-120
- **Qué hace:** Cuando usuario intenta iniciar una llamada
- **Validación:** Se debe llamar `TurnStunConfig.shouldBlockCallInRelease()` ANTES de crear conexión WebRTC

### 2. **config.dart** → `validateProductionSecurityConfig()`
- **Línea:** 122-148
- **Qué hace:** Valida toda la configuración en startup de la app
- **Status:** Actualmente NO bloquea el arranque (solo warning), solo bloquea llamadas

### 3. **webrtc_service.dart** → `initConnection()`
- **Línea:** 23-71
- **Qué hace:** Usa ICE servers construidos por `TurnStunConfig.buildIceServers()`

---

## 🎯 VARIABLES DE ENTORNO ESPERADAS

La aplicación espera **3 variables** vía `--dart-define`:

| Variable | Tipo | Requerido | Ejemplo |
|----------|------|-----------|---------|
| `TURN_URL` | String | ✅ SÍ | `turn:turn.orbit.com:3478` |
| `TURN_USERNAME` | String | ✅ SÍ | `user@orbit.com` |
| `TURN_CREDENTIAL` | String | ✅ SÍ | `securePassword123` |

**⚠️ Todas 3 deben estar presentes para que `isTurnConfigured()` devuelva `true`**

### En `turn_stun_config.dart`:
```dart
static const String _turnUrlEnv =
    String.fromEnvironment('TURN_URL', defaultValue: '');
static const String _turnUsernameEnv =
    String.fromEnvironment('TURN_USERNAME', defaultValue: '');
static const String _turnCredentialEnv =
    String.fromEnvironment('TURN_CREDENTIAL', defaultValue: '');
```

---

## 📋 ARCHIVOS QUE NECESITAS MODIFICAR

### **ARCHIVO 1: `lib/services/call_service.dart`**

**Ubicación:** Método `initiateCall()` línea ~65

**Cambio necesario:** Agregar validación TURN ANTES de inicializar WebRTC

```dart
Future<String> initiateCall({
  required String remoteUserId,
  bool isVideo = false,
}) async {
  try {
    // ✅ AGREGAR ESTA VALIDACIÓN:
    final turnError = TurnStunConfig.shouldBlockCallInRelease();
    if (turnError != null) {
      debugPrint(turnError);
      throw Exception(turnError);
    }
    
    // ... resto del código ...
    
    // Inicializar WebRTC (ya usa TURN internamente)
    _webrtcService = WebRTCService();
    await _webrtcService!.initConnection(isCaller: true);
```

**Import necesario:**
```dart
import 'turn_stun_config.dart';
```

---

### **ARCHIVO 2: `lib/screens/communication/call_initiate_screen.dart`**

**Ubicación:** Método `_initiateCall()` línea ~58

**Cambio necesario:** Capturar y mostrar error de TURN al usuario

```dart
Future<void> _initiateCall(
    String remoteUserId, String remoteDisplayName) async {
  try {
    final roomId = await _callService.initiateCall(
      remoteUserId: remoteUserId,
      isVideo: _isVideoEnabled,
    );
    // ... navegación ...
  } catch (e) {
    // ✅ Mostrar error TURN de forma amigable:
    if (e.toString().contains('PRODUCTION BLOCKED')) {
      _showError(
        'Llamadas deshabilitadas: Servidor TURN no configurado.\n'
        'Contacta al administrador.',
      );
    } else {
      _showError('Error: $e');
    }
  }
}
```

---

## 🚀 CÓMO COMPILAR CON TURN CONFIGURADO

### **Opción A: Compilación Manual (Recomendado)**

```powershell
cd C:\Users\Usuario\Documents\orbit

flutter build apk --release `
  --dart-define=TURN_URL=turn:your-server.com:3478 `
  --dart-define=TURN_USERNAME=your-username `
  --dart-define=TURN_CREDENTIAL=your-password
```

**Proveedores TURN recomendados:**

1. **Twilio (Mejor relación precio/calidad)**
   ```
   TURN_URL=turn:global.twilio.com:3478
   TURN_USERNAME=<app-sid>
   TURN_CREDENTIAL=<auth-token>
   ```

2. **Coturn Self-Hosted (Más barato)**
   ```
   TURN_URL=turn:your-server.com:3478
   TURN_USERNAME=username
   TURN_CREDENTIAL=password
   ```

3. **Metered.ca (Testing - Rate Limited)**
   ```
   TURN_URL=turn:global.relay.metered.ca:443
   TURN_USERNAME=metered-account
   TURN_CREDENTIAL=metered-password
   ```

---

### **Opción B: Usar Script PowerShell**

El archivo `COMPILE_PRODUCTION.ps1` ya soporta parámetros TURN:

```powershell
.\COMPILE_PRODUCTION.ps1 `
  -BuildType "optimized" `
  -TurnUrl "turn:your-server.com:3478" `
  -TurnUsername "your-username" `
  -TurnPass "your-password"
```

---

### **Opción C: Variables de Entorno Globales (Windows)**

Configura como variables de entorno del sistema (permanente):

```powershell
# En PowerShell como Administrador:
[Environment]::SetEnvironmentVariable('TURN_URL', 'turn:your-server.com:3478', 'User')
[Environment]::SetEnvironmentVariable('TURN_USERNAME', 'your-username', 'User')
[Environment]::SetEnvironmentVariable('TURN_CREDENTIAL', 'your-password', 'User')

# Luego compilar normalmente:
flutter build apk --release
```

---

## 🌐 CONFIGURACIÓN DE SERVIDORES ICE EN WEBRTC

### **Cómo funciona:**

```dart
// En webrtc_service.dart línea ~18-20:
List<Map<String, dynamic>> _buildIceServers() {
  return TurnStunConfig.buildIceServers();
}
```

### **Orden de prioridad ICE:**

1. **TURN Producción** (si está configurado)
   - Necesario para: NAT simétrico, double-NAT, firewalls restrictivos
   - Recomendado para: 40%+ de redes de producción

2. **STUN Públicos** (Google, siempre disponibles)
   - `stun.l.google.com:19302`
   - `stun1.l.google.com:19302`
   - Etc (5 servidores totales)

3. **TURN Fallback** (solo en DEBUG, metered.ca)
   - Para testing local
   - Rate-limited en producción (no usar)

### **Estructura de ICE Server:**

```dart
// STUN (solo descubrimiento de IP)
{'urls': 'stun:stun.l.google.com:19302'}

// TURN (relay de tráfico)
{
  'urls': 'turn:server.com:3478',
  'username': 'user@server.com',
  'credential': 'password123'
}
```

---

## ✅ VERIFICAR CONFIGURACIÓN

### **En tiempo de compilación:**

```bash
# Compilar con verbose para ver qué TURN se usa:
flutter build apk --release \
  --dart-define=TURN_URL=... \
  --dart-define=TURN_USERNAME=... \
  --dart-define=TURN_CREDENTIAL=... \
  -v

# Buscar en output: "✅ [TURN] Production TURN configured"
```

### **En tiempo de ejecución (en app):**

Agrega este código temporalmente en `main.dart`:

```dart
import 'lib/services/turn_stun_config.dart';

void main() {
  // Debug: Mostrar configuración TURN
  print(TurnStunConfig.getDiagnosticInfo());
  
  runApp(const MyApp());
}
```

**Output esperado en DEBUG:**
```
=== TURN/STUN Configuration ===
Mode: DEBUG (DEVELOPMENT)
TURN Configured: ✅ YES
TURN URL: turn:your-server.com:3478
STUN Servers: 5 public + 2 fallback
Production Validation: ✅ PASS
```

**Output esperado en RELEASE (sin TURN):**
```
=== TURN/STUN Configuration ===
Mode: RELEASE (PRODUCTION)
TURN Configured: ❌ NO
TURN URL: NOT SET (will use public STUN only)
STUN Servers: 5 public + 0 fallback
Production Validation: ❌ FAIL
Issues: 🔴 TURN not configured...
```

---

## 🔧 CAMBIOS ESPECÍFICOS NECESARIOS

### **1. call_service.dart - Agregar validación**

**Buscar:** `Future<String> initiateCall({`

**Agregar después de las primeras validaciones (línea ~76):**

```dart
// Validar TURN en release mode
final turnError = TurnStunConfig.shouldBlockCallInRelease();
if (turnError != null) {
  throw Exception(turnError);
}
```

**Y al inicio del archivo, agregar import:**
```dart
import 'turn_stun_config.dart';
```

---

### **2. call_initiate_screen.dart - Mejorar error handling**

**Buscar:** `} catch (e) {`

**Reemplazar el bloque catch:**

```dart
} catch (e) {
  String errorMsg = 'Error: $e';
  
  // Mostrar error específico para TURN
  if (e.toString().contains('PRODUCTION BLOCKED')) {
    errorMsg = 'Llamadas no disponibles: Servidor TURN no configurado.\n'
               'Contacta al administrador de la aplicación.';
  } else if (e.toString().contains('authenticated')) {
    errorMsg = 'Por favor inicia sesión primero.';
  }
  
  _showError(errorMsg);
}
```

---

### **3. Opcional: Agregar UI de diagnóstico**

En el AppBar de `call_initiate_screen.dart`, agregar botón de debug:

```dart
appBar: AppBar(
  title: const Text('Iniciar Llamada'),
  actions: [
    // Debug button (solo en development)
    if (kDebugMode)
      IconButton(
        icon: const Icon(Icons.info),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('TURN/STUN Config'),
              content: SingleChildScrollView(
                child: Text(TurnStunConfig.getDiagnosticInfo()),
              ),
              actions: [
                TextButton(
                  onPressed: Navigator.of(ctx).pop,
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
      ),
  ],
),
```

**Import:**
```dart
import 'package:flutter/foundation.dart';
import '../../services/turn_stun_config.dart';
```

---

## 📊 MATRIZ DE CONFIGURACIÓN

| Caso | Compilación | TURN Config | Resultado |
|------|------------|------------|-----------|
| **Debug local** | `flutter run` | No importa | ✅ Funciona (fallback test) |
| **Release sin TURN** | `flutter build apk --release` | ❌ NO | 🔴 Llamadas bloqueadas |
| **Release con TURN** | `flutter build apk ... --dart-define=TURN_URL=...` | ✅ SÍ | 🟢 Llamadas habilitadas |
| **Release + enforced** | `... --dart-define=ENFORCE_RELEASE_SECURITY_CONFIG=true` | ❌ NO | 🔴 App no inicia |

---

## 🚨 TROUBLESHOOTING

### Problema: "TURN not configured" en RELEASE pero NO lo quiero bloquear

**Solución:** La validación se hace en `shouldBlockCallInRelease()`. Para deshabilitar el bloqueo:

Edita `turn_stun_config.dart` línea 114-134:
```dart
static String? shouldBlockCallInRelease() {
  if (!kReleaseMode) return null;
  
  // ✅ COMENTAR ESTA LÍNEA PARA DESHABILITAR BLOQUEO:
  // if (!isTurnConfigured()) { ... }
  
  return null; // Siempre permitir
}
```

⚠️ **No recomendado en producción** (llamadas fallarán en 40%+ de redes)

---

### Problema: TURN funciona en Debug pero no en Release

**Causas posibles:**

1. ❌ No pasaste `--dart-define` en compilación
   ```bash
   # ❌ MAL
   flutter build apk --release
   
   # ✅ BIEN
   flutter build apk --release --dart-define=TURN_URL=... 
   ```

2. ❌ TURN_URL vacío o incorrecto
   ```bash
   # ❌ MAL
   --dart-define=TURN_URL=
   --dart-define=TURN_URL=invalid-url
   
   # ✅ BIEN
   --dart-define=TURN_URL=turn:server.com:3478
   ```

3. ❌ Servidor TURN no responde
   ```bash
   # Probar conexión:
   nc -zv your-server.com 3478
   ```

---

### Problema: La app se inicia pero las llamadas fallan silenciosamente

**Diagnóstico:**

```dart
// Agregar en main.dart:
import 'lib/services/turn_stun_config.dart';

void main() {
  final info = TurnStunConfig.getDiagnosticInfo();
  print(info); // Ver en logcat/debug console
  
  runApp(const MyApp());
}
```

Si muestra "TURN Configured: ❌ NO", entonces:
- Recompila con `--dart-define=TURN_URL=...`
- O configura variables de entorno del sistema

---

## 📚 REFERENCIAS

- **WebRTC ICE:** https://developer.mozilla.org/en-US/docs/Glossary/ICE
- **TURN Protocol:** https://tools.ietf.org/html/rfc5766
- **flutter_webrtc:** https://pub.dev/packages/flutter_webrtc
- **Twilio TURN:** https://www.twilio.com/docs/stun-turn
- **Coturn Setup:** https://github.com/coturn/coturn

---

## ✨ RESUMEN RÁPIDO

```
1. Edita: lib/services/call_service.dart
   → Agregar validación TurnStunConfig.shouldBlockCallInRelease()

2. Edita: lib/screens/communication/call_initiate_screen.dart
   → Mejorar manejo de error TURN

3. Compila con TURN:
   flutter build apk --release \
     --dart-define=TURN_URL=turn:your-server.com:3478 \
     --dart-define=TURN_USERNAME=username \
     --dart-define=TURN_CREDENTIAL=password

4. Verifica:
   - APK generado en: build/app/outputs/apk/release/app-release.apk
   - Instalá en dispositivo y prueba llamada
   - Debe funcionar en cualquier red (NAT, firewall, etc.)
```

---

**Fecha:** 2026-06-21  
**Status:** 🟢 READY FOR IMPLEMENTATION  
**Next:** Modificar archivos y recompilar con TURN configurado
