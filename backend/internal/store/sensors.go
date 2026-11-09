package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/db"
	"tek-sensor-monitor/backend/internal/models"
)

const sensorCols = `s.id, s.name, s.device_id, s.api_token, s.site_id, s.status::text, s.last_seen,
	s.created_at, s.color, s.created_by_user_id, s.idle_power_threshold_w,
	s.idle_current_threshold_a, s.idle_duration_seconds, s.notifications_enabled`

func scanSensor(row pgx.Row) (*models.Sensor, error) {
	var s models.Sensor
	err := row.Scan(&s.ID, &s.Name, &s.DeviceID, &s.APIToken, &s.SiteID, &s.Status, &s.LastSeen,
		&s.CreatedAt, &s.Color, &s.CreatedByUserID, &s.IdlePowerThresholdW,
		&s.IdleCurrentThresholdA, &s.IdleDurationSeconds, &s.NotificationsEnabled)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func collectSensors(rows pgx.Rows, err error) ([]models.Sensor, error) {
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Sensor
	for rows.Next() {
		s, err := scanSensor(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *s)
	}
	return out, rows.Err()
}

// ListSensors filters by site (preferred) or workshop, ordered by id.
func ListSensors(ctx context.Context, q db.DBTX, siteID, workshopID *int64) ([]models.Sensor, error) {
	switch {
	case siteID != nil:
		return collectSensors(q.Query(ctx, `SELECT `+sensorCols+` FROM sensors s WHERE s.site_id = $1 ORDER BY s.id`, *siteID))
	case workshopID != nil:
		return collectSensors(q.Query(ctx, `SELECT `+sensorCols+` FROM sensors s
			JOIN sites st ON s.site_id = st.id WHERE st.workshop_id = $1 ORDER BY s.id`, *workshopID))
	default:
		return collectSensors(q.Query(ctx, `SELECT `+sensorCols+` FROM sensors s ORDER BY s.id`))
	}
}

func GetSensorByID(ctx context.Context, q db.DBTX, id int64) (*models.Sensor, error) {
	return scanSensor(q.QueryRow(ctx, `SELECT `+sensorCols+` FROM sensors s WHERE s.id = $1`, id))
}

func GetSensorByDeviceID(ctx context.Context, q db.DBTX, deviceID string) (*models.Sensor, error) {
	return scanSensor(q.QueryRow(ctx, `SELECT `+sensorCols+` FROM sensors s WHERE s.device_id = $1`, deviceID))
}

func GetSensorByStoredToken(ctx context.Context, q db.DBTX, stored string) (*models.Sensor, error) {
	return scanSensor(q.QueryRow(ctx, `SELECT `+sensorCols+` FROM sensors s WHERE s.api_token = $1`, stored))
}

// ListSensorsWithLegacyTokens returns sensors whose token is not a sha256 hex
// digest (pre-hashing rows).
func ListSensorsWithLegacyTokens(ctx context.Context, q db.DBTX) ([]models.Sensor, error) {
	return collectSensors(q.Query(ctx, `SELECT `+sensorCols+` FROM sensors s WHERE s.api_token !~ '^[0-9a-f]{64}$' ORDER BY s.id`))
}

// GetSensorsByIDs keeps the order of ids given (unknown ids are skipped).
func GetSensorsByIDs(ctx context.Context, q db.DBTX, ids []int64) ([]models.Sensor, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	all, err := collectSensors(q.Query(ctx, `SELECT `+sensorCols+` FROM sensors s WHERE s.id = ANY($1) ORDER BY s.id`, ids))
	if err != nil {
		return nil, err
	}
	return all, nil
}

func ListSensorsByNames(ctx context.Context, q db.DBTX, names []string) ([]models.Sensor, error) {
	return collectSensors(q.Query(ctx, `SELECT `+sensorCols+` FROM sensors s WHERE s.name = ANY($1) ORDER BY s.id`, names))
}

type NewSensor struct {
	Name            string
	DeviceID        string
	StoredToken     string
	SiteID          *int64
	Color           *string
	CreatedByUserID *int64
}

func CreateSensor(ctx context.Context, q db.DBTX, n NewSensor) (*models.Sensor, error) {
	return scanSensor(q.QueryRow(ctx, `INSERT INTO sensors AS s (name, device_id, api_token, site_id, color, created_by_user_id)
		VALUES ($1, $2, $3, $4, $5, $6) RETURNING `+sensorCols,
		n.Name, n.DeviceID, n.StoredToken, n.SiteID, n.Color, n.CreatedByUserID))
}

func UpdateSensorToken(ctx context.Context, q db.DBTX, id int64, stored string) error {
	_, err := q.Exec(ctx, `UPDATE sensors SET api_token = $2 WHERE id = $1`, id, stored)
	return err
}

// SaveSensor writes all mutable columns of a sensor row.
func SaveSensor(ctx context.Context, q db.DBTX, s *models.Sensor) error {
	_, err := q.Exec(ctx, `UPDATE sensors SET name = $2, site_id = $3, color = $4,
		idle_power_threshold_w = $5, idle_current_threshold_a = $6, idle_duration_seconds = $7,
		notifications_enabled = $8 WHERE id = $1`,
		s.ID, s.Name, s.SiteID, s.Color, s.IdlePowerThresholdW, s.IdleCurrentThresholdA,
		s.IdleDurationSeconds, s.NotificationsEnabled)
	return err
}

func SetAllSensorsNotifications(ctx context.Context, q db.DBTX, enabled bool) (int64, error) {
	tag, err := q.Exec(ctx, `UPDATE sensors SET notifications_enabled = $1`, enabled)
	return tag.RowsAffected(), err
}

func SetSiteSensorsNotifications(ctx context.Context, q db.DBTX, siteID int64, enabled bool) error {
	_, err := q.Exec(ctx, `UPDATE sensors SET notifications_enabled = $2 WHERE site_id = $1`, siteID, enabled)
	return err
}

func SetWorkshopSensorsNotifications(ctx context.Context, q db.DBTX, workshopID int64, enabled bool) error {
	_, err := q.Exec(ctx, `UPDATE sensors SET notifications_enabled = $2
		WHERE site_id IN (SELECT id FROM sites WHERE workshop_id = $1)`, workshopID, enabled)
	return err
}

// DeleteSensor removes dependants explicitly, then the sensor row.
func DeleteSensor(ctx context.Context, q db.DBTX, id int64) error {
	for _, stmt := range []string{
		`DELETE FROM readings WHERE sensor_id = $1`,
		`DELETE FROM downtime_events WHERE sensor_id = $1`,
		`DELETE FROM sensor_placement_history WHERE sensor_id = $1`,
		`DELETE FROM sensors WHERE id = $1`,
	} {
		if _, err := q.Exec(ctx, stmt, id); err != nil {
			return err
		}
	}
	return nil
}

// UpdateLastSeen also flips the stored status to online.
func UpdateLastSeen(ctx context.Context, q db.DBTX, id int64, at time.Time) error {
	_, err := q.Exec(ctx, `UPDATE sensors SET last_seen = $2, status = 'online' WHERE id = $1`, id, at)
	return err
}

// MarkStaleOffline flips online sensors not seen since olderThan; returns ids.
func MarkStaleOffline(ctx context.Context, q db.DBTX, olderThan time.Time) ([]int64, error) {
	rows, err := q.Query(ctx, `UPDATE sensors SET status = 'offline'
		WHERE status = 'online' AND last_seen IS NOT NULL AND last_seen < $1 RETURNING id`, olderThan)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowTo[int64])
}

