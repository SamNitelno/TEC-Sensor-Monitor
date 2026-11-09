//go:build integration

// Package apitest holds end-to-end tests that run the real HTTP handler
// against a real TimescaleDB. Run with:
//
//	TEST_DATABASE_URL=postgresql://tek:<pw>@localhost:5432/tek_sensor_test \
//	  go test -tags integration ./internal/apitest/...
//
// The test database is dropped and re-created on every run.
package apitest

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"tek-sensor-monitor/backend/internal/config"
	"tek-sensor-monitor/backend/internal/db"
	"tek-sensor-monitor/backend/internal/delivery"
	"tek-sensor-monitor/backend/internal/httpapi"
	"tek-sensor-monitor/backend/internal/service"
	"tek-sensor-monitor/backend/internal/ws"
)

type testEnv struct {
	cfg   *config.Config
	pool  *pgxpool.Pool
	svc   *service.Service
	srv   *httptest.Server
	dbURL string
}

var env *testEnv

func testDatabaseURL() string {
	if v := os.Getenv("TEST_DATABASE_URL"); v != "" {
		return config.NormalizeDatabaseURL(v)
	}
	return "postgresql://tek:tek_secret@localhost:5432/tek_sensor_test"
}

// dropDatabase removes the target database (used for test cleanup).
func dropDatabase(ctx context.Context, target string) error {
	u, err := url.Parse(target)
	if err != nil {
		return err
	}
	name := strings.TrimPrefix(u.Path, "/")
	admin := *u
	admin.Path = "/postgres"
	conn, err := pgx.Connect(ctx, admin.String())
	if err != nil {
		return err
	}
	defer conn.Close(ctx)
	_, err = conn.Exec(ctx, "DROP DATABASE IF EXISTS "+pgx.Identifier{name}.Sanitize()+" WITH (FORCE)")
	return err
}

// recreateDatabase drops and creates the target database via the "postgres"
// maintenance database on the same server.
func recreateDatabase(ctx context.Context, target string) error {
	u, err := url.Parse(target)
	if err != nil {
		return err
	}
	name := strings.TrimPrefix(u.Path, "/")
	admin := *u
	admin.Path = "/postgres"
	conn, err := pgx.Connect(ctx, admin.String())
	if err != nil {
		return err
	}
	defer conn.Close(ctx)
	ident := pgx.Identifier{name}.Sanitize()
	if _, err := conn.Exec(ctx, "DROP DATABASE IF EXISTS "+ident+" WITH (FORCE)"); err != nil {
		return err
	}
	_, err = conn.Exec(ctx, "CREATE DATABASE "+ident)
	return err
}

func setEnv(dbURL string) {
	vals := map[string]string{
		"APP_ENV":                    "development",
		"DATABASE_URL":               dbURL,
		"JWT_SECRET":                 "test-jwt-secret-for-go-tests-32chars!",
		"ADMIN_LOGIN":                "admin",
		"ADMIN_PASSWORD":             "admin",
		"VIEWER_LOGIN":               "viewer",
		"VIEWER_PASSWORD":            "viewer",
		"ALLOW_PUBLIC_REGISTRATION":  "true",
		"VERIFICATION_DELIVERY_MODE": "test",
		"AUTH_LOGIN_RATE_LIMIT":      "1000/minute",
		"AUTH_REGISTER_RATE_LIMIT":   "1000/minute",
		"AUTH_VERIFY_RATE_LIMIT":     "1000/minute",
		"INGEST_RATE_LIMIT":          "10000/minute",
		"API_PUBLIC_BASE_URL":        "https://192.168.1.100",
		"DEVICE_INGEST_BASE_URL":     "",
		"CORS_ORIGINS":               "",
		"MQTT_ENABLED":               "false",
	}
	for k, v := range vals {
		os.Setenv(k, v)
	}
}

