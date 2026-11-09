//go:build integration

package apitest

import (
	"context"
	"math"
	"net/url"
	"testing"
	"time"

	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/service"
	"tek-sensor-monitor/backend/internal/store"
)

// isolate makes the detection cycle only see sensors created by this test.
func isolate(t *testing.T) (int64, string) {
	t.Helper()
	ctx := context.Background()
	// Push every other sensor far into the past so the cycle ignores them
	// (they are already offline with open events after the first cycle).
	id, tok := testSensor(t)
	env.svc.ResetIdleStateForTest()
	if _, err := env.pool.Exec(ctx, `DELETE FROM downtime_events WHERE sensor_id = $1`, id); err != nil {
		t.Fatal(err)
	}
	return id, tok
}

func openEvent(t *testing.T, id int64, typ string) *models.DowntimeEvent {
	t.Helper()
	e, err := store.GetOpenEvent(context.Background(), env.pool, id, typ)
	if err != nil {
		t.Fatal(err)
	}
	return e
}

func insertReading(t *testing.T, id int64, at time.Time, current float64, power *float64) {
	t.Helper()
	if _, err := store.UpsertReadings(context.Background(), env.pool, []models.Reading{{Time: at, SensorID: id, CurrentA: current, PowerW: power}}); err != nil {
		t.Fatal(err)
	}
}

func f64(v float64) *float64 { return &v }

func cycle(t *testing.T) {
	t.Helper()
	if err := env.svc.RunDowntimeCycle(context.Background()); err != nil {
		t.Fatal(err)
	}
}

func getSensor(t *testing.T, id int64) *models.Sensor {
	t.Helper()
	s, err := store.GetSensorByID(context.Background(), env.pool, id)
	if err != nil || s == nil {
		t.Fatalf("sensor %d: %v", id, err)
	}
	return s
}

// ---- test_downtime.py ----

func TestOfflineEventOpenedWhenStale(t *testing.T) {
	ctx := context.Background()
	id, _ := isolate(t)
	now := time.Now().UTC()
	insertReading(t, id, now.Add(-30*time.Second), 5.0, f64(1000))
	_ = store.UpdateLastSeen(ctx, env.pool, id, now.Add(-30*time.Second))
	cycle(t)
	if s := getSensor(t, id); s.Status != models.StatusOffline {
		t.Fatalf("status %s", s.Status)
	}
	e := openEvent(t, id, models.DowntimeOffline)
	if e == nil || e.EndedAt != nil {
		t.Fatalf("event %+v", e)
	}
	// Notifications were created for active users.
	var n int
	_ = env.pool.QueryRow(ctx, `SELECT count(*) FROM user_notifications WHERE kind = 'sensor_offline' AND message LIKE '%' || $1 || '%'`, getSensor(t, id).Name).Scan(&n)
	if n == 0 {
		t.Fatal("no offline notifications")
	}
}

func TestOfflineEventClosedOnIngestResume(t *testing.T) {
	ctx := context.Background()
	id, tok := isolate(t)
	stale := time.Now().UTC().Add(-30 * time.Second)
	insertReading(t, id, stale, 5.0, f64(1000))
	_ = store.UpdateLastSeen(ctx, env.pool, id, stale)
	if _, err := store.CreateEvent(ctx, env.pool, id, models.DowntimeOffline, stale); err != nil {
		t.Fatal(err)
	}
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 4.0, "power_w": 900.0}, header("X-Device-Token", tok)), 202)
	if openEvent(t, id, models.DowntimeOffline) != nil {
		t.Fatal("offline event still open")
	}
	var n int
	_ = env.pool.QueryRow(ctx, `SELECT count(*) FROM downtime_events WHERE sensor_id = $1 AND type = 'offline' AND ended_at IS NOT NULL`, id).Scan(&n)
	if n != 1 {
		t.Fatalf("closed events %d", n)
	}
}

func setIdleConfig(t *testing.T, id int64, powerThr float64, duration int64) {
	t.Helper()
	s := getSensor(t, id)
	s.IdlePowerThresholdW = &powerThr
	s.IdleDurationSeconds = &duration
	if err := store.SaveSensor(context.Background(), env.pool, s); err != nil {
		t.Fatal(err)
	}
}

