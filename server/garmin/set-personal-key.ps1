# Run interactively on the Windows account that runs the personal importer.
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This script requires Windows DPAPI.' }
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$privateRoot = Join-Path (Split-Path $projectRoot -Parent) 'Runtime\Garmin'
$keyPath = Join-Path $privateRoot 'personal-api-key.dpapi'
if (Test-Path -LiteralPath $keyPath) {
    throw 'A personal key is already configured. Do not overwrite it without reviewing the existing connection.'
}
New-Item -ItemType Directory -Path $privateRoot -Force | Out-Null
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = New-Object System.Security.AccessControl.DirectorySecurity
$acl.SetOwner($identity)
$acl.SetAccessRuleProtection($true, $false)
foreach ($sid in @($identity.Value, 'S-1-5-18', 'S-1-5-32-544')) {
    $principal = New-Object System.Security.Principal.SecurityIdentifier($sid)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $principal, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
}
Set-Acl -LiteralPath $privateRoot -AclObject $acl
$key = Read-Host 'Paste your Garmin Personal API key (input hidden)' -AsSecureString
try {
    if ($key.Length -eq 0) { throw 'The key is empty; nothing was saved.' }
    $encrypted = ConvertFrom-SecureString -SecureString $key
    Set-Content -LiteralPath $keyPath -Value $encrypted -Encoding UTF8
    Write-Output "Personal key saved with Windows DPAPI: $keyPath"
    Write-Output 'The key is outside the repository and was not sent to Garmin by this script.'
} finally {
    if ($null -ne $key) { $key.Dispose() }
    $encrypted = $null
}
