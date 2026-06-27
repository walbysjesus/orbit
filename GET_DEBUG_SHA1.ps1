# Get Debug Certificate SHA-1 for Firebase Registration
# Usage: .\GET_DEBUG_SHA1.ps1

$debugKeystorePath = "$env:USERPROFILE\.android\debug.keystore"

if (-not (Test-Path $debugKeystorePath)) {
    Write-Host "❌ Debug keystore no encontrado en: $debugKeystorePath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Posibles soluciones:" -ForegroundColor Yellow
    Write-Host "1. Ejecuta flutter run primera vez para generar debug.keystore"
    Write-Host "2. Verifica que %USERPROFILE%\.android existe"
    Write-Host ""
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Host "🔍 Obteniendo SHA-1 del debug certificate..." -ForegroundColor Cyan
Write-Host ""

$keytoolPaths = @(
    "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
    "keytool"  # Try system PATH
)

$keytoolFound = $false
$keytoolExe = ""

foreach ($path in $keytoolPaths) {
    if (Test-Path $path) {
        $keytoolExe = $path
        $keytoolFound = $true
        break
    }
}

if (-not $keytoolFound) {
    Write-Host "❌ keytool no encontrado. Asegúrate de tener Android SDK instalado." -ForegroundColor Red
    Write-Host ""
    Write-Host "Intenta abrir Android Studio y verificar la instalación." -ForegroundColor Yellow
    Read-Host "Presiona Enter para salir"
    exit 1
}

try {
    $output = & $keytoolExe -list -v -keystore $debugKeystorePath -alias androiddebugkey -storepass android -keypass android 2>&1
    $sha1Line = $output | Select-String "SHA1"
    
    if ($sha1Line) {
        $sha1Value = ($sha1Line -split ": ")[1].Trim()
        
        Write-Host "✅ SHA-1 encontrado:" -ForegroundColor Green
        Write-Host ""
        Write-Host "  $sha1Value" -ForegroundColor Yellow -BackgroundColor Black
        Write-Host ""
        Write-Host "📋 PASOS SIGUIENTES:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. Ve a Firebase Console (https://console.firebase.google.com)" -ForegroundColor White
        Write-Host "2. Selecciona proyecto 'orbit'" -ForegroundColor White
        Write-Host "3. Ve a Project Settings (⚙️ engranaje)" -ForegroundColor White
        Write-Host "4. En la pestaña 'Apps', selecciona tu app Android" -ForegroundColor White
        Write-Host "5. Sección 'Certificados SHA' → 'Agregar certificado SHA'" -ForegroundColor White
        Write-Host "6. Pega el SHA-1 de arriba y guarda" -ForegroundColor White
        Write-Host "7. Espera 1-2 minutos a que se propague" -ForegroundColor White
        Write-Host ""
        Write-Host "SHA-1 copiado al portapapeles ✅" -ForegroundColor Green
        
        # Copiar al portapapeles
        $sha1Value | Set-Clipboard
        
    } else {
        Write-Host "❌ No se pudo extraer SHA-1 del certificado" -ForegroundColor Red
        Write-Host ""
        Write-Host "Output completo:" -ForegroundColor Yellow
        $output | Write-Host
    }
} catch {
    Write-Host "❌ Error al ejecutar keytool: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Intenta ejecutar Android Studio y abre Project Structure para ver el SHA-1" -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Presiona Enter para salir"
