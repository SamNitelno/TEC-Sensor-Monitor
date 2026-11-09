# syntax=docker/dockerfile:1

FROM golang:1.27-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server \
 && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/tektool ./cmd/tektool

FROM alpine:3.22
RUN apk add --no-cache ca-certificates tzdata \
 && adduser -D -H -u 10001 app
WORKDIR /app
COPY --from=build /out/server /out/tektool /app/
USER app
EXPOSE 8000
# Migrations run on start; then HTTP API + background workers (single process).
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 CMD ["/app/server", "healthcheck"]
ENTRYPOINT ["/app/server"]
CMD ["serve"]
