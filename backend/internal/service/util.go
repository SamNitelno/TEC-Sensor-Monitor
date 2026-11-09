package service

import (
	"tek-sensor-monitor/backend/internal/db"
)

func isUniqueViolation(err error) bool { return db.IsUniqueViolation(err) }

func strPtr(s string) *string { return &s }
