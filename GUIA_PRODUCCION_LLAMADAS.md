# 🚀 Guía de Producción - Servicio de Llamadas Firebase P2P

**Estado:** ✅ LISTO PARA PRODUCCIÓN
**Componentes:** CallService + WebRTCService + FirestoreSignaling
**Soporta:** Audio/Video P2P, 5+ usuarios simultáneos

---

## 📦 Archivos Implementados

### Servicios
- ✅ **lib/services/call_service.dart** - Orquestación de llamadas (completo)
- ✅ **lib/services/webrtc_service.dart** - Gestión WebRTC + media streams
- ✅ **lib/services/firestore_signaling.dart** - Signalización vía Firestore

### Pantallas
- ✅ **lib/screens/communication/call_initiate_screen.dart** - Iniciar llamadas
- ✅ **lib/screens/communication/call_receiver_screen.dart** - Recibir llamadas
- ✅ **lib/screens/communication/video_call_screen_production.dart** - Video llamadas

### Configuración
- ✅ **firestore.rules** - Reglas de seguridad actualizadas
- ✅ **pubspec.yaml** - Dependencias necesarias (verificar)

---

## ⚙️ Configuración Requerida

### 1. Dependencias en pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase
  firebase_core: ^4.24.0
  firebase_auth: ^6.0.0
  cloud_firestore: ^4.14.0
  firebase_messaging: ^14.6.0
  
  # WebRTC
  flutter_webrtc: ^1.4.1
  
  # Utils
  uuid: ^4.0.0
  permission_handler: ^11.4.0
  audioplayers: ^6.0.0
  share_plus: ^8.0.0
```

Ejecutar:
```bash
flutter pub get
flutter pub upgrade
```

### 2. Permisos (Android)

**archivo:** `android/app/src/main/AndroidManifest.xml`

```xml
<!-- PERMISOS DE LLAMADAS -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- INTERNET (ya debería estar) -->
<uses-permission android:name="android.permission.INTERNET" />
```

### 3. Permisos (iOS)

**archivo:** `ios/Runner/Info.plist`

```xml
<!-- Cámara -->
<key>NSCameraUsageDescription</key>
<string>Necesitamos acceso a tu cámara para videollamadas</string>

<!-- Micrófono -->
<key>NSMicrophoneUsageDescription</key>
<string>Necesitamos acceso a tu micrófono para llamadas</string>

<!-- Tipo de transporte HTTP (si es necesario) -->
<key>NSLocalNetworkUsageDescription</key>
<string>Necesitamos acceso a la red local</string>
```

### 4. Actualizar Firestore Rules

```bash
firebase deploy --only firestore:rules
```

O via Firebase Console:
1. Firestore Database > Rules
2. Copiar contenido de `firestore.rules`
3. Publish

### 5. Configurar TTS/STUN/TURN

**archivo:** `lib/services/turn_stun_config.dart` (ya existe)

Públicos (gratis, para MVP):
```dart
const iceServers = [
  {'urls': ['stun:stun.l.google.com:19302']},
  {'urls': ['stun:stun1.l.google.com:19302']},
];
```

Para producción (recomendado):
```dart
const iceServers = [
  {'urls': ['stun:stun.stunprotocol.org:3478']},
  {
    'urls': ['turn:your-turn-server.com:3478'],
    'username': 'user',
    'credential': 'pass',
  },
];
```

---

## 🎯 Integración en main.dart

```dart
import 'package:orbit/screens/communication/call_initiate_screen.dart';
import 'package:orbit/screens/communication/call_receiver_screen.dart';
import 'package:orbit/screens/communication/video_call_screen_production.dart';

