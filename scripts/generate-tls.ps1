# Generate self-signed TLS cert for local LAN (Windows / cross-platform via OpenSSL).
# Usage: .\scripts\generate-tls.ps1
#        .\scripts\generate-tls.ps1 -Cn "192.168.1.100"

param(
    [string]$OutDir = "",
    [int]$Days = 3650,
    [string]$Cn = "localhost"
)

$ErrorActionPreference = "Stop"
if (-not $OutDir) {
    $OutDir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")) "infra/tls"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$keyPath = Join-Path $OutDir "server.key"
$crtPath = Join-Path $OutDir "server.crt"

$opensslExe = $null
$cmd = Get-Command openssl -ErrorAction SilentlyContinue
if ($cmd) { $opensslExe = $cmd.Source }
if (-not $opensslExe) {
    $gitOpenSsl = "C:\Program Files\Git\usr\bin\openssl.exe"
    if (Test-Path $gitOpenSsl) { $opensslExe = $gitOpenSsl }
}
if (-not $opensslExe) {
    Write-Error "OpenSSL not found. Run in Git Bash: sh infra/tls/generate-self-signed.sh infra/tls 3650 $Cn"
}

& $opensslExe req -x509 -nodes -days $Days -newkey rsa:2048 `
    -keyout $keyPath -out $crtPath `
    -subj "/CN=$Cn/O=TEC Sensor Monitor/C=RU"

Write-Host "Created:"
Write-Host "  $crtPath"
Write-Host "  $keyPath"
Write-Host "CN=$Cn - open https://$Cn/ in browser"
