$ErrorActionPreference = 'Stop'
$executable = Join-Path $PSScriptRoot 'runtime\pocketbase.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw 'PocketBase is not installed. Follow server/README.md first.'
}
$version = (& $executable --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch '\b0\.41\.1\b') {
    throw 'These checks target PocketBase 0.41.1.'
}

# Reserve a candidate ephemeral port; startup below also detects a lost race.
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()
$base = "http://127.0.0.1:$port"
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempRoot ('pace-auth-test-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testRoot
$process = $null
Add-Type -AssemblyName System.Net.Http
$client = [Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(5)

function Request($method, $path, $body, $token, $expected) {
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($method), "$base$path")
    if ($token) { $null = $request.Headers.TryAddWithoutValidation('Authorization', $token) }
    if ($null -ne $body) {
        $request.Content = [Net.Http.StringContent]::new(($body | ConvertTo-Json -Depth 10 -Compress), [Text.Encoding]::UTF8, 'application/json')
    }
    $response = $null
    try {
        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        $status = [int]$response.StatusCode
        if ($status -ne $expected) {
            # Never print response bodies, passwords or tokens on failure.
            throw "$method $path expected HTTP $expected, got $status."
        }
        $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if ($content) { return ($content | ConvertFrom-Json) }
    } finally {
        if ($response) { $response.Dispose() }
        $request.Dispose()
    }
}

try {
    $argsList = @('serve', "--http=127.0.0.1:$port", "--dir=`"$(Join-Path $testRoot 'data')`"", "--migrationsDir=`"$(Join-Path $PSScriptRoot 'pb_migrations')`"", "--hooksDir=`"$(Join-Path $PSScriptRoot 'pb_hooks')`"")
    $process = Start-Process -FilePath $executable -ArgumentList $argsList -WorkingDirectory $testRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $testRoot 'stdout.log') -RedirectStandardError (Join-Path $testRoot 'stderr.log')
    $ready = $false
    for ($attempt = 0; $attempt -lt 80; $attempt++) {
        if ($process.HasExited) { throw 'Temporary server exited before startup. Check the migration with PocketBase.' }
        try {
            $null = Request 'GET' '/api/health' $null $null 200
            $ready = $true
            break
        } catch { Start-Sleep -Milliseconds 100 }
    }
    if (-not $ready) { throw 'Temporary server did not become ready.' }
    $records = '/api/collections/pace_users/records'
    $auth = '/api/collections/pace_users/auth-with-password'
    $password = [Guid]::NewGuid().ToString('N') + '!aA7'
    $alice = Request 'POST' $records @{ email = 'alice@example.com'; password = $password; passwordConfirm = $password; name = 'Alice' } $null 200
    $bob = Request 'POST' $records @{ email = 'bob@example.com'; password = $password; passwordConfirm = $password; name = 'Bob' } $null 200
    $null = Request 'POST' $records @{ email = 'weak@example.com'; password = 'short'; passwordConfirm = 'short' } $null 400
    $null = Request 'POST' $records @{ email = 'fake@example.com'; password = $password; passwordConfirm = $password; verified = $true } $null 400
    $login = Request 'POST' $auth @{ identity = 'alice@example.com'; password = $password } $null 200
    if (-not $login.token -or $login.record.id -ne $alice.id) { throw 'Login did not return the correct identity.' }
    $null = Request 'POST' $auth @{ identity = 'alice@example.com'; password = 'incorrect-password' } $null 400
    $null = Request 'GET' "$records/$($alice.id)" $null $null 404
    $list = Request 'GET' $records $null $null 200
    if ($list.items.Count -ne 0) { throw 'Anonymous request exposed account records.' }
    $null = Request 'GET' "$records/$($alice.id)" $null $login.token 200
    $list = Request 'GET' $records $null $login.token 200
    if ($list.items.Count -ne 1 -or $list.items[0].id -ne $alice.id) { throw 'Account listing exposed another user.' }
    $null = Request 'GET' "$records/$($bob.id)" $null $login.token 404
    $null = Request 'PATCH' "$records/$($bob.id)" @{ name = 'Changed' } $login.token 404
    $null = Request 'PATCH' "$records/$($alice.id)" @{ name = 'Alice updated' } $login.token 200
    $null = Request 'PATCH' "$records/$($alice.id)" @{ verified = $true } $login.token 404
    $null = Request 'PATCH' "$records/$($alice.id)" @{ emailVisibility = $true } $login.token 404
    $null = Request 'DELETE' "$records/$($alice.id)" $null $login.token 403
    $refreshed = Request 'POST' '/api/collections/pace_users/auth-refresh' @{} $login.token 200
    if (-not $refreshed.token -or $refreshed.record.id -ne $alice.id) { throw 'Token refresh changed the identity.' }
    Write-Output 'PASS: registration, password policy, login, refresh and account isolation.'
} finally {
    $client.Dispose()
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
        $process.WaitForExit()
    }
    # Delete only the unique directory created by this invocation, in one shell.
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    if ([IO.Path]::GetDirectoryName($resolvedTestRoot).TrimEnd('\') -ne $tempRoot.TrimEnd('\') -or [IO.Path]::GetFileName($resolvedTestRoot) -notmatch '^pace-auth-test-[a-f0-9]{32}$') {
        throw 'Refusing cleanup outside the temporary test directory.'
    }
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
}
