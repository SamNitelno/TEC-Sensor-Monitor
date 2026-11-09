package main

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/joho/godotenv"

	"tek-sensor-monitor/backend/internal/config"
)

// repoRoot walks up from the working directory to the folder holding .env /
// docker-compose.yml (the monorepo root).
func repoRoot() string {
	dir, _ := os.Getwd()
	for d := dir; ; {
		if fileExists(filepath.Join(d, "docker-compose.yml")) {
			return d
		}
		parent := filepath.Dir(d)
		if parent == d {
			return dir
		}
		d = parent
	}
}

func fileExists(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir()
}

// loadDotEnv loads <repo>/.env without overriding the process environment.
func loadDotEnv() {
	_ = godotenv.Load(filepath.Join(repoRoot(), ".env"))
}

func envOr(name, def string) string {
	if v := strings.TrimSpace(os.Getenv(name)); v != "" {
		return v
	}
	return def
}

// apiClient is a small JSON client for /api/v1 (system proxies bypassed, like
// the Python tools did).
type apiClient struct {
	base  string
	token string
	http  *http.Client
}

func newAPIClient(base string, insecureTLS bool) *apiClient {
	tr := &http.Transport{Proxy: nil}
	if insecureTLS {
		tr.TLSClientConfig = &tls.Config{InsecureSkipVerify: true} //nolint:gosec // LAN self-signed certs
	}
	return &apiClient{base: strings.TrimRight(base, "/"), http: &http.Client{Timeout: 120 * time.Second, Transport: tr}}
}

type apiError struct {
	status int
	body   string
}

func (e *apiError) Error() string { return fmt.Sprintf("API error: %d %s", e.status, e.body) }

// do sends a JSON request; out may be nil. Non-2xx returns *apiError.
func (c *apiClient) do(method, path string, query url.Values, body any, out any) (int, error) {
	u := c.base + path
	if len(query) > 0 {
		u += "?" + query.Encode()
	}
	var rdr io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return 0, err
		}
		rdr = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, u, rdr)
	if err != nil {
		return 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	if c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return resp.StatusCode, &apiError{status: resp.StatusCode, body: string(data)}
	}
	if out != nil && len(data) > 0 {
		if err := json.Unmarshal(data, out); err != nil {
			return resp.StatusCode, fmt.Errorf("decode %s %s: %w", method, path, err)
		}
	}
	return resp.StatusCode, nil
}

func (c *apiClient) login(login, password string) error {
	var resp struct {
		AccessToken string `json:"access_token"`
	}
	if _, err := c.do("POST", "/api/v1/auth/login", nil, map[string]string{"login": login, "password": password}, &resp); err != nil {
		return fmt.Errorf("login as %q: %w", login, err)
	}
	c.token = resp.AccessToken
	return nil
}

type sensorRow struct {
	ID       int64  `json:"id"`
	Name     string `json:"name"`
	DeviceID string `json:"device_id"`
}

func (c *apiClient) sensors() ([]sensorRow, error) {
	var out []sensorRow
	_, err := c.do("GET", "/api/v1/sensors", nil, nil, &out)
	return out, err
}

// deviceCredentials returns (token, ingest URL) for a sensor. The API only
// reveals a device token when it is rotated (tokens are hashed at rest), so
// rotation must be requested explicitly.
func (c *apiClient) deviceCredentials(sensorID int64, rotate bool) (token, ingestURL string, err error) {
	if rotate {
		var r struct {
			APIToken  string `json:"api_token"`
			IngestURL string `json:"ingest_url"`
		}
		if _, err := c.do("POST", fmt.Sprintf("/api/v1/sensors/%d/rotate-token", sensorID), nil, nil, &r); err != nil {
			return "", "", err
		}
		return r.APIToken, r.IngestURL, nil
	}
	var p struct {
		APIToken  *string `json:"api_token"`
		IngestURL string  `json:"ingest_url"`
	}
	if _, err := c.do("GET", fmt.Sprintf("/api/v1/sensors/%d/provisioning-token", sensorID), nil, nil, &p); err != nil {
		return "", "", err
	}
	if p.APIToken != nil {
		token = *p.APIToken
	}
	return token, p.IngestURL, nil
}

// databaseURL resolves the DB connection string for tools that talk to the
// database directly. The compose service host "timescaledb" is mapped to
// localhost when it does not resolve (running on the host machine).
func databaseURL(flagValue string) (string, error) {
	raw := flagValue
	if raw == "" {
		raw = os.Getenv("DATABASE_URL")
	}
	if raw == "" {
		return "", fmt.Errorf("DATABASE_URL is not set (use --db or .env)")
	}
	u := config.NormalizeDatabaseURL(raw)
	parsed, err := url.Parse(u)
	if err == nil && parsed.Hostname() == "timescaledb" {
		if _, lookupErr := net.LookupHost("timescaledb"); lookupErr != nil {
			port := parsed.Port()
			if port == "" {
				port = "5432"
			}
			parsed.Host = "localhost:" + port
			u = parsed.String()
			fmt.Fprintln(os.Stderr, "note: host 'timescaledb' is not resolvable here, using localhost")
		}
	}
	return u, nil
}
