$ErrorActionPreference = 'Stop'
Write-Output 'Periodic polling has been retired. Requesting one refresh only.'
& (Join-Path $PSScriptRoot 'request-personal-refresh.ps1') -ForceRefresh
