package service

import (
	"context"
	"sort"
	"time"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/store"
)

// ---- idle thresholds -------------------------------------------------------

func (s *Service) idleCurrentThreshold(sensor *models.Sensor) float64 {
	if sensor.IdleCurrentThresholdA != nil {
		return *sensor.IdleCurrentThresholdA
	}
	return s.Cfg.DefaultIdleCurrentThresholdA
}

func (s *Service) idlePowerThreshold(sensor *models.Sensor) float64 {
	if sensor.IdlePowerThresholdW != nil {
		return *sensor.IdlePowerThresholdW
	}
	return s.Cfg.DefaultIdlePowerThresholdW
}

func (s *Service) idleDuration(sensor *models.Sensor) int64 {
	if sensor.IdleDurationSeconds != nil {
		return *sensor.IdleDurationSeconds
	}
	return int64(s.Cfg.DefaultIdleDurationSeconds)
}

// IsSampleIdle: idle when current is near zero; power is consulted only if
// current is low (so load current with zero power still counts as active).
func (s *Service) IsSampleIdle(sensor *models.Sensor, currentA float64, powerW *float64) bool {
	if currentA >= s.idleCurrentThreshold(sensor) {
		return false
	}
	if powerW != nil {
		return *powerW < s.idlePowerThreshold(sensor)
	}
	return true
}

// median mirrors statistics.median (mean of the two middle values).
func median(values []float64) float64 {
	v := append([]float64(nil), values...)
	sort.Float64s(v)
	n := len(v)
	if n%2 == 1 {
		return v[n/2]
	}
	return (v[n/2-1] + v[n/2]) / 2
}

// smoothingWindow mirrors readings[-N:] (N<=0 keeps the whole slice).
func smoothingWindow(readings []models.Reading, n int) []models.Reading {
	if n <= 0 || n >= len(readings) {
		return readings
	}
	return readings[len(readings)-n:]
}

func (s *Service) isBelowIdleThreshold(sensor *models.Sensor, readings []models.Reading) bool {
	if len(readings) == 0 {
		return false
	}
	window := smoothingWindow(readings, s.Cfg.DowntimeSmoothingSamples)
	currents := make([]float64, 0, len(window))
	var powers []float64
	for _, r := range window {
		currents = append(currents, r.CurrentA)
		if r.PowerW != nil {
			powers = append(powers, *r.PowerW)
		}
	}
	if median(currents) >= s.idleCurrentThreshold(sensor) {
		return false
	}
	if len(powers) > 0 {
		return median(powers) < s.idlePowerThreshold(sensor)
	}
	return true
}

// IsIdleState: the smoothed window and the latest sample both indicate idle.
func (s *Service) IsIdleState(sensor *models.Sensor, readings []models.Reading) bool {
	if len(readings) == 0 {
		return false
	}
	last := readings[len(readings)-1]
	return s.isBelowIdleThreshold(sensor, readings) && s.IsSampleIdle(sensor, last.CurrentA, last.PowerW)
}

// ---- in-memory idle debounce state ------------------------------------------

func (s *Service) idlePending(id int64) (time.Time, bool) {
	s.idleMu.Lock()
	defer s.idleMu.Unlock()
	t, ok := s.idlePendingSince[id]
	return t, ok
}

func (s *Service) setIdlePending(id int64, t time.Time) {
	s.idleMu.Lock()
	s.idlePendingSince[id] = t
	s.idleMu.Unlock()
}

func (s *Service) clearIdlePending(id int64) {
	s.idleMu.Lock()
	delete(s.idlePendingSince, id)
	s.idleMu.Unlock()
}

// SetIdlePendingForTest exposes the debounce state to tests.
func (s *Service) SetIdlePendingForTest(id int64, t *time.Time) {
	if t == nil {
		s.clearIdlePending(id)
		return
	}
	s.setIdlePending(id, *t)
}

// ResetIdleStateForTest clears all debounce state.
func (s *Service) ResetIdleStateForTest() {
	s.idleMu.Lock()
	s.idlePendingSince = map[int64]time.Time{}
	s.idleMu.Unlock()
}

// ---- ingest-side handling ----------------------------------------------------

