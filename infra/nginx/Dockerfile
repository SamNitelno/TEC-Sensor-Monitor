# Serves pre-built Flutter Web (build on host — no ghcr.io / Flutter-in-Docker).
# Run first: scripts/build-prod.ps1  (or flutter build web manually)

FROM nginx:1.27-alpine
COPY infra/nginx/nginx.conf /etc/nginx/nginx.conf
COPY frontend/build/web /usr/share/nginx/html
RUN test -f /usr/share/nginx/html/index.html \
    || (echo "ERROR: frontend/build/web missing. Run: scripts/build-prod.ps1" && exit 1)
RUN mkdir -p /etc/nginx/tls
