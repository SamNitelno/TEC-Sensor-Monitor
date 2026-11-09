//go:build integration

package apitest

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"tek-sensor-monitor/backend/internal/config"
	"tek-sensor-monitor/backend/internal/delivery"
	"tek-sensor-monitor/backend/internal/service"
	"tek-sensor-monitor/backend/internal/ws"

	"io"
	"log/slog"
	"net/http/httptest"
	"tek-sensor-monitor/backend/internal/httpapi"
)

// ---- test_auth_capabilities.py ----

func TestAuthCapabilities(t *testing.T) {
	r := do(t, "GET", "/api/v1/auth/capabilities", nil)
	expectStatus(t, r, 200)
	body := r.json(t)
	if _, ok := body["public_registration"].(bool); !ok {
		t.Fatalf("public_registration not bool: %v", body)
	}
	if _, ok := body["password_reset"].(bool); !ok {
		t.Fatalf("password_reset not bool: %v", body)
	}
}

// ---- test_auth_roles.py ----

func TestLoginReturnsJWTWithRoleAndExp(t *testing.T) {
	r := do(t, "POST", "/api/v1/auth/login", map[string]string{"login": "admin", "password": "admin"})
	expectStatus(t, r, 200)
	body := r.json(t)
	if body["token_type"] != "bearer" || body["role"] != "admin" {
		t.Fatalf("unexpected body %v", body)
	}
	claims := jwt.MapClaims{}
	_, err := jwt.ParseWithClaims(body["access_token"].(string), claims, func(*jwt.Token) (any, error) {
		return []byte(env.cfg.JWTSecret), nil
	}, jwt.WithValidMethods([]string{"HS256"}))
	if err != nil {
		t.Fatal(err)
	}
	if claims["sub"] != "admin" || claims["role"] != "admin" || claims["uid"] == nil {
		t.Fatalf("claims %v", claims)
	}
	if exp, _ := claims.GetExpirationTime(); exp == nil || !exp.After(time.Now()) {
		t.Fatalf("exp not in future: %v", claims["exp"])
	}
}

func TestInvalidJWTRejected(t *testing.T) {
	r := do(t, "GET", "/api/v1/sensors", nil, bearer("not-a-jwt"))
	expectStatus(t, r, 401)
	if r.json(t)["detail"] != "Invalid or expired token" {
		t.Fatalf("detail: %s", r.body)
	}
}

func TestExpiredJWTRejected(t *testing.T) {
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": "admin", "uid": 1, "role": "admin", "exp": time.Now().Add(-time.Minute).Unix(),
	})
	s, _ := tok.SignedString([]byte(env.cfg.JWTSecret))
	expectStatus(t, do(t, "GET", "/api/v1/sensors", nil, bearer(s)), 401)
}

func TestMissingAuthIs401NotAuthenticated(t *testing.T) {
	r := do(t, "GET", "/api/v1/sensors", nil)
	expectStatus(t, r, 401)
	if r.json(t)["detail"] != "Not authenticated" {
		t.Fatalf("detail: %s", r.body)
	}
	expectStatus(t, do(t, "GET", "/api/v1/sensors", nil, header("Authorization", "Basic abc")), 401)
}

func TestViewerForbiddenOnMutations(t *testing.T) {
	tok := viewerToken(t)
	// The role check runs before body validation (body lacks workshop_id).
	r := do(t, "POST", "/api/v1/sites", map[string]any{"name": "QA"}, bearer(tok))
	expectStatus(t, r, 403)
	if r.json(t)["detail"] != "Insufficient permissions" {
		t.Fatalf("detail: %s", r.body)
	}
	expectStatus(t, do(t, "PATCH", "/api/v1/sensors/1", map[string]any{"name": "x"}, bearer(tok)), 403)
	expectStatus(t, do(t, "DELETE", "/api/v1/sensors/1", nil, bearer(tok)), 403)
}

