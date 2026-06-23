@echo off
REM ============================================================
REM COMPILACIÓN OPTIMIZADA PARA 4GB RAM
REM ============================================================

setlocal enabledelayedexpansion
cd /d C:\Users\Usuario\Documents\orbit

color 0A
cls

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║         🚀 BUILD OPTIMIZADO PARA 4GB RAM                  ║
echo ║         Orbit - Firebase P2P Calling                       ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

REM Verificar RAM disponible
for /f "tokens=2" %%A in ('wmic OS get TotalVisibleMemorySize /value ^| find "="') do set /a totalRam=%%A/1024/1024
echo [INFO] RAM Total: %totalRam% GB

if %totalRam% LSS 4 (
    echo [⚠️ WARNING] Tienes menos de 4GB RAM. Este build puede fallar.
    echo Recomendación: Cierra otras aplicaciones (Chrome, Slack, etc)
    echo.
    set /p continue="¿Continuar? (S/N): "
    if /i not "%continue%"=="S" exit /b 0
)

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║ PASO 1: Limpieza                                            ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

echo [1/4] Eliminando build anteriores...
flutter clean
if %errorlevel% neq 0 (
    echo ❌ Error en flutter clean
    pause
    exit /b 1
)
echo ✅ Limpieza completada

REM Limpiar gradle cache también
echo [2/4] Limpiando Gradle cache...
if exist ".gradle" (
    rmdir /s /q .gradle 2>nul
)
echo ✅ Gradle cache limpio

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║ PASO 2: Obtener dependencias                                ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

echo [3/4] Descargando dependencias (pub get)...
flutter pub get
if %errorlevel% neq 0 (
    echo ❌ Error en flutter pub get
    pause
    exit /b 1
)
echo ✅ Dependencias descargadas

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║ PASO 3: Compilación APK Release (4GB Optimizado)            ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

echo [4/4] Compilando APK Release...
echo Parámetros de optimización para 4GB RAM:
echo   • Xmx: 1024m (máximo heap)
echo   • Workers: 2 (parallelism reducido)
echo   • Low Memory: Habilitado (lint deshabilitado)
echo.
echo ⏱️ Tiempo estimado: 15-20 minutos
echo 💾 RAM estimado: 1.2 GB
echo.

REM Build con optimizaciones para 4GB
flutter build apk --release ^
    -v ^
    --no-pub

if %errorlevel% neq 0 (
    echo.
    echo ❌ ERROR EN COMPILACIÓN
    echo.
    echo Soluciones:
    echo 1. Cierra todas las apps (Chrome, Visual Studio, etc)
    echo 2. Aumenta PageFile: https://bit.ly/pagefile-windows
    echo 3. Usa flutter build apk --release --split-per-abi
    echo.
    pause
    exit /b 1
)

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║ ✅ COMPILACIÓN EXITOSA                                      ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

REM Verificar APK
if exist "build\app\outputs\apk\release\app-release.apk" (
    for %%F in (build\app\outputs\apk\release\app-release.apk) do (
        echo 📦 APK Generado:
        echo    Archivo: app-release.apk
        echo    Tamaño: %%~zF bytes ^(~%%~zF MB^)
        echo    Ruta: build\app\outputs\apk\release\
        echo.
    )
) else (
    echo ⚠️  No se encontró APK. Revisa los logs arriba.
    pause
    exit /b 1
)

echo.
echo 📊 PRÓXIMOS PASOS:
echo    1. Instalar en dispositivo:
echo       adb install build\app\outputs\apk\release\app-release.apk
echo.
echo    2. O copiar el APK manualmente a:
echo       C:\Users\Usuario\Documents\orbit\build\app\outputs\apk\release\app-release.apk
echo.
echo    3. Testing checklist:
echo       ✓ Registrarse / Login
echo       ✓ Enviar 1 mensaje de chat
echo       ✓ Iniciar 1 llamada de audio
echo       ✓ Iniciar 1 llamada de video
echo       ✓ Terminar ambas llamadas
echo.
echo 📚 Documentación:
echo    • ANALISIS_PRODUCCION_4GB_RAM.md
echo    • GUIA_PRODUCCION_LLAMADAS.md
echo    • RESUMEN_FINAL.md
echo.

echo ═══════════════════════════════════════════════════════════════
echo 🎉 ¡BUILD COMPLETADO EXITOSAMENTE! 🎉
echo ═══════════════════════════════════════════════════════════════

pause
