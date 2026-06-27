# 🚀 ACTUALIZACIÓN AUTOMÁTICA DE REGLAS DE FIRESTORE

## ✅ Archivos Creados Automáticamente

1. **firestore.rules.dev** - Reglas para desarrollo
2. **UPDATE_FIRESTORE_RULES.ps1** - Script PowerShell automático
3. **UPDATE_FIRESTORE_RULES.bat** - Script Batch automático  
4. **ACTUALIZAR_FIRESTORE_REGLAS.md** - Guía manual completa

---

## 🎯 ¿QUÉ HACER AHORA?

### OPCIÓN A: Automático (Recomendado) - 2 minutos

#### En PowerShell:
```powershell
# Abre PowerShell en el directorio del proyecto
.\UPDATE_FIRESTORE_RULES.ps1

# Sigue las instrucciones:
# 1. Ingresa tu PROJECT_ID (ej: orbit-abc123)
# 2. El script desplegará las reglas automáticamente
# 3. Presiona R en Flutter terminal
```

#### En Windows cmd.exe:
```batch
UPDATE_FIRESTORE_RULES.bat

# Sigue las instrucciones:
# 1. Ingresa tu PROJECT_ID 
# 2. El script desplegará las reglas automáticamente
# 3. Presiona R en Flutter terminal
```

**Requisito:** Tener Firebase CLI instalado
```bash
npm install -g firebase-tools
firebase login
```

---

### OPCIÓN B: Manual en Firebase Console - 5 minutos

1. Ve a https://console.firebase.google.com
2. Proyecto → **Firestore Database** → Pestaña **Reglas**
3. Copia y pega:
```firestore
rules_version = '3';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```
4. Haz clic en **Publicar**
5. Presiona **R** en Flutter terminal

---

## 📊 Resumen de Cambios

| Paso | Estado | Acción |
|------|--------|--------|
| ✅ Arreglar código | COMPLETADO | LateInitializationError + infinite retries |
| ✅ Crear scripts | COMPLETADO | UPDATE_FIRESTORE_RULES.ps1 y .bat |
| ⏳ Actualizar reglas | PENDIENTE | Ejecuta script O haz manualmente |
| ⏳ Reiniciar Flutter | PENDIENTE | Presiona R en terminal |

---

## 🚦 Próximos Pasos

1. **Ejecuta script automático** (Opción A) O manualmente (Opción B)
2. **Espera 1-2 minutos** para propagación
3. **Presiona R** en terminal Flutter
4. **Verifica:** Intenta enviar mensaje de chat

---

## ✨ Resultado Esperado

```
✅ Chat carga sin PERMISSION_DENIED
✅ Puedes enviar y recibir mensajes
✅ Video call no crashea
✅ No hay infinite retries
```

---

*Creado automáticamente: 2026-06-24*
