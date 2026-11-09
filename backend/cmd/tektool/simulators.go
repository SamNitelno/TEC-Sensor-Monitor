package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"math"
	"math/rand/v2"
	"net/http"
	"os"
	"os/signal"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"

	"tek-sensor-monitor/backend/internal/jsonx"
)

// currentGenerator: base load + noise with occasional idle (zero) periods.
type currentGenerator struct {
	baseLoad      float64
	idleRemaining int
}

func newCurrentGenerator() *currentGenerator {
	return &currentGenerator{baseLoad: 2.5 + rand.Float64()*3.5}
}

func (g *currentGenerator) nextCurrent() float64 {
	if g.idleRemaining > 0 {
		g.idleRemaining--
		return 0
	}
	if rand.Float64() < 0.05 {
		g.idleRemaining = 3 + rand.IntN(10)
		return 0
	}
	if rand.Float64() < 0.02 {
		g.baseLoad = 2.5 + rand.Float64()*3.5
	}
	return math.Max(0, g.baseLoad+rand.NormFloat64()*0.15)
}

// nextPower: plausible active power for ~230 V AC.
func (g *currentGenerator) nextPower(currentA float64) float64 {
	if currentA <= 0.05 {
		return 0
	}
	voltage := 225 + rand.Float64()*10
	pf := 0.92 + rand.Float64()*0.07
	return math.Max(0, voltage*currentA*pf)
}

func round(v float64, digits int) float64 {
	p := math.Pow(10, float64(digits))
	return math.RoundToEven(v*p) / p
}

var errUnrecoverable = errors.New("unrecoverable error or invalid token")

func sendReading(client *http.Client, url, token string, current, power float64, maxRetries int) error {
	payload := map[string]any{
		"current_a": round(current, 3),
		"ts":        jsonx.FormatISO(time.Now()),
		"power_w":   round(power, 1),
	}
	data, _ := json.Marshal(payload)
	for attempt := 1; attempt <= maxRetries; attempt++ {
		req, _ := http.NewRequest(http.MethodPost, url, bytes.NewReader(data))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Device-Token", token)
		resp, err := client.Do(req)
		now := jsonx.FormatISO(time.Now())
		if err == nil {
			body, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			if resp.StatusCode < 300 {
				fmt.Printf("[%s] %d %s\n", now, resp.StatusCode, body)
				return nil
			}
			fmt.Fprintf(os.Stderr, "[%s] HTTP %d: %s\n", now, resp.StatusCode, body)
			if resp.StatusCode == http.StatusUnauthorized {
				return errUnrecoverable
			}
		} else {
			fmt.Fprintf(os.Stderr, "[%s] Network error (attempt %d/%d): %v\n", now, attempt, maxRetries, err)
		}
		if attempt < maxRetries {
			time.Sleep(time.Duration(math.Min(math.Pow(2, float64(attempt)), 30)) * time.Second)
		}
	}
	return errUnrecoverable
}

func runESPSim(args []string) error {
	fs := flag.NewFlagSet("esp-sim", flag.ExitOnError)
	url := fs.String("url", "http://localhost:8000/api/v1/ingest", "ingest endpoint URL")
	token := fs.String("token", "", "device API token (X-Device-Token), required")
	interval := fs.Float64("interval", 5.0, "seconds between readings")
	count := fs.Int("count", 0, "stop after N readings (0 = run until Ctrl+C)")
	_ = fs.Parse(args)
	if *token == "" {
		return errors.New("--token is required")
	}
	client := &http.Client{Timeout: 10 * time.Second, Transport: &http.Transport{Proxy: nil}}
	gen := newCurrentGenerator()
	fmt.Printf("Sending telemetry to %s every %gs (Ctrl+C to stop)\n", *url, *interval)
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt)
	for sent := 0; *count == 0 || sent < *count; sent++ {
		current := gen.nextCurrent()
		power := gen.nextPower(current)
		if err := sendReading(client, *url, *token, current, power, 5); err != nil {
			return fmt.Errorf("stopping: %w", err)
		}
		select {
		case <-stop:
			return nil
		case <-time.After(time.Duration(*interval * float64(time.Second))):
		}
	}
	return nil
}

func runMQTTSim(args []string) error {
	fs := flag.NewFlagSet("mqtt-sim", flag.ExitOnError)
	deviceID := fs.String("device-id", "", "sensor device_id from the admin UI, required")
	host := fs.String("host", "localhost", "MQTT broker host")
	port := fs.Int("port", 1883, "MQTT broker port")
	user := fs.String("username", envOr("MQTT_USERNAME", ""), "MQTT username (default $MQTT_USERNAME)")
	pass := fs.String("password", envOr("MQTT_PASSWORD", ""), "MQTT password (default $MQTT_PASSWORD)")
	interval := fs.Float64("interval", 5.0, "seconds between messages")
	current := fs.Float64("current", 0.0, "fixed current_a (A)")
	power := fs.Float64("power", 0.0, "fixed power_w (W)")
	simulate := fs.Bool("simulate", false, "sine-wave demo values")
	count := fs.Int("count", 0, "stop after N messages (0 = run until Ctrl+C)")
	_ = fs.Parse(args)
	if *deviceID == "" {
		return errors.New("--device-id is required")
	}
	telemetryTopic := "sensors/" + *deviceID + "/telemetry"
	statusTopic := "sensors/" + *deviceID + "/status"

	opts := mqtt.NewClientOptions().
		AddBroker(fmt.Sprintf("tcp://%s:%d", *host, *port)).
		SetClientID("sim-"+*deviceID).
		SetKeepAlive(30*time.Second).
		SetWill(statusTopic, `{"status": "offline"}`, 1, true)
	if *user != "" {
		opts.SetUsername(*user)
	}
	if *pass != "" {
		opts.SetPassword(*pass)
	}
	client := mqtt.NewClient(opts)
	if tok := client.Connect(); tok.Wait() && tok.Error() != nil {
		return fmt.Errorf("connect: %w", tok.Error())
	}
	defer client.Disconnect(250)
	client.Publish(statusTopic, 1, true, `{"status": "online"}`).Wait()
	fmt.Printf("Publishing to %s every %gs (Ctrl+C to stop)\n", telemetryTopic, *interval)

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt)
	for tick := 0; *count == 0 || tick < *count; tick++ {
		c, p := *current, *power
		if *simulate {
			c = 5.0 + 4.0*math.Sin(float64(tick)/10.0) + (rand.Float64()*0.2 - 0.1)
			p = c * 230.0
		}
		payload, _ := json.Marshal(map[string]any{
			"current_a": round(c, 3),
			"power_w":   round(p, 1),
			"ts":        jsonx.FormatISO(time.Now()),
		})
		client.Publish(telemetryTopic, 0, false, payload).Wait()
		select {
		case <-stop:
			return nil
		case <-time.After(time.Duration(*interval * float64(time.Second))):
		}
	}
	return nil
}
