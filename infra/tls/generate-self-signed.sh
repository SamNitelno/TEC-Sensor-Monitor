#!/usr/bin/env sh
# Generate self-signed TLS certificate for local LAN deployment.
# For public production, replace with Let's Encrypt (see docs/production.md).

set -e

OUT_DIR="${1:-infra/tls}"
DAYS="${2:-3650}"
CN="${3:-tec-sensor.local}"

mkdir -p "$OUT_DIR"

openssl req -x509 -nodes -days "$DAYS" -newkey rsa:2048 \
  -keyout "$OUT_DIR/server.key" \
  -out "$OUT_DIR/server.crt" \
  -subj "/CN=${CN}/O=TEC Sensor Monitor/C=RU"

echo "Created $OUT_DIR/server.crt and $OUT_DIR/server.key (CN=${CN})"
