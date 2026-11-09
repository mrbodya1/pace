# Keep the browser origin stable so local workouts and saved sessions survive restarts.
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & flutter run -d chrome --web-hostname=localhost --web-port=5050 @args
    if ($LASTEXITCODE -ne 0) { throw "Flutter stopped with code $LASTEXITCODE" }
} finally {
    Pop-Location
}
