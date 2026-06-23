@echo off
REM ============================================================
REM Run Debug App with Hot Reload on 4GB RAM System
REM ============================================================

echo.
echo ============================================================
echo  ORBIT: Run Debug with Hot Reload
echo ============================================================
echo.

cd /d C:\Users\Usuario\Documents\orbit

REM Limit Java memory for flutter run
set JAVA_TOOL_OPTIONS=-Xmx256m -Xms128m
set GRADLE_OPTS=-Xmx256m -Xms128m

echo Starting app with debugging...
echo (Connect Android device or start emulator first)
echo.

flutter run -v --debug ^
  --dart-define=TURN_URL=turn:global.relay.metered.ca:443 ^
  --dart-define=TURN_USERNAME=e70cbac304a68ec4f92ff805 ^
  --dart-define=TURN_CREDENTIAL=h/jquALTyVnBtiWN

pause