func TestAdminProvisioningReturnsIngestURLOnly(t *testing.T) {
	id, _ := testSensor(t)
	r := do(t, "GET", "/api/v1/sensors/"+itoa(id)+"/provisioning-token", nil, bearer(adminToken(t)))
	expectStatus(t, r, 200)
	body := r.json(t)
	if body["api_token"] != nil {
		t.Fatalf("api_token should be null: %v", body)
	}
	if !strings.HasSuffix(body["ingest_url"].(string), "/api/v1/ingest") {
		t.Fatalf("ingest_url %v", body["ingest_url"])
	}
	// https public URL is downgraded to http for the ESP.
	if body["ingest_url"] != "http://192.168.1.100/api/v1/ingest" {
		t.Fatalf("ingest_url %v", body["ingest_url"])
	}
	if !strings.Contains(body["message"].(string), "POST /sensors/{id}/rotate-token") {
		t.Fatalf("message %v", body["message"])
	}
}

func TestViewerCannotFetchProvisioningToken(t *testing.T) {
	id, _ := testSensor(t)
	expectStatus(t, do(t, "GET", "/api/v1/sensors/"+itoa(id)+"/provisioning-token", nil, bearer(viewerToken(t))), 403)
}

func TestAdminCanCreateSite(t *testing.T) {
	tok := adminToken(t)
	w := do(t, "POST", "/api/v1/workshops", map[string]any{"name": "QA Workshop"}, bearer(tok))
	expectStatus(t, w, 201)
	s := do(t, "POST", "/api/v1/sites", map[string]any{"name": "QA Site", "workshop_id": w.json(t)["id"]}, bearer(tok))
	expectStatus(t, s, 201)
	if s.json(t)["name"] != "QA Site" {
		t.Fatalf("body %s", s.body)
	}
}

// ---- test_registration_disabled.py ----

func TestRegisterDisabledWhenPublicRegistrationOff(t *testing.T) {
	cfg := *env.cfg
	cfg.AllowPublicRegistration = false
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	svc := service.New(&cfg, env.pool, ws.NewHub(log), delivery.New(&cfg, log), log)
	srv := httptest.NewServer(httpapi.New(svc, log))
	defer srv.Close()
	old := env.srv
	env.srv = srv
	defer func() { env.srv = old }()

	r := do(t, "POST", "/api/v1/auth/register", map[string]string{"login": "nobody1", "password": "Passw0rd1"})
	expectStatus(t, r, 404)
	if r.json(t)["detail"] != "Not found" {
		t.Fatalf("detail %s", r.body)
	}
	expectStatus(t, do(t, "GET", "/api/v1/auth/check-login?login=nobody1", nil), 404)
	caps := do(t, "GET", "/api/v1/auth/capabilities", nil).json(t)
	if caps["public_registration"] != false {
		t.Fatalf("caps %v", caps)
	}
}

// ---- rate limiting (slowapi parity) ----

func TestRateLimitReturns429WithErrorKey(t *testing.T) {
	cfg := *env.cfg
	cfg.AuthLoginRateLimit = "2/minute"
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	svc := service.New(&cfg, env.pool, ws.NewHub(log), delivery.New(&cfg, log), log)
	srv := httptest.NewServer(httpapi.New(svc, log))
	defer srv.Close()
	old := env.srv
	env.srv = srv
	defer func() { env.srv = old }()

	creds := map[string]string{"login": "admin", "password": "admin"}
	expectStatus(t, do(t, "POST", "/api/v1/auth/login", creds), 200)
	expectStatus(t, do(t, "POST", "/api/v1/auth/login", creds), 200)
	r := do(t, "POST", "/api/v1/auth/login", creds)
	expectStatus(t, r, 429)
	if r.json(t)["error"] != "Rate limit exceeded: 2 per 1 minute" {
		t.Fatalf("body %s", r.body)
	}
	// Validation errors (422) do not consume quota, other routes are independent.
	expectStatus(t, do(t, "GET", "/api/v1/auth/check-login?login=abcd", nil), 200)
}

func TestConfigRejectsWeakProductionSecrets(t *testing.T) {
	cfg := config.Config{AppEnv: "production", JWTSecret: "short", AdminPassword: "admin", ViewerPassword: "viewer"}
	if errs := cfg.ProductionErrors(); len(errs) != 4 {
		t.Fatalf("want 4 errors, got %v", errs)
	}
	_ = context.Background()
}
