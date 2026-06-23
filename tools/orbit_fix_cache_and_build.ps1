Param(
  [ValidateSet('release','debug')]
  [string]$Mode = 'release',

  # Para equipos con poca RAM evita android-x64.
  [string]$TargetPlatform = 'android-arm64,android-arm',

  # Si lo activas, genera APK universal (más lento/pesado)
  [switch]$NoSplitPerAbi,

  # Si lo activas, NO borra el cache (solo aplica fix de locks/daemons)
  [switch]$SkipCacheClear
)

$ErrorActionPreference = 'Stop'

function Step([string]$msg) { Write-Host "`n=== $msg ===`n" -ForegroundColor Cyan }
function Info([string]$msg) { Write-Host $msg -ForegroundColor DarkGray }
function Warn([string]$msg) { Write-Host $msg -ForegroundColor Yellow }
function Success([string]$msg) { Write-Host $msg -ForegroundColor Green }
function ErrorExit([string]$msg) { Write-Host "!!! ERROR: $msg" -ForegroundColor Red; exit 1 }

Step '0) Pre-checks & Setup Environment Variables'
# Estos env vars se convierten en propiedades Gradle (ORG_GRADLE_PROJECT_*),
# y ayudan cuando falla el build incluido de Flutter (dev.flutter.flutter-plugin-loader).
# Asegurarse que se aplica a todos los subproyectos y builds incluidos.

# Kotlin: Forzar compilación in-process y desactivar daemon para baja RAM.
${env:ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy} = 'in-process'
${env:ORG_GRADLE_PROJECT_kotlin.daemon.enabled} = 'false'

# Gradle: Reducir paralelismo y desactivar daemon.
${env:ORG_GRADLE_PROJECT_org.gradle.workers.max} = '1'
${env:ORG_GRADLE_PROJECT_org.gradle.daemon} = 'false'
${env:ORG_GRADLE_PROJECT_org.gradle.parallel} = 'false'

# Timeouts de red más altos para bajar dependencias en conexiones lentas.
${env:ORG_GRADLE_PROJECT_systemProp.org.gradle.internal.http.connectionTimeout} = '60000'
${env:ORG_GRADLE_PROJECT_systemProp.org.gradle.internal.http.socketTimeout} = '240000'

Info "Variables de entorno Gradle configuradas para baja RAM."
Info "Kotlin Strategy: ${env:ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy}"
Info "Gradle Workers Max: ${env:ORG_GRADLE_PROJECT_org.gradle.workers.max}"

if (-not (Test-Path 'pubspec.yaml')) { ErrorExit 'Ejecuta este script desde la raíz del proyecto (donde está pubspec.yaml).' }
if (-not (Test-Path 'android\gradlew.bat')) { ErrorExit 'No se encontró android\gradlew.bat.' }

Step '1) Stop Gradle daemons'
Push-Location android
try { & .\gradlew.bat --stop | Out-Host } catch { Warn "gradlew --stop falló (continuo): $($_.Exception.Message)" }
Pop-Location

Step '2) Kill Gradle/Kotlin java.exe daemons (para liberar locks)'
$javaProcs = Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
  Where-Object {
    ($_.CommandLine -match 'GradleDaemon') -or
    ($_.CommandLine -match 'org\.gradle') -or
    ($_.CommandLine -match 'kotlin-daemon') -or
    ($_.CommandLine -match 'KotlinCompileDaemon')
  }

if ($javaProcs) {
  foreach ($p in ($javaProcs | Sort-Object ProcessId -Descending)) {
    try {
      Info "Stopping PID $($p.ProcessId): $($p.CommandLine)"
      Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
    } catch {
      Warn "No pude detener PID $($p.ProcessId): $($_.Exception.Message)"
    }
  }
} else {
  Info 'No se detectaron daemons java.exe de Gradle/Kotlin.'
}

Step '3) Clear project-local Gradle cache (android/.gradle-user-home)'
if ($SkipCacheClear) {
  Info 'SkipCacheClear activado; no se borra cache.'
} else {
  $projectGradleHome = 'android\.gradle-user-home'
  if (Test-Path $projectGradleHome) {
    # Nota: en Windows a veces el borrado falla con "no se puede encontrar parte de la ruta" si
    # algún proceso crea/borra archivos mientras se recorre el árbol. Usamos SilentlyContinue y verificamos.
    try {
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $projectGradleHome
    } catch {
      # No debería llegar aquí con SilentlyContinue, pero por si acaso.
      Warn "No pude borrar ${projectGradleHome}: $($_.Exception.Message)"
    }

    if (Test-Path $projectGradleHome) {
      Warn "No se pudo borrar completamente ${projectGradleHome} (posible lock por antivirus/Android Studio)."
      Warn "Recomendación: cierra Android Studio y cualquier terminal, y vuelve a ejecutar el script."
      Warn "Si persiste, reinicia el PC o agrega excepción en antivirus para esa carpeta."
    } else {
      Success "Removed entire Gradle cache folder: ${projectGradleHome}"
    }
  } else {
    Info "No se encontró el directorio de cache: ${projectGradleHome}"
  }
}


Step '4) flutter clean + pub get'
& flutter clean | Out-Host
& flutter pub get | Out-Host

Step "5) flutter build apk --$Mode (low-RAM)"
# Diagnóstico de RAM disponible antes de empezar el build pesado.
# TotalPhysicalMemory está en Win32_ComputerSystem; FreePhysicalMemory está en Win32_OperatingSystem.
$cs = Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory
$os = Get-CimInstance Win32_OperatingSystem | Select-Object FreePhysicalMemory
$totalGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
$freeGB = [math]::Round(($os.FreePhysicalMemory * 1KB) / 1GB, 2)
Info "RAM total: ${totalGB}GB, RAM disponible: ${freeGB}GB antes del build."

# Flutter no tiene flag --info. Usamos --verbose para más detalle.
$flutterArgs = @('build','apk',"--$Mode",'--verbose')
if (-not $NoSplitPerAbi) { $flutterArgs += '--split-per-abi' }
if (-not [string]::IsNullOrWhiteSpace($TargetPlatform)) { $flutterArgs += "--target-platform=$TargetPlatform" }
Info ("Running: flutter " + ($flutterArgs -join ' '))

& flutter @flutterArgs
if ($LASTEXITCODE -ne 0) {
  Warn "flutter build falló con exit code $LASTEXITCODE"

  Step '5b) Gradle diagnostics (assembleRelease --info --stacktrace)'
  Push-Location android
  try {
    & .\gradlew.bat assembleRelease --no-daemon --info --stacktrace 2>&1 | Tee-Object -FilePath ..\build_gradle_diagnostics.log | Out-Host
    Warn 'Se guardó log en: build_gradle_diagnostics.log'
  } catch {
    Warn "Gradle diagnostics también falló: $($_.Exception.Message)"
  } finally {
    Pop-Location
  }

  ErrorExit "Build failed. Check logs above and build_gradle_diagnostics.log."
}

Success "APK build completed successfully!"



Step '6) Output APKs'
$outDir = 'build\app\outputs\flutter-apk'
if (Test-Path $outDir) {
  Get-ChildItem $outDir -Filter *.apk -Recurse -ErrorAction SilentlyContinue |`
    Sort-Object LastWriteTime -Descending |`
    Select-Object FullName, Length, LastWriteTime |`
    Format-Table -AutoSize
} else {
  Warn "No output dir: ${outDir}"
}

Success "Script finished. Check for APKs in build\app\outputs\flutter-apk\"