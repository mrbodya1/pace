# Verifies token issuance only. Credentials travel to curl over stdin, never argv.
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This script requires Windows DPAPI.' }
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$keyPath = Join-Path (Split-Path $projectRoot -Parent) 'Runtime\Garmin\personal-api-key.dpapi'
if (-not (Test-Path -LiteralPath $keyPath -PathType Leaf)) {
    throw 'Configure the key interactively with set-personal-key.ps1 first.'
}
$secureKey = $null
$keyPointer = [IntPtr]::Zero
$plainKey = $null
$config = $null
$outputText = $null
$responseText = $null
$response = $null
$process = $null
try {
    $secureKey = ConvertTo-SecureString (Get-Content -LiteralPath $keyPath -Raw).Trim()
    $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
    if ($plainKey -match '[\x00-\x20"\\]') {
        throw 'Stored key has unsupported whitespace or configuration characters. No key was printed.'
    }
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (-not (Test-Path -LiteralPath $curl -PathType Leaf)) { throw 'Windows curl.exe is required.' }
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $curl
    $info.Arguments = '--config -'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    # Fixed destination, no redirect following, ordinary certificate verification.
    # Header is passed only over the private child-process stdin pipe.
    $config = @"
url = "https://personal.connectapi.garmin.com/personalapitoken-service/personal-api/personal-api-key/token"
request = "POST"
header = "Authorization: ApiKey $plainKey"
data = ""
silent
show-error
connect-timeout = 8
max-time = 20
write-out = "\n%{http_code}"
"@
    $process.Start() | Out-Null
    $process.StandardInput.Write($config)
    $process.StandardInput.Close()
    $config = $null
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(25000)) {
        $process.Kill()
        throw 'Garmin request exceeded the diagnostic timeout. No credentials were printed.'
    }
    $outputText = $stdout.GetAwaiter().GetResult()
    $stderr.GetAwaiter().GetResult() | Out-Null
    if ($process.ExitCode -ne 0) {
        throw "Garmin HTTPS transport failed: curl code $($process.ExitCode). No headers, credentials or response body were printed."
    }
    $separator = $outputText.LastIndexOf("`n")
    if ($separator -lt 0) { throw 'Garmin diagnostic did not return an HTTP status.' }
    $httpStatus = $outputText.Substring($separator + 1).Trim()
    if ($httpStatus -notmatch '^2\d\d$') {
        throw "Garmin authorization rejected: HTTP=$httpStatus. No credentials or response body were printed."
    }
    $responseText = $outputText.Substring(0, $separator)
    $token = $null
    $jwtPattern = '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'
    if ($responseText.Trim() -match $jwtPattern) {
        # The Personal endpoint may return the token directly rather than OAuth JSON.
        $token = $responseText.Trim()
    } else {
        try { $response = ConvertFrom-Json -InputObject $responseText } catch {
            throw 'Garmin returned neither OAuth JSON nor a JWT-shaped token. Response body was not printed.'
        }
        if ($response -is [string]) { $token = $response }
        elseif ($response.access_token) { $token = $response.access_token }
    }
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw 'Garmin response did not contain a token. Response body was not printed.'
    }
    Write-Output 'GARMIN_PERSONAL_AUTH_OK'
    Write-Output 'Token issuance verified. Token not printed or saved; no activities were downloaded or imported.'
} finally {
    if ($keyPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer) }
    if ($null -ne $secureKey) { $secureKey.Dispose() }
    if ($null -ne $process) { $process.Dispose() }
    $plainKey = $null
    $config = $null
    $outputText = $null
    $responseText = $null
    $response = $null
    $token = $null
    $stdout = $null
    $stderr = $null
}
