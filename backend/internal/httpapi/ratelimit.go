package httpapi

import (
	"fmt"
	"net"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

// rateSpec is a parsed limit such as "10/minute" or "10 per 2 minutes".
type rateSpec struct {
	amount   int
	multiple int
	unit     string
	period   time.Duration
}

var unitDurations = map[string]time.Duration{
	"second": time.Second,
	"minute": time.Minute,
	"hour":   time.Hour,
	"day":    24 * time.Hour,
	"month":  30 * 24 * time.Hour,
	"year":   365 * 24 * time.Hour,
}

var specRe = regexp.MustCompile(`^\s*(\d+)\s*(?:/|per)\s*(\d+)?\s*([a-zA-Z]+?)s?\s*$`)

func parseRateSpec(s string) (rateSpec, error) {
	m := specRe.FindStringSubmatch(s)
	if m == nil {
		return rateSpec{}, fmt.Errorf("invalid rate limit %q", s)
	}
	amount, _ := strconv.Atoi(m[1])
	multiple := 1
	if m[2] != "" {
		multiple, _ = strconv.Atoi(m[2])
	}
	unit := strings.ToLower(m[3])
	d, ok := unitDurations[unit]
	if !ok {
		return rateSpec{}, fmt.Errorf("invalid rate limit unit %q", s)
	}
	return rateSpec{amount: amount, multiple: multiple, unit: unit, period: time.Duration(multiple) * d}, nil
}

// String mirrors the limits library: "10 per 1 minute".
func (r rateSpec) String() string {
	return fmt.Sprintf("%d per %d %s", r.amount, r.multiple, r.unit)
}

type window struct {
	start time.Time
	count int
}

// rateLimiter is an in-memory fixed-window limiter keyed by route + client
// IP (the slowapi/limits behaviour the API had before).
type rateLimiter struct {
	mu      sync.Mutex
	windows map[string]*window
	specs   map[string]rateSpec
	now     func() time.Time
}

func newRateLimiter() *rateLimiter {
	return &rateLimiter{windows: map[string]*window{}, specs: map[string]rateSpec{}, now: time.Now}
}

// rateLimitError renders as 429 {"error": "Rate limit exceeded: ..."}.
type rateLimitError struct{ spec rateSpec }

func (e *rateLimitError) Error() string { return "Rate limit exceeded: " + e.spec.String() }

func (l *rateLimiter) Check(route, spec, ip string) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	rs, ok := l.specs[spec]
	if !ok {
		var err error
		rs, err = parseRateSpec(spec)
		if err != nil {
			return nil // misconfigured limit: do not block traffic
		}
		l.specs[spec] = rs
	}
	now := l.now()
	key := route + "|" + ip
	w := l.windows[key]
	if w == nil || now.Sub(w.start) >= rs.period {
		w = &window{start: now}
		l.windows[key] = w
	}
	if w.count >= rs.amount {
		return &rateLimitError{spec: rs}
	}
	w.count++
	if len(l.windows) > 10000 {
		for k, v := range l.windows {
			if now.Sub(v.start) >= time.Hour {
				delete(l.windows, k)
			}
		}
	}
	return nil
}

var trustedProxyPrefixes = []string{"127.0.0.1", "::1", "172.", "10.", "192.168."}

func isTrustedProxy(host string) bool {
	for _, p := range trustedProxyPrefixes {
		if host == p || strings.HasPrefix(host, p) {
			return true
		}
	}
	return false
}

// clientIP returns X-Forwarded-For's first hop when the peer is a trusted
// proxy (nginx / docker network), otherwise the peer address.
func clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	if isTrustedProxy(host) {
		if fwd := r.Header.Get("X-Forwarded-For"); fwd != "" {
			first, _, _ := strings.Cut(fwd, ",")
			return strings.TrimSpace(first)
		}
	}
	return host
}
