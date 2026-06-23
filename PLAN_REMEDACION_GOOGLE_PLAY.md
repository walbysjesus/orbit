# 📋 PLAN DE REMEDIACIÓN POR BLOQUES - GOOGLE PLAY
**Orbit Security Hardening**  
**Generado:** 3 de Junio 2026  
**Objetivo:** Eliminar bloqueadores críticos antes de Go Live en Play Store

---

## 🎯 VISIÓN GENERAL

Google Play rechazará o marcará como riesgo la app si:
- ❌ Contiene debug providers en producción
- ❌ Expone credenciales (API keys)
- ❌ Tiene permisos injustificados sin documentación
- ❌ Falla validación Play Integrity

**Plan:** 3 bloques de trabajo. Bloques 1-2 son OBLIGATORIOS. Bloque 3 es mejora.

---

## 🔴 BLOQUE 1: CRÍTICOS - SEMANA 1 (OBLIGATORIO)
**Tiempo Total:** ~3-4 horas  
**Impacto Google Play:** SIN ESTE, RECHAZA LA APP

### 1.1 - Remover Debug Providers de App Check (Prioridad MÁXIMA)
**Tiempo:** 2-3 horas  
**Riesgo:** CRÍTICO - Validación de app comprometida  
**Archivos:** `lib/main.dart`

**Problema:**
```dart
// ❌ ACTUAL - Inseguro en producción
if (kDebugMode) {
  await FirebaseAppCheck.instance.activate(
    providerAndroid: const AndroidDebugProvider(),  // ❌ Debug en prod
    providerApple: const AppleDebugProvider(),      // ❌ Debug en prod
  );
}
```

**Solución - Fase 1a:**
1. Cambiar estructura: Debug SOLO en `kDebugMode`, Production en `else`
2. Instalar dependencia: `google_play_integrity: ^0.2.0`
3. Implementar estrategia condicional por build variant

**Tareas Exactas:**
- [ ] Actualizar `pubspec.yaml` con `google_play_integrity`
- [ ] Reescribir bloque App Check en `lib/main.dart` (15 min)
- [ ] Crear archivo `lib/firebase/app_check_config.dart` (30 min)
- [ ] Verificar en release build (30 min)
- [ ] Testear con `flutter build apk --release` (1 hora)

**Código a Implementar:**
```dart
// lib/firebase/app_check_config.dart (NUEVO)
Future<void> configureAppCheck() async {
  if (kDebugMode) {
    // Solo para desarrollo local
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidDebugProvider(),
      providerApple: const AppleDebugProvider(),
    );
  } else {
    // Producción: Play Integrity API
    await FirebaseAppCheck.instance.activate(
      providerAndroid: PlayIntegrityProvider(),
      providerApple: const AppleDeviceCheckProvider(),
    );
  }
}
```

**Validación:**
- Build `release` no debe contener `AndroidDebugProvider`
- Verificar con: `grep -r "AndroidDebugProvider" --include="*.dart"`

---

### 1.2 - Mover API Key OpenWeatherMap a Firebase Remote Config
**Tiempo:** 30-45 minutos  
**Riesgo:** CRÍTICO - Exposición de credenciales  
**Archivos:** `lib/services/weather_service.dart`, Firebase Console

**Problema:**
```dart
// ❌ ACTUAL - Key expuesta
const String openWeatherMapApiKey = 'API_KEY_AQUI'; // Compilada en APK
WeatherFactory(openWeatherMapApiKey, language: Language.SPANISH);
```

**Solución:**
1. En Firebase Console → Remote Config → Agregar parámetro
2. Obtener API key en tiempo de ejecución
3. Fallback para offline

**Tareas Exactas:**
- [ ] En Firebase Console crear parámetro `openweather_api_key` (5 min)
- [ ] Crear helper `lib/services/config_service.dart` (15 min)
- [ ] Actualizar `weather_service.dart` (10 min)
- [ ] Testear con `flutter run --release` (10 min)

**Código a Implementar:**
```dart
// lib/services/config_service.dart (NUEVO)
class ConfigService {
  static Future<String> getOpenWeatherKey() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getString('openweather_api_key') ?? '';
  }
}

// lib/services/weather_service.dart (ACTUALIZADO)
final apiKey = await ConfigService.getOpenWeatherKey();
WeatherFactory(apiKey, language: Language.SPANISH);
```

