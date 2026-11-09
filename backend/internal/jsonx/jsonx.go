// Package jsonx provides JSON value types that serialise exactly like the
// former Pydantic/Python output (timestamps and floats).
package jsonx

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math"
	"time"
)

// formatUTC renders YYYY-MM-DDTHH:MM:SS[.ffffff]<suffix> in UTC; fractional
// microseconds appear only when non-zero (Python/Pydantic behaviour).
func formatUTC(t time.Time, suffix string) string {
	u := t.UTC()
	s := u.Format("2006-01-02T15:04:05")
	if us := u.Nanosecond() / 1000; us != 0 {
		s += fmt.Sprintf(".%06d", us)
	}
	return s + suffix
}

// FormatREST formats like Pydantic v2 (UTC rendered as "Z").
func FormatREST(t time.Time) string { return formatUTC(t, "Z") }

// FormatISO formats like Python datetime.isoformat() for UTC ("+00:00").
func FormatISO(t time.Time) string { return formatUTC(t, "+00:00") }

// Time is a REST timestamp.
type Time struct{ time.Time }

func (t Time) MarshalJSON() ([]byte, error) {
	return []byte(`"` + FormatREST(t.Time) + `"`), nil
}

// NewTime wraps t; NewTimePtr returns nil for a nil input.
func NewTime(t time.Time) Time { return Time{t} }

func NewTimePtr(t *time.Time) *Time {
	if t == nil {
		return nil
	}
	return &Time{*t}
}

// ISOTime is a WebSocket timestamp (Python isoformat()).
type ISOTime struct{ time.Time }

func (t ISOTime) MarshalJSON() ([]byte, error) {
	return []byte(`"` + FormatISO(t.Time) + `"`), nil
}

func NewISOTimePtr(t *time.Time) *ISOTime {
	if t == nil {
		return nil
	}
	return &ISOTime{*t}
}

// Float always carries a decimal point or exponent (4 -> 4.0), like Python.
type Float float64

func (f Float) MarshalJSON() ([]byte, error) {
	v := float64(f)
	if math.IsNaN(v) || math.IsInf(v, 0) {
		return []byte("null"), nil
	}
	b, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	if !bytes.ContainsAny(b, ".eE") {
		b = append(b, '.', '0')
	}
	return b, nil
}

func FloatPtr(v *float64) *Float {
	if v == nil {
		return nil
	}
	f := Float(*v)
	return &f
}
