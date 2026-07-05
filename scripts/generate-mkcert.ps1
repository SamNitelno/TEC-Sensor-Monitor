# Generate LAN-trusted TLS certs with mkcert (recommended for native Flutter clients).
# Install mkcert: https://github.com/FiloSottile/mkcert
#   choco install mkcert   OR   scoop install mkcert
#
# Usage:
#   .\scripts\generate-mkcert.ps1 -LanIp 192.168.1.100

param(
    [Parameter(Mandatory = $true)]
    [string]$LanIp,
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
if (-not $OutDir) {
    $OutDir = Join-Path $Root "infra/tls"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if (-not (Get-Command mkcert -ErrorAction SilentlyContinue)) {
    Write-Error "mkcert not found. Install from https://github.com/FiloSottile/mkcert and run: mkcert -install"
}

Push-Location $OutDir
try {
    mkcert -install
    mkcert -cert-file server.crt -key-file server.key $LanIp localhost 127.0.0.1
    Write-Host "Wrote $OutDir/server.crt and server.key"
    Write-Host "Install mkcert root CA on Android/Windows clients: copy CA from 'mkcert -CAROOT' and trust it."
} finally {
    Pop-Location
}
