package service

import (
	"context"
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/security"
	"tek-sensor-monitor/backend/internal/store"
	"tek-sensor-monitor/backend/internal/validate"
)

// EnsureBootstrapUsers creates or re-syncs the admin and viewer accounts from
// the environment (idempotent; existing roles are not changed).
func (s *Service) EnsureBootstrapUsers(ctx context.Context) error {
	if s.Cfg.IsProduction() {
		if err := validate.Password(s.Cfg.AdminPassword); err != nil {
			return fmt.Errorf("ADMIN_PASSWORD: %w", err)
		}
		if err := validate.Password(s.Cfg.ViewerPassword); err != nil {
			return fmt.Errorf("VIEWER_PASSWORD: %w", err)
		}
	}
	return s.tx(ctx, func(tx pgx.Tx) error {
		for _, acc := range []struct{ login, password, role string }{
			{s.Cfg.AdminLogin, s.Cfg.AdminPassword, models.RoleAdmin},
			{s.Cfg.ViewerLogin, s.Cfg.ViewerPassword, models.RoleViewer},
		} {
			user, err := store.GetUserByLogin(ctx, tx, acc.login)
			if err != nil {
				return err
			}
			if user == nil {
				hash, err := security.HashPassword(acc.password)
				if err != nil {
					return err
				}
				if _, err := store.CreateUser(ctx, tx, acc.login, hash, acc.role); err != nil {
					return err
				}
				continue
			}
			if !security.VerifyPassword(acc.password, user.PasswordHash) {
				hash, err := security.HashPassword(acc.password)
				if err != nil {
					return err
				}
				if err := store.SetUserPasswordHash(ctx, tx, user.ID, hash); err != nil {
					return err
				}
			}
		}
		return nil
	})
}

// DemoSensorNames are the sensors that receive synthetic demo readings.
var DemoSensorNames = []string{"Демо датчик 1", "Демо датчик 2", "Демо датчик 3", "Smoke Sensor"}

// roundHalfEven rounds like Python's round(x, ndigits).
func roundHalfEven(x float64, digits int) float64 {
	p := math.Pow(10, float64(digits))
	return math.RoundToEven(x*p) / p
}

// SeedDemoReadings regenerates 24 h of 5-second synthetic readings for the
// demo sensors and refreshes the continuous aggregates.
func (s *Service) SeedDemoReadings(ctx context.Context) (*DemoSeedResponse, error) {
	sensors, err := store.ListSensorsByNames(ctx, s.Pool, DemoSensorNames)
	if err != nil {
		return nil, err
	}
	resp := &DemoSeedResponse{SensorNames: []string{}}
	if len(sensors) == 0 {
		return resp, nil
	}
	sort.SliceStable(sensors, func(i, j int) bool { return sensors[i].Name < sensors[j].Name })
	ids := make([]int64, 0, len(sensors))
	for _, sn := range sensors {
		ids = append(ids, sn.ID)
	}
	now := s.now()
	const steps = 24 * 60 * 12
	err = s.tx(ctx, func(tx pgx.Tx) error {
		if err := store.DeleteReadingsForSensors(ctx, tx, ids); err != nil {
			return err
		}
		for index, sensor := range sensors {
			base := 3.5 + float64(index)*1.8
			rows := make([]models.Reading, 0, 4000)
			flush := func() error {
				n, err := store.UpsertReadings(ctx, tx, rows)
				resp.Points += n
				rows = rows[:0]
				return err
			}
			for step := 0; step < steps; step++ {
				ts := now.Add(-time.Duration(steps-1-step) * 5 * time.Second)
				t := float64(step) / 12.0
				wave := math.Sin(t/10.0+float64(index)) * 1.5
				pulse := 0.3 * math.Sin(t/2.5)
				current := math.Max(0.15, base+wave+pulse+float64(step%120)*0.002)
				power := roundHalfEven(current*230, 1)
				rows = append(rows, models.Reading{Time: ts, SensorID: sensor.ID, CurrentA: roundHalfEven(current, 3), PowerW: &power})
				if len(rows) >= 4000 {
					if err := flush(); err != nil {
						return err
					}
				}
			}
			if len(rows) > 0 {
				if err := flush(); err != nil {
					return err
				}
			}
			if err := store.UpdateLastSeen(ctx, tx, sensor.ID, now); err != nil {
				return err
			}
			resp.SensorNames = append(resp.SensorNames, sensor.Name)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	resp.Sensors = len(sensors)
	if err := store.RefreshContinuousAggregates(ctx, s.Pool); err != nil {
		s.Log.Warn("Continuous aggregate refresh failed", "error", err)
	}
	return resp, nil
}
