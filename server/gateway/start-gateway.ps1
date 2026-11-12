$ErrorActionPreference = 'Stop'
$executable = 'D:\Applications\HomeServer\Caddy\bin\caddy.exe'
$config = Join-Path $PSScriptRoot 'Caddyfile'
$logs = 'D:\Applications\PACE\Runtime\Logs'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'Verified Caddy binary is missing.' }
$parsed = (& $executable adapt --config $config --adapter caddyfile | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0) { throw 'Invalid gateway configuration.' }
$listeners = @($parsed.apps.http.servers.PSObject.Properties.Value.listen)
if ($listeners.Count -ne 1 -or $listeners[0] -ne '127.0.0.1:8091' -or -not $parsed.admin.disabled) {
    throw 'Refuse gateway listener outside loopback or an enabled Caddy admin API.'
}
$ready = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    try {
        $health = Invoke-RestMethod 'http://127.0.0.1:8090/api/health' -TimeoutSec 2
        if ($health.code -eq 200) { $ready = $true; break }
    } catch { }
    Start-Sleep -Seconds 1
}
if (-not $ready) { throw 'PocketBase is not ready; gateway was not started.' }
$log = Join-Path $logs ('gateway-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
# Start-Process redirects native stderr without PowerShell 5 treating JSON logs as errors.
$arguments = @('run', '--config', ('"' + $config + '"'), '--adapter', 'caddyfile')
$child = Start-Process -FilePath $executable -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $log -RedirectStandardError ($log + '.stderr')
if ($child.ExitCode -ne 0) { throw "Caddy exited with code $($child.ExitCode); inspect $log.stderr" }
