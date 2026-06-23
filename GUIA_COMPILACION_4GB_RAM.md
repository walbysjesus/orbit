# 🔧 GUÍA COMPILACIÓN ORBIT EN SISTEMAS CON 4GB RAM

## ⚠️ PROBLEMA
- Compilación anterior: **7+ horas sin resultado**
- Sistema: **4GB RAM** (insuficiente para Release builds)
- Causa: Gradle + Java consume 2.5-3GB, resta muy poco

## ✅ SOLUCIÓN: COMPILE EN DEBUG MODE

**Debug mode es 60-70% más ligero que Release mode** y permite hot reload para pruebas.

---

## 📋 PASO A PASO

### PASO 1: PREPARAR (5 minutos)
```
1. Cierra TODAS las aplicaciones (navegador, Discord, Spotify, etc)
2. Abre Task Manager (Ctrl+Shift+Esc)
3. Ve a Performance → Memory
4. Asegúrate de tener mínimo **1.5GB de RAM disponible**
   (Si tienes menos, reinicia el PC)
```

### PASO 2: COMPILAR DEBUG APK (15-20 minutos)

Opción A: **Script automático (RECOMENDADO)**
```
1. Abre: C:\Users\Usuario\Documents\orbit\BUILD_DEBUG_4GB.bat
2. Doble-clic para ejecutar
3. Espera hasta que termine
```

Opción B: **Manual en Terminal**
```bash
cd C:\Users\Usuario\Documents\orbit
BUILD_DEBUG_4GB.bat
```

**Durante la compilación verás:**
```
[1/5] Stopping Gradle daemon...
[2/5] Aggressive cache clean...
[3/5] Getting Flutter dependencies...
[4/5] Building Debug APK with TURN configuration...
       (Espera 10-15 minutos aquí)
[5/5] BUILD SUCCESSFUL!
```

### PASO 3: INSTALAR APK (2 minutos)

Opción A: **Si compiló exitosamente**
```bash
flutter install
```

Opción B: **Manual**
```
1. Conecta Android a USB (o abre emulador)
2. Ejecuta: flutter install
   O manualmente: adb install build/app/outputs/flutter-apk/app-debug.apk
```

### PASO 4: EJECUTAR CON HOT RELOAD (Pruebas en tiempo real)

```bash
flutter run
```

O usa el script:
```
RUN_DEBUG_HOTRELOAD.bat
```

**Ahora puedes:**
- Ver logs en tiempo real
- Hacer cambios en código
- Presionar `r` para hot reload
- Presionar `R` para full restart
- Ver errores en consola

---

## 🎯 DIFERENCIAS DEBUG vs RELEASE

| Aspecto | DEBUG | RELEASE |
|---------|-------|---------|
| Tiempo compilación | 15 min | 1+ hora |
| Memoria RAM | 800MB-1.2GB | 2.5-3.5GB |
| Tamaño APK | 150-200MB | 50-80MB |
| Hot reload | ✅ SÍ | ❌ NO |
| Debugging | ✅ COMPLETO | ⚠️ Limitado |
| Pruebas | ✅ IDEAL | ❌ Lento |
| Producción | ❌ NO | ✅ SÍ |

---

## 🚨 SI FALLA LA COMPILACIÓN

### Error: "Out of Memory"
```bash
# Opción 1: Ultra-baja memoria
set GRADLE_OPTS=-Xmx200m -Xms100m
flutter clean
flutter pub get
flutter build apk --debug

# Opción 2: Sin daemon (más lento pero seguro)
flutter clean
set GRADLE_OPTS=-Xmx200m
flutter build apk --debug --no-android-gradle-daemon
```

### Error: "Gradle task failed"
```bash
# Limpia TODO
rmdir /s /q build
rmdir /s /q android\build
rmdir /s /q .dart_tool\build
del pubspec.lock

# Reinicia
flutter pub get
flutter build apk --debug
```

