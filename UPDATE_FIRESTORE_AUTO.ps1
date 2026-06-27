# Script automático para desplegar reglas de Firestore sin input
# Usa el proyecto "current" de Firebase automáticamente

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Firebase Firestore Rules - Auto Deploy (No Input)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Verificar si Firebase CLI está instalado
try {
    firebase --version | Out-Null
    Write-Host "✅ Firebase CLI encontrado" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Firebase CLI no encontrado" -ForegroundColor Red
    Write-Host ""
    Write-Host "Instálalo con:" -ForegroundColor Yellow
    Write-Host "  npm install -g firebase-tools" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Host ""

# Obtener el proyecto actual sin input
Write-Host "Obteniendo proyecto actual..." -ForegroundColor Cyan

# Intentar obtener proyecto actual del contexto Firebase
$currentProject = firebase use 2>&1 | Select-String "Currently using project" | ForEach-Object { 
    $_ -match "Currently using project \[([^\]]+)\]" | Out-Null
    $matches[1]
}

if ([string]::IsNullOrWhiteSpace($currentProject)) {
    # Si no hay proyecto actual, obtener del archivo .firebaserc
    if (Test-Path ".firebaserc") {
        $firebaserc = Get-Content ".firebaserc" | ConvertFrom-Json
        $currentProject = $firebaserc.projects.default
    }
}

if ([string]::IsNullOrWhiteSpace($currentProject)) {
    Write-Host "❌ ERROR: No se pudo determinar el proyecto actual" -ForegroundColor Red
    Write-Host ""
    Write-Host "Intenta:" -ForegroundColor Yellow
    Write-Host "  firebase use orbit-app-1" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Host "✅ Proyecto actual: $currentProject" -ForegroundColor Green
Write-Host ""

# Copiar archivo de desarrollo a firestore.rules
Write-Host "Preparando reglas de Firestore..." -ForegroundColor Cyan
if (Test-Path "firestore.rules.dev") {
    Copy-Item -Path "firestore.rules.dev" -Destination "firestore.rules" -Force
    Write-Host "✅ Archivo firestore.rules.dev copiado a firestore.rules" -ForegroundColor Green
} else {
    Write-Host "⚠️ Archivo firestore.rules.dev no encontrado, usando firestore.rules existente" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Desplegando reglas de Firestore..." -ForegroundColor Cyan
Write-Host ""

# Desplegar reglas
firebase deploy --project=$currentProject --only firestore:rules

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "✅ SUCCESS: Reglas de Firestore actualizadas!" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Proyecto: $currentProject" -ForegroundColor Green
    Write-Host ""
    Write-Host "Próximos pasos:" -ForegroundColor Cyan
    Write-Host "1. Presiona 'R' en la terminal de Flutter para reiniciar" -ForegroundColor White
    Write-Host "2. El chat debería cargar sin PERMISSION_DENIED" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "❌ ERROR: Fallo al desplegar reglas" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Soluciones:" -ForegroundColor Yellow
    Write-Host "1. Verifica conexión a Firebase: firebase login" -ForegroundColor White
    Write-Host "2. Verifica proyecto: firebase use orbit-app-1" -ForegroundColor White
    Write-Host "3. Intenta manualmente en Firebase Console" -ForegroundColor White
    Write-Host ""
}

Read-Host "Presiona Enter para salir"
