//go:build integration

package apitest

import (
	"context"
	"encoding/json"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"

	"tek-sensor-monitor/backend/internal/service"
)

// ---- test_readings.py ----

func TestAutoSelectBucket(t *testing.T) {
	now := time.Now()
	if b := service.AutoSelectBucket(now.Add(-365*24*time.Hour), now); b != "day" {
		t.Fatalf("year -> %s", b)
	}
	if b := service.AutoSelectBucket(now.Add(-time.Hour), now); b != "raw" {
		t.Fatalf("hour -> %s", b)
	}
}

func TestReadingsYearRangeUnderLimit(t *testing.T) {
	id, tok := testSensor(t)
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 1.0}, header("X-Device-Token", tok)), 202)
	now := time.Now().UTC()
	q := url.Values{"from": {now.AddDate(-1, 0, 0).Format(time.RFC3339)}, "to": {now.Format(time.RFC3339)}}
	r := do(t, "GET", "/api/v1/sensors/"+itoa(id)+"/readings?"+q.Encode(), nil, bearer(viewerToken(t)))
	expectStatus(t, r, 200)
	body := r.json(t)
	if body["bucket"] != "day" || len(body["points"].([]any)) >= 2000 {
		t.Fatalf("body %s", r.body)
	}
}

func TestGroupedReadingsRawAndValidation(t *testing.T) {
	id, tok := testSensor(t)
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 4.0, "power_w": 900.0}, header("X-Device-Token", tok)), 202)
	vt := viewerToken(t)
	now := time.Now().UTC().Add(time.Second)
	q := url.Values{"from": {now.Add(-time.Hour).Format(time.RFC3339Nano)}, "to": {now.Format(time.RFC3339Nano)}, "sensor_ids": {itoa(id), "999999"}}
	r := do(t, "GET", "/api/v1/readings?"+q.Encode(), nil, bearer(vt))
	expectStatus(t, r, 200)
	series := r.json(t)["series"].([]any)
	if len(series) != 1 {
		t.Fatalf("series %s", r.body)
	}
	s := series[0].(map[string]any)
	pts := s["points"].([]any)
	if s["bucket"] != "raw" || len(pts) != 1 {
		t.Fatalf("series %v", s)
	}
	p := pts[0].(map[string]any)
	if p["avg"] != 4.0 || p["min"] != 4.0 || p["max"] != 4.0 || p["power_w"] != 900.0 {
		t.Fatalf("point %v", p)
	}
	// Floats keep a decimal point like the Python API.
	if !strings.Contains(string(r.body), `"avg":4.0`) {
		t.Fatalf("float formatting %s", r.body)
	}
	bad := url.Values{"from": {now.Format(time.RFC3339)}, "to": {now.Add(-time.Hour).Format(time.RFC3339)}}
	r = do(t, "GET", "/api/v1/readings?"+bad.Encode(), nil, bearer(vt))
	expectStatus(t, r, 422)
	if r.json(t)["detail"] != "'from' must be before 'to'" {
		t.Fatalf("detail %s", r.body)
	}
	r = do(t, "GET", "/api/v1/readings?to=2026-01-01T00:00:00Z", nil, bearer(vt))
	expectStatus(t, r, 422)
	e := r.json(t)["detail"].([]any)[0].(map[string]any)
	if e["type"] != "missing" || e["msg"] != "Field required" {
		t.Fatalf("detail %v", e)
	}
	empty := do(t, "GET", "/api/v1/readings?"+url.Values{"from": q["from"], "to": q["to"], "site_id": {"999999"}}.Encode(), nil, bearer(vt))
	if string(empty.body) != `{"series":[]}` {
		t.Fatalf("empty %s", empty.body)
	}
}

// ---- groups: CRUD, cascades and fixed delete behaviour ----

