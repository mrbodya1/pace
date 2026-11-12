# Public PACE API; the client device does not need Tailscale.
$ErrorActionPreference = 'Stop'
$api = 'https://bodya1-pc.tail3c1c24.ts.net'
Push-Location $PSScriptRoot
try {
    & flutter run "--dart-define=PACE_API_URL=$api" @args
    if ($LASTEXITCODE -ne 0) { throw "Flutter stopped with code $LASTEXITCODE" }
} finally {
    Pop-Location
}
