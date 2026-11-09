package main

import (
	"errors"
	"flag"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"tek-sensor-monitor/backend/internal/jsonx"
)

func apiFlags(fs *flag.FlagSet, defaultBase string) (base, login, password *string) {
	base = fs.String("api", envOr("TEKTOOL_API", defaultBase), "API base URL (without /api/v1)")
	login = fs.String("login", envOr("ADMIN_LOGIN", "admin"), "admin login (default $ADMIN_LOGIN)")
	password = fs.String("password", envOr("ADMIN_PASSWORD", "admin"), "admin password (default $ADMIN_PASSWORD)")
	return
}

var demoSensorNames = map[string]bool{"Демо датчик 1": true, "Демо датчик 2": true, "Демо датчик 3": true, "Smoke Sensor": true}

func runSeedDemo(args []string) error {
	fs := flag.NewFlagSet("seed-demo", flag.ExitOnError)
	base, login, password := apiFlags(fs, "http://localhost:8000")
	_ = fs.Parse(args)
	c := newAPIClient(*base, false)
	if err := c.login(*login, *password); err != nil {
		return err
	}

	anon := newAPIClient(*base, false)
	for _, u := range []string{"operator1", "operator2"} {
		var check struct {
			Available bool `json:"available"`
		}
		if _, err := anon.do("GET", "/api/v1/auth/check-login", url.Values{"login": {u}}, nil, &check); err == nil && check.Available {
			_, _ = anon.do("POST", "/api/v1/auth/register", nil, map[string]string{"login": u, "password": "Oper1234"}, nil)
		}
	}

	type group struct {
		ID   int64  `json:"id"`
		Name string `json:"name"`
	}
	var workshops []group
	for _, w := range [][2]string{{"Цех A", "#00D4AA"}, {"Цех B", "#F5A623"}} {
		var created group
		if _, err := c.do("POST", "/api/v1/workshops", nil, map[string]string{"name": w[0], "color": w[1]}, &created); err == nil {
			workshops = append(workshops, created)
		} else {
			workshops = nil
			if _, err := c.do("GET", "/api/v1/workshops", nil, nil, &workshops); err != nil {
				return err
			}
		}
	}

	var sites []group
	colors := []string{"#58A6FF", "#E06C75", "#D2A8FF"}
	idx := 0
	for _, w := range workshops {
		for n := 1; n <= 2; n++ {
			var created group
			body := map[string]any{"name": fmt.Sprintf("%s · Площадка %d", w.Name, n), "workshop_id": w.ID, "color": colors[idx%len(colors)]}
			if _, err := c.do("POST", "/api/v1/sites", nil, body, &created); err == nil {
				sites = append(sites, created)
			}
			idx++
		}
	}
	if len(sites) == 0 {
		if _, err := c.do("GET", "/api/v1/sites", nil, nil, &sites); err != nil {
			return err
		}
	}

	existing, err := c.sensors()
	if err != nil {
		return err
	}
	byDevice, byName := map[string]bool{}, map[string]bool{}
	for _, s := range existing {
		byDevice[s.DeviceID], byName[s.Name] = true, true
	}
	sensorColors := []string{"#79C0FF", "#FF7B72", "#FFA657"}
	for i, site := range sites {
		if i >= 3 {
			break
		}
		deviceID := fmt.Sprintf("DEMO-SENSOR-%03d", i+1)
		name := fmt.Sprintf("Демо датчик %d", i+1)
		if byDevice[deviceID] || byName[name] {
			continue
		}
		_, _ = c.do("POST", "/api/v1/sensors", nil, map[string]any{
			"name": name, "device_id": deviceID, "site_id": site.ID, "color": sensorColors[i%len(sensorColors)],
		}, nil)
	}
	if !byName["Smoke Sensor"] && len(sites) > 0 && !byDevice["SMOKE-DEMO-001"] {
		_, _ = c.do("POST", "/api/v1/sensors", nil, map[string]any{
			"name": "Smoke Sensor", "device_id": "SMOKE-DEMO-001", "site_id": sites[0].ID, "color": "#D2A8FF",
		}, nil)
	}
	fmt.Println("Demo sensors ensured")

	var seeded map[string]any
	if _, err := c.do("POST", "/api/v1/sensors/seed-demo-readings", nil, nil, &seeded); err != nil {
		fmt.Println("Demo readings failed:", err)
		return nil
	}
	fmt.Printf("Demo readings: %v\n", seeded)
	return nil
}

