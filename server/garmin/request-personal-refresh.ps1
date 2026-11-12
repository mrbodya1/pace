param([switch]$ForceRefresh)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$private = if ($env:PACE_GARMIN_RUNTIME) { $env:PACE_GARMIN_RUNTIME } else { Join-Path (Split-Path $projectRoot -Parent) 'Runtime\Garmin' }
$python = if ($env:PACE_GARMIN_PYTHON) { $env:PACE_GARMIN_PYTHON } else { Join-Path $private 'venv\Scripts\python.exe' }
$collector = if ($env:PACE_GARMIN_COLLECTOR) { $env:PACE_GARMIN_COLLECTOR } else { Join-Path $PSScriptRoot 'collect_personal.py' }
$stateFile = Join-Path $private 'refresh-state.json'
$mutex = New-Object System.Threading.Mutex($false, 'Local\PACE-Garmin-Refresh')
$locked = $false
try {
    $locked = $mutex.WaitOne(0)
    if (-not $locked) { Write-Output '{"phase":"running"}'; exit 0 }
    $now = [DateTimeOffset]::UtcNow
    if (Test-Path -LiteralPath $stateFile) {
        try {
            $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
            $started = [DateTimeOffset]::Parse($state.startedAt)
            if (($state.phase -eq 'running' -or $state.phase -eq 'starting') -and ($now-$started).TotalSeconds -lt 300) {
                Write-Output '{"phase":"running"}'; exit 0
            }
            if ($state.phase -eq 'ready') {
                $completed = [DateTimeOffset]::Parse($state.completedAt)
                $minimum = if ($ForceRefresh) { 10 } else { 300 }
                if (($now-$completed).TotalSeconds -lt $minimum) { Write-Output '{"phase":"ready"}'; exit 0 }
            }
        } catch { }
    }
    if (-not (Test-Path -LiteralPath $python -PathType Leaf) -or -not (Test-Path -LiteralPath $collector -PathType Leaf)) {
        throw 'Personal Garmin collector is not installed.'
    }
    $state = @{phase='starting';startedAt=$now.ToString('o')}
    $temporary = $stateFile + '.launch.tmp'
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($temporary,($state | ConvertTo-Json -Compress),$utf8)
    if (Test-Path -LiteralPath $stateFile) { [IO.File]::Replace($temporary,$stateFile,$null) }
    else { [IO.File]::Move($temporary,$stateFile) }
    $log = Join-Path $private ('refresh-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '.log')
    $child = Start-Process -FilePath $python -ArgumentList @('"' + $collector + '"', '--refresh') -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError ($log+'.stderr')
    Write-Output '{"phase":"running"}'
} finally {
    if ($locked) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
