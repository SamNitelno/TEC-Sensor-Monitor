package service

import (
	"io"
	"log/slog"
	"testing"
	"time"

	"tek-sensor-monitor/backend/internal/config"
	"tek-sensor-monitor/backend/internal/models"
)

func newUnitService() *Service {
	cfg := &config.Config{
		SensorOfflineThresholdSeconds: 15,
		DowntimeSmoothingSamples:      3,
		DefaultIdlePowerThresholdW:    50,
		DefaultIdleCurrentThresholdA:  0.5,
		DefaultIdleDurationSeconds:    60,
	}
	return New(cfg, nil, nil, nil, slog.New(slog.NewTextHandler(io.Discard, nil)))
}

func f(v float64) *float64 { return &v }

func TestAutoSelectBucketBoundaries(t *testing.T) {
	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	cases := []struct {
		d    time.Duration
		want string
	}{
		{time.Hour, "raw"},
		{10_000 * time.Second, "raw"},
		{10_001 * time.Second, "minute"},
		{2000 * time.Minute, "minute"},
		{2001 * time.Minute, "hour"},
		{2000 * time.Hour, "hour"},
		{2001 * time.Hour, "day"},
		{365 * 24 * time.Hour, "day"},
	}
	for _, c := range cases {
		if got := AutoSelectBucket(base, base.Add(c.d)); got != c.want {
			t.Errorf("%v -> %s, want %s", c.d, got, c.want)
		}
	}
}

func TestClampDeviceTimestamp(t *testing.T) {
	now := time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC)
	if got := ClampDeviceTimestamp(time.Date(1970, 1, 1, 0, 0, 0, 0, time.UTC), now); !got.Equal(now) {
		t.Errorf("stale -> %v", got)
	}
	if got := ClampDeviceTimestamp(now.Add(time.Minute), now); !got.Equal(now) {
		t.Errorf("future -> %v", got)
	}
	ok := now.Add(20 * time.Second)
	if got := ClampDeviceTimestamp(ok, now); !got.Equal(ok) {
		t.Errorf("within skew -> %v", got)
	}
	ts := ResolveTimestamps([]IngestReading{{}, {}, {TS: &ok}}, now)
	if !ts[0].Equal(now) || !ts[1].Equal(now.Add(time.Microsecond)) || !ts[2].Equal(ok) {
		t.Errorf("resolve %v", ts)
	}
}

func TestFormatDurationRU(t *testing.T) {
	cases := map[float64]string{
		-5: "0 сек", 0: "0 сек", 59.9: "59 сек", 60: "1 мин", 3599: "59 мин", 3600: "1 ч",
		3660: "1 ч 1 мин", 86400: "1 д", 90000: "1 д 1 ч",
	}
	for in, want := range cases {
		if got := FormatDurationRU(in); got != want {
			t.Errorf("FormatDurationRU(%v) = %q, want %q", in, got, want)
		}
	}
}

func readings(vals ...[2]float64) []models.Reading {
	out := make([]models.Reading, len(vals))
	for i, v := range vals {
		p := v[1]
		out[i] = models.Reading{CurrentA: v[0], PowerW: &p}
		if p < 0 {
			out[i].PowerW = nil
		}
	}
	return out
}

func TestIdleDetectionRules(t *testing.T) {
	s := newUnitService()
	sensor := &models.Sensor{}
	// Load current with zero power is active.
	if s.IsSampleIdle(sensor, 4.2, f(0)) {
		t.Error("current above threshold must be active")
	}
	if !s.IsSampleIdle(sensor, 0.1, f(10)) || s.IsSampleIdle(sensor, 0.1, f(60)) || !s.IsSampleIdle(sensor, 0.1, nil) {
		t.Error("IsSampleIdle power rules")
	}
	// Median of the last 3: one spike does not end idle, but the latest sample must be idle too.
	if !s.IsIdleState(sensor, readings([2]float64{5, 900}, [2]float64{0.1, 5}, [2]float64{0.2, 6}, [2]float64{0.1, 5})) {
		t.Error("expected idle")
	}
	if s.IsIdleState(sensor, readings([2]float64{0.1, 5}, [2]float64{0.1, 5}, [2]float64{6, 1200})) {
		t.Error("latest active sample must break idle")
	}
	// Even count median averages middle values (statistics.median).
	if got := median([]float64{1, 2, 3, 10}); got != 2.5 {
		t.Errorf("median = %v", got)
	}
	// Per-sensor thresholds override defaults.
	thr := 0.05
	sensor.IdleCurrentThresholdA = &thr
	if s.IsSampleIdle(sensor, 0.1, nil) {
		t.Error("per-sensor current threshold ignored")
	}
}

func TestSensorOnline(t *testing.T) {
	s := newUnitService()
	now := time.Now()
	recent := now.Add(-10 * time.Second)
	old := now.Add(-16 * time.Second)
	if !s.IsSensorOnline(&models.Sensor{LastSeen: &recent}, now) || s.IsSensorOnline(&models.Sensor{LastSeen: &old}, now) ||
		s.IsSensorOnline(&models.Sensor{}, now) {
		t.Error("online threshold")
	}
}

func TestParseDateTime(t *testing.T) {
	want := time.Date(2026, 6, 30, 12, 0, 0, 0, time.UTC)
	for _, in := range []string{
		"2026-06-30T12:00:00Z", "2026-06-30T12:00:00+00:00", "2026-06-30T15:00:00+03:00",
		"2026-06-30 12:00:00", "2026-06-30T12:00:00", "1782820800", "1782820800000",
	} {
		got, err := ParseDateTime(in)
		if err != nil || !got.Equal(want) {
			t.Errorf("ParseDateTime(%q) = %v, %v", in, got, err)
		}
	}
	if got, _ := ParseDateTime("2026-06-30T12:00:00.123456789Z"); got.Nanosecond() != 123456000 {
		t.Errorf("fraction %v", got)
	}
	if got, _ := ParseDateTime("2026-06-30"); !got.Equal(time.Date(2026, 6, 30, 0, 0, 0, 0, time.UTC)) {
		t.Errorf("date only %v", got)
	}
	for _, bad := range []string{"", "abc", "2026-13-01T00:00:00Z", "2026-02-30T00:00:00Z"} {
		if _, err := ParseDateTime(bad); err == nil {
			t.Errorf("ParseDateTime(%q) accepted", bad)
		}
	}
}
