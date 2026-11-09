// Package config loads backend settings from environment variables and an
// optional .env file. Names and defaults mirror the former pydantic-settings
// model so existing .env files keep working unchanged.
package config

import (
	"fmt"
	"net/url"
	"os"
	"strconv"
	"strings"

	"github.com/joho/godotenv"
)

type Config struct {
	AppEnv              string
	DatabaseURL         string // as given (may contain "+asyncpg")
	JWTSecret           string
	JWTExpireMinutes    int
	AdminLogin          string
	AdminPassword       string
	APIPublicBaseURL    string
	DeviceIngestBaseURL string
	ViewerLogin         string
	ViewerPassword      string

	AllowPublicRegistration bool

	SensorOfflineThresholdSeconds     int
	SensorOfflineCheckIntervalSeconds int
	DowntimeWorkerIntervalSeconds     int
	DowntimeSmoothingSamples          int
	DefaultIdlePowerThresholdW        float64
	DefaultIdleCurrentThresholdA      float64
	DefaultIdleDurationSeconds        int

	VerificationCodeTTLMinutes int
	VerificationMaxAttempts    int
	VerificationSMTPHost       string
	VerificationSMTPPort       int
	VerificationSMTPUser       string
	VerificationSMTPPassword   string
	VerificationSMSAPIID       string
	VerificationSMSFrom        string
	VerificationDeliveryMode   string

	CORSOrigins string
	LogLevel    string
	JSONLogs    bool

	IngestRateLimit       string
	AuthLoginRateLimit    string
	AuthRegisterRateLimit string
	AuthVerifyRateLimit   string
	IngestMaxBatchSize    int
	IngestMaxCurrentA     float64
	IngestMinCurrentA     float64
	IngestMaxPowerW       float64
	IngestMinPowerW       float64

	MQTTEnabled  bool
	MQTTHost     string
	MQTTPort     int
	MQTTUsername string
	MQTTPassword string

	TimescaleRetentionDays     int
	TimescaleCompressAfterDays int

	// HTTPAddr is the listen address of the API server (Go-only setting).
	HTTPAddr string
}

// Load reads .env from the working directory (if present) without overriding
// variables already set in the process environment, then parses settings.
func Load() (*Config, error) {
	_ = godotenv.Load(".env")
	return FromEnv()
}

