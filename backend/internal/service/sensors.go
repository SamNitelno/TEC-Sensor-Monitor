package service

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/apperr"
	"tek-sensor-monitor/backend/internal/jsonx"
	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/security"
	"tek-sensor-monitor/backend/internal/store"
)

const (
	createTokenWarning = "Токен устройства показывается только один раз. Сохраните его сейчас — " +
		"повторно получить через API нельзя."
	rotateTokenWarning = "Новый токен устройства. Сохраните его сейчас — предыдущий токен больше не действует. " +
		"Обновите прошивку или BLE-привязку."
	provisioningMessage = "Токен устройства недоступен после создания. " +
		"Для BLE-привязки используйте POST /sensors/{id}/rotate-token."
)

func (s *Service) toSensorItem(sensor *models.Sensor, now time.Time) SensorItem {
	return SensorItem{
		ID:                    sensor.ID,
		Name:                  sensor.Name,
		DeviceID:              sensor.DeviceID,
		SiteID:                sensor.SiteID,
		Status:                s.effectiveStatus(sensor, now),
		LastSeen:              jsonx.NewTimePtr(sensor.LastSeen),
		Color:                 sensor.Color,
		IdlePowerThresholdW:   jsonx.FloatPtr(sensor.IdlePowerThresholdW),
		IdleCurrentThresholdA: jsonx.FloatPtr(sensor.IdleCurrentThresholdA),
		IdleDurationSeconds:   sensor.IdleDurationSeconds,
		NotificationsEnabled:  sensor.NotificationsEnabled,
		CreatedAt:             jsonx.NewTime(sensor.CreatedAt),
	}
}

func (s *Service) ListSensors(ctx context.Context, siteID, workshopID *int64) ([]SensorItem, error) {
	sensors, err := store.ListSensors(ctx, s.Pool, siteID, workshopID)
	if err != nil {
		return nil, err
	}
	now := s.now()
	out := make([]SensorItem, 0, len(sensors))
	for i := range sensors {
		out = append(out, s.toSensorItem(&sensors[i], now))
	}
	return out, nil
}

func (s *Service) getSensor(ctx context.Context, q store.Querier, id int64) (*models.Sensor, error) {
	sensor, err := store.GetSensorByID(ctx, q, id)
	if err != nil {
		return nil, err
	}
	if sensor == nil {
		return nil, apperr.NotFound("Sensor not found")
	}
	return sensor, nil
}

func (s *Service) GetSensor(ctx context.Context, id int64) (*SensorItem, error) {
	sensor, err := s.getSensor(ctx, s.Pool, id)
	if err != nil {
		return nil, err
	}
	item := s.toSensorItem(sensor, s.now())
	return &item, nil
}

