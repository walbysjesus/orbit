@echo off
REM Script para actualizar reglas de Firestore automáticamente
REM Requiere: Firebase CLI instalado (npm install -g firebase-tools)

echo.
echo ============================================================
echo Firebase Firestore Rules Update
echo ============================================================
echo.

REM Verificar si Firebase CLI está instalado
where firebase >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Firebase CLI no encontrado.
    echo.
    echo Instálalo con:
    echo   npm install -g firebase-tools
    echo.
    pause
    exit /b 1
)

echo Verificando conexión a Firebase...
firebase projects:list >nul 2>nul
if %errorlevel% neq 0 (
    echo.
    echo ERROR: No autenticado en Firebase.
    echo.
    echo Ejecuta:
    echo   firebase login
    echo.
    pause
    exit /b 1
)

echo.
echo Selecciona el proyecto Orbit:
echo.

firebase projects:list

echo.
set /p PROJECT_ID="Ingresa el PROJECT_ID (ej: orbit-abc123): "

if "%PROJECT_ID%"=="" (
    echo ERROR: PROJECT_ID no puede estar vacío.
    pause
    exit /b 1
)

echo.
echo Desplegando reglas de Firestore...
echo.

firebase deploy --project=%PROJECT_ID% --only firestore:rules

if %errorlevel% equ 0 (
    echo.
    echo ============================================================
    echo SUCCESS: Reglas de Firestore actualizadas! 
    echo ============================================================
    echo.
    echo Ahora presiona R en la terminal de Flutter para reiniciar.
    echo.
) else (
    echo.
    echo ERROR: Fallo al desplegar reglas.
    echo.
)

pause
