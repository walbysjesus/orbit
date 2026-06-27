@echo off
REM ============================================================
REM Flutter Run - Optimized for 4GB RAM
REM ============================================================
REM This script validates mobile device and runs flutter install+run

echo.
echo ============================================================
echo  ORBIT: Flutter Run (4GB RAM Optimized)
echo ============================================================
echo.

setlocal enabledelayedexpansion

cd /d C:\Users\Usuario\Documents\orbit

where flutter >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Flutter no esta instalado o no esta en PATH.
  echo         Instala Flutter o abre una terminal con Flutter configurado.
  echo.
  pause
  exit /b 1
)

REM Step 1: Kill any Java/Gradle daemon processes
echo [1/4] Stopping background processes...
taskkill /F /IM java.exe >nul 2>&1
timeout /t 2 /nobreak

REM Step 2: Ensure clean state
echo [2/4] Preparing build...
if exist .dart_tool\build rmdir /s /q .dart_tool\build >nul 2>&1

REM Step 3: Detect connected devices
echo [3/4] Checking connected devices...
flutter devices
echo.
set /p DEVICE_ID=Ingresa Device ID (vacio = automatico): 
echo.

REM Step 4: Run with minimal memory footprint and install on selected device
echo [4/4] Running app and installing on mobile...
echo       Press 'r' for reload, 'R' for restart, 'q' to quit
echo.

REM Set minimal memory for this run
set GRADLE_OPTS=-Xmx256m -Xms128m
set JAVA_TOOL_OPTIONS=-Xmx256m -Xms128m

set TURN_URL=turn:global.relay.metered.ca:443
set TURN_USERNAME=e70cbac304a68ec4f92ff805
set TURN_CREDENTIAL=h/jquALTyVnBtiWN

if "%DEVICE_ID%"=="" (
  flutter run --dart-define=TURN_URL=%TURN_URL% --dart-define=TURN_USERNAME=%TURN_USERNAME% --dart-define=TURN_CREDENTIAL=%TURN_CREDENTIAL%
) else (
  flutter run -d %DEVICE_ID% --dart-define=TURN_URL=%TURN_URL% --dart-define=TURN_USERNAME=%TURN_USERNAME% --dart-define=TURN_CREDENTIAL=%TURN_CREDENTIAL%
)

echo.
pause
