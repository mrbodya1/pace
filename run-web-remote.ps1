# Preserve the same browser origin and local storage as run-web.ps1.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'run-remote.ps1') -d chrome --web-hostname=localhost --web-port=5050 @args
