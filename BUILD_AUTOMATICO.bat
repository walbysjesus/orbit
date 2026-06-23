@echo off
REM ============================================================
REM Script Automático - Build APK Release + Testing
REM ============================================================

setlocal enabledelayedexpansion
cd /d C:\Users\Usuario\Documents\orbit

echo.
echo ============================================================
echo  🚀 COMPILACIÓN AUTOMÁTICA - ORBIT LLAMADAS FIREBASE
echo ============================================================
echo.

REM Paso 1: Verificar Flutter
echo [1/5] Verificando Flutter...
flutter --version
if %errorlevel% neq 0 (
    echo ❌ Flutter no está instalado
    pause
    exit /b 1
)

REM Paso 2: Clean
echo.
echo [2/5] Limpiando compilaciones anteriores...
flutter clean
if %errorlevel% neq 0 (
    echo ❌ Error en flutter clean
    pause
    exit /b 1
)
echo ✅ Clean completado

REM Paso 3: Pub Get
echo.
echo [3/5] Descargando dependencias...
flutter pub get
if %errorlevel% neq 0 (
    echo ❌ Error en flutter pub get
    pause
    exit /b 1
)
echo ✅ Dependencias descargadas

REM Paso 4: Elegir modo de compilación
echo.
echo [4/5] Seleccionando modo de compilación...
echo.
echo Opciones:
echo   1 = APK Release (Producción)
echo   2 = Flutter Run (Testing en emulador)
echo.
set /p BUILD_MODE="Selecciona (1 o 2): "

if "%BUILD_MODE%"=="1" (
    echo.
    echo ⏳ Compilando APK Release...
    echo Tiempo estimado: 10-15 minutos
    echo.
    flutter build apk --release
    if %errorlevel% neq 0 (
        echo ❌ Error en build apk
        pause
        exit /b 1
    )
    echo.
    echo ✅ APK generado en: build\app\outputs\apk\release\app-release.apk
    echo.
    echo 📊 Información del APK:
    for %%F in (build\app\outputs\apk\release\app-release.apk) do (
        echo    Archivo: app-release.apk
        echo    Tamaño: %%~zF bytes
    )
) else if "%BUILD_MODE%"=="2" (
    echo.
    echo ⏳ Ejecutando en emulador...
    flutter run
) else (
    echo ❌ Opción inválida
    pause
    exit /b 1
)

REM Paso 5: Finalización
echo.
echo ============================================================
echo ✅ COMPILACIÓN COMPLETADA
echo ============================================================
echo.
echo 📚 Documentación:
echo    • RESUMEN_FINAL.md - Resumen general
echo    • CHECKLIST_IMPLEMENTACION.md - Checklist detallado
echo    • GUIA_PRODUCCION_LLAMADAS.md - Guía de producción
echo.
echo 🎯 Próximos pasos:
echo    1. Testear con 2 emuladores (audio + video)
echo    2. Testear con 5 emuladores (múltiples usuarios)
echo    3. Verificar logs en Firebase Console
echo    4. Deploy a Play Store (opcional)
echo.
echo ============================================================
pause