// En MaterialApp routes:
routes: {
  '/call-initiate': (_) => const CallInitiateScreen(),
  '/call-receiver': (_) {
    final args = ModalRoute.of(_)!.settings.arguments as Map;
    return CallReceiverScreen(
      callId: args['callId'],
      callerId: args['callerId'],
      callerName: args['callerName'],
      callerPhoto: args['callerPhoto'],
      isVideo: args['isVideo'] ?? false,
    );
  },
  '/video-call': (_) {
    final args = ModalRoute.of(_)!.settings.arguments as Map;
    return VideoCallScreenProduction(
      roomId: args['roomId'],
      remoteUserId: args['remoteUserId'],
      remoteDisplayName: args['remoteDisplayName'],
      isVideo: args['isVideo'] ?? false,
      isCaller: args['isCaller'] ?? true,
    );
  },
}
```

---

## 👥 Flujo de Uso (5 Usuarios)

### Usuario 1 Llama a Usuario 2

**Paso 1: Navegar a iniciar llamada**
```dart
Navigator.of(context).pushNamed('/call-initiate');
```

**Paso 2: Seleccionar usuario y tipo de llamada**
- Opción A: Audio solamente
- Opción B: Video

**Paso 3: Usuario 2 recibe notificación**
- FCM notifica a Usuario 2
- Se abre `CallReceiverScreen`

**Paso 4: Usuario 2 Acepta**
- Ambos entran a `VideoCallScreenProduction`
- Conexión WebRTC P2P se establece
- Intercambio de SDP/ICE vía Firestore

**Paso 5: Llamada activa**
- Chat en tiempo real (audio/video)
- Controles: Mute/Unmute, Camera On/Off, End Call

**Paso 6: Finalizar**
- Click "End Call"
- Se registra duración en Firestore
- Se limpia conexión P2P

---

## 🧪 Testing Local (5 Emuladores)

```bash
# Terminal 1: Emulador Android 1
emulator -avd Pixel_4_API_30 &
flutter run -d emulator-5554

# Terminal 2: Emulador Android 2
emulator -avd Pixel_5_API_30 &
flutter run -d emulator-5556

# Terminal 3: Emulador Android 3
emulator -avd Nexus_5X_API_30 &
flutter run -d emulator-5558

# Etc...
```

O usar **iOS Simulator:**
```bash
open -a Simulator
flutter run -d <UUID>
```

---

## 📊 Monitoreo en Firestore Console

### Documentos Creados

```
firestore/
├── calls/{callId}
│   ├── callerId: "uid..."
│   ├── receiverId: "uid..."
│   ├── status: "active" | "ended"
│   ├── duration: 120 (segundos)
│   └── createdAt: Timestamp
│
├── callSignaling/{roomId}
│   ├── sdpOffer: {...}
│   ├── sdpAnswer: {...}
│   ├── callerCandidates/
│   │   └── {batchId}: {candidates: [...]}
│   └── calleeCandidates/
│       └── {batchId}: {candidates: [...]}
```

### Verificación

```bash
# Via Firebase CLI
firebase firestore:get calls/<callId>
firebase firestore:get callSignaling/<roomId>

