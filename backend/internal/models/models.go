// Package models defines the database row types.
package models

import "time"

const (
	RoleAdmin  = "admin"
	RoleViewer = "viewer"

	StatusOnline  = "online"
	StatusOffline = "offline"

	DowntimeOffline = "offline"
	DowntimeIdle    = "idle"
)

type User struct {
	ID               int64
	Login            string
	PasswordHash     string
	Role             string
	CreatedAt        time.Time
	Email            *string
	Phone            *string
	PromotedByUserID *int64
	UpdatedAt        *time.Time
	IsActive         bool
}

type Workshop struct {
	ID                   int64
	Name                 string
	Color                *string
	NotificationsEnabled bool
	CreatedAt            time.Time
}

type Site struct {
	ID                   int64
	Name                 string
	WorkshopID           *int64
	Color                *string
	NotificationsEnabled bool
	CreatedAt            time.Time
}

type Sensor struct {
	ID                    int64
	Name                  string
	DeviceID              string
	APIToken              string
	SiteID                *int64
	Status                string
	LastSeen              *time.Time
	CreatedAt             time.Time
	Color                 *string
	CreatedByUserID       *int64
	IdlePowerThresholdW   *float64
	IdleCurrentThresholdA *float64
	IdleDurationSeconds   *int64
	NotificationsEnabled  bool
}

type Reading struct {
	Time     time.Time
	SensorID int64
	CurrentA float64
	PowerW   *float64
}

type DowntimeEvent struct {
	ID        int64
	SensorID  int64
	Type      string
	StartedAt time.Time
	EndedAt   *time.Time
}

type Notification struct {
	ID        int64
	UserID    int64
	Message   string
	Kind      string
	CreatedAt time.Time
	ReadAt    *time.Time
}

type ContactVerificationBatch struct {
	ID             string
	UserID         int64
	PendingLogin   *string
	PendingEmail   *string
	PendingPhone   *string
	ClearEmail     bool
	ClearPhone     bool
	EmailCodeHash  *string
	PhoneCodeHash  *string
	EmailVerified  bool
	FailedAttempts int
	ExpiresAt      time.Time
	CreatedAt      time.Time
}

type PasswordResetBatch struct {
	ID             string
	UserID         int64
	Channel        string
	Destination    string
	CodeHash       string
	FailedAttempts int
	ExpiresAt      time.Time
	ConsumedAt     *time.Time
	CreatedAt      time.Time
}

// SensorPlacement is one row of sensor_placement_history with joined names.
type SensorPlacement struct {
	SiteID          *int64
	SiteName        *string
	WorkshopID      *int64
	WorkshopName    *string
	AssignedAt      time.Time
	AssignedByLogin *string
}

// SensorScope is a sensor with its current site and workshop names.
type SensorScope struct {
	Sensor       Sensor
	SiteID       *int64
	SiteName     *string
	WorkshopID   *int64
	WorkshopName *string
}