// FromEnv parses settings from the current process environment only.
func FromEnv() (*Config, error) {
	p := &parser{}
	c := &Config{
		AppEnv:              p.str("APP_ENV", "development"),
		DatabaseURL:         p.required("DATABASE_URL"),
		JWTSecret:           p.required("JWT_SECRET"),
		JWTExpireMinutes:    p.integer("JWT_EXPIRE_MINUTES", 720),
		AdminLogin:          p.required("ADMIN_LOGIN"),
		AdminPassword:       p.required("ADMIN_PASSWORD"),
		APIPublicBaseURL:    p.str("API_PUBLIC_BASE_URL", "http://localhost:8000"),
		DeviceIngestBaseURL: p.str("DEVICE_INGEST_BASE_URL", ""),
		ViewerLogin:         p.str("VIEWER_LOGIN", "viewer"),
		ViewerPassword:      p.required("VIEWER_PASSWORD"),

		AllowPublicRegistration: p.boolean("ALLOW_PUBLIC_REGISTRATION", true),

		SensorOfflineThresholdSeconds:     p.integer("SENSOR_OFFLINE_THRESHOLD_SECONDS", 15),
		SensorOfflineCheckIntervalSeconds: p.integer("SENSOR_OFFLINE_CHECK_INTERVAL_SECONDS", 5),
		DowntimeWorkerIntervalSeconds:     p.integer("DOWNTIME_WORKER_INTERVAL_SECONDS", 30),
		DowntimeSmoothingSamples:          p.integer("DOWNTIME_SMOOTHING_SAMPLES", 3),
		DefaultIdlePowerThresholdW:        p.float("DEFAULT_IDLE_POWER_THRESHOLD_W", 50.0),
		DefaultIdleCurrentThresholdA:      p.float("DEFAULT_IDLE_CURRENT_THRESHOLD_A", 0.5),
		DefaultIdleDurationSeconds:        p.integer("DEFAULT_IDLE_DURATION_SECONDS", 60),

		VerificationCodeTTLMinutes: p.integer("VERIFICATION_CODE_TTL_MINUTES", 10),
		VerificationMaxAttempts:    p.integer("VERIFICATION_MAX_ATTEMPTS", 5),
		VerificationSMTPHost:       p.str("VERIFICATION_SMTP_HOST", "smtp.gmail.com"),
		VerificationSMTPPort:       p.integer("VERIFICATION_SMTP_PORT", 587),
		VerificationSMTPUser:       p.str("VERIFICATION_SMTP_USER", ""),
		VerificationSMTPPassword:   p.str("VERIFICATION_SMTP_PASSWORD", ""),
		VerificationSMSAPIID:       p.str("VERIFICATION_SMS_API_ID", ""),
		VerificationSMSFrom:        p.str("VERIFICATION_SMS_FROM", ""),
		VerificationDeliveryMode:   p.str("VERIFICATION_DELIVERY_MODE", "log"),

		CORSOrigins: strings.TrimSpace(p.str("CORS_ORIGINS", "")),
		LogLevel:    p.str("LOG_LEVEL", "INFO"),
		JSONLogs:    p.boolean("JSON_LOGS", true),

		IngestRateLimit:       p.str("INGEST_RATE_LIMIT", "120/minute"),
		AuthLoginRateLimit:    p.str("AUTH_LOGIN_RATE_LIMIT", "10/minute"),
		AuthRegisterRateLimit: p.str("AUTH_REGISTER_RATE_LIMIT", "5/minute"),
		AuthVerifyRateLimit:   p.str("AUTH_VERIFY_RATE_LIMIT", "10/minute"),
		IngestMaxBatchSize:    p.integer("INGEST_MAX_BATCH_SIZE", 100),
		IngestMaxCurrentA:     p.float("INGEST_MAX_CURRENT_A", 1000.0),
		IngestMinCurrentA:     p.float("INGEST_MIN_CURRENT_A", 0.0),
		IngestMaxPowerW:       p.float("INGEST_MAX_POWER_W", 1_000_000.0),
		IngestMinPowerW:       p.float("INGEST_MIN_POWER_W", 0.0),

		MQTTEnabled:  p.boolean("MQTT_ENABLED", false),
		MQTTHost:     p.str("MQTT_HOST", "mosquitto"),
		MQTTPort:     p.integer("MQTT_PORT", 1883),
		MQTTUsername: p.str("MQTT_USERNAME", ""),
		MQTTPassword: p.str("MQTT_PASSWORD", ""),

		TimescaleRetentionDays:     p.integer("TIMESCALE_RETENTION_DAYS", 365),
		TimescaleCompressAfterDays: p.integer("TIMESCALE_COMPRESS_AFTER_DAYS", 7),

		HTTPAddr: p.str("HTTP_ADDR", ":8000"),
	}
	if len(p.errs) > 0 {
		return nil, fmt.Errorf("invalid configuration: %s", strings.Join(p.errs, "; "))
	}
	return c, nil
}

// IsProduction mirrors Settings.is_production.
func (c *Config) IsProduction() bool {
	return strings.ToLower(strings.TrimSpace(c.AppEnv)) == "production"
}

// CORSOriginList mirrors Settings.cors_origin_list.
func (c *Config) CORSOriginList() []string {
	if c.CORSOrigins == "" {
		if c.IsProduction() {
			return nil
		}
		return []string{"*"}
	}
	var out []string
	for _, o := range strings.Split(c.CORSOrigins, ",") {
		if o = strings.TrimSpace(o); o != "" {
			out = append(out, o)
		}
	}
	return out
}

