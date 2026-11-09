package service

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/store"
)

// IngestReading is one validated telemetry sample.
type IngestReading struct {
	CurrentA float64
	PowerW   *float64
	TS       *time.Time
}

const maxDeviceClockSkew = 30 * time.Second

var minValidTime = time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)

// ClampDeviceTimestamp replaces implausible device clocks with server time.
func ClampDeviceTimestamp(ts, serverNow time.Time) time.Time {
	ts = ts.UTC()
	if ts.Before(minValidTime) || ts.After(serverNow.Add(maxDeviceClockSkew)) {
		return serverNow
	}
	return ts
}

// ResolveTimestamps: device ts (clamped) or server time + index microseconds.
func ResolveTimestamps(readings []IngestReading, serverNow time.Time) []time.Time {
	out := make([]time.Time, len(readings))
	for i, r := range readings {
		if r.TS != nil {
			out[i] = ClampDeviceTimestamp(*r.TS, serverNow)
		} else {
			out[i] = serverNow.Add(time.Duration(i) * time.Microsecond)
		}
	}
	return out
}

// Ingest stores readings, refreshes last_seen, closes downtime events and
// broadcasts the latest reading + online status.
func (s *Service) Ingest(ctx context.Context, sensor *models.Sensor, readings []IngestReading) (int, error) {
	if len(readings) == 0 {
		return 0, nil
	}
	receivedAt := s.now()
	timestamps := ResolveTimestamps(readings, receivedAt)
	rows := make([]models.Reading, len(readings))
	for i, r := range readings {
		rows[i] = models.Reading{Time: timestamps[i], SensorID: sensor.ID, CurrentA: r.CurrentA, PowerW: r.PowerW}
	}
	var accepted int
	err := s.tx(ctx, func(tx pgx.Tx) error {
		var err error
		accepted, err = store.UpsertReadings(ctx, tx, rows)
		if err != nil {
			return err
		}
		if err := store.UpdateLastSeen(ctx, tx, sensor.ID, receivedAt); err != nil {
			return err
		}
		last := readings[len(readings)-1]
		return s.handleTelemetryActivity(ctx, tx, sensor, &last, receivedAt)
	})
	if err != nil {
		return 0, err
	}
	if accepted > 0 {
		last := len(readings) - 1
		s.Hub.BroadcastReading(sensor.ID, readings[last].CurrentA, readings[last].PowerW, timestamps[last])
		s.Hub.BroadcastSensorStatus(sensor.ID, models.StatusOnline, &receivedAt)
	}
	return accepted, nil
}
