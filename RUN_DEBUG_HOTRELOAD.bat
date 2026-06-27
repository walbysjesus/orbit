@echo off
REM ============================================================
REM Run Debug App with Hot Reload on 4GB RAM System
REM ============================================================

echo.
echo ============================================================
echo  ORBIT: Run Debug with Hot Reload
echo ============================================================
echo.

setlocal enabledelayedexpansion
cd /d C:\Users\Usuario\Documents\orbit

where flutter >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Flutter no esta instalado o no esta en PATH.
  pause
  exit /b 1
)

REM Limit Java memory for flutter run
set JAVA_TOOL_OPTIONS=-Xmx256m -Xms128m
set GRADLE_OPTS=-Xmx256m -Xms128m

set TURN_URL=turn:global.relay.metered.ca:443
set TURN_USERNAME=e70cbac304a68ec4f92ff805
set TURN_CREDENTIAL=h/jquALTyVnBtiWN

echo Dispositivos conectados:
flutter devices
echo.
set /p DEVICE_ID=Ingresa Device ID para debug (vacio = automatico): 
echo.
echo Iniciando app en modo debug...
echo Teclas: r=hot reload, R=hot restart, q=salir
echo.

if "%DEVICE_ID%"=="" (
  flutter run --debug ^
    --dart-define=TURN_URL=%TURN_URL% ^
    --dart-define=TURN_USERNAME=%TURN_USERNAME% ^
    --dart-define=TURN_CREDENTIAL=%TURN_CREDENTIAL%
) else (
  flutter run -d %DEVICE_ID% --debug ^
    --dart-define=TURN_URL=%TURN_URL% ^
    --dart-define=TURN_USERNAME=%TURN_USERNAME% ^
    --dart-define=TURN_CREDENTIAL=%TURN_CREDENTIAL%
)

pause