func TestMain(m *testing.M) {
	ctx := context.Background()
	dbURL := testDatabaseURL()
	if err := recreateDatabase(ctx, dbURL); err != nil {
		fmt.Fprintln(os.Stderr, "cannot prepare test database (is TimescaleDB running?):", err)
		os.Exit(1)
	}
	setEnv(dbURL)
	cfg, err := config.FromEnv()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	if err := db.Migrate(ctx, dbURL, cfg.JWTSecret, log); err != nil {
		fmt.Fprintln(os.Stderr, "migrate:", err)
		os.Exit(1)
	}
	pool, err := db.Open(ctx, dbURL, 10*time.Second)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	svc := service.New(cfg, pool, ws.NewHub(log), delivery.New(cfg, log), log)
	if err := svc.EnsureBootstrapUsers(ctx); err != nil {
		fmt.Fprintln(os.Stderr, "bootstrap:", err)
		os.Exit(1)
	}
	srv := httptest.NewServer(httpapi.New(svc, log))
	env = &testEnv{cfg: cfg, pool: pool, svc: svc, srv: srv, dbURL: dbURL}
	code := m.Run()
	srv.Close()
	pool.Close()
	os.Exit(code)
}

// ---- HTTP helpers ------------------------------------------------------------

type resp struct {
	status int
	body   []byte
	header http.Header
}

func (r resp) json(t *testing.T) map[string]any {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal(r.body, &m); err != nil {
		t.Fatalf("decode %s: %v", r.body, err)
	}
	return m
}

func (r resp) list(t *testing.T) []any {
	t.Helper()
	var l []any
	if err := json.Unmarshal(r.body, &l); err != nil {
		t.Fatalf("decode list %s: %v", r.body, err)
	}
	return l
}

type reqOpt func(*http.Request)

func bearer(token string) reqOpt {
	return func(r *http.Request) { r.Header.Set("Authorization", "Bearer "+token) }
}

func header(k, v string) reqOpt { return func(r *http.Request) { r.Header.Set(k, v) } }

func do(t *testing.T, method, path string, body any, opts ...reqOpt) resp {
	t.Helper()
	var rdr io.Reader
	switch b := body.(type) {
	case nil:
	case string:
		rdr = strings.NewReader(b)
	default:
		data, err := json.Marshal(b)
		if err != nil {
			t.Fatal(err)
		}
		rdr = bytes.NewReader(data)
	}
	req, err := http.NewRequest(method, env.srv.URL+path, rdr)
	if err != nil {
		t.Fatal(err)
	}
	if rdr != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	for _, o := range opts {
		o(req)
	}
	client := &http.Client{CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	res, err := client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	data, _ := io.ReadAll(res.Body)
	return resp{status: res.StatusCode, body: data, header: res.Header}
}

func expectStatus(t *testing.T, r resp, want int) {
	t.Helper()
	if r.status != want {
		t.Fatalf("status = %d, want %d; body: %s", r.status, want, r.body)
	}
}

func loginToken(t *testing.T, login, password string) string {
	t.Helper()
	r := do(t, "POST", "/api/v1/auth/login", map[string]string{"login": login, "password": password})
	expectStatus(t, r, 200)
	return r.json(t)["access_token"].(string)
}

func adminToken(t *testing.T) string  { return loginToken(t, "admin", "admin") }
func viewerToken(t *testing.T) string { return loginToken(t, "viewer", "viewer") }

var uniq = time.Now().UnixNano()

func unique(prefix string) string {
	uniq++
	return fmt.Sprintf("%s%d", prefix, uniq%1_000_000_000)
}

// testSensor creates a workshop, site and sensor through the API and returns
// (sensor id, plaintext device token).
func testSensor(t *testing.T) (int64, string) {
	t.Helper()
	tok := adminToken(t)
	w := do(t, "POST", "/api/v1/workshops", map[string]any{"name": unique("W-")}, bearer(tok))
	expectStatus(t, w, 201)
	s := do(t, "POST", "/api/v1/sites", map[string]any{"name": unique("S-"), "workshop_id": w.json(t)["id"]}, bearer(tok))
	expectStatus(t, s, 201)
	sn := do(t, "POST", "/api/v1/sensors", map[string]any{
		"name": unique("Sensor-"), "device_id": unique("DEV-"), "site_id": s.json(t)["id"],
	}, bearer(tok))
	expectStatus(t, sn, 201)
	body := sn.json(t)
	id := int64(body["sensor"].(map[string]any)["id"].(float64))
	return id, body["api_token"].(string)
}

func num(v any) float64 { return v.(float64) }
