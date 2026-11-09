package httpapi

import (
	"fmt"
	"net/http"

	"tek-sensor-monitor/backend/internal/service"
)

var bucketValues = []string{"raw", "minute", "hour", "day"}

func (a *API) ingest(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	sensor, err := a.svc.SensorFromDeviceToken(c.r.Context(), c.r.Header.Get("X-Device-Token"))
	if err != nil {
		return 0, nil, err
	}
	readings := a.parseIngestPayload(c)
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	if err := c.rateLimit("ingest", a.svc.Cfg.IngestRateLimit); err != nil {
		return 0, nil, err
	}
	accepted, err := a.svc.Ingest(c.r.Context(), sensor, readings)
	if err != nil {
		return 0, nil, err
	}
	a.log.Info("ingest_accepted", "sensor_id", sensor.ID, "accepted", accepted)
	return http.StatusAccepted, service.IngestResponse{Accepted: accepted}, nil
}

// parseIngestPayload accepts one reading object or a JSON array of them.
func (a *API) parseIngestPayload(c *rc) []service.IngestReading {
	cfg := a.svc.Cfg
	if !c.hasBody {
		c.addErr(fieldError{Type: "missing", Loc: []any{"body"}, Msg: "Field required", Input: nil})
		return nil
	}
	var items []any
	if list, ok := c.bodyAny.([]any); ok && !c.notJSON {
		items = list
	} else {
		items = []any{c.bodyAny}
	}
	if len(items) > cfg.IngestMaxBatchSize {
		c.addErr(fieldError{Type: "value_error", Loc: []any{"body"},
			Msg:   fmt.Sprintf("Value error, Batch size exceeds maximum of %d", cfg.IngestMaxBatchSize),
			Input: c.bodyAny, Ctx: map[string]any{"error": map[string]any{}}})
		return nil
	}
	out := make([]service.IngestReading, 0, len(items))
	for i, item := range items {
		m, ok := item.(map[string]any)
		if !ok || c.notJSON {
			c.addErr(fieldError{Type: "model_type", Loc: []any{"body", i},
				Msg:   "Input should be a valid dictionary or instance of ReadingIn",
				Input: jsonInput(item), Ctx: map[string]any{"class_name": "ReadingIn"}})
			continue
		}
		o := &obj{c: c, fields: m, input: m, loc: []any{"body", i}, ok: true}
		current, _ := o.number("current_a", true, floatBound(cfg.IngestMinCurrentA), floatBound(cfg.IngestMaxCurrentA))
		power, _ := o.number("power_w", false, floatBound(cfg.IngestMinPowerW), floatBound(cfg.IngestMaxPowerW))
		ts := o.dateTime("ts")
		if current != nil {
			out = append(out, service.IngestReading{CurrentA: *current, PowerW: power, TS: ts})
		}
	}
	return out
}

func (a *API) listSensors(c *rc) (int, any, error) {
	if _, err := c.viewer(); err != nil {
		return 0, nil, err
	}
	siteID := c.queryInt("site_id")
	workshopID := c.queryInt("workshop_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.ListSensors(c.r.Context(), siteID, workshopID)
	return http.StatusOK, resp, err
}

func (a *API) sensorsBulkNotifications(c *rc) (int, any, error) {
	return a.bulkNotifications(c, a.svc.SetAllSensorNotifications)
}

func (a *API) sitesBulkNotifications(c *rc) (int, any, error) {
	return a.bulkNotifications(c, a.svc.SetAllSiteNotifications)
}

func (a *API) workshopsBulkNotifications(c *rc) (int, any, error) {
	return a.bulkNotifications(c, a.svc.SetAllWorkshopNotifications)
}

func (a *API) bulkNotifications(c *rc, fn func(ctx contextT, enabled bool) (*service.BulkNotificationsResponse, error)) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	enabled := c.object().boolRequired("enabled")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := fn(c.r.Context(), enabled)
	return http.StatusOK, resp, err
}

func (a *API) seedDemoReadings(c *rc) (int, any, error) {
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.SeedDemoReadings(c.r.Context())
	return http.StatusOK, resp, err
}