func runVerifyDemo(args []string) error {
	fs := flag.NewFlagSet("verify-demo", flag.ExitOnError)
	base, login, password := apiFlags(fs, "http://127.0.0.1:8000")
	_ = fs.Parse(args)
	c := newAPIClient(*base, false)
	if err := c.login(*login, *password); err != nil {
		return err
	}
	var seeded map[string]any
	status, err := c.do("POST", "/api/v1/sensors/seed-demo-readings", nil, nil, &seeded)
	fmt.Println("seed status:", status, seeded, errString(err))

	sensors, err := c.sensors()
	if err != nil {
		return err
	}
	var targets []sensorRow
	for _, s := range sensors {
		if demoSensorNames[s.Name] {
			targets = append(targets, s)
		}
	}
	fmt.Print("target sensors: [")
	for i, s := range targets {
		if i > 0 {
			fmt.Print(", ")
		}
		fmt.Printf("(%d, '%s')", s.ID, s.Name)
	}
	fmt.Println("]")
	now := time.Now().UTC()
	start := now.Add(-time.Hour)
	for _, s := range targets {
		var resp struct {
			Series []struct {
				Points []any `json:"points"`
			} `json:"series"`
		}
		q := url.Values{"from": {jsonx.FormatISO(start)}, "to": {jsonx.FormatISO(now)},
			"sensor_ids": {fmt.Sprint(s.ID)}, "bucket": {"raw"}}
		if _, err := c.do("GET", "/api/v1/readings", q, nil, &resp); err != nil {
			return err
		}
		count := 0
		for _, ser := range resp.Series {
			count += len(ser.Points)
		}
		fmt.Printf("  %s: %d points (last hour)\n", s.Name, count)
	}
	return nil
}

func errString(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}

func runSmoke(args []string) error {
	fs := flag.NewFlagSet("smoke", flag.ExitOnError)
	base, login, password := apiFlags(fs, "http://127.0.0.1:8000")
	_ = fs.Parse(args)
	check := func(cond bool, format string, a ...any) error {
		if !cond {
			return fmt.Errorf("FAILED: "+format, a...)
		}
		return nil
	}
	stamp := time.Now().Unix()
	user := fmt.Sprintf("smoke_user_%d", stamp)
	anon := newAPIClient(*base, false)

	var avail struct {
		Available bool `json:"available"`
	}
	status, err := anon.do("GET", "/api/v1/auth/check-login", url.Values{"login": {user}}, nil, &avail)
	if e := check(err == nil && status == 200 && avail.Available, "check-login: %d %v", status, err); e != nil {
		return e
	}
	var reg struct {
		Role string `json:"role"`
	}
	status, err = anon.do("POST", "/api/v1/auth/register", nil, map[string]string{"login": user, "password": "Pass1234"}, &reg)
	if e := check(err == nil && status == 201 && reg.Role == "viewer", "register: %d %v", status, err); e != nil {
		return e
	}
	status, _ = anon.do("POST", "/api/v1/auth/register", nil, map[string]string{"login": user, "password": "12345678"}, nil)
	if e := check(status == 400 || status == 422 || status == 409, "weak password register returned %d", status); e != nil {
		return e
	}

	c := newAPIClient(*base, false)
	if err := c.login(*login, *password); err != nil {
		return err
	}
	if _, err := c.do("GET", "/api/v1/auth/me", nil, nil, nil); err != nil {
		return fmt.Errorf("FAILED: /auth/me: %w", err)
	}
	var users []struct {
		ID    int64  `json:"id"`
		Login string `json:"login"`
	}
	if _, err := c.do("GET", "/api/v1/users", nil, nil, &users); err != nil {
		return fmt.Errorf("FAILED: /users: %w", err)
	}
	var smokeID int64
	for _, u := range users {
		if u.Login == user {
			smokeID = u.ID
		}
	}
	if e := check(smokeID != 0, "registered user not listed"); e != nil {
		return e
	}
	if _, err := c.do("POST", fmt.Sprintf("/api/v1/users/%d/promote", smokeID), nil, nil, nil); err != nil {
		return fmt.Errorf("FAILED: promote: %w", err)
	}
	if _, err := c.do("POST", fmt.Sprintf("/api/v1/users/%d/demote", smokeID), nil, nil, nil); err != nil {
		return fmt.Errorf("FAILED: demote: %w", err)
	}
	var ws struct {
		ID int64 `json:"id"`
	}
	if status, err := c.do("POST", "/api/v1/workshops", nil, map[string]string{"name": "Smoke WS", "color": "#AABBCC"}, &ws); err != nil || status != 201 {
		return fmt.Errorf("FAILED: create workshop: %d %v", status, err)
	}
	var site struct {
		ID int64 `json:"id"`
	}
	if status, err := c.do("POST", "/api/v1/sites", nil, map[string]any{"name": "Smoke Site", "workshop_id": ws.ID, "color": "#112233"}, &site); err != nil || status != 201 {
		return fmt.Errorf("FAILED: create site: %d %v", status, err)
	}
	var sensor struct {
		Sensor struct {
			ID int64 `json:"id"`
		} `json:"sensor"`
	}
	if status, err := c.do("POST", "/api/v1/sensors", nil, map[string]any{
		"name": "Smoke Sensor", "device_id": fmt.Sprintf("SMOKE-%d", stamp), "site_id": site.ID, "color": "#445566",
	}, &sensor); err != nil || status != 201 {
		return fmt.Errorf("FAILED: create sensor: %d %v", status, err)
	}
	var audit struct {
		CreatedByLogin *string `json:"created_by_login"`
	}
	if _, err := c.do("GET", fmt.Sprintf("/api/v1/sensors/%d/audit", sensor.Sensor.ID), nil, nil, &audit); err != nil {
		return fmt.Errorf("FAILED: audit: %w", err)
	}
	if e := check(audit.CreatedByLogin != nil && *audit.CreatedByLogin == *login, "audit created_by_login mismatch"); e != nil {
		return e
	}
	fmt.Println("All smoke tests passed")
	return nil
}

