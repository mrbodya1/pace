# Disable public sharing without resetting other Tailscale ports or services.
$ErrorActionPreference = 'Stop'
& tailscale funnel --https=443 off
if ($LASTEXITCODE -ne 0) { throw 'Could not disable Funnel.' }
& tailscale serve --bg --https=443 http://127.0.0.1:8091
if ($LASTEXITCODE -ne 0) { throw 'Could not restore private API access.' }
& tailscale serve status
