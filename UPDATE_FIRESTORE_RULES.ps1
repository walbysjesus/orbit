# Script para actualizar reglas de Firestore automáticamente
# Requiere: Firebase CLI instalado (npm install -g firebase-tools)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Firebase Firestore Rules Auto-Update" -ForegroundColor Cyan
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

# Verificar autenticación
Write-Host "Verificando autenticación Firebase..." -ForegroundColor Cyan
$output = firebase projects:list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ERROR: No autenticado en Firebase" -ForegroundColor Red
    Write-Host ""
    Write-Host "Ejecuta:" -ForegroundColor Yellow
    Write-Host "  firebase login" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Host "✅ Autenticado en Firebase" -ForegroundColor Green
Write-Host ""

# Mostrar proyectos disponibles
Write-Host "Proyectos disponibles:" -ForegroundColor Cyan
Write-Host ""
firebase projects:list
Write-Host ""

# Pedir PROJECT_ID
$PROJECT_ID = Read-Host "Ingresa PROJECT_ID del proyecto Orbit (ej: orbit-abc123)"

if ([string]::IsNullOrWhiteSpace($PROJECT_ID)) {
    Write-Host "❌ ERROR: PROJECT_ID no puede estar vacío" -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Host ""
Write-Host "Desplegando reglas a proyecto: $PROJECT_ID" -ForegroundColor Cyan
Write-Host ""

# Copiar archivo de desarrollo a firestore.rules
Copy-Item -Path "firestore.rules.dev" -Destination "firestore.rules" -Force
Write-Host "✅ Archivo firestore.rules.dev copiado a firestore.rules" -ForegroundColor Green
Write-Host ""

# Desplegar reglas
Write-Host "Desplegando reglas de Firestore..." -ForegroundColor Cyan
firebase deploy --project=$PROJECT_ID --only firestore:rules

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "✅ SUCCESS: Reglas de Firestore actualizadas!" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
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
    Write-Host "1. Verifica que PROJECT_ID sea correcto" -ForegroundColor White
    Write-Host "2. Verifica que tengas permisos en Firebase" -ForegroundColor White
    Write-Host "3. Intenta manualmente en Firebase Console" -ForegroundColor White
    Write-Host ""
}

Read-Host "Presiona Enter para salir"
