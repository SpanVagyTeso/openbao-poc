<#
.SYNOPSIS
    Generates a fresh SSH key pair, has OpenBao sign it, and logs in to ssh-target.

.EXAMPLE
    .\connect.ps1
    .\connect.ps1 -Ttl 15m
    .\connect.ps1 -Command 'id; uname -n'
#>
[CmdletBinding()]
param(
    [string]$BaoAddr  = 'http://localhost:8200',
    # Defaults to the root token from secrets\init.json
    [string]$BaoToken = $env:BAO_TOKEN,
    [string]$Mount    = 'ssh-client-signer',
    [string]$Role     = 'demo',
    [string]$User     = 'demo',
    [string]$SshHost  = 'localhost',
    [int]   $Port     = 2222,
    # Certificate lifetime, e.g. 5m or 30m (capped by the role's max_ttl)
    [string]$Ttl,
    # Remove the stored host key first (ssh-target generates new host keys when recreated)
    [switch]$ResetHostKey,
    # Run this command instead of an interactive shell
    [string]$Command
)

$ErrorActionPreference = 'Stop'

foreach ($tool in 'ssh', 'ssh-keygen') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool not found. Install the Windows OpenSSH client (Settings > System > Optional features)."
    }
}

if (-not $BaoToken) {
    $initFile = Join-Path $PSScriptRoot 'secrets\init.json'
    if (-not (Test-Path $initFile)) { throw "No -BaoToken given and $initFile not found. Run 'docker compose up -d' first." }
    $BaoToken = (Get-Content $initFile -Raw | ConvertFrom-Json).root_token
}

$keyDir     = Join-Path $env:USERPROFILE '.ssh\openbao'
$key        = Join-Path $keyDir 'id_ed25519'
$cert       = "$key-cert.pub"
$knownHosts = Join-Path $keyDir 'known_hosts'
New-Item -ItemType Directory -Force $keyDir | Out-Null

# Fresh key pair for every login
Remove-Item -Force -ErrorAction SilentlyContinue $key, "$key.pub", $cert
# '""' because Windows PowerShell 5.1 drops empty string arguments to native programs
ssh-keygen -q -t ed25519 -N '""' -C "$env:USERNAME@$env:COMPUTERNAME" -f $key
if ($LASTEXITCODE -ne 0) { throw 'ssh-keygen failed' }

# Ask OpenBao to sign the public key
$body = @{
    public_key       = (Get-Content "$key.pub" -Raw).Trim()
    valid_principals = $User
}
if ($Ttl) { $body.ttl = $Ttl }

try {
    $resp = Invoke-RestMethod -Method Post -Uri "$BaoAddr/v1/$Mount/sign/$Role" `
        -Headers @{ 'X-Vault-Token' = $BaoToken } `
        -ContentType 'application/json' -Body ($body | ConvertTo-Json)
} catch {
    throw "OpenBao signing request failed: $($_.Exception.Message) $($_.ErrorDetails.Message)"
}

# ssh needs the certificate without a BOM
[IO.File]::WriteAllText($cert, $resp.data.signed_key, (New-Object Text.UTF8Encoding $false))

Write-Host '--- certificate ---'
ssh-keygen -L -f $cert

if ($ResetHostKey -and (Test-Path $knownHosts)) {
    ssh-keygen -q -R "[$SshHost]:$Port" -f $knownHosts | Out-Null
}

Write-Host "--- ssh $User@${SshHost}:$Port ---"
$sshArgs = @(
    '-i', $key,
    '-o', 'IdentitiesOnly=yes',
    '-o', "CertificateFile=$cert",
    '-o', "UserKnownHostsFile=$knownHosts",
    '-o', 'StrictHostKeyChecking=accept-new',
    '-p', $Port,
    "$User@$SshHost"
)
if ($Command) { $sshArgs += $Command }

ssh @sshArgs
exit $LASTEXITCODE