// handleTelemetryActivity closes offline events and (for an active last
// sample) idle events as soon as telemetry arrives.
func (s *Service) handleTelemetryActivity(ctx context.Context, tx pgx.Tx, sensor *models.Sensor, last *IngestReading, at time.Time) error {
	if _, err := store.CloseOpenEvents(ctx, tx, sensor.ID, models.DowntimeOffline, at); err != nil {
		return err
	}
	if last == nil || s.IsSampleIdle(sensor, last.CurrentA, last.PowerW) {
		return nil
	}
	s.clearIdlePending(sensor.ID)
	n, err := store.CloseOpenEvents(ctx, tx, sensor.ID, models.DowntimeIdle, at)
	if err != nil {
		return err
	}
	if n > 0 {
		s.Log.Info("Sensor active (ingest), idle event closed", "sensor", sensor.Name)
	}
	return nil
}

// HandleMQTTLWTOffline marks a sensor offline immediately (MQTT Last Will).
func (s *Service) HandleMQTTLWTOffline(ctx context.Context, sensor *models.Sensor) error {
	now := s.now()
	err := s.tx(ctx, func(tx pgx.Tx) error {
		if err := store.SetSensorStatus(ctx, tx, sensor.ID, models.StatusOffline); err != nil {
			return err
		}
		open, err := store.GetOpenEvent(ctx, tx, sensor.ID, models.DowntimeOffline)
		if err != nil {
			return err
		}
		if open == nil {
			startedAt := now
			if sensor.LastSeen != nil {
				startedAt = *sensor.LastSeen
			}
			if _, err := store.CreateEvent(ctx, tx, sensor.ID, models.DowntimeOffline, startedAt); err != nil {
				return err
			}
			if err := s.notifyDowntimeEvent(ctx, tx, sensor, models.DowntimeOffline, startedAt); err != nil {
				return err
			}
			s.Log.Info("Sensor offline (MQTT LWT)", "sensor", sensor.Name)
		}
		return nil
	})
	if err != nil {
		return err
	}
	s.Hub.BroadcastSensorStatus(sensor.ID, models.StatusOffline, sensor.LastSeen)
	return nil
}

// ---- downtime worker -----------------------------------------------------------

type pendingBroadcast struct {
	sensorID int64
	status   string
	lastSeen *time.Time
}

