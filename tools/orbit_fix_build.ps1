Param(
  [ValidateSet("release","debug")]
  [string]$Mode = "release",
  [string]$TargetPlatform = "android-arm64,android-arm",
  [switch]$NoSplitPerAbi,
  [switch]$SkipFlutterClean
)

$ErrorActionPreference = "Stop"

function Step([string]$msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Info([string]$msg) { Write-Host $msg -ForegroundColor DarkGray }
function Warn([string]$msg) { Write-Host $msg -ForegroundColor Yellow }

Step "Orbit: auto-fix Gradle/Kotlin daemon + journal lock"
Warn "Recomendación: cierra Android Studio antes de correr este script."

Step "Stop Gradle daemons"
Push-Location android
try { .\gradlew.bat --stop | Out-Host } catch { Warn "gradlew --stop falló (continuo): $($_.Exception.Message)" }
Pop-Location

Step "Kill Gradle/Kotlin java.exe processes (si existen)"
$javaProcs = Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
  Where-Object {
    ($_.CommandLine -match "GradleDaemon") -or
    ($_.CommandLine -match "org\.gradle") -or
    ($_.CommandLine -match "kotlin-daemon") -or
    ($_.CommandLine -match "KotlinCompileDaemon")
  }

if ($javaProcs) {
  foreach ($p in $javaProcs) {
    try {
      Info "Stopping PID $($p.ProcessId): $($p.CommandLine)"
      Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
    } catch {
      Warn "No pude detener PID $($p.ProcessId): $($_.Exception.Message)"
    }
  }
} else {
  Info "No se detectaron daemons java.exe de Gradle/Kotlin."
}

Step "Stop Gradle daemons (2)"
Push-Location android
try { .\gradlew.bat --stop | Out-Host } catch { }
Pop-Location

Step "Clear Gradle journal cache"
$lockFile  = "android\.gradle-user-home\caches\journal-1\journal-1.lock"
$journalDir = "android\.gradle-user-home\caches\journal-1"
if (Test-Path $lockFile) { try { Remove-Item -Force $lockFile; Write-Host "Removed lock: $lockFile" -ForegroundColor Green } catch { Warn "No pude borrar lock: $($_.Exception.Message)" } }
if (Test-Path $journalDir) { try { Remove-Item -Recurse -Force $journalDir; Write-Host "Removed journal dir: $journalDir" -ForegroundColor Green } catch { Warn "No pude borrar journal dir: $($_.Exception.Message)" } }

Step "flutter clean + pub get"
if (-not $SkipFlutterClean) { flutter clean | Out-Host } else { Info "SkipFlutterClean enabled." }
flutter pub get | Out-Host

Step "flutter build apk"
$args = @("build","apk","--$Mode")
if (-not $NoSplitPerAbi) { $args += "--split-per-abi" }
if ($TargetPlatform) { $args += "--target-platform=$TargetPlatform" }
Info ("Running: flutter " + ($args -join " "))
flutter @args | Out-Host

Step "Build outputs"
$outDir = "build\app\outputs\flutter-apk"
if (Test-Path $outDir) {
  Get-ChildItem $outDir -Filter *.apk -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object FullName, Length, LastWriteTime |
    Format-Table -AutoSize
} else {
  Warn "No output dir: $outDir"
}
