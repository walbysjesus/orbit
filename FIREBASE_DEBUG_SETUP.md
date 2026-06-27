# 🔧 Firebase Debug Setup - Solución a Errores de Autenticación

## 📋 Problemas Detectados
1. **GoogleApiManager Error**: SHA-1 del certificado debug no registrado en Firebase
2. **Firestore PERMISSION_DENIED**: Reglas de Firestore requieren autenticación

---

## ✅ PASO 1: Registrar SHA-1 del Debug Certificate

### Opción A: Obtener SHA-1 (Windows Command Line)
```bash
cd %USERPROFILE%\.android

keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android | findstr SHA1
```

**Resultado esperado:**
```
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

Copia el valor de SHA1 (sin espacios).

### Opción B: Obtener SHA-1 (Windows PowerShell)
```powershell
$keytoolPath = "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe"
& $keytoolPath -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | Select-String "SHA1"
```

### Opción C: Android Studio (GUI)
1. Abre Android Studio
2. Ve a **File** → **Project Structure**
3. En el panel izquierdo, selecciona **Modules** → **app**
4. Haz clic en la pestaña **Signing**
5. Verás el SHA1 en la sección de configuración

---

## 🔐 PASO 2: Registrar SHA-1 en Firebase Console

1. Ve a **[Firebase Console](https://console.firebase.google.com/)**
2. Selecciona tu proyecto **Orbit**
3. Ve a **Project Settings** (engranaje en la esquina superior)
4. En la pestaña **Apps**, selecciona tu app Android
5. En la sección **Certificados SHA**, haz clic en **Agregar certificado SHA**
6. Pega el SHA1 que obtuviste en el PASO 1
7. Haz clic en **Guardar**

**⏳ Espera 1-2 minutos a que se propague** (Firebase actualiza los servicios)

---

## 🛡️ PASO 3: Actualizar Reglas de Firestore

### Para DESARROLLO (Testing local)
Temporalmente abre Firestore a todos:

1. Ve a **Firebase Console** → Tu proyecto → **Firestore Database**
2. Haz clic en pestaña **Reglas**
3. Reemplaza todo el contenido con esto:

```firestore
rules_version = '3';
service cloud.firestore {
  match /databases/{database}/documents {
    // ⚠️ SOLO PARA DESARROLLO - Permite lectura/escritura a todos
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

4. Haz clic en **Publicar**

### Para PRODUCCIÓN (Después de testing)
Protege Firestore requiriendo autenticación:

```firestore
rules_version = '3';
service cloud.firestore {
  match /databases/{database}/documents {
    // Requiere autenticación para todos los documentos
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Opcional: Más específico por colección
    match /messages/{roomId}/{messageId} {
      allow read, write: if request.auth != null;
    }
    
    match /chatRooms/{roomId} {
      allow read, write: if request.auth != null;
    }
    
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
  }
}
```

5. Haz clic en **Publicar**

---

## 📱 PASO 4: Vuelve a ejecutar Flutter

```powershell
cd C:\Users\Usuario\Documents\orbit

# Si flutter run sigue activo, presiona Ctrl+C

flutter run
```

**⏳ Primera compilación: 10-15 minutos**

**✅ Signos de éxito:**
- ✅ App abre sin error "PRODUCTION BLOCKED"
- ✅ Pantalla de login/registro aparece
- ✅ Puedes hacer login
- ✅ Chat carga mensajes sin error PERMISSION_DENIED

---

## 🐛 Solución de Problemas

### Aún veo "GoogleApiManager - Unknown calling package"
→ **Espera 2-3 minutos** después de registrar el SHA1 en Firebase (se propaga lentamente)

### Aún veo "PERMISSION_DENIED" en Firestore
→ **Verifica que publicaste las reglas** (Step 3)

### El app compila pero se cuelga en "Inicializando..."
→ Presiona `r` en la terminal para recargar
→ Si persiste, presiona `R` para restart completo

### Firebase Console muestra el proyecto pero no veo Firestore
→ **Tu proyecto puede tener Realtime Database en lugar de Firestore**
→ Crea una base de datos Firestore: **Firestore Database** → **Crear base de datos**

---

## 🔍 Verificación Manual

Desde la terminal Flutter run:
```
I/flutter: [SHA1 Registered]: Your debug certificate is now registered ✅
I/flutter: [Firestore Rules]: Successfully subscribed to messages collection ✅
```

Si ves estos logs, ¡todo está funcionando!

---

## 📞 Próximos Pasos

Una vez que firebase funcione:

1. **Haz commit** con los cambios de chat_screen.dart:
   ```bash
   git add .
   git commit -m "fix: Add auth validation and improve Firebase error handling"
   ```

2. **Mueve a GitHub Codespaces** (16GB RAM, compilación más rápida)

3. **Build Release APK** (requiere TURN configurado):
   ```bash
   flutter build apk --release \
     --dart-define=TURN_URL=turn:global.relay.metered.ca:443 \
     --dart-define=TURN_USERNAME=e70cbac304a68ec4f92ff805 \
     --dart-define=TURN_CREDENTIAL=h/jquALTyVnBtiWN
   ```

---

## ⚠️ NOTA IMPORTANTE

**NO** es un error que el app tarde 1-2 minutos en cargar mensajes la primera vez:
- Firestore está revalidando permisos
- Los streams están estableciendo conexiones
- ICE candidates se están recopilando (WebRTC)

Si ve errores después de 30 segundos, ahí SÍ hay un problema.

---

*Documento generado automáticamente - Actualizado: 2026-06-23*