var tokenDefineRe = regexp.MustCompile(`#define HC_DEVICE_TOKEN "([^"]+)"`)

func runPrepareESPSecrets(args []string) error {
	fs := flag.NewFlagSet("prepare-esp-secrets", flag.ExitOnError)
	base := fs.String("api", strings.TrimRight(envOr("API_PUBLIC_BASE_URL", "http://localhost:8000"), "/"), "API base URL (default $API_PUBLIC_BASE_URL)")
	login := fs.String("login", envOr("ADMIN_LOGIN", "admin"), "admin login")
	password := fs.String("password", envOr("ADMIN_PASSWORD", "admin"), "admin password")
	deviceID := fs.String("device-id", "", "sensor device_id (default: first sensor)")
	rotate := fs.Bool("rotate", false, "rotate the device token via API and write the new one (invalidates the old token)")
	out := fs.String("out", filepath.Join(repoRoot(), "firmware", "src", "secrets.h"), "output file")
	_ = fs.Parse(args)

	c := newAPIClient(*base, true)
	if err := c.login(*login, *password); err != nil {
		return err
	}
	sensors, err := c.sensors()
	if err != nil {
		return err
	}
	if len(sensors) == 0 {
		return errors.New("no sensors in database — create one in admin UI first")
	}
	sensor := sensors[0]
	if *deviceID != "" {
		found := false
		for _, s := range sensors {
			if s.DeviceID == *deviceID {
				sensor, found = s, true
			}
		}
		if !found {
			return fmt.Errorf("sensor %q not found", *deviceID)
		}
	}
	token, ingestURL, err := c.deviceCredentials(sensor.ID, *rotate)
	if err != nil {
		return err
	}
	if token == "" {
		token = strings.TrimSpace(os.Getenv("DEVICE_TOKEN"))
	}
	if token == "" {
		if data, err := os.ReadFile(*out); err == nil {
			if m := tokenDefineRe.FindSubmatch(data); m != nil {
				token = string(m[1])
			}
		}
	}
	if token == "" {
		return errors.New("device token not available from API (hashed at rest). " +
			"Use --rotate, set DEVICE_TOKEN in .env or keep the existing firmware/src/secrets.h")
	}
	content := "#pragma once\n// Auto-generated by tektool prepare-esp-secrets — do not commit\n\n" +
		fmt.Sprintf("#define HC_SERVER_URL \"%s\"\n#define HC_DEVICE_TOKEN \"%s\"\n", ingestURL, token)
	if err := os.WriteFile(*out, []byte(content), 0o600); err != nil {
		return err
	}
	fmt.Println("Wrote", *out)
	fmt.Println("ingest_url:", ingestURL)
	fmt.Printf("sensor: %s (id=%d)\n", sensor.Name, sensor.ID)
	return nil
}
