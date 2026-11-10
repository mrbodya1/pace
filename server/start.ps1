$ErrorActionPreference = 'Stop'
$serverRoot = $PSScriptRoot
$executable = Join-Path $serverRoot 'runtime\pocketbase.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw 'Extract the official PocketBase Windows x64 archive into server/runtime first. See README.md.'
}
$version = (& $executable --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch '\b0\.41\.1\b') {
    throw 'This server configuration targets PocketBase 0.41.1. Back up existing data before changing versions.'
}
Push-Location $serverRoot
try {
    & $executable serve '--http=127.0.0.1:8090' "--dir=$(Join-Path $serverRoot 'pb_data')" "--migrationsDir=$(Join-Path $serverRoot 'pb_migrations')" "--hooksDir=$(Join-Path $serverRoot 'pb_hooks')"
    if ($LASTEXITCODE -ne 0) { throw "PocketBase stopped with code $LASTEXITCODE" }
} finally {
    Pop-Location
}
