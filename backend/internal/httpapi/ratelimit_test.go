package httpapi

import (
	"net/http/httptest"
	"testing"
	"time"
)

func TestParseRateSpec(t *testing.T) {
	cases := map[string]string{
		"10/minute":       "10 per 1 minute",
		"120/minute":      "120 per 1 minute",
		"5 per 2 seconds": "5 per 2 second",
		"100/hour":        "100 per 1 hour",
		" 3 / day ":       "3 per 1 day",
	}
	for in, want := range cases {
		spec, err := parseRateSpec(in)
		if err != nil || spec.String() != want {
			t.Errorf("parseRateSpec(%q) = %q, %v", in, spec.String(), err)
		}
	}
	if _, err := parseRateSpec("lots"); err == nil {
		t.Error("invalid spec accepted")
	}
}

func TestFixedWindowLimiter(t *testing.T) {
	l := newRateLimiter()
	now := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	l.now = func() time.Time { return now }
	for i := 0; i < 2; i++ {
		if err := l.Check("login", "2/minute", "1.1.1.1"); err != nil {
			t.Fatal(err)
		}
	}
	err := l.Check("login", "2/minute", "1.1.1.1")
	if err == nil || err.Error() != "Rate limit exceeded: 2 per 1 minute" {
		t.Fatalf("err = %v", err)
	}
	if l.Check("login", "2/minute", "2.2.2.2") != nil || l.Check("ingest", "2/minute", "1.1.1.1") != nil {
		t.Fatal("limits must be per client and per route")
	}
	now = now.Add(time.Minute)
	if l.Check("login", "2/minute", "1.1.1.1") != nil {
		t.Fatal("window did not reset")
	}
}

func TestClientIPTrustsProxyHeaderOnlyFromPrivatePeers(t *testing.T) {
	r := httptest.NewRequest("GET", "/", nil)
	r.RemoteAddr = "172.18.0.5:5555"
	r.Header.Set("X-Forwarded-For", "203.0.113.9, 172.18.0.5")
	if got := clientIP(r); got != "203.0.113.9" {
		t.Errorf("proxied = %s", got)
	}
	r.RemoteAddr = "203.0.113.50:1234"
	if got := clientIP(r); got != "203.0.113.50" {
		t.Errorf("direct = %s", got)
	}
}
