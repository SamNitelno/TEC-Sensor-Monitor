#!/usr/bin/env sh
# Production deploy: Flutter Web build + docker compose prod stack.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_BASE_URL="${API_BASE_URL:-}"

if [ -z "$API_BASE_URL" ] && [ -f "$ROOT/.env" ]; then
  API_BASE_URL="$(grep -E '^API_PUBLIC_BASE_URL=' "$ROOT/.env" | head -1 | cut -d= -f2- | tr -d "\"'" )"
fi
API_BASE_URL="${API_BASE_URL:-https://localhost}"

TLS_DIR="$ROOT/infra/tls"
if [ ! -f "$TLS_DIR/server.crt" ]; then
  echo "TLS certificate missing — generating self-signed cert..."
  CN="$(echo "$API_BASE_URL" | sed -E 's|^https?://||; s|/.*||; s|:.*||')"
  CN="${CN:-localhost}"
  sh "$ROOT/infra/tls/generate-self-signed.sh" "$TLS_DIR" 3650 "$CN"
fi

echo "Building Flutter Web (API_BASE_URL=$API_BASE_URL)..."
cd "$ROOT/frontend"
flutter pub get
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"

test -f "$ROOT/frontend/build/web/index.html" || {
  echo "ERROR: Flutter build failed"
  exit 1
}

echo "Starting prod stack..."
cd "$ROOT"
docker compose -f docker-compose.prod.yml up -d --build

echo "Done. Open $API_BASE_URL/ (accept self-signed TLS if prompted)."
