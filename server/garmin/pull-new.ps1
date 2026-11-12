$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'request-personal-refresh.ps1') -ForceRefresh
