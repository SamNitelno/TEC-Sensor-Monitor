package store

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/db"
	"tek-sensor-monitor/backend/internal/models"
)

const upsertReadingSQL = `INSERT INTO readings (time, sensor_id, current_a, power_w)
	VALUES ($1, $2, $3, $4)
	ON CONFLICT (time, sensor_id) DO UPDATE
	SET current_a = EXCLUDED.current_a, power_w = EXCLUDED.power_w`

// UpsertReadings inserts (or overwrites on duplicate timestamp) readings in a
// single round-trip; returns the number of rows sent.
func UpsertReadings(ctx context.Context, q db.DBTX, rows []models.Reading) (int, error) {
	if len(rows) == 0 {
		return 0, nil
	}
	batch := &pgx.Batch{}
	for _, r := range rows {
		batch.Queue(upsertReadingSQL, r.Time, r.SensorID, r.CurrentA, r.PowerW)
	}
	br := q.SendBatch(ctx, batch)
	for range rows {
		if _, err := br.Exec(); err != nil {
			_ = br.Close()
			return 0, err
		}
	}
	return len(rows), br.Close()
}

func DeleteReadingsForSensors(ctx context.Context, q db.DBTX, ids []int64) error {
	if len(ids) == 0 {
		return nil
	}
	_, err := q.Exec(ctx, `DELETE FROM readings WHERE sensor_id = ANY($1)`, ids)
	return err
}

// RecentReadings returns the latest `limit` readings in ascending time order.
func RecentReadings(ctx context.Context, q db.DBTX, sensorID int64, limit int) ([]models.Reading, error) {
	rows, err := q.Query(ctx, `SELECT time, sensor_id, current_a, power_w FROM readings
		WHERE sensor_id = $1 ORDER BY time DESC LIMIT $2`, sensorID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Reading
	for rows.Next() {
		var r models.Reading
		if err := rows.Scan(&r.Time, &r.SensorID, &r.CurrentA, &r.PowerW); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	for i, j := 0, len(out)-1; i < j; i, j = i+1, j-1 {
		out[i], out[j] = out[j], out[i]
	}
	return out, nil
}

// ReadingPoint is one chart point (raw or aggregated).
type ReadingPoint struct {
	Time   time.Time
	Avg    float64
	Min    float64
	Max    float64
	PowerW *float64
}

// MaxPoints caps every readings query.
const MaxPoints = 2000

var aggregateViews = map[string]string{
	"minute": "readings_minute",
	"hour":   "readings_hour",
	"day":    "readings_day",
}

// FetchReadings returns up to MaxPoints points for a sensor and bucket.
func FetchReadings(ctx context.Context, q db.DBTX, sensorID int64, from, to time.Time, bucket string) ([]ReadingPoint, error) {
	var sql string
	if bucket == "raw" {
		sql = `SELECT time, current_a, current_a, current_a, power_w
			FROM readings
			WHERE sensor_id = $1 AND time >= $2 AND time <= $3
			ORDER BY time ASC LIMIT $4`
	} else {
		view, ok := aggregateViews[bucket]
		if !ok {
			return nil, fmt.Errorf("unknown bucket %q", bucket)
		}
		sql = `SELECT bucket, avg_current_a, min_current_a, max_current_a, avg_power_w
			FROM ` + view + `
			WHERE sensor_id = $1 AND bucket >= $2 AND bucket <= $3
			ORDER BY bucket ASC LIMIT $4`
	}
	rows, err := q.Query(ctx, sql, sensorID, from, to, MaxPoints)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []ReadingPoint{}
	for rows.Next() {
		var p ReadingPoint
		if err := rows.Scan(&p.Time, &p.Avg, &p.Min, &p.Max, &p.PowerW); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// RefreshContinuousAggregates refreshes all chart views (must run outside a
// transaction).
func RefreshContinuousAggregates(ctx context.Context, q db.DBTX) error {
	for _, view := range []string{"readings_minute", "readings_hour", "readings_day"} {
		if _, err := q.Exec(ctx, fmt.Sprintf("CALL refresh_continuous_aggregate('%s', NULL, NULL)", view)); err != nil {
			return err
		}
	}
	return nil
}