func (s *Service) integrationSnippet(token string) IntegrationSnippet {
	url := s.Cfg.IngestURL()
	return IntegrationSnippet{
		Method: "POST",
		URL:    url,
		Headers: orderedStrings{
			{"Content-Type", "application/json"},
			{"X-Device-Token", token},
		},
		BodySchema: orderedStrings{
			{"current_a", "float A RMS (required)"},
			{"power_w", "float W (optional)"},
			{"ts", "ISO8601 string (optional)"},
		},
		BodyExample: orderedFloatPairs{{"current_a", 4.25}, {"power_w", 980.0}},
		Curl: `curl -X POST "` + url + `" \` + "\n" +
			`  -H "Content-Type: application/json" \` + "\n" +
			`  -H "X-Device-Token: ` + token + `" \` + "\n" +
			`  -d '{"current_a": 4.25, "power_w": 980.0}'`,
	}
}

type SensorCreateRequest struct {
	Name     string
	DeviceID string
	SiteID   *int64
	Color    *string
}

func (s *Service) CreateSensor(ctx context.Context, actor *models.User, req SensorCreateRequest) (*SensorCreateResponse, error) {
	token := security.TokenURLSafe(32)
	var sensor *models.Sensor
	err := s.tx(ctx, func(tx pgx.Tx) error {
		existing, err := store.GetSensorByDeviceID(ctx, tx, req.DeviceID)
		if err != nil {
			return err
		}
		if existing != nil {
			return apperr.Conflict("device_id already exists")
		}
		if req.SiteID != nil {
			site, err := store.GetSite(ctx, tx, *req.SiteID)
			if err != nil {
				return err
			}
			if site == nil {
				return apperr.NotFound("Site not found")
			}
		}
		var createdBy *int64
		if actor != nil {
			id := actor.ID
			createdBy = &id
		}
		sensor, err = store.CreateSensor(ctx, tx, store.NewSensor{
			Name: req.Name, DeviceID: req.DeviceID, StoredToken: security.HashDeviceToken(token, s.Cfg.JWTSecret),
			SiteID: req.SiteID, Color: req.Color, CreatedByUserID: createdBy,
		})
		if err != nil {
			if isUniqueViolation(err) {
				return apperr.Conflict("device_id already exists")
			}
			return err
		}
		return store.RecordPlacement(ctx, tx, sensor.ID, req.SiteID, createdBy)
	})
	if err != nil {
		return nil, err
	}
	return &SensorCreateResponse{
		Sensor:      s.toSensorItem(sensor, s.now()),
		APIToken:    token,
		Warning:     createTokenWarning,
		Integration: s.integrationSnippet(token),
	}, nil
}

// SensorUpdateRequest: SiteIDSet distinguishes an explicit "site_id": null
// (clear the site) from an absent key (keep it).
type SensorUpdateRequest struct {
	Name                      *string
	SiteIDSet                 bool
	SiteID                    *int64
	Color                     *string
	ClearColor                bool
	IdlePowerThresholdW       *float64
	ClearIdlePowerThreshold   bool
	IdleCurrentThresholdA     *float64
	ClearIdleCurrentThreshold bool
	IdleDurationSeconds       *int64
	ClearIdleDuration         bool
	NotificationsEnabled      *bool
}

func (s *Service) UpdateSensor(ctx context.Context, actor *models.User, id int64, req SensorUpdateRequest) (*SensorItem, error) {
	var sensor *models.Sensor
	err := s.tx(ctx, func(tx pgx.Tx) error {
		var err error
		sensor, err = s.getSensor(ctx, tx, id)
		if err != nil {
			return err
		}
		if req.SiteIDSet && req.SiteID != nil {
			site, err := store.GetSite(ctx, tx, *req.SiteID)
			if err != nil {
				return err
			}
			if site == nil {
				return apperr.NotFound("Site not found")
			}
		}
		oldSite := sensor.SiteID
		if req.Name != nil {
			sensor.Name = *req.Name
		}
		if req.SiteIDSet {
			sensor.SiteID = req.SiteID
		}
		if req.ClearColor {
			sensor.Color = nil
		} else if req.Color != nil {
			sensor.Color = req.Color
		}
		if req.ClearIdlePowerThreshold {
			sensor.IdlePowerThresholdW = nil
		} else if req.IdlePowerThresholdW != nil {
			sensor.IdlePowerThresholdW = req.IdlePowerThresholdW
		}
		if req.ClearIdleCurrentThreshold {
			sensor.IdleCurrentThresholdA = nil
		} else if req.IdleCurrentThresholdA != nil {
			sensor.IdleCurrentThresholdA = req.IdleCurrentThresholdA
		}
		if req.ClearIdleDuration {
			sensor.IdleDurationSeconds = nil
		} else if req.IdleDurationSeconds != nil {
			sensor.IdleDurationSeconds = req.IdleDurationSeconds
		}
		if req.NotificationsEnabled != nil {
			sensor.NotificationsEnabled = *req.NotificationsEnabled
		}
		if err := store.SaveSensor(ctx, tx, sensor); err != nil {
			return err
		}
		if req.SiteIDSet && !sameID(oldSite, sensor.SiteID) {
			var assignedBy *int64
			if actor != nil {
				aid := actor.ID
				assignedBy = &aid
			}
			return store.RecordPlacement(ctx, tx, sensor.ID, sensor.SiteID, assignedBy)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	item := s.toSensorItem(sensor, s.now())
	return &item, nil
}

func sameID(a, b *int64) bool {
	if a == nil || b == nil {
		return a == nil && b == nil
	}
	return *a == *b
}

func (s *Service) DeleteSensor(ctx context.Context, id int64) error {
	return s.tx(ctx, func(tx pgx.Tx) error {
		if _, err := s.getSensor(ctx, tx, id); err != nil {
			return err
		}
		return store.DeleteSensor(ctx, tx, id)
	})
}

func (s *Service) SensorAudit(ctx context.Context, id int64) (*SensorAuditInfo, error) {
	scopes, err := store.ListSensorScopes(ctx, s.Pool, []int64{id}, nil, nil)
	if err != nil {
		return nil, err
	}
	if len(scopes) == 0 {
		return nil, apperr.NotFound("Sensor not found")
	}
	sc := scopes[0]
	var createdBy *string
	if sc.Sensor.CreatedByUserID != nil {
		u, err := store.GetUserByID(ctx, s.Pool, *sc.Sensor.CreatedByUserID)
		if err != nil {
			return nil, err
		}
		if u != nil {
			createdBy = &u.Login
		}
	}
	history, err := store.ListPlacements(ctx, s.Pool, id)
	if err != nil {
		return nil, err
	}
	records := make([]SensorPlacementRecord, 0, len(history))
	for _, h := range history {
		records = append(records, SensorPlacementRecord{
			SiteID: h.SiteID, SiteName: h.SiteName, WorkshopID: h.WorkshopID, WorkshopName: h.WorkshopName,
			AssignedAt: jsonx.NewTime(h.AssignedAt), AssignedByLogin: h.AssignedByLogin,
		})
	}
	return &SensorAuditInfo{
		ID: sc.Sensor.ID, Name: sc.Sensor.Name, DeviceID: sc.Sensor.DeviceID,
		CreatedAt: jsonx.NewTime(sc.Sensor.CreatedAt), CreatedByLogin: createdBy,
		CurrentSiteID: sc.Sensor.SiteID, CurrentSiteName: sc.SiteName,
		CurrentWorkshopID: sc.WorkshopID, CurrentWorkshopName: sc.WorkshopName,
		Color: sc.Sensor.Color, PlacementHistory: records,
	}, nil
}

func (s *Service) SetAllSensorNotifications(ctx context.Context, enabled bool) (*BulkNotificationsResponse, error) {
	n, err := store.SetAllSensorsNotifications(ctx, s.Pool, enabled)
	if err != nil {
		return nil, err
	}
	return &BulkNotificationsResponse{Updated: n}, nil
}

func (s *Service) ProvisioningToken(ctx context.Context, id int64) (*ProvisioningTokenResponse, error) {
	if _, err := s.getSensor(ctx, s.Pool, id); err != nil {
		return nil, err
	}
	msg := provisioningMessage
	return &ProvisioningTokenResponse{IngestURL: s.Cfg.IngestURL(), APIToken: nil, Message: &msg}, nil
}

func (s *Service) RotateToken(ctx context.Context, id int64) (*RotateTokenResponse, error) {
	if _, err := s.getSensor(ctx, s.Pool, id); err != nil {
		return nil, err
	}
	token := security.TokenURLSafe(32)
	if err := store.UpdateSensorToken(ctx, s.Pool, id, security.HashDeviceToken(token, s.Cfg.JWTSecret)); err != nil {
		return nil, err
	}
	return &RotateTokenResponse{APIToken: token, IngestURL: s.Cfg.IngestURL(), Warning: rotateTokenWarning}, nil
}