func TestGroupsCRUDAndNotificationCascade(t *testing.T) {
	tok := adminToken(t)
	ctx := context.Background()
	id, _ := testSensor(t)
	s := getSensor(t, id)
	siteID := *s.SiteID
	var workshopID int64
	_ = env.pool.QueryRow(ctx, `SELECT workshop_id FROM sites WHERE id = $1`, siteID).Scan(&workshopID)

	r := do(t, "PATCH", "/api/v1/workshops/"+itoa(workshopID), map[string]any{"notifications_enabled": false}, bearer(tok))
	expectStatus(t, r, 200)
	if getSensor(t, id).NotificationsEnabled {
		t.Fatal("workshop toggle did not cascade to sensors")
	}
	r = do(t, "PATCH", "/api/v1/sites/"+itoa(siteID), map[string]any{"notifications_enabled": true, "color": "#00ff00"}, bearer(tok))
	expectStatus(t, r, 200)
	if r.json(t)["color"] != "#00FF00" || !getSensor(t, id).NotificationsEnabled {
		t.Fatalf("site patch %s", r.body)
	}
	b := do(t, "POST", "/api/v1/sensors/notifications/bulk", map[string]any{"enabled": true}, bearer(tok))
	expectStatus(t, b, 200)
	if b.json(t)["updated"].(float64) < 1 {
		t.Fatalf("bulk %s", b.body)
	}
	expectStatus(t, do(t, "POST", "/api/v1/workshops/notifications/bulk", map[string]any{"enabled": true}, bearer(tok)), 200)
	expectStatus(t, do(t, "POST", "/api/v1/sites/notifications/bulk", map[string]any{}, bearer(tok)), 422)

	// Sensor PATCH: explicit null clears the site, absent key keeps it.
	r = do(t, "PATCH", "/api/v1/sensors/"+itoa(id), map[string]any{"name": "renamed"}, bearer(tok))
	if r.json(t)["site_id"] == nil {
		t.Fatalf("absent site_id cleared the site: %s", r.body)
	}
	r = do(t, "PATCH", "/api/v1/sensors/"+itoa(id), map[string]any{"site_id": nil, "idle_duration_seconds": 30, "idle_power_threshold_w": 25}, bearer(tok))
	expectStatus(t, r, 200)
	body := r.json(t)
	if body["site_id"] != nil || body["idle_duration_seconds"] != 30.0 || body["idle_power_threshold_w"] != 25.0 {
		t.Fatalf("patch %s", r.body)
	}
	if !strings.Contains(string(r.body), `"idle_power_threshold_w":25.0`) {
		t.Fatalf("float formatting %s", r.body)
	}
	expectStatus(t, do(t, "PATCH", "/api/v1/sensors/"+itoa(id), map[string]any{"idle_duration_seconds": 0}, bearer(tok)), 422)
	audit := do(t, "GET", "/api/v1/sensors/"+itoa(id)+"/audit", nil, bearer(tok))
	expectStatus(t, audit, 200)
	hist := audit.json(t)["placement_history"].([]any)
	if len(hist) != 2 || hist[0].(map[string]any)["site_id"] != nil || audit.json(t)["created_by_login"] != "admin" {
		t.Fatalf("audit %s", audit.body)
	}

	// Bug fix: deleting a site with placement history returns 204 (was 500).
	expectStatus(t, do(t, "DELETE", "/api/v1/sites/"+itoa(siteID), nil, bearer(tok)), 204)
	// Workshop without sites can be deleted; with sites -> 409 (was 500).
	w := do(t, "POST", "/api/v1/workshops", map[string]any{"name": "ToDelete"}, bearer(tok))
	wID := int64(w.json(t)["id"].(float64))
	expectStatus(t, do(t, "POST", "/api/v1/sites", map[string]any{"name": "inner", "workshop_id": wID}, bearer(tok)), 201)
	r = do(t, "DELETE", "/api/v1/workshops/"+itoa(wID), nil, bearer(tok))
	expectStatus(t, r, 409)
	expectStatus(t, do(t, "DELETE", "/api/v1/workshops/"+itoa(workshopID), nil, bearer(tok)), 204)
	expectStatus(t, do(t, "DELETE", "/api/v1/workshops/"+itoa(workshopID), nil, bearer(tok)), 404)

	expectStatus(t, do(t, "DELETE", "/api/v1/sensors/"+itoa(id), nil, bearer(tok)), 204)
	expectStatus(t, do(t, "GET", "/api/v1/sensors/"+itoa(id), nil, bearer(tok)), 404)
	expectStatus(t, do(t, "GET", "/api/v1/sensors/abc", nil, bearer(tok)), 422)
}

func TestSensorCreateConflicts(t *testing.T) {
	tok := adminToken(t)
	dev := unique("DUP-")
	expectStatus(t, do(t, "POST", "/api/v1/sensors", map[string]any{"name": "a", "device_id": dev}, bearer(tok)), 201)
	r := do(t, "POST", "/api/v1/sensors", map[string]any{"name": "b", "device_id": dev}, bearer(tok))
	expectStatus(t, r, 409)
	if r.json(t)["detail"] != "device_id already exists" {
		t.Fatalf("detail %s", r.body)
	}
	r = do(t, "POST", "/api/v1/sensors", map[string]any{"name": "c", "device_id": unique("X-"), "site_id": 999999}, bearer(tok))
	expectStatus(t, r, 404)
	if r.json(t)["detail"] != "Site not found" {
		t.Fatalf("detail %s", r.body)
	}
}