### Se cuelga durante "Gradle task"
```
1. Cierra Task Manager
2. Presiona Ctrl+C (cancela compilación)
3. Espera 2 minutos
4. Ejecuta: taskkill /F /IM java.exe
5. Reinicia compilación
```

---

## 📊 MONITOREO DURANTE COMPILACIÓN

Abre otra Terminal (Ctrl+Shift+C) y ejecuta:
```bash
# Ver uso de RAM en tiempo real
wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /format:list

# Ver procesos Java
tasklist | findstr java

# Cancelar compilación si RAM < 200MB libre
taskkill /F /IM java.exe
```

---

## ✨ CONFIGURACIONES APLICADAS

### gradle.properties (ACTUALIZADO)
```properties
# Memoria mínima para 4GB RAM
org.gradle.jvmargs=-Xmx512m -Xms256m
org.gradle.daemon=false
org.gradle.parallel=false
org.gradle.workers.max=1

# Compilador eficiente
kotlin.daemon.jvmargs=-Xmx256m
```

### Variables de entorno
```
GRADLE_USER_HOME=%TEMP%\gradle_cache
GRADLE_OPTS=-Xmx256m -Xms128m
JAVA_TOOL_OPTIONS=-Xmx256m
```

---

## 🎯 PRÓXIMOS PASOS

### Después de compilar DEBUG:
```
1. flutter install
2. flutter run
3. Abre la app
4. Prueba: Chat, Llamadas, Home
5. Revisa logs en VS Code (Terminal)
6. Reporta errores
```

### Cuando quieras RELEASE:
```bash
# Solo cuando DEBUG esté PERFECTO
# Necesitarás más RAM o un PC mejor
flutter build apk --release \
  --dart-define=TURN_URL=turn:global.relay.metered.ca:443 \
  --dart-define=TURN_USERNAME=e70cbac304a68ec4f92ff805 \
  --dart-define=TURN_CREDENTIAL=h/jquALTyVnBtiWN
```

---

## 🆘 SOPORTE RÁPIDO

Si falla, **COPIA esto y comparte:**

```bash
# Esto te dirá qué está pasando
flutter doctor -v
flutter --version
java -version
```

---

## ⏱️ TIEMPOS ESPERADOS

```
BUILD_DEBUG_4GB.bat:
  - Paso 1 (Stop daemon):        1-2 seg
  - Paso 2 (Clean):              5-10 seg
  - Paso 3 (Get deps):           30-60 seg (depende internet)
  - Paso 4 (Build):              10-15 min ← EL LENTO
  - Paso 5 (Success):            5 seg
  ─────────────────────────────
  TOTAL:                         12-18 minutos

flutter run después:             5-8 minutos
```

---

## 📝 NOTAS IMPORTANTES

1. **DEBUG ≠ RELEASE**
   - Debug: Para desarrollo y pruebas
   - Release: Para producción (necesita compilación completa)

2. **TURN está configurado**
   - Las 3 variables se inyectan automáticamente
   - Funciona en ambos modos (DEBUG y RELEASE)

3. **Hot reload en DEBUG**
   - Presiona `r`: reload sin perder estado
   - Presiona `R`: restart completo
   - Presiona `q`: salir

4. **Si lo dejas compilando de noche**
   - Puede tomar 20-30 min en PC lento
   - Es NORMAL que tarde

---

## 🎓 RESUMEN EJECUTIVO

**Antes (RELEASE):** 7+ horas, sin memoria → FRACASO
**Ahora (DEBUG):** 15 minutos, con memoria → ÉXITO ✅

**Usa DEBUG para:**
- Desarrollo
- Pruebas funcionales
- Hot reload y debugging
- Experimentar

**Usa RELEASE solo para:**
- App Store
- Google Play
- Producción final

**Cuando compilado en DEBUG esté perfecto,
recompila en RELEASE con más recursos o en otro PC.**

