package service

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/apperr"
	"tek-sensor-monitor/backend/internal/jsonx"
	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/store"
)

// FormatDurationRU renders a duration the way notification texts expect.
func FormatDurationRU(seconds float64) string {
	total := int64(seconds)
	if total < 0 {
		total = 0
	}
	if total < 60 {
		return fmt.Sprintf("%d сек", total)
	}
	minutes := total / 60
	if minutes < 60 {
		return fmt.Sprintf("%d мин", minutes)
	}
	hours := minutes / 60
	minutes %= 60
	if hours < 24 {
		if minutes != 0 {
			return fmt.Sprintf("%d ч %d мин", hours, minutes)
		}
		return fmt.Sprintf("%d ч", hours)
	}
	days := hours / 24
	hours %= 24
	if hours != 0 {
		return fmt.Sprintf("%d д %d ч", days, hours)
	}
	return fmt.Sprintf("%d д", days)
}

// notifyDowntimeEvent creates one notification per active user when an
// offline/idle event opens (only if the sensor has notifications enabled).
func (s *Service) notifyDowntimeEvent(ctx context.Context, tx pgx.Tx, sensor *models.Sensor, eventType string, startedAt time.Time) error {
	if !sensor.NotificationsEnabled {
		return nil
	}
	workshop := "—"
	if sensor.SiteID != nil {
		name, err := store.WorkshopNameForSite(ctx, tx, *sensor.SiteID)
		if err != nil {
			return err
		}
		if name != nil {
			workshop = *name
		}
	}
	now := s.now()
	duration := FormatDurationRU(now.Sub(startedAt).Seconds())
	var message, kind string
	if eventType == models.DowntimeOffline {
		message = fmt.Sprintf("«%s» · цех «%s» · offline · с начала %s", sensor.Name, workshop, duration)
		kind = "sensor_offline"
	} else {
		message = fmt.Sprintf("«%s» · цех «%s» · простой · с начала %s", sensor.Name, workshop, duration)
		kind = "sensor_idle"
	}
	userIDs, err := store.ListActiveUserIDs(ctx, tx)
	if err != nil {
		return err
	}
	return store.CreateNotificationsForUsers(ctx, tx, userIDs, message, kind, now)
}

func (s *Service) ListUnreadNotifications(ctx context.Context, user *models.User) ([]NotificationItem, error) {
	rows, err := store.ListUnreadNotifications(ctx, s.Pool, user.ID, 50)
	if err != nil {
		return nil, err
	}
	out := make([]NotificationItem, 0, len(rows))
	for _, n := range rows {
		out = append(out, NotificationItem{ID: n.ID, Message: n.Message, Kind: n.Kind, CreatedAt: jsonx.NewTime(n.CreatedAt)})
	}
	return out, nil
}

func (s *Service) UnreadCount(ctx context.Context, user *models.User) (*NotificationCountResponse, error) {
	n, err := store.CountUnreadNotifications(ctx, s.Pool, user.ID)
	if err != nil {
		return nil, err
	}
	return &NotificationCountResponse{Count: n}, nil
}

func (s *Service) AcknowledgeNotification(ctx context.Context, user *models.User, id int64) (*NotificationAckResponse, error) {
	n, err := store.GetUserNotification(ctx, s.Pool, user.ID, id)
	if err != nil {
		return nil, err
	}
	if n == nil {
		return nil, apperr.NotFound("Notification not found")
	}
	if err := store.MarkNotificationsRead(ctx, s.Pool, []int64{n.ID}, s.now()); err != nil {
		return nil, err
	}
	return &NotificationAckResponse{ID: n.ID, Read: true}, nil
}

func (s *Service) AcknowledgeAll(ctx context.Context, user *models.User) (*AckAllResponse, error) {
	var count int
	err := s.tx(ctx, func(tx pgx.Tx) error {
		rows, err := store.ListUnreadNotifications(ctx, tx, user.ID, 500)
		if err != nil {
			return err
		}
		ids := make([]int64, 0, len(rows))
		for _, n := range rows {
			ids = append(ids, n.ID)
		}
		count = len(ids)
		return store.MarkNotificationsRead(ctx, tx, ids, s.now())
	})
	if err != nil {
		return nil, err
	}
	return &AckAllResponse{Acknowledged: count}, nil
}
