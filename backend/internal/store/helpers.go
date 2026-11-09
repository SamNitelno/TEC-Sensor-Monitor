package store

import (
	"strings"

	"tek-sensor-monitor/backend/internal/db"
)

// Querier is an alias of db.DBTX for callers outside this package.
type Querier = db.DBTX

func normalizeEmail(v string) string { return strings.ToLower(strings.TrimSpace(v)) }