func TestNotificationsAckFlow(t *testing.T) {
	_, tok := newViewer(t)
	expectStatus(t, do(t, "GET", "/api/v1/notifications/unread-count", nil, bearer(tok)), 200)
	r := do(t, "POST", "/api/v1/notifications/999999/ack", nil, bearer(tok))
	expectStatus(t, r, 404)
	if r.json(t)["detail"] != "Notification not found" {
		t.Fatalf("detail %s", r.body)
	}
	ack := do(t, "POST", "/api/v1/notifications/ack-all", nil, bearer(tok))
	expectStatus(t, ack, 200)
	if _, ok := ack.json(t)["acknowledged"]; !ok {
		t.Fatalf("ack-all %s", ack.body)
	}
	c := do(t, "GET", "/api/v1/notifications/unread-count", nil, bearer(tok))
	if c.json(t)["count"] != 0.0 {
		t.Fatalf("count %s", c.body)
	}
}

func TestTrailingSlashRedirectsAndUnknownRoute(t *testing.T) {
	r := do(t, "GET", "/api/v1/sensors/", nil)
	expectStatus(t, r, 307)
	if !strings.HasSuffix(r.header.Get("Location"), "/api/v1/sensors") {
		t.Fatalf("location %s", r.header.Get("Location"))
	}
	r = do(t, "GET", "/api/v1/unknown", nil)
	expectStatus(t, r, 404)
	if string(r.body) != `{"detail":"Not Found"}` {
		t.Fatalf("body %s", r.body)
	}
	expectStatus(t, do(t, "PUT", "/api/v1/sensors", nil), 405)
	h := do(t, "GET", "/health", nil)
	if string(h.body) != `{"status":"ok"}` {
		t.Fatalf("health %s", h.body)
	}
}

func TestCORSPreflight(t *testing.T) {
	r := do(t, "OPTIONS", "/api/v1/auth/login", nil,
		header("Origin", "http://localhost:5000"), header("Access-Control-Request-Method", "POST"),
		header("Access-Control-Request-Headers", "content-type,authorization"))
	expectStatus(t, r, 200)
	if r.header.Get("Access-Control-Allow-Origin") != "http://localhost:5000" ||
		r.header.Get("Access-Control-Allow-Headers") != "content-type,authorization" ||
		r.header.Get("Access-Control-Allow-Credentials") != "true" {
		t.Fatalf("headers %v", r.header)
	}
	g := do(t, "GET", "/health", nil, header("Origin", "http://localhost:5000"))
	if g.header.Get("Access-Control-Allow-Origin") != "*" {
		t.Fatalf("simple cors %v", g.header)
	}
}

// ---- test_websocket.py ----

func wsURL(path string) string { return "ws" + strings.TrimPrefix(env.srv.URL, "http") + path }

func TestWebsocketRejectsMissingToken(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, resp, err := websocket.Dial(ctx, wsURL("/ws"), nil)
	if err == nil {
		t.Fatal("connection accepted without token")
	}
	if resp == nil || resp.StatusCode != 403 {
		t.Fatalf("resp %v", resp)
	}
	_, _, err = websocket.Dial(ctx, wsURL("/ws?token=garbage"), nil)
	if err == nil {
		t.Fatal("connection accepted with invalid token")
	}
}

func TestWebsocketReceivesReadingAndStatus(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	conn, _, err := websocket.Dial(ctx, wsURL("/ws?token="+viewerToken(t)), nil)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.CloseNow()
	if err := conn.Write(ctx, websocket.MessageText, []byte("ping")); err != nil {
		t.Fatal(err)
	}
	id, tok := testSensor(t)
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 3.0, "power_w": 690.0, "ts": time.Now().UTC().Format(time.RFC3339)}, header("X-Device-Token", tok)), 202)
	got := map[string]map[string]any{}
	for len(got) < 2 {
		_, data, err := conn.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		var m map[string]any
		_ = json.Unmarshal(data, &m)
		if m["sensor_id"] == float64(id) {
			got[m["type"].(string)] = m
			if m["type"] == "reading" && !strings.HasSuffix(m["ts"].(string), "+00:00") {
				t.Fatalf("ts format %v", m["ts"])
			}
		}
	}
	if got["reading"]["current_a"] != 3.0 || got["sensor_status"]["status"] != "online" || got["sensor_status"]["last_seen"] == nil {
		t.Fatalf("messages %v", got)
	}
}
