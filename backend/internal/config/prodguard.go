package config

import (
	"strings"

	"tek-sensor-monitor/backend/internal/validate"
)

var weakSecrets = map[string]bool{
	"change-me-to-a-long-random-string": true,
	"change-me":                         true,
	"changeme":                          true,
	"secret":                            true,
	"password":                          true,
	"admin":                             true,
	"viewer":                            true,
	"tek_secret":                        true,
	"jwt_secret":                        true,
	"test":                              true,
	"12345678":                          true,
}

func isWeak(value string) bool {
	normalized := strings.ToLower(strings.TrimSpace(value))
	return normalized == "" || weakSecrets[normalized]
}

// ProductionErrors returns the list of fatal misconfigurations when
// APP_ENV=production (empty in any other environment).
func (c *Config) ProductionErrors() []string {
	if !c.IsProduction() {
		return nil
	}
	var errs []string
	if isWeak(c.JWTSecret) || len([]rune(c.JWTSecret)) < 32 {
		errs = append(errs, "JWT_SECRET must be at least 32 characters and not a placeholder")
	}
	if isWeak(c.AdminPassword) {
		errs = append(errs, "ADMIN_PASSWORD is weak or uses a placeholder value")
	} else if err := validate.Password(c.AdminPassword); err != nil {
		errs = append(errs, "ADMIN_PASSWORD: "+err.Error())
	}
	if isWeak(c.ViewerPassword) {
		errs = append(errs, "VIEWER_PASSWORD is weak or uses a placeholder value")
	} else if err := validate.Password(c.ViewerPassword); err != nil {
		errs = append(errs, "VIEWER_PASSWORD: "+err.Error())
	}
	if strings.TrimSpace(c.CORSOrigins) == "" {
		errs = append(errs, "CORS_ORIGINS must be set explicitly in production")
	}
	if strings.ToLower(strings.TrimSpace(c.VerificationDeliveryMode)) == "production" {
		errs = append(errs, "VERIFICATION_DELIVERY_MODE=production is disabled for LAN prod; use log or test")
	}
	return errs
}
