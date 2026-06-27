# 🚀 FLUTTER RUN - GUÍA RÁPIDA PARA 4GB RAM

## ⚡ OPCIÓN RÁPIDA (RECOMENDADA)

```bash
FLUTTER_RUN_OPTIMIZED.bat
```

Doble-clic en este archivo. Automáticamente:
- Mata procesos Java residuales
- Limpia build cache
- Ejecuta `flutter run` con memoria optimizada
- Habilita hot reload

---

## 📋 PASOS SI USAS TERMINAL

### **PASO 1: Limpia (una sola vez)**
```bash
cd C:\Users\Usuario\Documents\orbit
flutter clean
```

### **PASO 2: Obtén dependencias**
```bash
flutter pub get
```

### **PASO 3: Ejecuta (con hot reload)**
```bash
flutter run
```

---

## 🎯 DURANTE FLUTTER RUN

**Presiona:**
- `r` → Hot reload (cambios rápidos, sin perder estado)
- `R` → Hot restart (full restart, reset de estado)
- `q` → Quit (salir)

---

## 📊 TIEMPOS ESPERADOS

| Paso | Tiempo |
|------|--------|
| flutter clean | 10-15 seg |
| flutter pub get | 30-60 seg |
| Primera vez flutter run | 8-12 min |
| Hot reload (después) | 2-5 seg |

---

## ✅ CONFIGURACIÓN APLICADA

### gradle.properties (OPTIMIZADO)

```properties
# 256MB heap (máximo para 4GB RAM)
org.gradle.jvmargs=-Xmx256m -Xms128m

# Daemon HABILITADO (ayuda con hot reload)
org.gradle.daemon=true

# Sin paralelización (ahorra memoria)
org.gradle.parallel=false
org.gradle.workers.max=1

# Cache y config-cache ACTIVADOS
org.gradle.caching=true
org.gradle.configuration-cache=true

# DEBUG: Sin ProGuard (ahorra memoria)
android.enableProguardInDebugBuild=false

# Kotlin incremental
kotlin.incremental=true
```

---

## 🛑 SI FALLA

### Error: "Out of Memory"

**Opción 1: Intenta de nuevo**
```bash
FLUTTER_RUN_OPTIMIZED.bat
```

**Opción 2: Más agresivo**
```bash
taskkill /F /IM java.exe
flutter clean
flutter run
```

### Error: "Gradle task failed"
```bash
rmdir /s /q android\build
rmdir /s /q .dart_tool\build
flutter pub get
flutter run
```

### Se cuelga en "Gradle task"
```bash
# Presiona Ctrl+C
taskkill /F /IM java.exe
flutter run
```

---

## 📱 CONECTAR TELÉFONO

Antes de ejecutar `flutter run`:

1. Conecta Android por USB
2. En el teléfono:
   - Ajustes → Información del dispositivo
   - Presiona "Número de compilación" 7 veces
   - Ajustes → Opciones de desarrollador
   - Activa "Depuración USB"

3. Ejecuta `flutter run`
4. La app se abre automáticamente

---

## ✨ PRÓXIMOS COMANDOS

**Para ver logs:**
```bash
flutter logs
```

**Para reinstalar limpio:**
```bash
flutter uninstall
flutter run
```

**Para debug profundo:**
```bash
flutter run -v
```

---

## 🎓 RESUMEN

**Antes:** 7+ horas compilando RELEASE = IMPOSIBLE
**Ahora:** 12 min compilando DEBUG + hot reload = VIABLE ✅

**Para desarrollo:**
- Usa `flutter run` con hot reload
- Compila DEBUG (mucho más rápido)
- Prueba en tiempo real

**Para release (después):**
- En GitHub Codespaces (16GB RAM)
- `flutter build apk --release`
- 30-40 minutos máximo

---

## 💡 TIPS

1. **Cierra otras aplicaciones** mientras ejecutas
2. **Monitorea RAM**: Win+Shift+Esc → Task Manager → Performance
3. **Si RAM < 500MB**: Reinicia el PC antes
4. **Hot reload falla?** Usa `R` en lugar de `r`