func (a *API) getSensor(c *rc) (int, any, error) {
	if _, err := c.viewer(); err != nil {
		return 0, nil, err
	}
	id := c.pathInt("sensor_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.GetSensor(c.r.Context(), id)
	return http.StatusOK, resp, err
}

func (a *API) sensorAudit(c *rc) (int, any, error) {
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	id := c.pathInt("sensor_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.SensorAudit(c.r.Context(), id)
	return http.StatusOK, resp, err
}

func (a *API) provisioningToken(c *rc) (int, any, error) {
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	id := c.pathInt("sensor_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.ProvisioningToken(c.r.Context(), id)
	return http.StatusOK, resp, err
}

func (a *API) rotateToken(c *rc) (int, any, error) {
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	id := c.pathInt("sensor_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.RotateToken(c.r.Context(), id)
	return http.StatusOK, resp, err
}

func (a *API) createSensor(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	actor, err := c.admin()
	if err != nil {
		return 0, nil, err
	}
	b := c.object()
	name, _ := b.str("name", true, false, 1, 255)
	deviceID, _ := b.str("device_id", true, false, 1, 64)
	siteID, _ := b.integer("site_id", false, nil)
	color := b.color("color")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.CreateSensor(c.r.Context(), actor, service.SensorCreateRequest{
		Name: *name, DeviceID: *deviceID, SiteID: siteID, Color: color,
	})
	return http.StatusCreated, resp, err
}

func (a *API) updateSensor(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	actor, err := c.admin()
	if err != nil {
		return 0, nil, err
	}
	id := c.pathInt("sensor_id")
	b := c.object()
	var req service.SensorUpdateRequest
	req.Name, _ = b.str("name", false, true, 1, 255)
	req.SiteID, req.SiteIDSet = b.integer("site_id", false, nil)
	req.Color = b.color("color")
	req.ClearColor = b.boolean("clear_color", false)
	req.IdlePowerThresholdW, _ = b.number("idle_power_threshold_w", false, intBound(0), nil)
	req.ClearIdlePowerThreshold = b.boolean("clear_idle_power_threshold", false)
	req.IdleCurrentThresholdA, _ = b.number("idle_current_threshold_a", false, intBound(0), nil)
	req.ClearIdleCurrentThreshold = b.boolean("clear_idle_current_threshold", false)
	req.IdleDurationSeconds, _ = b.integer("idle_duration_seconds", false, int64Ptr(1))
	req.ClearIdleDuration = b.boolean("clear_idle_duration", false)
	req.NotificationsEnabled = b.optBool("notifications_enabled")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.UpdateSensor(c.r.Context(), actor, id, req)
	return http.StatusOK, resp, err
}

func (a *API) deleteSensor(c *rc) (int, any, error) {
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	id := c.pathInt("sensor_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	if err := a.svc.DeleteSensor(c.r.Context(), id); err != nil {
		return 0, nil, err
	}
	return http.StatusNoContent, nil, nil
}

func (a *API) sensorReadings(c *rc) (int, any, error) {
	if _, err := c.viewer(); err != nil {
		return 0, nil, err
	}
	id := c.pathInt("sensor_id")
	from := c.queryDateTime("from")
	to := c.queryDateTime("to")
	bucket := c.queryEnum("bucket", bucketValues)
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.SensorReadings(c.r.Context(), id, from, to, bucket)
	return http.StatusOK, resp, err
}

func (a *API) groupedReadings(c *rc) (int, any, error) {
	if _, err := c.viewer(); err != nil {
		return 0, nil, err
	}
	from := c.queryDateTime("from")
	to := c.queryDateTime("to")
	sensorIDs := c.queryIntList("sensor_ids")
	siteID := c.queryInt("site_id")
	workshopID := c.queryInt("workshop_id")
	bucket := c.queryEnum("bucket", bucketValues)
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.GroupedReadings(c.r.Context(), sensorIDs, from, to, bucket, siteID, workshopID)
	return http.StatusOK, resp, err
}

func (a *API) downtimeEvents(c *rc) (int, any, error) {
	if _, err := c.viewer(); err != nil {
		return 0, nil, err
	}
	from := c.queryDateTime("from")
	to := c.queryDateTime("to")
	sensorID := c.queryInt("sensor_id")
	siteID := c.queryInt("site_id")
	workshopID := c.queryInt("workshop_id")
	typ := c.queryEnum("type", []string{"offline", "idle"})
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.DowntimeEvents(c.r.Context(), from, to, sensorID, siteID, workshopID, typ)
	return http.StatusOK, resp, err
}

func (a *API) downtimeSummary(c *rc) (int, any, error) {
	if _, err := c.viewer(); err != nil {
		return 0, nil, err
	}
	from := c.queryDateTime("from")
	to := c.queryDateTime("to")
	sensorID := c.queryInt("sensor_id")
	siteID := c.queryInt("site_id")
	workshopID := c.queryInt("workshop_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.DowntimeSummary(c.r.Context(), from, to, sensorID, siteID, workshopID)
	return http.StatusOK, resp, err
}
