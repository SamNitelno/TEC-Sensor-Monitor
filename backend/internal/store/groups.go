package store

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/db"
	"tek-sensor-monitor/backend/internal/models"
)

const workshopCols = `id, name, color, notifications_enabled, created_at`

func scanWorkshop(row pgx.Row) (*models.Workshop, error) {
	var w models.Workshop
	err := row.Scan(&w.ID, &w.Name, &w.Color, &w.NotificationsEnabled, &w.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &w, nil
}

func ListWorkshops(ctx context.Context, q db.DBTX) ([]models.Workshop, error) {
	rows, err := q.Query(ctx, `SELECT `+workshopCols+` FROM workshops ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Workshop
	for rows.Next() {
		w, err := scanWorkshop(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *w)
	}
	return out, rows.Err()
}

func GetWorkshop(ctx context.Context, q db.DBTX, id int64) (*models.Workshop, error) {
	return scanWorkshop(q.QueryRow(ctx, `SELECT `+workshopCols+` FROM workshops WHERE id = $1`, id))
}

func CreateWorkshop(ctx context.Context, q db.DBTX, name string, color *string) (*models.Workshop, error) {
	return scanWorkshop(q.QueryRow(ctx,
		`INSERT INTO workshops (name, color) VALUES ($1, $2) RETURNING `+workshopCols, name, color))
}

func SaveWorkshop(ctx context.Context, q db.DBTX, w *models.Workshop) error {
	_, err := q.Exec(ctx, `UPDATE workshops SET name = $2, color = $3, notifications_enabled = $4 WHERE id = $1`,
		w.ID, w.Name, w.Color, w.NotificationsEnabled)
	return err
}

func SetAllWorkshopsNotifications(ctx context.Context, q db.DBTX, enabled bool) error {
	_, err := q.Exec(ctx, `UPDATE workshops SET notifications_enabled = $1`, enabled)
	return err
}

func CountWorkshopSites(ctx context.Context, q db.DBTX, workshopID int64) (int64, error) {
	var n int64
	err := q.QueryRow(ctx, `SELECT count(*) FROM sites WHERE workshop_id = $1`, workshopID).Scan(&n)
	return n, err
}

func DeleteWorkshop(ctx context.Context, q db.DBTX, id int64) error {
	_, err := q.Exec(ctx, `DELETE FROM workshops WHERE id = $1`, id)
	return err
}

const siteCols = `id, name, workshop_id, color, notifications_enabled, created_at`

func scanSite(row pgx.Row) (*models.Site, error) {
	var s models.Site
	err := row.Scan(&s.ID, &s.Name, &s.WorkshopID, &s.Color, &s.NotificationsEnabled, &s.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func ListSites(ctx context.Context, q db.DBTX, workshopID *int64) ([]models.Site, error) {
	var rows pgx.Rows
	var err error
	if workshopID != nil {
		rows, err = q.Query(ctx, `SELECT `+siteCols+` FROM sites WHERE workshop_id = $1 ORDER BY id`, *workshopID)
	} else {
		rows, err = q.Query(ctx, `SELECT `+siteCols+` FROM sites ORDER BY id`)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Site
	for rows.Next() {
		s, err := scanSite(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *s)
	}
	return out, rows.Err()
}

func GetSite(ctx context.Context, q db.DBTX, id int64) (*models.Site, error) {
	return scanSite(q.QueryRow(ctx, `SELECT `+siteCols+` FROM sites WHERE id = $1`, id))
}

func CreateSite(ctx context.Context, q db.DBTX, name string, workshopID int64, color *string) (*models.Site, error) {
	return scanSite(q.QueryRow(ctx,
		`INSERT INTO sites (name, workshop_id, color) VALUES ($1, $2, $3) RETURNING `+siteCols, name, workshopID, color))
}

func SaveSite(ctx context.Context, q db.DBTX, s *models.Site) error {
	_, err := q.Exec(ctx, `UPDATE sites SET name = $2, workshop_id = $3, color = $4, notifications_enabled = $5 WHERE id = $1`,
		s.ID, s.Name, s.WorkshopID, s.Color, s.NotificationsEnabled)
	return err
}

func SetSitesNotifications(ctx context.Context, q db.DBTX, workshopID *int64, enabled bool) error {
	var err error
	if workshopID != nil {
		_, err = q.Exec(ctx, `UPDATE sites SET notifications_enabled = $2 WHERE workshop_id = $1`, *workshopID, enabled)
	} else {
		_, err = q.Exec(ctx, `UPDATE sites SET notifications_enabled = $1`, enabled)
	}
	return err
}

// DeleteSite detaches sensors and placement history, then deletes the site.
// (The ORM nulled sensors.site_id; history rows are nulled too so the FK on
// sensor_placement_history.site_id no longer turns this into a 500.)
func DeleteSite(ctx context.Context, q db.DBTX, id int64) error {
	for _, stmt := range []string{
		`UPDATE sensors SET site_id = NULL WHERE site_id = $1`,
		`UPDATE sensor_placement_history SET site_id = NULL WHERE site_id = $1`,
		`DELETE FROM sites WHERE id = $1`,
	} {
		if _, err := q.Exec(ctx, stmt, id); err != nil {
			return err
		}
	}
	return nil
}

// RecordPlacement appends to sensor_placement_history.
func RecordPlacement(ctx context.Context, q db.DBTX, sensorID int64, siteID, assignedBy *int64) error {
	_, err := q.Exec(ctx, `INSERT INTO sensor_placement_history (sensor_id, site_id, assigned_by_user_id) VALUES ($1, $2, $3)`,
		sensorID, siteID, assignedBy)
	return err
}

// ListPlacements returns the history for a sensor, newest first.
func ListPlacements(ctx context.Context, q db.DBTX, sensorID int64) ([]models.SensorPlacement, error) {
	rows, err := q.Query(ctx, `SELECT h.site_id, st.name, st.workshop_id, w.name, h.assigned_at, u.login
		FROM sensor_placement_history h
		LEFT JOIN sites st ON h.site_id = st.id
		LEFT JOIN workshops w ON st.workshop_id = w.id
		LEFT JOIN users u ON h.assigned_by_user_id = u.id
		WHERE h.sensor_id = $1
		ORDER BY h.assigned_at DESC, h.id DESC`, sensorID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.SensorPlacement
	for rows.Next() {
		var p models.SensorPlacement
		if err := rows.Scan(&p.SiteID, &p.SiteName, &p.WorkshopID, &p.WorkshopName, &p.AssignedAt, &p.AssignedByLogin); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}
