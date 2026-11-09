package service

import (
	"tek-sensor-monitor/backend/internal/jsonx"
	"tek-sensor-monitor/backend/internal/models"
)

// Response DTOs. Field order and names follow the former Pydantic schemas;
// optional values are always emitted (as null) exactly like before.

type TokenResponse struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	Role        string `json:"role"`
}

type LoginAvailabilityResponse struct {
	Login     string `json:"login"`
	Available bool   `json:"available"`
}

type AuthCapabilitiesResponse struct {
	PublicRegistration bool `json:"public_registration"`
	PasswordReset      bool `json:"password_reset"`
}

// UserProfile is also used as UserListItem (identical shape).
type UserProfile struct {
	ID               int64      `json:"id"`
	Login            string     `json:"login"`
	Role             string     `json:"role"`
	Email            *string    `json:"email"`
	Phone            *string    `json:"phone"`
	PromotedByUserID *int64     `json:"promoted_by_user_id"`
	CreatedAt        jsonx.Time `json:"created_at"`
}

func toProfile(u *models.User) UserProfile {
	return UserProfile{
		ID: u.ID, Login: u.Login, Role: u.Role, Email: u.Email, Phone: u.Phone,
		PromotedByUserID: u.PromotedByUserID, CreatedAt: jsonx.NewTime(u.CreatedAt),
	}
}

type ProfileUpdateResponse struct {
	Profile     UserProfile `json:"profile"`
	AccessToken *string     `json:"access_token"`
}

type ContactSendCodesResponse struct {
	BatchID           string       `json:"batch_id"`
	Step              string       `json:"step"`
	DestinationMasked *string      `json:"destination_masked"`
	Message           string       `json:"message"`
	Profile           *UserProfile `json:"profile"`
	AccessToken       *string      `json:"access_token"`
}

type ContactVerifyCodeResponse struct {
	Step              string       `json:"step"`
	DestinationMasked *string      `json:"destination_masked"`
	Message           string       `json:"message"`
	Profile           *UserProfile `json:"profile"`
	AccessToken       *string      `json:"access_token"`
}

type PasswordResetRequestResponse struct {
	BatchID           string `json:"batch_id"`
	DestinationMasked string `json:"destination_masked"`
	Message           string `json:"message"`
}

type MessageResponse struct {
	Message string `json:"message"`
}

type RoleChangeResponse struct {
	User    UserProfile `json:"user"`
	Message string      `json:"message"`
}

type NotificationItem struct {
	ID        int64      `json:"id"`
	Message   string     `json:"message"`
	Kind      string     `json:"kind"`
	CreatedAt jsonx.Time `json:"created_at"`
}

type NotificationAckResponse struct {
	ID   int64 `json:"id"`
	Read bool  `json:"read"`
}

type NotificationCountResponse struct {
	Count int64 `json:"count"`
}

type AckAllResponse struct {
	Acknowledged int `json:"acknowledged"`
}

type BulkNotificationsResponse struct {
	Updated int64 `json:"updated"`
}

// SensorItem serves both SensorListItem and SensorDetail.
type SensorItem struct {
	ID                    int64        `json:"id"`
	Name                  string       `json:"name"`
	DeviceID              string       `json:"device_id"`
	SiteID                *int64       `json:"site_id"`
	Status                string       `json:"status"`
	LastSeen              *jsonx.Time  `json:"last_seen"`
	Color                 *string      `json:"color"`
	IdlePowerThresholdW   *jsonx.Float `json:"idle_power_threshold_w"`
	IdleCurrentThresholdA *jsonx.Float `json:"idle_current_threshold_a"`
	IdleDurationSeconds   *int64       `json:"idle_duration_seconds"`
	NotificationsEnabled  bool         `json:"notifications_enabled"`
	CreatedAt             jsonx.Time   `json:"created_at"`
}

type IntegrationSnippet struct {
	Method      string            `json:"method"`
	URL         string            `json:"url"`
	Headers     orderedStrings    `json:"headers"`
	BodySchema  orderedStrings    `json:"body_schema"`
	BodyExample orderedFloatPairs `json:"body_example"`
	Curl        string            `json:"curl"`
}

type SensorCreateResponse struct {
	Sensor      SensorItem         `json:"sensor"`
	APIToken    string             `json:"api_token"`
	Warning     string             `json:"warning"`
	Integration IntegrationSnippet `json:"integration"`
}

type ProvisioningTokenResponse struct {
	IngestURL string  `json:"ingest_url"`
	APIToken  *string `json:"api_token"`
	Message   *string `json:"message"`
}

type RotateTokenResponse struct {
	APIToken  string `json:"api_token"`
	IngestURL string `json:"ingest_url"`
	Warning   string `json:"warning"`
}

