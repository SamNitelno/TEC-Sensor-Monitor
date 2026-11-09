package jsonx

import (
	"encoding/json"
	"testing"
	"time"
)

// Expected strings were produced by Pydantic v2 / datetime.isoformat().
func TestTimeFormats(t *testing.T) {
	cases := []struct {
		t         time.Time
		rest, iso string
	}{
		{time.Date(2026, 1, 2, 3, 4, 5, 0, time.UTC), "2026-01-02T03:04:05Z", "2026-01-02T03:04:05+00:00"},
		{time.Date(2026, 1, 2, 3, 4, 5, 123000000, time.UTC), "2026-01-02T03:04:05.123000Z", "2026-01-02T03:04:05.123000+00:00"},
		{time.Date(2026, 1, 2, 3, 4, 5, 123456789, time.UTC), "2026-01-02T03:04:05.123456Z", "2026-01-02T03:04:05.123456+00:00"},
		{time.Date(2026, 1, 2, 3, 4, 5, 100000, time.UTC), "2026-01-02T03:04:05.000100Z", "2026-01-02T03:04:05.000100+00:00"},
		{time.Date(2026, 1, 2, 10, 4, 5, 0, time.FixedZone("", 7*3600)), "2026-01-02T03:04:05Z", "2026-01-02T03:04:05+00:00"},
	}
	for _, c := range cases {
		if got := FormatREST(c.t); got != c.rest {
			t.Errorf("FormatREST = %s, want %s", got, c.rest)
		}
		if got := FormatISO(c.t); got != c.iso {
			t.Errorf("FormatISO = %s, want %s", got, c.iso)
		}
	}
}

func TestFloatKeepsDecimalPoint(t *testing.T) {
	cases := map[float64]string{4: "4.0", 0: "0.0", 2100.5: "2100.5", 0.30000000000000004: "0.30000000000000004", 1e-7: "1e-7", -3: "-3.0"}
	for in, want := range cases {
		b, _ := json.Marshal(Float(in))
		if string(b) != want {
			t.Errorf("Float(%v) = %s, want %s", in, b, want)
		}
	}
	var nilPtr *Float
	b, _ := json.Marshal(struct {
		V *Float `json:"v"`
	}{nilPtr})
	if string(b) != `{"v":null}` {
		t.Errorf("nil = %s", b)
	}
}