func TestIdleEventOnLowPower(t *testing.T) {
	ctx := context.Background()
	id, _ := isolate(t)
	setIdleConfig(t, id, 100, 0)
	now := time.Now().UTC()
	for offset := 0; offset < 6; offset++ {
		insertReading(t, id, now.Add(-time.Duration(30-offset*5)*time.Second), 0.1, f64(10))
	}
	_ = store.UpdateLastSeen(ctx, env.pool, id, now)
	pending := now.Add(-120 * time.Second)
	env.svc.SetIdlePendingForTest(id, &pending)
	cycle(t)
	e := openEvent(t, id, models.DowntimeIdle)
	if e == nil || e.EndedAt != nil {
		t.Fatalf("idle event %+v", e)
	}
	if !e.StartedAt.Equal(pending.Truncate(time.Microsecond)) {
		t.Fatalf("started_at %v want %v", e.StartedAt, pending)
	}
}

func TestIdleDebounceNeedsTwoCycles(t *testing.T) {
	ctx := context.Background()
	id, _ := isolate(t)
	setIdleConfig(t, id, 100, 0)
	now := time.Now().UTC()
	for offset := 0; offset < 3; offset++ {
		insertReading(t, id, now.Add(-time.Duration(10-offset*5)*time.Second), 0.1, f64(10))
	}
	_ = store.UpdateLastSeen(ctx, env.pool, id, now)
	cycle(t)
	if openEvent(t, id, models.DowntimeIdle) != nil {
		t.Fatal("idle event opened on the first observation")
	}
	cycle(t)
	if openEvent(t, id, models.DowntimeIdle) == nil {
		t.Fatal("idle event not opened on the second cycle")
	}
}

func TestIdleClosedWhenCurrentHighButPowerLow(t *testing.T) {
	ctx := context.Background()
	id, tok := isolate(t)
	if _, err := store.CreateEvent(ctx, env.pool, id, models.DowntimeIdle, time.Now().Add(-5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 4.2, "power_w": 0.0}, header("X-Device-Token", tok)), 202)
	if openEvent(t, id, models.DowntimeIdle) != nil {
		t.Fatal("idle event still open")
	}
}

func TestIdleClosedOnIngestActivity(t *testing.T) {
	ctx := context.Background()
	id, tok := isolate(t)
	if _, err := store.CreateEvent(ctx, env.pool, id, models.DowntimeIdle, time.Now().Add(-5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 8.0, "power_w": 1500.0}, header("X-Device-Token", tok)), 202)
	if openEvent(t, id, models.DowntimeIdle) != nil {
		t.Fatal("idle event still open")
	}
}

