$ErrorActionPreference = 'Stop'
$server = Split-Path $PSScriptRoot -Parent
$data = Join-Path $server 'pb_data\data.db'
if (-not (Test-Path -LiteralPath $data -PathType Leaf)) { throw 'Existing PocketBase database is missing; restore it before starting.' }
try {
    $health = Invoke-RestMethod 'http://127.0.0.1:8090/api/health' -TimeoutSec 2
    if ($health.code -eq 200) { Write-Output 'Existing PocketBase is already running.'; exit 0 }
} catch { }
$log = Join-Path 'D:\Applications\PACE\Runtime\Logs' ('backend-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
& (Join-Path $server 'start.ps1') *> $log
if ($LASTEXITCODE -ne 0) { throw "PocketBase exited with code $LASTEXITCODE" }