// RunDowntimeCycle evaluates offline and idle state for every sensor in one
// transaction; status broadcasts are sent after a successful commit.
func (s *Service) RunDowntimeCycle(ctx context.Context) error {
	now := s.now()
	var broadcasts []pendingBroadcast
	err := s.tx(ctx, func(tx pgx.Tx) error {
		broadcasts = broadcasts[:0]
		sensors, err := store.ListSensors(ctx, tx, nil, nil)
		if err != nil {
			return err
		}
		for i := range sensors {
			sensor := &sensors[i]
			b, err := s.processOffline(ctx, tx, sensor, now)
			if err != nil {
				return err
			}
			if b != nil {
				broadcasts = append(broadcasts, *b)
			}
			if err := s.processIdle(ctx, tx, sensor, now); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return err
	}
	for _, b := range broadcasts {
		s.Hub.BroadcastSensorStatus(b.sensorID, b.status, b.lastSeen)
	}
	return nil
}

func (s *Service) processOffline(ctx context.Context, tx pgx.Tx, sensor *models.Sensor, now time.Time) (*pendingBroadcast, error) {
	online := s.IsSensorOnline(sensor, now)
	open, err := store.GetOpenEvent(ctx, tx, sensor.ID, models.DowntimeOffline)
	if err != nil {
		return nil, err
	}
	var b *pendingBroadcast
	if !online {
		if sensor.Status != models.StatusOffline {
			if err := store.SetSensorStatus(ctx, tx, sensor.ID, models.StatusOffline); err != nil {
				return nil, err
			}
			b = &pendingBroadcast{sensor.ID, models.StatusOffline, sensor.LastSeen}
		}
		if open == nil {
			startedAt := now
			if sensor.LastSeen != nil {
				startedAt = *sensor.LastSeen
			}
			if _, err := store.CreateEvent(ctx, tx, sensor.ID, models.DowntimeOffline, startedAt); err != nil {
				return nil, err
			}
			if err := s.notifyDowntimeEvent(ctx, tx, sensor, models.DowntimeOffline, startedAt); err != nil {
				return nil, err
			}
			s.Log.Info("Sensor offline, downtime event opened", "sensor", sensor.Name)
		}
		return b, nil
	}
	if sensor.Status != models.StatusOnline {
		if err := store.SetSensorStatus(ctx, tx, sensor.ID, models.StatusOnline); err != nil {
			return nil, err
		}
		b = &pendingBroadcast{sensor.ID, models.StatusOnline, sensor.LastSeen}
	}
	if open != nil {
		if err := store.CloseEvent(ctx, tx, open.ID, now); err != nil {
			return nil, err
		}
		s.Log.Info("Sensor online, offline event closed", "sensor", sensor.Name)
	}
	return b, nil
}

func (s *Service) processIdle(ctx context.Context, tx pgx.Tx, sensor *models.Sensor, now time.Time) error {
	if !s.IsSensorOnline(sensor, now) {
		s.clearIdlePending(sensor.ID)
		return nil
	}
	limit := s.Cfg.DowntimeSmoothingSamples
	if limit < 3 {
		limit = 3
	}
	readings, err := store.RecentReadings(ctx, tx, sensor.ID, limit)
	if err != nil {
		return err
	}
	if len(readings) == 0 {
		return nil
	}
	open, err := store.GetOpenEvent(ctx, tx, sensor.ID, models.DowntimeIdle)
	if err != nil {
		return err
	}
	if s.IsIdleState(sensor, readings) {
		pending, ok := s.idlePending(sensor.ID)
		if !ok {
			s.setIdlePending(sensor.ID, now)
			return nil
		}
		if now.Sub(pending).Seconds() < float64(s.idleDuration(sensor)) {
			return nil
		}
		if open == nil {
			if _, err := store.CreateEvent(ctx, tx, sensor.ID, models.DowntimeIdle, pending); err != nil {
				return err
			}
			if err := s.notifyDowntimeEvent(ctx, tx, sensor, models.DowntimeIdle, pending); err != nil {
				return err
			}
			s.Log.Info("Sensor idle, downtime event opened", "sensor", sensor.Name)
		}
		return nil
	}
	s.clearIdlePending(sensor.ID)
	if open != nil {
		if err := store.CloseEvent(ctx, tx, open.ID, now); err != nil {
			return err
		}
		s.Log.Info("Sensor active, idle event closed", "sensor", sensor.Name)
	}
	return nil
}

// MarkStaleSensorsOffline is the offline watchdog step: flip sensors not seen
// for SENSOR_OFFLINE_THRESHOLD_SECONDS and broadcast (last_seen = null).
func (s *Service) MarkStaleSensorsOffline(ctx context.Context) (int, error) {
	threshold := s.now().Add(-time.Duration(s.Cfg.SensorOfflineThresholdSeconds) * time.Second)
	ids, err := store.MarkStaleOffline(ctx, s.Pool, threshold)
	if err != nil {
		return 0, err
	}
	for _, id := range ids {
		s.Hub.BroadcastSensorStatus(id, models.StatusOffline, nil)
	}
	return len(ids), nil
}

// RunDowntimeWorker loops until ctx is cancelled.
func (s *Service) RunDowntimeWorker(ctx context.Context) {
	interval := time.Duration(s.Cfg.DowntimeWorkerIntervalSeconds) * time.Second
	for {
		if err := s.RunDowntimeCycle(ctx); err != nil && ctx.Err() == nil {
			s.Log.Error("Downtime worker failed", "error", err)
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(interval):
		}
	}
}

// RunOfflineWatchdog loops until ctx is cancelled.
func (s *Service) RunOfflineWatchdog(ctx context.Context) {
	interval := time.Duration(s.Cfg.SensorOfflineCheckIntervalSeconds) * time.Second
	for {
		n, err := s.MarkStaleSensorsOffline(ctx)
		if err != nil && ctx.Err() == nil {
			s.Log.Error("Offline watchdog failed", "error", err)
		} else if n > 0 {
			s.Log.Info("Marked sensor(s) offline (no telemetry)", "count", n)
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(interval):
		}
	}
}