func TestIdleNotClosedByIdleIngest(t *testing.T) {
	ctx := context.Background()
	id, tok := isolate(t)
	if _, err := store.CreateEvent(ctx, env.pool, id, models.DowntimeIdle, time.Now().Add(-5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	expectStatus(t, do(t, "POST", "/api/v1/ingest", map[string]any{"current_a": 0.0, "power_w": 0.0}, header("X-Device-Token", tok)), 202)
	if openEvent(t, id, models.DowntimeIdle) == nil {
		t.Fatal("idle event closed by an idle sample")
	}
}

func TestIdleEventClosedWhenPowerRises(t *testing.T) {
	ctx := context.Background()
	id, _ := isolate(t)
	setIdleConfig(t, id, 100, 0)
	now := time.Now().UTC()
	if _, err := store.CreateEvent(ctx, env.pool, id, models.DowntimeIdle, now.Add(-5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	for offset := 5; offset >= 1; offset-- {
		insertReading(t, id, now.Add(-time.Duration(offset)*time.Second), 8.0, f64(1500))
	}
	_ = store.UpdateLastSeen(ctx, env.pool, id, now)
	cycle(t)
	if openEvent(t, id, models.DowntimeIdle) != nil {
		t.Fatal("idle event still open")
	}
}

func TestDowntimeSummaryMatchesInterval(t *testing.T) {
	ctx := context.Background()
	id, _ := isolate(t)
	now := time.Now().UTC()
	e, err := store.CreateEvent(ctx, env.pool, id, models.DowntimeIdle, now.Add(-2*time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	_ = store.CloseEvent(ctx, env.pool, e.ID, now.Add(-time.Hour))
	sum, err := env.svc.DowntimeSummary(ctx, now.Add(-3*time.Hour), now, &id, nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	if len(sum.Sensors) != 1 || math.Abs(float64(sum.Sensors[0].IdleSeconds)-3600) > 36 {
		t.Fatalf("summary %+v", sum.Sensors)
	}
	if len(sum.Workshops) != 1 || math.Abs(float64(sum.Workshops[0].TotalSeconds)-3600) > 36 {
		t.Fatalf("workshops %+v", sum.Workshops)
	}
	// Clipping to the requested window.
	sum, _ = env.svc.DowntimeSummary(ctx, now.Add(-90*time.Minute), now, &id, nil, nil)
	if math.Abs(float64(sum.Sensors[0].IdleSeconds)-1800) > 18 {
		t.Fatalf("clipped %+v", sum.Sensors)
	}
}

func TestDowntimeEventsAPI(t *testing.T) {
	ctx := context.Background()
	id, _ := isolate(t)
	now := time.Now().UTC()
	if _, err := store.CreateEvent(ctx, env.pool, id, models.DowntimeOffline, now.Add(-10*time.Minute)); err != nil {
		t.Fatal(err)
	}
	q := url.Values{"from": {now.Add(-time.Hour).Format(time.RFC3339Nano)}, "to": {now.Format(time.RFC3339Nano)}, "sensor_id": {itoa(id)}}
	r := do(t, "GET", "/api/v1/downtime/events?"+q.Encode(), nil, bearer(viewerToken(t)))
	expectStatus(t, r, 200)
	events := r.json(t)["events"].([]any)
	if len(events) < 1 {
		t.Fatalf("events %s", r.body)
	}
	ev := events[0].(map[string]any)
	if ev["type"] != "offline" || ev["ended_at"] != nil || ev["duration_seconds"] != nil || ev["workshop_name"] == nil {
		t.Fatalf("event %v", ev)
	}
	r = do(t, "GET", "/api/v1/downtime/summary?"+q.Encode(), nil, bearer(viewerToken(t)))
	expectStatus(t, r, 200)
	expectStatus(t, do(t, "GET", "/api/v1/downtime/events?from=x&to=y", nil, bearer(viewerToken(t))), 422)
	expectStatus(t, do(t, "GET", "/api/v1/downtime/events?"+q.Encode()+"&type=bogus", nil, bearer(viewerToken(t))), 422)
}

func TestOfflineWatchdogFlipsStatus(t *testing.T) {
	ctx := context.Background()
	id, _ := isolate(t)
	_ = store.UpdateLastSeen(ctx, env.pool, id, time.Now().Add(-time.Minute))
	n, err := env.svc.MarkStaleSensorsOffline(ctx)
	if err != nil || n < 1 {
		t.Fatalf("n=%d err=%v", n, err)
	}
	if s := getSensor(t, id); s.Status != models.StatusOffline {
		t.Fatalf("status %s", s.Status)
	}
}

func TestMQTTLWTMarksOffline(t *testing.T) {
	ctx := context.Background()
	id, _ := isolate(t)
	_ = store.UpdateLastSeen(ctx, env.pool, id, time.Now())
	if err := env.svc.HandleMQTTLWTOffline(ctx, getSensor(t, id)); err != nil {
		t.Fatal(err)
	}
	if getSensor(t, id).Status != models.StatusOffline || openEvent(t, id, models.DowntimeOffline) == nil {
		t.Fatal("LWT not applied")
	}
}

func TestMQTTTelemetryParsing(t *testing.T) {
	r, err := env.svc.ParseMQTTTelemetry(map[string]any{"current_a": 1.5, "power_w": "300", "ts": "2026-07-05T10:00:00Z"})
	if err != nil || r.CurrentA != 1.5 || *r.PowerW != 300 || r.TS == nil {
		t.Fatalf("r=%+v err=%v", r, err)
	}
	if _, err := env.svc.ParseMQTTTelemetry(map[string]any{"current_a": 99999.0}); err == nil {
		t.Fatal("out-of-range current accepted")
	}
	if _, err := env.svc.ParseMQTTTelemetry(map[string]any{"power_w": 1.0}); err == nil {
		t.Fatal("missing current accepted")
	}
	if dev, ch, ok := service.ParseMQTTTopic("sensors/ESP-1/status"); !ok || dev != "ESP-1" || ch != "status" {
		t.Fatal("topic parse")
	}
}
