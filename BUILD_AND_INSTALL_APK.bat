@echo off
REM ============================================================
REM ORBIT: Build APK + Install on Device
REM ============================================================
REM Genera el APK con credenciales TURN y lo instala en el movil.
REM El APK queda en build\app\outputs\flutter-apk\app-debug.apk
REM para que puedas instalarlo tambien en un segundo dispositivo.

echo.
echo ============================================================
echo  ORBIT: Build APK + Instalar en Dispositivo
echo ============================================================
echo.

setlocal enabledelayedexpansion
cd /d C:\Users\Usuario\Documents\orbit

where flutter >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Flutter no esta en PATH.
  pause
  exit /b 1
)

REM --- TURN credentials ---
set TURN_URL=turn:global.relay.metered.ca:443
set TURN_USERNAME=e70cbac304a68ec4f92ff805
set TURN_CREDENTIAL=h/jquALTyVnBtiWN

REM Step 1: Build APK debug
echo [1/3] Construyendo APK debug con credenciales TURN...
echo       (puede tardar 10-20 min la primera vez)
echo.

flutter build apk --debug ^
  --dart-define=TURN_URL=%TURN_URL% ^
  --dart-define=TURN_USERNAME=%TURN_USERNAME% ^
  --dart-define=TURN_CREDENTIAL=%TURN_CREDENTIAL%

if errorlevel 1 (
  echo.
  echo [ERROR] Build fallo. Revisa los errores arriba.
  pause
  exit /b 1
)

echo.
echo [OK] APK generado en:
echo      build\app\outputs\flutter-apk\app-debug.apk
echo.

REM Step 2: Detectar dispositivos
echo [2/3] Dispositivos conectados:
flutter devices
echo.
set /p DEVICE_ID=Ingresa Device ID para instalar (vacio = omitir instalacion): 

if "%DEVICE_ID%"=="" (
  echo.
  echo [INFO] Instalacion omitida. Copia el APK manualmente:
  echo        build\app\outputs\flutter-apk\app-debug.apk
  echo.
  goto :OPEN_FOLDER
)

REM Step 3: Install APK on device
echo.
echo [3/3] Instalando APK en dispositivo %DEVICE_ID%...
adb -s %DEVICE_ID% install -r build\app\outputs\flutter-apk\app-debug.apk

if errorlevel 1 (
  echo.
  echo [WARN] adb install fallo. Intenta instalar el APK manualmente.
) else (
  echo.
  echo [OK] APK instalado correctamente en %DEVICE_ID%.
)

:OPEN_FOLDER
echo.
echo Abriendo carpeta del APK...
explorer build\app\outputs\flutter-apk

echo.
echo ============================================================
echo  Para instalar en el SEGUNDO dispositivo:
echo  1. Conecta el segundo movil con USB
echo  2. Ejecuta:  adb install build\app\outputs\flutter-apk\app-debug.apk
echo     O copia el APK y comparte por WhatsApp/Drive.
echo ============================================================
echo.
pause
