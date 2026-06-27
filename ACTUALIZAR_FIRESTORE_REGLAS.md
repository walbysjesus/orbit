# 🔧 Actualizar Reglas de Firestore - Guía Manual

## ⚡ OPCIÓN 1: Automático (Recomendado)

Si tienes Firebase CLI instalado:

```powershell
# En PowerShell
.\UPDATE_FIRESTORE_RULES.ps1
```

O en Windows cmd:
```batch
UPDATE_FIRESTORE_RULES.bat
```

---

## 📋 OPCIÓN 2: Manual en Firebase Console

### Paso 1: Abre Firebase Console
1. Ve a https://console.firebase.google.com
2. Selecciona tu proyecto **Orbit**

### Paso 2: Abre Firestore Database
1. En el menú izquierdo, haz clic en **Firestore Database**
2. Haz clic en la pestaña **Reglas** (Rules)

### Paso 3: Reemplaza las Reglas
Copia TODO el contenido siguiente y pégalo en el editor:

```firestore
rules_version = '3';
service cloud.firestore {
  match /databases/{database}/documents {
    // ========== DEVELOPMENT MODE ==========
    // Allow all reads/writes for development testing
    // This is ONLY for development - never use in production!
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

### Paso 4: Publica las Reglas
1. Haz clic en el botón azul **Publicar** (Publish)
2. Confirma haciendo clic en **Publicar** nuevamente

### Paso 5: Espera Propagación
⏳ **Espera 1-2 minutos** para que las reglas se propaguen a los servidores de Firebase.

---

## ✅ Verificación

Después de completar cualquier opción:

1. Presiona **R** en la terminal de `flutter run`
2. Abre la app en tu dispositivo
3. Intenta enviar un mensaje de chat

**Si funciona:**
```
✅ Mensaje enviado correctamente
✅ Chat carga sin PERMISSION_DENIED
```

**Si aún no funciona:**
- Espera 2-3 minutos más para propagación
- Recarga la app (presiona R en Flutter)
- Verifica que publicaste las reglas correctamente

---

## ⚠️ IMPORTANTE: Reglas de Producción

Las reglas de arriba (`match /{document=**}`) son **SOLO PARA DESARROLLO**.

Para producción, usa reglas restrictivas:

```firestore
rules_version = '3';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 🔧 Troubleshooting

| Problema | Solución |
|----------|----------|
| "PERMISSION_DENIED" aún persiste | Espera 2-3 min + presiona R en Flutter |
| Botón "Publicar" deshabilitado | Verifica que hayas copiado las reglas correctamente |
| "Invalid rules syntax" | Copia el código exacto de arriba |
| Firebase CLI no funciona | Ejecuta `firebase login` primero |

---

*Última actualización: 2026-06-24*