// ResolvedDeviceIngestBaseURL mirrors Settings.resolved_device_ingest_base_url.
func (c *Config) ResolvedDeviceIngestBaseURL() string {
	if strings.TrimSpace(c.DeviceIngestBaseURL) != "" {
		return strings.TrimRight(c.DeviceIngestBaseURL, "/")
	}
	public := strings.TrimRight(c.APIPublicBaseURL, "/")
	switch {
	case strings.HasPrefix(public, "https://"):
		return "http://" + strings.TrimPrefix(public, "https://")
	case strings.HasPrefix(public, "http://"):
		return public
	default:
		return "http://" + public
	}
}

// IngestURL is the full device ingest endpoint.
func (c *Config) IngestURL() string {
	return c.ResolvedDeviceIngestBaseURL() + "/api/v1/ingest"
}

// PgxDatabaseURL converts SQLAlchemy-style URLs (postgresql+asyncpg://) into a
// libpq URL that pgx understands.
func (c *Config) PgxDatabaseURL() string {
	return NormalizeDatabaseURL(c.DatabaseURL)
}

func NormalizeDatabaseURL(raw string) string {
	u := strings.TrimSpace(raw)
	if i := strings.Index(u, "://"); i > 0 {
		scheme := u[:i]
		if plus := strings.Index(scheme, "+"); plus > 0 {
			scheme = scheme[:plus]
		}
		u = scheme + u[i:]
	}
	return u
}

// PostgresPassword is derived from DATABASE_URL (kept for parity with the
// Python settings model).
func (c *Config) PostgresPassword() string {
	parsed, err := url.Parse(c.PgxDatabaseURL())
	if err != nil || parsed.User == nil {
		return ""
	}
	pw, _ := parsed.User.Password()
	return pw
}

type parser struct{ errs []string }

func lookup(name string) (string, bool) {
	if v, ok := os.LookupEnv(name); ok {
		return v, true
	}
	// pydantic-settings matched env names case-insensitively.
	lower := strings.ToLower(name)
	for _, kv := range os.Environ() {
		if i := strings.IndexByte(kv, '='); i > 0 && strings.ToLower(kv[:i]) == lower {
			return kv[i+1:], true
		}
	}
	return "", false
}

func (p *parser) str(name, def string) string {
	if v, ok := lookup(name); ok {
		return v
	}
	return def
}

func (p *parser) required(name string) string {
	v, ok := lookup(name)
	if !ok {
		p.errs = append(p.errs, name+" is required")
	}
	return v
}

func (p *parser) integer(name string, def int) int {
	v, ok := lookup(name)
	if !ok || strings.TrimSpace(v) == "" {
		return def
	}
	n, err := strconv.Atoi(strings.TrimSpace(v))
	if err != nil {
		p.errs = append(p.errs, name+" must be an integer")
		return def
	}
	return n
}

func (p *parser) float(name string, def float64) float64 {
	v, ok := lookup(name)
	if !ok || strings.TrimSpace(v) == "" {
		return def
	}
	f, err := strconv.ParseFloat(strings.TrimSpace(v), 64)
	if err != nil {
		p.errs = append(p.errs, name+" must be a number")
		return def
	}
	return f
}

func (p *parser) boolean(name string, def bool) bool {
	v, ok := lookup(name)
	if !ok {
		return def
	}
	b, valid := ParseBool(v)
	if !valid {
		p.errs = append(p.errs, name+" must be a boolean")
		return def
	}
	return b
}

// ParseBool accepts the same spellings as pydantic.
func ParseBool(v string) (bool, bool) {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "1", "true", "t", "yes", "y", "on":
		return true, true
	case "0", "false", "f", "no", "n", "off":
		return false, true
	}
	return false, false
}
