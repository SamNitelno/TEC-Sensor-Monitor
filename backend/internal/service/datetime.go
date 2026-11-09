package service

import (
	"errors"
	"math"
	"regexp"
	"strconv"
	"strings"
	"time"
)

var isoRe = regexp.MustCompile(`^(\d{4})-(\d{2})-(\d{2})(?:[Tt _](\d{2}):(\d{2})(?::(\d{2})(?:[.,](\d{1,9}))?)?)?\s*(Z|z|[+-]\d{2}(?::?\d{2})?)?$`)

// ParseDateTime accepts what Pydantic's lax datetime parsing accepted for
// query/body values: ISO 8601 (with "T" or space, optional fraction, optional
// offset), plain dates, and unix timestamps in seconds or milliseconds.
// Values without an offset are treated as UTC.
func ParseDateTime(s string) (time.Time, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return time.Time{}, errors.New("empty datetime")
	}
	if f, err := strconv.ParseFloat(s, 64); err == nil && !math.IsNaN(f) && !math.IsInf(f, 0) {
		return FromUnix(f), nil
	}
	m := isoRe.FindStringSubmatch(s)
	if m == nil {
		return time.Time{}, describeDateError(s)
	}
	atoi := func(v string) int {
		n, _ := strconv.Atoi(v)
		return n
	}
	year, month, day := atoi(m[1]), atoi(m[2]), atoi(m[3])
	hour, minute, sec := atoi(m[4]), atoi(m[5]), atoi(m[6])
	nsec := 0
	if m[7] != "" {
		frac := (m[7] + "000000000")[:9]
		nsec = atoi(frac)
		// Python datetimes carry microseconds only.
		nsec = nsec / 1000 * 1000
	}
	switch {
	case month < 1 || month > 12:
		return time.Time{}, errors.New("month value is outside expected range of 1-12")
	case day < 1 || day > 31:
		return time.Time{}, errors.New("day value is outside expected range")
	case hour > 23:
		return time.Time{}, errors.New("hour value is outside expected range of 0-23")
	case minute > 59:
		return time.Time{}, errors.New("minute value is outside expected range of 0-59")
	case sec > 59:
		return time.Time{}, errors.New("second value is outside expected range of 0-59")
	}
	loc := time.UTC
	if tz := m[8]; tz != "" && tz != "Z" && tz != "z" {
		sign := 1
		if tz[0] == '-' {
			sign = -1
		}
		digits := strings.ReplaceAll(tz[1:], ":", "")
		h := atoi(digits[:2])
		mm := 0
		if len(digits) >= 4 {
			mm = atoi(digits[2:4])
		}
		if h > 23 || mm > 59 {
			return time.Time{}, errors.New("invalid timezone")
		}
		loc = time.FixedZone("", sign*(h*3600+mm*60))
	}
	t := time.Date(year, time.Month(month), day, hour, minute, sec, nsec, loc)
	if t.Day() != day {
		return time.Time{}, errors.New("day value is outside expected range")
	}
	return t.UTC(), nil
}

func isDigits(s string) bool {
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return s != ""
}

// describeDateError approximates the parser messages Pydantic (speedate)
// produced for malformed datetimes.
func describeDateError(s string) error {
	switch {
	case len(s) < 10:
		return errors.New("input is too short")
	case !isDigits(s[0:4]):
		return errors.New("invalid character in year")
	case s[4] != '-' || s[7] != '-':
		return errors.New("invalid date separator, expected `-`")
	case !isDigits(s[5:7]):
		return errors.New("invalid character in month")
	case !isDigits(s[8:10]):
		return errors.New("invalid character in day")
	case len(s) > 10 && !strings.ContainsRune("Tt_ ", rune(s[10])):
		return errors.New("invalid datetime separator, expected `T`, `t`, `_` or space")
	}
	return errors.New("invalid datetime format")
}

// FromUnix interprets numbers like Pydantic: values above 2e10 are
// milliseconds, otherwise seconds.
func FromUnix(f float64) time.Time {
	if math.Abs(f) > 2e10 {
		f /= 1000
	}
	sec, frac := math.Modf(f)
	us := math.Round(frac * 1e6)
	return time.Unix(int64(sec), int64(us)*1000).UTC()
}
