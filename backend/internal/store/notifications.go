package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/db"
	"tek-sensor-monitor/backend/internal/models"
)

func CreateNotification(ctx context.Context, q db.DBTX, userID int64, message, kind string, at time.Time) error {
	_, err := q.Exec(ctx, `INSERT INTO user_notifications (user_id, message, kind, created_at) VALUES ($1, $2, $3, $4)`,
		userID, message, kind, at)
	return err
}

// CreateNotificationsForUsers inserts the same message for many users.
func CreateNotificationsForUsers(ctx context.Context, q db.DBTX, userIDs []int64, message, kind string, at time.Time) error {
	if len(userIDs) == 0 {
		return nil
	}
	_, err := q.Exec(ctx, `INSERT INTO user_notifications (user_id, message, kind, created_at)
		SELECT unnest($1::int[]), $2, $3, $4`, userIDs, message, kind, at)
	return err
}

func ListUnreadNotifications(ctx context.Context, q db.DBTX, userID int64, limit int) ([]models.Notification, error) {
	rows, err := q.Query(ctx, `SELECT id, user_id, message, kind, created_at, read_at FROM user_notifications
		WHERE user_id = $1 AND read_at IS NULL ORDER BY created_at DESC, id DESC LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []models.Notification{}
	for rows.Next() {
		var n models.Notification
		if err := rows.Scan(&n.ID, &n.UserID, &n.Message, &n.Kind, &n.CreatedAt, &n.ReadAt); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, rows.Err()
}

func CountUnreadNotifications(ctx context.Context, q db.DBTX, userID int64) (int64, error) {
	var n int64
	err := q.QueryRow(ctx, `SELECT count(*) FROM user_notifications WHERE user_id = $1 AND read_at IS NULL`, userID).Scan(&n)
	return n, err
}

// GetUserNotification returns a notification only if it belongs to the user.
func GetUserNotification(ctx context.Context, q db.DBTX, userID, id int64) (*models.Notification, error) {
	var n models.Notification
	err := q.QueryRow(ctx, `SELECT id, user_id, message, kind, created_at, read_at FROM user_notifications
		WHERE id = $1 AND user_id = $2`, id, userID).Scan(&n.ID, &n.UserID, &n.Message, &n.Kind, &n.CreatedAt, &n.ReadAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &n, nil
}

func MarkNotificationsRead(ctx context.Context, q db.DBTX, ids []int64, at time.Time) error {
	if len(ids) == 0 {
		return nil
	}
	_, err := q.Exec(ctx, `UPDATE user_notifications SET read_at = $2 WHERE id = ANY($1)`, ids, at)
	return err
}
