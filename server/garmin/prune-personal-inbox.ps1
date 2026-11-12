param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9]{15}$')][string]$Owner)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$private = if ($env:PACE_GARMIN_RUNTIME) { $env:PACE_GARMIN_RUNTIME } else { Join-Path (Split-Path $projectRoot -Parent) 'Runtime\Garmin' }
$python = if ($env:PACE_GARMIN_PYTHON) { $env:PACE_GARMIN_PYTHON } else { Join-Path $private 'venv\Scripts\python.exe' }
# Always the real local maintenance implementation; no Garmin key/network is used.
& $python (Join-Path $PSScriptRoot 'collect_personal.py') --prune-only --expected-owner $Owner
if ($LASTEXITCODE -ne 0) { throw 'Garmin queue maintenance failed.' }
