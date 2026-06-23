@echo off
REM ============================================================
REM Build Debug APK for 4GB RAM System
REM ============================================================
REM This script compiles Orbit in DEBUG mode (much lighter)
REM with memory optimization for 4GB RAM systems

echo.
echo ============================================================
echo  ORBIT: Debug Build for 4GB RAM
echo ============================================================
echo.

setlocal enabledelayedexpansion

cd /d C:\Users\Usuario\Documents\orbit

REM Step 1: Kill any existing Gradle daemon
echo [1/5] Stopping Gradle daemon...
taskkill /F /IM java.exe >nul 2>&1
timeout /t 2 /nobreak

REM Step 2: Clean aggressively
echo [2/5] Aggressive cache clean...
if exist build rmdir /s /q build >nul 2>&1
if exist .dart_tool\build rmdir /s /q .dart_tool\build >nul 2>&1
if exist android\.gradle rmdir /s /q android\.gradle >nul 2>&1
if exist android\build rmdir /s /q android\build >nul 2>&1
if exist pubspec.lock del pubspec.lock >nul 2>&1

echo       Cleaned old builds and caches

REM Step 3: Get dependencies
echo [3/5] Getting Flutter dependencies...
flutter pub get

REM Step 4: Build APK (Debug = much lighter than Release)
echo [4/5] Building Debug APK with TURN configuration...
echo       (This will take 10-15 minutes on 4GB RAM)
echo.

REM Use minimal memory settings for build
set GRADLE_USER_HOME=%TEMP%\gradle_cache
set GRADLE_OPTS=-Xmx256m -Xms128m -XX:MaxMetaspaceSize=64m -XX:+UseG1GC

flutter build apk ^
  --debug ^
  --dart-define=TURN_URL=turn:global.relay.metered.ca:443 ^
  --dart-define=TURN_USERNAME=e70cbac304a68ec4f92ff805 ^
  --dart-define=TURN_CREDENTIAL=h/jquALTyVnBtiWN

if errorlevel 1 (
    echo.
    echo [ERROR] Build failed. Trying recovery...
    echo.
    taskkill /F /IM java.exe >nul 2>&1
    timeout /t 3 /nobreak
    
    echo Retrying with ultra-low memory settings...
    set GRADLE_OPTS=-Xmx200m -Xms100m -XX:MaxMetaspaceSize=32m
    
    flutter build apk ^
      --debug ^
      --dart-define=TURN_URL=turn:global.relay.metered.ca:443 ^
      --dart-define=TURN_USERNAME=e70cbac304a68ec4f92ff805 ^
      --dart-define=TURN_CREDENTIAL=h/jquALTyVnBtiWN
)

REM Step 5: Check result
if exist build\app\outputs\flutter-apk\app-debug.apk (
    echo.
    echo ============================================================
    echo  BUILD SUCCESSFUL!
    echo ============================================================
    echo.
    echo APK location:
    echo   C:\Users\Usuario\Documents\orbit\build\app\outputs\flutter-apk\app-debug.apk
    echo.
    echo Size: 
    for %%A in (build\app\outputs\flutter-apk\app-debug.apk) do echo   %%~zA bytes
    echo.
    echo Next steps:
    echo   1. flutter install
    echo   2. flutter run
    echo.
) else (
    echo.
    echo ============================================================
    echo  BUILD FAILED
    echo ============================================================
    echo.
    echo If build still fails, try:
    echo   1. Close all other applications
    echo   2. Disable antivirus temporarily
    echo   3. Check Windows Task Manager (Resource Monitor tab)
    echo.
)

echo.
pause
