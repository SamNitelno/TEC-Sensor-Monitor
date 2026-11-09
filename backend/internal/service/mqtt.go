package service

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"

	"tek-sensor-monitor/backend/internal/store"
)

// ParseMQTTTopic splits sensors/<device_id>/<channel>.
func ParseMQTTTopic(topic string) (deviceID, channel string, ok bool) {
	parts := strings.Split(topic, "/")
	if len(parts) == 3 && parts[0] == "sensors" {
		return parts[1], parts[2], true
	}
	return "", "", false
}

// ParseMQTTTelemetry validates a telemetry payload with the same bounds as
// HTTP ingest. Unlike the Python subscriber, a bad message is skipped instead
// of tearing down the MQTT connection.
func (s *Service) ParseMQTTTelemetry(payload map[string]any) (*IngestReading, error) {
	rawCurrent, ok := payload["current_a"]
	if !ok || rawCurrent == nil {
		return nil, fmt.Errorf("missing current_a")
	}
	current, err := anyToFloat(rawCurrent)
	if err != nil {
		return nil, fmt.Errorf("current_a: %w", err)
	}
	if current < s.Cfg.IngestMinCurrentA || current > s.Cfg.IngestMaxCurrentA {
		return nil, fmt.Errorf("current_a out of range")
	}
	r := &IngestReading{CurrentA: current}
	if raw, ok := payload["power_w"]; ok && raw != nil {
		p, err := anyToFloat(raw)
		if err != nil {
			return nil, fmt.Errorf("power_w: %w", err)
		}
		if p < s.Cfg.IngestMinPowerW || p > s.Cfg.IngestMaxPowerW {
			return nil, fmt.Errorf("power_w out of range")
		}
		r.PowerW = &p
	}
	if raw, ok := payload["ts"]; ok && raw != nil && raw != "" {
		str, isStr := raw.(string)
		if !isStr {
			return nil, fmt.Errorf("ts must be a string")
		}
		ts, err := ParseDateTime(str)
		if err != nil {
			return nil, fmt.Errorf("ts: %w", err)
		}
		r.TS = &ts
	}
	return r, nil
}

func anyToFloat(v any) (float64, error) {
	switch x := v.(type) {
	case float64:
		return x, nil
	case string:
		var f float64
		if _, err := fmt.Sscan(strings.TrimSpace(x), &f); err != nil {
			return 0, fmt.Errorf("not a number")
		}
		return f, nil
	case bool:
		if x {
			return 1, nil
		}
		return 0, nil
	}
	return 0, fmt.Errorf("not a number")
}

func (s *Service) handleMQTTMessage(ctx context.Context, topic string, body []byte) {
	deviceID, channel, ok := ParseMQTTTopic(topic)
	if !ok {
		return
	}
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		s.Log.Warn("mqtt_invalid_payload", "topic", topic)
		return
	}
	sensor, err := store.GetSensorByDeviceID(ctx, s.Pool, deviceID)
	if err != nil {
		s.Log.Error("mqtt_handler_error", "topic", topic, "error", err)
		return
	}
	switch channel {
	case "telemetry":
		if sensor == nil {
			s.Log.Warn("mqtt_unknown_device", "device_id", deviceID)
			return
		}
		reading, err := s.ParseMQTTTelemetry(payload)
		if err != nil {
			s.Log.Warn("mqtt_invalid_telemetry", "device_id", deviceID, "error", err.Error())
			return
		}
		if _, err := s.Ingest(ctx, sensor, []IngestReading{*reading}); err != nil {
			s.Log.Error("mqtt_ingest_failed", "device_id", deviceID, "error", err)
		}
	case "status":
		if status, _ := payload["status"].(string); status != "offline" || sensor == nil {
			return
		}
		if err := s.HandleMQTTLWTOffline(ctx, sensor); err != nil {
			s.Log.Error("mqtt_lwt_failed", "device_id", deviceID, "error", err)
			return
		}
		s.Log.Info("mqtt_lwt_offline", "device_id", deviceID, "sensor_id", sensor.ID)
	}
}

// RunMQTTSubscriber connects to the broker (with exponential reconnect
// backoff 1s..60s) and processes messages sequentially until ctx ends.
func (s *Service) RunMQTTSubscriber(ctx context.Context) {
	if !s.Cfg.MQTTEnabled {
		return
	}
	messages := make(chan mqtt.Message, 1024)
	opts := mqtt.NewClientOptions().
		AddBroker(fmt.Sprintf("tcp://%s:%d", s.Cfg.MQTTHost, s.Cfg.MQTTPort)).
		SetClientID(fmt.Sprintf("tek-backend-%d", time.Now().UnixNano())).
		SetKeepAlive(60 * time.Second).
		SetAutoReconnect(true).
		SetConnectRetry(true).
		SetConnectRetryInterval(time.Second).
		SetMaxReconnectInterval(60 * time.Second).
		SetCleanSession(true)
	if s.Cfg.MQTTUsername != "" {
		opts.SetUsername(s.Cfg.MQTTUsername)
	}
	if s.Cfg.MQTTPassword != "" {
		opts.SetPassword(s.Cfg.MQTTPassword)
	}
	handler := func(_ mqtt.Client, m mqtt.Message) {
		select {
		case messages <- m:
		case <-ctx.Done():
		}
	}
	opts.SetOnConnectHandler(func(c mqtt.Client) {
		for _, topic := range []string{"sensors/+/telemetry", "sensors/+/status"} {
			if tok := c.Subscribe(topic, 0, handler); tok.Wait() && tok.Error() != nil {
				s.Log.Error("mqtt_subscribe_failed", "topic", topic, "error", tok.Error())
			}
		}
		s.Log.Info("mqtt_connected", "host", s.Cfg.MQTTHost, "port", s.Cfg.MQTTPort)
	})
	opts.SetConnectionLostHandler(func(_ mqtt.Client, err error) {
		s.Log.Warn("mqtt_connection_lost", "error", err.Error())
	})
	client := mqtt.NewClient(opts)
	client.Connect()
	defer client.Disconnect(250)

	for {
		select {
		case <-ctx.Done():
			return
		case m := <-messages:
			s.handleMQTTMessage(ctx, m.Topic(), m.Payload())
		}
	}
}
