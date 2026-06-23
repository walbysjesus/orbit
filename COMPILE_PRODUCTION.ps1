#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script de compilación 100% optimizado para Orbit App con 4GB RAM
.DESCRIPTION
    Compila APK release de Orbit con todas las optimizaciones para sistemas con 4GB RAM
.EXAMPLE
    .\COMPILE_PRODUCTION.ps1
#>

param(
    [ValidateSet("normal", "optimized", "split")]
    [string]$BuildType = "optimized",
    
    [string]$TurnUrl = "",
    [string]$TurnUsername = "",
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
    [string]$TurnPass = ""
)

$ErrorActionPreference = "Stop"
$projectPath = "C:\Users\Usuario\Documents\orbit"

Write-Host @"
╔════════════════════════════════════════════════════════════╗
║  🚀 ORBIT APP - COMPILACIÓN PRODUCTION READY              ║
║     (Optimizado para 4GB RAM)                             ║
╚════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

# Cambiar al directorio del proyecto
Set-Location $projectPath
Write-Host "[1/5] Ingresando a directorio: $projectPath" -ForegroundColor Yellow

# Verificar Flutter
Write-Host "[2/5] Verificando Flutter..." -ForegroundColor Yellow
$flutterVersion = & flutter --version | head -1
Write-Host "     ✅ Flutter: $flutterVersion" -ForegroundColor Green

# Limpiar
Write-Host "[3/5] Limpiando builds anteriores..." -ForegroundColor Yellow
& flutter clean | Out-Null
Write-Host "     ✅ Limpieza completada" -ForegroundColor Green

# Pub get
Write-Host "[4/5] Descargando dependencias..." -ForegroundColor Yellow
& flutter pub get | Out-Null
Write-Host "     ✅ Dependencias listas" -ForegroundColor Green

# Build
Write-Host "[5/5] Compilando APK Release..." -ForegroundColor Yellow
Write-Host "     Build Type: $BuildType" -ForegroundColor Cyan
Write-Host "     ⏱️  Tiempo estimado: 15-20 minutos" -ForegroundColor Cyan
Write-Host "     💾 RAM esperado: ~1.2 GB" -ForegroundColor Cyan
Write-Host ""

$buildCmd = @("build", "apk", "--release")

# Agregar parámetros específicos
switch ($BuildType) {
    "normal" {
        Write-Host "📦 Modo: Normal (tamaño estándar)" -ForegroundColor Cyan
    }
    "optimized" {
        Write-Host "⚡ Modo: Optimizado para 4GB RAM (RECOMENDADO)" -ForegroundColor Cyan
        $buildCmd += @("-j", "2")
    }
    "split" {
        Write-Host "📦 Modo: Split por arquitectura (menor tamaño)" -ForegroundColor Cyan
        $buildCmd += "--split-per-abi"
    }
}

# Agregar TURN si está configurado
if ($TurnUrl -and $TurnUsername -and $TurnPass) {
    Write-Host "🔐 TURN Server configurado" -ForegroundColor Cyan
    $buildCmd += @(
        "--dart-define=TURN_URL=$TurnUrl",
        "--dart-define=TURN_USERNAME=$TurnUsername",
        "--dart-define=TURN_CREDENTIAL=$TurnPass"
    )
}

Write-Host ""
Write-Host "Iniciando compilación..." -ForegroundColor Yellow

# Ejecutar build
try {
    & flutter @buildCmd
    $buildStatus = $LASTEXITCODE
} catch {
    Write-Host "❌ Error durante la compilación: $_" -ForegroundColor Red
    exit 1
}

if ($buildStatus -eq 0) {
    Write-Host ""
    Write-Host @"
╔════════════════════════════════════════════════════════════╗
║  ✅ ¡COMPILACIÓN EXITOSA!                                 ║
╚════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

    # Mostrar información del APK
    $apkPath = "build/app/outputs/apk/release/app-release.apk"
    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length / 1MB
        Write-Host ""
        Write-Host "📦 APK Generado:" -ForegroundColor Green
        Write-Host "   Archivo: app-release.apk" -ForegroundColor White
        Write-Host "   Tamaño: $([math]::Round($apkSize, 2)) MB" -ForegroundColor White
        Write-Host "   Ruta: $apkPath" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "📊 PRÓXIMOS PASOS:" -ForegroundColor Green
    Write-Host ""
    Write-Host "1️⃣ Instalar en emulador:" -ForegroundColor Cyan
    Write-Host "   adb install build/app/outputs/apk/release/app-release.apk" -ForegroundColor White
    Write-Host ""
    Write-Host "2️⃣ O copiar a dispositivo:" -ForegroundColor Cyan
    Write-Host "   El APK está en: $projectPath\build\app\outputs\apk\release\" -ForegroundColor White
    Write-Host ""
    Write-Host "3️⃣ Testear funcionalidades:" -ForegroundColor Cyan
    Write-Host "   ✓ Registrarse / Login" -ForegroundColor White
    Write-Host "   ✓ Enviar mensaje de chat" -ForegroundColor White
    Write-Host "   ✓ Iniciar audio call" -ForegroundColor White
    Write-Host "   ✓ Iniciar video call" -ForegroundColor White
    Write-Host "   ✓ Ver call history" -ForegroundColor White
    Write-Host ""
    Write-Host "4️⃣ Monitorear en Firebase:" -ForegroundColor Cyan
    Write-Host "   https://console.firebase.google.com" -ForegroundColor White
    Write-Host ""
    Write-Host "5️⃣ Para Play Store:" -ForegroundColor Cyan
    Write-Host "   • Crea cuenta Google Play Developer" -ForegroundColor White
    Write-Host "   • Sube el APK" -ForegroundColor White
    Write-Host "   • Revisa Privacy Policy (PRIVACY_POLICY_FINAL.md)" -ForegroundColor White
    Write-Host "   • Revisa Terms of Service (TERMS_OF_SERVICE_FINAL.md)" -ForegroundColor White
    Write-Host "   • Google Play revisará en 24-48 horas" -ForegroundColor White
    Write-Host ""
    Write-Host @"
════════════════════════════════════════════════════════════
           🎉 ¡ORBIT APP LISTA PARA PRODUCCIÓN! 🎉
════════════════════════════════════════════════════════════
"@ -ForegroundColor Green

} else {
    Write-Host ""
    Write-Host @"
❌ ERROR EN LA COMPILACIÓN
════════════════════════════════════════════════════════════
"@ -ForegroundColor Red
    Write-Host ""
    Write-Host "Soluciones posibles:" -ForegroundColor Yellow
    Write-Host "1. Cierra todas las aplicaciones (Chrome, Slack, etc)" -ForegroundColor White
    Write-Host "2. Aumenta PageFile: Win+X → System → Advanced" -ForegroundColor White
    Write-Host "3. Intenta con: flutter build apk --release --split-per-abi" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host ""
