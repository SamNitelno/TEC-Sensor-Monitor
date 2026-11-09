//go:build integration

package apitest

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"time"

	"tek-sensor-monitor/backend/internal/security"
)

func readingCount(t *testing.T, sensorID int64) int {
	t.Helper()
	var n int
	if err := env.pool.QueryRow(context.Background(), `SELECT count(*) FROM readings WHERE sensor_id = $1`, sensorID).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

type lastReading struct {
	time     time.Time
	currentA float64
	powerW   *float64
}

func latestReading(t *testing.T, sensorID int64) lastReading {
	t.Helper()
	var r lastReading
	err := env.pool.QueryRow(context.Background(),
		`SELECT time, current_a, power_w FROM readings WHERE sensor_id = $1 ORDER BY time DESC LIMIT 1`, sensorID).
		Scan(&r.time, &r.currentA, &r.powerW)
	if err != nil {
		t.Fatal(err)
	}
	return r
}

// ---- test_ingest.py ----

func TestIngestMissingTokenReturns401(t *testing.T) {
	r := do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 1.0})
	expectStatus(t, r, 401)
	if r.json(t)["detail"] != "Invalid device token" {
		t.Fatalf("detail %s", r.body)
	}
}

func TestIngestWrongTokenReturns401(t *testing.T) {
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 1.0}, header("X-Device-Token", "definitely-wrong-token")), 401)
}

func TestIngestValidTokenWritesAndUpdatesSensor(t *testing.T) {
	id, tok := testSensor(t)
	before := readingCount(t, id)
	r := do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 7.77}, header("X-Device-Token", tok))
	expectStatus(t, r, 202)
	if string(r.body) != `{"accepted":1}` {
		t.Fatalf("body %s", r.body)
	}
	if readingCount(t, id) != before+1 {
		t.Fatal("reading not stored")
	}
	var status string
	var lastSeen *time.Time
	if err := env.pool.QueryRow(context.Background(), `SELECT status::text, last_seen FROM sensors WHERE id = $1`, id).Scan(&status, &lastSeen); err != nil {
		t.Fatal(err)
	}
	if status != "online" || lastSeen == nil {
		t.Fatalf("status %s last_seen %v", status, lastSeen)
	}
	s := do(t, "GET", "/api/v1/sensors/"+itoa(id), nil, bearer(viewerToken(t)))
	if s.json(t)["status"] != "online" {
		t.Fatalf("sensor %s", s.body)
	}
}

func TestIngestWithPowerPersisted(t *testing.T) {
	id, tok := testSensor(t)
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 9.1, "power_w": 2100.0}, header("X-Device-Token", tok)), 202)
	r := latestReading(t, id)
	if r.currentA != 9.1 || r.powerW == nil || *r.powerW != 2100.0 {
		t.Fatalf("reading %+v", r)
	}
}

func TestIngestWithoutPowerStillWorks(t *testing.T) {
	id, tok := testSensor(t)
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 3.3}, header("X-Device-Token", tok)), 202)
	if r := latestReading(t, id); r.powerW != nil {
		t.Fatalf("power_w should be NULL: %+v", r)
	}
}

func TestIngestAcceptsBatch(t *testing.T) {
	_, tok := testSensor(t)
	r := do(t, "POST", "/api/v1/ingest", []map[string]any{{"current_a": 1.0, "power_w": 200.0}, {"current_a": 2.0}}, header("X-Device-Token", tok))
	expectStatus(t, r, 202)
	if r.json(t)["accepted"] != 2.0 {
		t.Fatalf("body %s", r.body)
	}
	expectStatus(t, do(t, "POST", "/api/v1/ingest", "[]", header("X-Device-Token", tok)), 202)
}

func TestIngestDuplicateDeviceTimestampUpdatesReading(t *testing.T) {
	id, tok := testSensor(t)
	ts := time.Now().UTC().Add(-5 * time.Second).Format(time.RFC3339Nano)
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 1.5, "ts": ts}, header("X-Device-Token", tok)), 202)
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 2.5, "ts": ts}, header("X-Device-Token", tok)), 202)
	var n int
	var cur float64
	if err := env.pool.QueryRow(context.Background(),
		`SELECT count(*), max(current_a) FROM readings WHERE sensor_id = $1`, id).Scan(&n, &cur); err != nil {
		t.Fatal(err)
	}
	if n != 1 || cur != 2.5 {
		t.Fatalf("count %d current %v", n, cur)
	}
}

func TestIngestRejectsOutOfRangeCurrent(t *testing.T) {
	_, tok := testSensor(t)
	r := do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 99999}, header("X-Device-Token", tok))
	expectStatus(t, r, 422)
	e := r.json(t)["detail"].([]any)[0].(map[string]any)
	// Same text as Pydantic (verified against the Python backend).
	if e["msg"] != "Input should be less than or equal to 1000" || fmt.Sprint(e["loc"]) != "[body 0 current_a]" {
		t.Fatalf("error %v", e)
	}
	r = do(t, "POST", "/api/v1/ingest", map[string]any{"power_w": 1}, header("X-Device-Token", tok))
	expectStatus(t, r, 422)
	// Invalid payload with a bad token: auth runs first.
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": -1}, header("X-Device-Token", "bad")), 401)
}

func TestIngestRejectsOversizedBatch(t *testing.T) {
	_, tok := testSensor(t)
	items := make([]map[string]any, 101)
	for i := range items {
		items[i] = map[string]any{"current_a": 1.0}
	}
	r := do(t, "POST", "/api/v1/ingest", items, header("X-Device-Token", tok))
	expectStatus(t, r, 422)
	if !strings.Contains(string(r.body), "Batch size exceeds maximum of 100") {
		t.Fatalf("body %s", r.body)
	}
}

func TestIngestStaleDeviceTimestampUsesServerTime(t *testing.T) {
	id, tok := testSensor(t)
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 1.0, "ts": "1970-01-01T00:00:00Z"}, header("X-Device-Token", tok)), 202)
	if r := latestReading(t, id); r.time.Year() < 2024 {
		t.Fatalf("stale ts stored: %v", r.time)
	}
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 1.0, "ts": time.Now().Add(time.Hour).Format(time.RFC3339)}, header("X-Device-Token", tok)), 202)
	if r := latestReading(t, id); r.time.After(time.Now().Add(time.Minute)) {
		t.Fatalf("future ts stored: %v", r.time)
	}
}

func TestIngestLegacyPlaintextToken(t *testing.T) {
	id, _ := testSensor(t)
	plain := security.TokenURLSafe(32)
	if _, err := env.pool.Exec(context.Background(), `UPDATE sensors SET api_token = $2 WHERE id = $1`, id, plain); err != nil {
		t.Fatal(err)
	}
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 1.0}, header("X-Device-Token", plain)), 202)
}

func TestRotateTokenInvalidatesOld(t *testing.T) {
	id, old := testSensor(t)
	r := do(t, "POST", "/api/v1/sensors/"+itoa(id)+"/rotate-token", nil, bearer(adminToken(t)))
	expectStatus(t, r, 200)
	var body struct {
		APIToken  string `json:"api_token"`
		IngestURL string `json:"ingest_url"`
		Warning   string `json:"warning"`
	}
	_ = json.Unmarshal(r.body, &body)
	if len(body.APIToken) != 43 || body.Warning == "" {
		t.Fatalf("body %s", r.body)
	}
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 1.0}, header("X-Device-Token", old)), 401)
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 1.0}, header("X-Device-Token", body.APIToken)), 202)
}