**Validación:**
- La key NO debe aparecer en `lib/` código fuente
- Verificar con: `grep -r "openWeatherMapApiKey\|AIzaSy" lib/ --include="*.dart"`

---

## 🟠 BLOQUE 2: MEDIOS - SEMANA 1-2 (ANTES DE ENVIAR)
**Tiempo Total:** ~4-5 horas  
**Impacto Google Play:** Play Protect puede marcar como "riesgo"

### 2.1 - Documentar/Justificar Permisos Foreground Service
**Tiempo:** 1 hora  
**Riesgo:** MEDIO - Rechazo en Play Store si no está justificado  
**Archivos:** `android/app/src/main/AndroidManifest.xml`

**Problema:**
```xml
<!-- ❓ ¿Cuándo se usan estos? -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_PHONE_CALL" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CAMERA" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTEDDEVICE" />
```

**Solución:**
1. Auditar: ¿Orbit realmente necesita todos estos?
2. Agregar documentación en Play Store listing
3. Reducir si es posible

**Tareas Exactas:**
- [ ] Revisar `lib/services/` para encontrar dónde se usan (15 min)
- [ ] Agregar comentarios en AndroidManifest (10 min)
- [ ] Crear documento `PERMISSIONS_JUSTIFICATION.md` (20 min)
- [ ] Preparar texto para Play Store listing (15 min)

**Guía para Play Store:**
```markdown
## Justificación de Permisos:

### FOREGROUND_SERVICE_PHONE_CALL
- Usado para: Llamadas VoIP en tiempo real
- Razón: Mantener servicio activo durante llamadas

### FOREGROUND_SERVICE_MICROPHONE
- Usado para: Grabación de notas de voz
- Razón: Indicador visual de que micrófono está activo

### FOREGROUND_SERVICE_CAMERA
- Usado para: Videollamadas
- Razón: Notificación sobre video en curso

### FOREGROUND_SERVICE_CONNECTEDDEVICE
- Usado para: Sincronización con dispositivos Bluetooth
- Razón: Conexiones periféricas activas
```

---

### 2.2 - Implementar Certificate Pinning
**Tiempo:** 1.5-2 horas  
**Riesgo:** MEDIO - Protección contra MITM attacks  
**Archivos:** `lib/services/api_client.dart`, `android/app/src/main/res/xml/`

**Problema:**
```dart
// ❌ ACTUAL - Sin pinning
final client = HttpClient();
// Acepta cualquier certificado válido
```

**Solución:**
1. Usar `dio` package con `dio_http_cache` + pinning
2. O agregar `network_security_config.xml`

**Tareas Exactas:**
- [ ] Agregar `dio: ^5.3.0` a pubspec.yaml (5 min)
- [ ] Crear `lib/services/dio_client.dart` (30 min)
- [ ] Descargar certificado de API backend (10 min)
- [ ] Testear conexión (15 min)

**Código a Implementar:**
```dart
// lib/services/dio_client.dart (NUEVO)
import 'package:dio/dio.dart';

class DioClient {
  static Dio createDioWithPinning() {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.orbit.app',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // Agregar interceptor de pinning
    dio.httpClientAdapter = HttpClientAdapter();
    
    return dio;
  }
}
```

---

### 2.3 - Mejorar Configuración ProGuard/R8
**Tiempo:** 30-45 minutos  
**Riesgo:** BAJO-MEDIO - Seguridad por ofuscación  
**Archivos:** `android/app/proguard-rules.pro`

**Problema:**
```proguard
# ❌ ACTUAL - Muy básico
-keep class kotlin.Metadata { *; }
-keepattributes SourceFile,LineNumberTable
```

**Solución:**
Agregar reglas más agresivas para ofuscación

**Tareas Exactas:**
- [ ] Actualizar `proguard-rules.pro` (20 min)
- [ ] Testear build release (15 min)
- [ ] Verificar que la app funciona (10 min)