type ReadingPoint struct {
	Time   jsonx.Time   `json:"time"`
	Avg    jsonx.Float  `json:"avg"`
	Min    jsonx.Float  `json:"min"`
	Max    jsonx.Float  `json:"max"`
	PowerW *jsonx.Float `json:"power_w"`
}

type ReadingsResponse struct {
	Bucket string         `json:"bucket"`
	Points []ReadingPoint `json:"points"`
}

type SensorSeries struct {
	SensorID   int64          `json:"sensor_id"`
	SensorName string         `json:"sensor_name"`
	Bucket     string         `json:"bucket"`
	Points     []ReadingPoint `json:"points"`
}

type GroupedReadingsResponse struct {
	Series []SensorSeries `json:"series"`
}

type DemoSeedResponse struct {
	Sensors     int      `json:"sensors"`
	Points      int      `json:"points"`
	SensorNames []string `json:"sensor_names"`
}

type SensorPlacementRecord struct {
	SiteID          *int64     `json:"site_id"`
	SiteName        *string    `json:"site_name"`
	WorkshopID      *int64     `json:"workshop_id"`
	WorkshopName    *string    `json:"workshop_name"`
	AssignedAt      jsonx.Time `json:"assigned_at"`
	AssignedByLogin *string    `json:"assigned_by_login"`
}

type SensorAuditInfo struct {
	ID                  int64                   `json:"id"`
	Name                string                  `json:"name"`
	DeviceID            string                  `json:"device_id"`
	CreatedAt           jsonx.Time              `json:"created_at"`
	CreatedByLogin      *string                 `json:"created_by_login"`
	CurrentSiteID       *int64                  `json:"current_site_id"`
	CurrentSiteName     *string                 `json:"current_site_name"`
	CurrentWorkshopID   *int64                  `json:"current_workshop_id"`
	CurrentWorkshopName *string                 `json:"current_workshop_name"`
	Color               *string                 `json:"color"`
	PlacementHistory    []SensorPlacementRecord `json:"placement_history"`
}

type WorkshopResponse struct {
	ID                   int64      `json:"id"`
	Name                 string     `json:"name"`
	Color                *string    `json:"color"`
	NotificationsEnabled bool       `json:"notifications_enabled"`
	CreatedAt            jsonx.Time `json:"created_at"`
}

type SiteResponse struct {
	ID                   int64      `json:"id"`
	Name                 string     `json:"name"`
	WorkshopID           int64      `json:"workshop_id"`
	Color                *string    `json:"color"`
	NotificationsEnabled bool       `json:"notifications_enabled"`
	CreatedAt            jsonx.Time `json:"created_at"`
}

type DowntimeEventItem struct {
	ID              int64        `json:"id"`
	SensorID        int64        `json:"sensor_id"`
	SensorName      string       `json:"sensor_name"`
	SiteID          *int64       `json:"site_id"`
	SiteName        *string      `json:"site_name"`
	WorkshopID      *int64       `json:"workshop_id"`
	WorkshopName    *string      `json:"workshop_name"`
	Type            string       `json:"type"`
	StartedAt       jsonx.Time   `json:"started_at"`
	EndedAt         *jsonx.Time  `json:"ended_at"`
	DurationSeconds *jsonx.Float `json:"duration_seconds"`
}

type DowntimeEventsResponse struct {
	Events []DowntimeEventItem `json:"events"`
}

type DowntimeSummaryItem struct {
	SensorID       int64       `json:"sensor_id"`
	SensorName     string      `json:"sensor_name"`
	SiteID         *int64      `json:"site_id"`
	SiteName       *string     `json:"site_name"`
	WorkshopID     *int64      `json:"workshop_id"`
	WorkshopName   *string     `json:"workshop_name"`
	OfflineSeconds jsonx.Float `json:"offline_seconds"`
	IdleSeconds    jsonx.Float `json:"idle_seconds"`
	TotalSeconds   jsonx.Float `json:"total_seconds"`
}

type WorkshopDowntimeSummaryItem struct {
	WorkshopID     int64       `json:"workshop_id"`
	WorkshopName   string      `json:"workshop_name"`
	OfflineSeconds jsonx.Float `json:"offline_seconds"`
	IdleSeconds    jsonx.Float `json:"idle_seconds"`
	TotalSeconds   jsonx.Float `json:"total_seconds"`
}

type DowntimeSummaryResponse struct {
	Sensors   []DowntimeSummaryItem         `json:"sensors"`
	Workshops []WorkshopDowntimeSummaryItem `json:"workshops"`
}

type IngestResponse struct {
	Accepted int `json:"accepted"`
}
