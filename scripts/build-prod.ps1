# Production deploy: Flutter Web build + docker compose prod stack.
# Usage: .\scripts\build-prod.ps1
#        .\scripts\build-prod.ps1 -ApiBaseUrl "https://192.168.0.181"

param(
    [string]$ApiBaseUrl = ""
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Read-EnvValue {
    param([string]$Name)
    $envFile = Join-Path $Root ".env"
    if (-not (Test-Path $envFile)) { return $null }
    foreach ($line in Get-Content $envFile) {
        if ($line -match "^\s*$Name=(.+)$") {
            return $matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return $null
}

if (-not $ApiBaseUrl) {
    $ApiBaseUrl = Read-EnvValue "API_PUBLIC_BASE_URL"
}
if (-not $ApiBaseUrl) {
    $ApiBaseUrl = "https://localhost"
    Write-Warning "API_PUBLIC_BASE_URL not set; using $ApiBaseUrl"
}

$TlsDir = Join-Path $Root "infra/tls"
$CrtPath = Join-Path $TlsDir "server.crt"
if (-not (Test-Path $CrtPath)) {
    Write-Host "TLS certificate missing — generating self-signed cert..."
    $cn = ($ApiBaseUrl -replace '^https?://', '' -replace '/.*$', '' -replace ':.*$', '')
    if (-not $cn) { $cn = "localhost" }
    & (Join-Path $PSScriptRoot "generate-tls.ps1") -OutDir $TlsDir -Cn $cn
}

Write-Host "Building Flutter Web (API_BASE_URL=$ApiBaseUrl)..."
Push-Location (Join-Path $Root "frontend")
try {
    flutter pub get
    flutter build web --release --dart-define=API_BASE_URL=$ApiBaseUrl
} finally {
    Pop-Location
}

$webIndex = Join-Path $Root "frontend/build/web/index.html"
if (-not (Test-Path $webIndex)) {
    throw "Flutter build failed: $webIndex not found"
}

Write-Host "Starting prod stack..."
Push-Location $Root
try {
    docker compose -f docker-compose.prod.yml up -d --build
} finally {
    Pop-Location
}

Write-Host "Done. Open $ApiBaseUrl/ (accept self-signed TLS if prompted)."
