package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/db"
	"tek-sensor-monitor/backend/internal/models"
)

const eventCols = `e.id, e.sensor_id, e.type::text, e.started_at, e.ended_at`

func scanEvent(row pgx.Row) (*models.DowntimeEvent, error) {
	var e models.DowntimeEvent
	err := row.Scan(&e.ID, &e.SensorID, &e.Type, &e.StartedAt, &e.EndedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &e, nil
}

// GetOpenEvent returns the most recently started open event of a type.
func GetOpenEvent(ctx context.Context, q db.DBTX, sensorID int64, typ string) (*models.DowntimeEvent, error) {
	return scanEvent(q.QueryRow(ctx, `SELECT `+eventCols+` FROM downtime_events e
		WHERE e.sensor_id = $1 AND e.type = $2::text::downtime_type AND e.ended_at IS NULL
		ORDER BY e.started_at DESC LIMIT 1`, sensorID, typ))
}

// CloseOpenEvents sets ended_at on every open event of the type.
func CloseOpenEvents(ctx context.Context, q db.DBTX, sensorID int64, typ string, endedAt time.Time) (int64, error) {
	tag, err := q.Exec(ctx, `UPDATE downtime_events SET ended_at = $3
		WHERE sensor_id = $1 AND type = $2::text::downtime_type AND ended_at IS NULL`, sensorID, typ, endedAt)
	return tag.RowsAffected(), err
}

func CloseEvent(ctx context.Context, q db.DBTX, eventID int64, endedAt time.Time) error {
	_, err := q.Exec(ctx, `UPDATE downtime_events SET ended_at = $2 WHERE id = $1`, eventID, endedAt)
	return err
}

func CreateEvent(ctx context.Context, q db.DBTX, sensorID int64, typ string, startedAt time.Time) (*models.DowntimeEvent, error) {
	return scanEvent(q.QueryRow(ctx, `INSERT INTO downtime_events AS e (sensor_id, type, started_at)
		VALUES ($1, $2::text::downtime_type, $3) RETURNING `+eventCols, sensorID, typ, startedAt))
}

// EventRow is an event with the sensor's current placement names.
type EventRow struct {
	Event        models.DowntimeEvent
	SensorName   string
	SiteID       *int64
	SiteName     *string
	WorkshopID   *int64
	WorkshopName *string
}

// ListEventsInRange returns events overlapping [from, to], newest first.
func ListEventsInRange(ctx context.Context, q db.DBTX, from, to time.Time, sensorIDs []int64, siteID, workshopID *int64, typ *string) ([]EventRow, error) {
	var ids any
	if len(sensorIDs) > 0 {
		ids = sensorIDs
	}
	rows, err := q.Query(ctx, `SELECT `+eventCols+`, s.name, st.id, st.name, w.id, w.name
		FROM downtime_events e
		JOIN sensors s ON e.sensor_id = s.id
		LEFT JOIN sites st ON s.site_id = st.id
		LEFT JOIN workshops w ON st.workshop_id = w.id
		WHERE e.started_at < $2
		  AND (e.ended_at IS NULL OR e.ended_at > $1)
		  AND ($3::int[] IS NULL OR e.sensor_id = ANY($3))
		  AND ($4::int IS NULL OR s.site_id = $4)
		  AND ($5::int IS NULL OR st.workshop_id = $5)
		  AND ($6::text IS NULL OR e.type::text = $6)
		ORDER BY e.started_at DESC, e.id DESC`, from, to, ids, siteID, workshopID, typ)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []EventRow
	for rows.Next() {
		var r EventRow
		e := &r.Event
		if err := rows.Scan(&e.ID, &e.SensorID, &e.Type, &e.StartedAt, &e.EndedAt,
			&r.SensorName, &r.SiteID, &r.SiteName, &r.WorkshopID, &r.WorkshopName); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}