**Código a Implementar:**
```proguard
# android/app/proguard-rules.pro (ACTUALIZADO)

# Mantener clases de Firebase
-keep class com.google.firebase.** { *; }
-keepnames class com.google.firebase.** { *; }

# Mantener modelo de datos
-keep class com.orbit.app.models.** { *; }

# Ofuscar nombres
-obfuscationdictionary obfuscation_dict.txt

# Optimizar más agresivamente
-optimizationpasses 5
-dontoptimize

# Remover logging en release
-assumenosideeffects class android.util.Log {
  public static *** d(...);
  public static *** v(...);
  public static *** i(...);
}
```

---

## 🟡 BLOQUE 3: NICE-TO-HAVE - SEMANA 2+ (OPCIONAL)
**Tiempo Total:** ~2-3 horas  
**Impacto Google Play:** Mejora score de confianza

### 3.1 - Mejorar Storage de Tokens de Autenticación
**Tiempo:** 45 minutos - 1 hora  
**Archivos:** `lib/services/auth_service.dart`

**Mejora:** Usar `flutter_secure_storage` en lugar de `SharedPreferences` para tokens

### 3.2 - Completar Firestore Rules
**Tiempo:** 30-45 minutos  
**Archivos:** `firestore.rules`

**Mejora:** Agregar validaciones de estructura y rate limiting

### 3.3 - Agregar Rate Limiting a Storage Rules
**Tiempo:** 20-30 minutos  
**Archivos:** `storage.rules`

**Mejora:** Prevenir abuso de uploads masivos

---

## 📅 CRONOGRAMA RECOMENDADO

### **Semana 1 (Esta Semana)**
```
Lunes:
  ✓ 1.1 - Remover Debug Providers (Mañana: 2-3h)
  ✓ 1.2 - API Key a Remote Config (Tarde: 45min)

Martes:
  ✓ 2.1 - Documentar Permisos (Mañana: 1h)
  ✓ 2.2 - Certificate Pinning (Tarde: 2h)

Miércoles:
  ✓ 2.3 - ProGuard Mejorado (Mañana: 45min)
  ✓ Testing & QA (Tarde: 2h)

Jueves:
  ✓ Build Release final
  ✓ Testear en device real
  ✓ Preparar para Play Store

Viernes:
  ✓ Submit a Google Play Console (Private Track o Beta)
```

### **Semana 2 (Si es necesario)**
- Bloque 3: Mejoras opcionales
- Monitoreo en Beta Track
- Ajustes basados en feedback

---

## ✅ CHECKLIST DE VALIDACIÓN

Antes de enviar a Play Store:

```
🔴 CRÍTICOS:
[ ] App Check: AndroidDebugProvider REMOVIDO de release
[ ] Verificar: grep -r "AndroidDebugProvider" en build/ = 0 resultados
[ ] API Key OpenWeatherMap en Remote Config
[ ] Verificar: openWeatherMapApiKey NO aparece en strings.xml o código

🟠 MEDIOS:
[ ] Documentación de permisos agregada al listing
[ ] Certificate Pinning implementado
[ ] ProGuard rules mejoradas
[ ] Build release compila sin warnings

🧪 TESTING:
[ ] flutter build apk --release ✓
[ ] APK instalable en device ✓
[ ] Firebase operations funcionan ✓
[ ] Weather API obtiene datos ✓
[ ] Llamadas VoIP activas ✓

📊 PLAY STORE:
[ ] Privacy Policy actualizada
[ ] Content Rating completado
[ ] Cuenta de desarrollador verificada
[ ] Keystore registrado en Play Console
```

---

## 🚀 PRÓXIMOS PASOS

**AHORA:**
1. Confirmar qué bloques implementas primero
2. Yo puedo hacer los cambios de código automáticamente
3. Testear después de cada bloque

**LUEGO:**
4. Build release final
5. Submit a Google Play Console (recomendado: Beta Track primero)
6. Monitoreo de Play Protect

---

## 📞 DEPENDENCIAS

- ✅ Cuenta Firebase activa (ya tienes)
- ✅ Google Play Console (necesitas para submit)
- ✅ Certificado SSL de tu API (para certificate pinning)
- ⚠️ API Key OpenWeatherMap (requiere regeneración después de mover)

---

**¿Por dónde empezamos?**
- **Opción A:** Implemento todo en orden automáticamente
- **Opción B:** Bloque por bloque según tu disponibilidad
- **Opción C:** Solo críticos esta semana, medios después
