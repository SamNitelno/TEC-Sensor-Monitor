// Package service implements the business logic behind the HTTP API, the
// background workers and the MQTT subscriber.
package service

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"tek-sensor-monitor/backend/internal/apperr"
	"tek-sensor-monitor/backend/internal/config"
	"tek-sensor-monitor/backend/internal/db"
	"tek-sensor-monitor/backend/internal/delivery"
	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/security"
	"tek-sensor-monitor/backend/internal/store"
	"tek-sensor-monitor/backend/internal/ws"
)

// FeatureInDevelopment is returned (503) when code delivery is unavailable.
const FeatureInDevelopment = "Функция в разработке, приносим извинения"

type Service struct {
	Cfg      *config.Config
	Pool     *pgxpool.Pool
	Hub      *ws.Hub
	Delivery *delivery.Delivery
	Log      *slog.Logger

	// Now is the clock (overridable in tests).
	Now func() time.Time

	idleMu           sync.Mutex
	idlePendingSince map[int64]time.Time
}

func New(cfg *config.Config, pool *pgxpool.Pool, hub *ws.Hub, del *delivery.Delivery, log *slog.Logger) *Service {
	return &Service{
		Cfg: cfg, Pool: pool, Hub: hub, Delivery: del, Log: log,
		Now:              func() time.Time { return time.Now().UTC() },
		idlePendingSince: map[int64]time.Time{},
	}
}

func (s *Service) now() time.Time { return s.Now().UTC() }

func (s *Service) tx(ctx context.Context, fn func(tx pgx.Tx) error) error {
	return db.InTx(ctx, s.Pool, fn)
}

func (s *Service) issueToken(u *models.User) (string, error) {
	return security.CreateAccessToken(s.Cfg.JWTSecret, s.Cfg.JWTExpireMinutes, u.ID, u.Login, u.Role)
}

// ---- authentication -------------------------------------------------------

// UserFromToken validates a JWT and loads the active user (role is always
// re-read from the database).
func (s *Service) UserFromToken(ctx context.Context, token string) (*models.User, error) {
	claims, err := security.DecodeAccessToken(s.Cfg.JWTSecret, token)
	if err != nil {
		return nil, apperr.Unauthorized("Invalid or expired token")
	}
	var user *models.User
	switch {
	case claims.UID != nil:
		user, err = store.GetUserByID(ctx, s.Pool, *claims.UID)
	case claims.Subject != "":
		user, err = store.GetUserByLogin(ctx, s.Pool, claims.Subject)
	default:
		return nil, apperr.Unauthorized("Invalid token payload")
	}
	if err != nil {
		return nil, err
	}
	if user == nil || !user.IsActive {
		return nil, apperr.Unauthorized("User not found")
	}
	return user, nil
}

// SensorFromDeviceToken authenticates an ingest request.
func (s *Service) SensorFromDeviceToken(ctx context.Context, token string) (*models.Sensor, error) {
	if token == "" {
		return nil, apperr.Unauthorized("Invalid device token")
	}
	sensor, err := store.GetSensorByStoredToken(ctx, s.Pool, security.HashDeviceToken(token, s.Cfg.JWTSecret))
	if err != nil {
		return nil, err
	}
	if sensor != nil {
		return sensor, nil
	}
	// Legacy plaintext tokens stored before hashing was introduced.
	legacy, err := store.ListSensorsWithLegacyTokens(ctx, s.Pool)
	if err != nil {
		return nil, err
	}
	for i := range legacy {
		if security.ConstantTimeEqual(legacy[i].APIToken, token) {
			return &legacy[i], nil
		}
	}
	return nil, apperr.Unauthorized("Invalid device token")
}

// ---- sensor status --------------------------------------------------------

// IsSensorOnline: last_seen within SENSOR_OFFLINE_THRESHOLD_SECONDS of now.
func (s *Service) IsSensorOnline(sensor *models.Sensor, now time.Time) bool {
	if sensor.LastSeen == nil {
		return false
	}
	age := now.Sub(*sensor.LastSeen).Seconds()
	return age <= float64(s.Cfg.SensorOfflineThresholdSeconds)
}

func (s *Service) effectiveStatus(sensor *models.Sensor, now time.Time) string {
	if s.IsSensorOnline(sensor, now) {
		return models.StatusOnline
	}
	return models.StatusOffline
}