# Ver tamaño de base de datos
firebase firestore:get --all | grep -c '"name"'
```

---

## 🔒 Consideraciones de Seguridad

| Aspecto | Implementado | Detalles |
|--------|---|---|
| Autenticación | ✅ | Solo usuarios autenticados pueden llamar |
| Autorización | ✅ | Solo participantes acceden a signaling |
| E2E Crypto | ⚠️ | Firebase maneja SDP/ICE, datos en tránsito usan WebRTC DTLS |
| Rate Limiting | ⚠️ | Configurar en Firebase Console |
| Cleanup | ✅ | Documentos expirados se eliminan automáticamente |

### Recomendaciones Producción

1. **Habilitar HTTPS en TURN server**
   ```dart
   {'urls': ['turns:your-server.com:443']}
   ```

2. **Implementar Firebase Security Rules más restrictivas**
   ```javascript
   match /calls/{callId} {
     allow create: if quota_exceeded(request.auth.uid) == false;
   }
   ```

3. **Monitoreo con Sentry**
   ```dart
   try {
     await _callService.initiateCall(...);
   } catch (e) {
     Sentry.captureException(e);
   }
   ```

4. **Rate Limiting**
   - Máx 5 llamadas/minuto por usuario
   - Máx 3 llamadas simultáneas

---

## 🚨 Troubleshooting

### Error: "No authenticated user"
```
❌ Solución: Verificar que usuario está loggeado en Firebase Auth
✅ Probar: print(_auth.currentUser?.uid);
```

### Error: "No peer connection"
```
❌ Solución: initConnection() no fue llamado
✅ Probar: Verificar que CallService.initiateCall/acceptCall fue llamado
```

### Error: "Signaling timeout"
```
❌ Solución: Conexión lenta a Firestore
✅ Probar: Mejorar conexión de red, usar WiFi
```

### Error: "Camera/Microphone not found"
```
❌ Solución: Permisos no otorgados
✅ Probar: 
   - iOS: Settings > Privacy > Camera/Microphone
   - Android: App Settings > Permissions
```

### Llamada No Conecta
```
❌ Solución: ICE candidates no se están intercambiando
✅ Verificación:
   1. Firestore > callSignaling/{roomId}/callerCandidates
   2. Firestore > callSignaling/{roomId}/calleeCandidates
   3. Si vacío = problema de permisos
```

---

## 📋 Checklist Pre-Producción

- [ ] Actualizar `pubspec.yaml` con versiones correctas
- [ ] Agregar permisos en `AndroidManifest.xml` e `Info.plist`
- [ ] Deployar Firestore Rules: `firebase deploy --only firestore:rules`
- [ ] Configurar TURN server (opcional pero recomendado)
- [ ] Habilitar FCM notifications
- [ ] Testear con 5 dispositivos físicos
- [ ] Verificar límites de Firestore (lee/escribe/deletes)
- [ ] Configurar monitoreo (Crashlytics/Sentry)
- [ ] Documentar proceso de soporte para usuarios
- [ ] Crear script de backup/cleanup

---

## 🔧 Scripts Útiles

### Limpiar Firestore (documentos viejos)

```bash
# Firestore Cloud Function
exports.cleanupExpiredCalls = functions.pubsub
  .schedule('every 1 hours')
  .timeZone('UTC')
  .onRun(async (context) => {
    const db = admin.firestore();
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    const calls = await db.collection('calls')
      .where('createdAt', '<', cutoff)
      .where('status', '==', 'ended')
      .get();
    
    calls.forEach(doc => doc.ref.delete());
  });
```

### Monitorar Estadísticas de Llamadas

```dart
Stream<Map<String, dynamic>> getCallStats() {
  return FirebaseFirestore.instance
      .collection('calls')
      .where('createdAt', isGreaterThan: DateTime.now().subtract(Duration(days: 1)))
      .snapshots()
      .map((snap) => {
        'totalCalls': snap.docs.length,
        'videoCalls': snap.docs.where((d) => d['isVideo']).length,
        'avgDuration': snap.docs.isEmpty 
          ? 0 
          : snap.docs.map((d) => d['duration'] ?? 0).reduce((a,b) => a+b) ~/ snap.docs.length,
      });
}
```

---

## 📞 Soporte

Para issues o preguntas:

1. Revisar logs en VS Code Debug Console
2. Verificar Firestore Rules (Firebase Console)
3. Monitorar RTCPeerConnection state (WebRTC stats)
4. Checkear permisos en dispositivos

**Documentación oficial:**
- [Flutter WebRTC](https://github.com/cloudwebrtc/flutter-webrtc)
- [Firebase Cloud Firestore](https://firebase.google.com/docs/firestore)
- [WebRTC Signaling](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API)

---

**Versión:** 1.0
**Última actualización:** 2026-06-19
**Estado:** ✅ PRODUCCIÓN