func SetSensorStatus(ctx context.Context, q db.DBTX, id int64, status string) error {
	_, err := q.Exec(ctx, `UPDATE sensors SET status = $2::text::sensor_status WHERE id = $1`, id, status)
	return err
}

// ListSensorScopes returns sensors (with site/workshop names) filtered like
// downtime_repository.list_sensors_for_scope, ordered by id.
func ListSensorScopes(ctx context.Context, q db.DBTX, sensorIDs []int64, siteID, workshopID *int64) ([]models.SensorScope, error) {
	sql := `SELECT ` + sensorCols + `, st.id, st.name, w.id, w.name
		FROM sensors s
		LEFT JOIN sites st ON s.site_id = st.id
		LEFT JOIN workshops w ON st.workshop_id = w.id
		WHERE ($1::int[] IS NULL OR s.id = ANY($1))
		  AND ($2::int IS NULL OR s.site_id = $2)
		  AND ($3::int IS NULL OR st.workshop_id = $3)
		ORDER BY s.id`
	var ids any
	if len(sensorIDs) > 0 {
		ids = sensorIDs
	}
	rows, err := q.Query(ctx, sql, ids, siteID, workshopID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.SensorScope
	for rows.Next() {
		var sc models.SensorScope
		s := &sc.Sensor
		if err := rows.Scan(&s.ID, &s.Name, &s.DeviceID, &s.APIToken, &s.SiteID, &s.Status, &s.LastSeen,
			&s.CreatedAt, &s.Color, &s.CreatedByUserID, &s.IdlePowerThresholdW,
			&s.IdleCurrentThresholdA, &s.IdleDurationSeconds, &s.NotificationsEnabled,
			&sc.SiteID, &sc.SiteName, &sc.WorkshopID, &sc.WorkshopName); err != nil {
			return nil, err
		}
		out = append(out, sc)
	}
	return out, rows.Err()
}

// WorkshopNameForSite resolves site -> workshop name (nil when missing).
func WorkshopNameForSite(ctx context.Context, q db.DBTX, siteID int64) (*string, error) {
	var name *string
	err := q.QueryRow(ctx, `SELECT w.name FROM sites st JOIN workshops w ON st.workshop_id = w.id WHERE st.id = $1`, siteID).Scan(&name)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return name, err
}
