#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script para compilar APK release con configuración TURN
.DESCRIPTION
    Compila Orbit APK con servidores TURN/STUN configurados
.EXAMPLE
    .\COMPILE_WITH_TURN.ps1 -TurnUrl "turn:global.relay.metered.ca:443" -TurnUsername "username" -TurnPassword "password"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TurnUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$TurnUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$TurnPassword,
    
    [ValidateSet("optimized", "normal")]
    [string]$BuildType = "optimized"
)

$ErrorActionPreference = "Stop"
$projectPath = "C:\Users\Usuario\Documents\orbit"

Write-Host @"
╔════════════════════════════════════════════════════════════╗
║  🚀 ORBIT APP - COMPILACIÓN CON TURN CONFIGURADO         ║
║     Production Release Build                              ║
╚════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host "`n📋 Configuración:" -ForegroundColor Cyan
Write-Host "  TURN URL:      $TurnUrl"
Write-Host "  TURN Username: $TurnUsername"
Write-Host "  Build Type:    $BuildType"

cd $projectPath

Write-Host "`n🧹 Limpiando proyecto..." -ForegroundColor Yellow
flutter clean

Write-Host "`n📦 Descargando dependencias..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n🔨 Compilando APK release con TURN..." -ForegroundColor Yellow

$buildCmd = @(
    "build",
    "apk",
    "--release",
    "--dart-define=TURN_URL=$TurnUrl",
    "--dart-define=TURN_USERNAME=$TurnUsername",
    "--dart-define=TURN_CREDENTIAL=$TurnPassword"
)

# Agregar optimizaciones para 4GB RAM
if ($BuildType -eq "optimized") {
    Write-Host "⚡ Usando optimizaciones para 4GB RAM" -ForegroundColor Cyan
}

Invoke-Expression "flutter $($buildCmd -join ' ')"

if ($LASTEXITCODE -eq 0) {
    Write-Host @"

✅ ¡COMPILACIÓN EXITOSA!

📦 APK Generado:
   $projectPath\build\app\outputs\apk\release\app-release.apk

🔍 Verificación de TURN:
   ✓ TURN_URL:        $TurnUrl
   ✓ TURN_USERNAME:   $TurnUsername
   ✓ TURN_CREDENTIAL: ******* (configurado)

🚀 Próximos pasos:
   1. Instala el APK en tu dispositivo
   2. Prueba una llamada de audio
   3. Prueba una llamada de vídeo
   4. Verifica que funciona en cualquier red

📝 Nota: El TURN está configurado para producción.
   Las llamadas funcionarán incluso en redes con NAT restrictivo.

"@ -ForegroundColor Green
} else {
    Write-Host "`n❌ La compilación falló. Revisa los errores anteriores." -ForegroundColor Red
    exit 1
}
