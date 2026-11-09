package service

import (
	"context"
	"sort"
	"time"

	"tek-sensor-monitor/backend/internal/jsonx"
	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/store"
)

func (s *Service) DowntimeEvents(ctx context.Context, from, to time.Time, sensorID, siteID, workshopID *int64, typ *string) (*DowntimeEventsResponse, error) {
	var ids []int64
	if sensorID != nil {
		ids = []int64{*sensorID}
	}
	rows, err := store.ListEventsInRange(ctx, s.Pool, from, to, ids, siteID, workshopID, typ)
	if err != nil {
		return nil, err
	}
	resp := &DowntimeEventsResponse{Events: make([]DowntimeEventItem, 0, len(rows))}
	for _, r := range rows {
		e := r.Event
		item := DowntimeEventItem{
			ID: e.ID, SensorID: e.SensorID, SensorName: r.SensorName,
			SiteID: r.SiteID, SiteName: r.SiteName, WorkshopID: r.WorkshopID, WorkshopName: r.WorkshopName,
			Type: e.Type, StartedAt: jsonx.NewTime(e.StartedAt), EndedAt: jsonx.NewTimePtr(e.EndedAt),
		}
		if e.EndedAt != nil {
			d := jsonx.Float(e.EndedAt.Sub(e.StartedAt).Seconds())
			item.DurationSeconds = &d
		}
		resp.Events = append(resp.Events, item)
	}
	return resp, nil
}

func clipSeconds(e *models.DowntimeEvent, from, to, now time.Time) float64 {
	start := e.StartedAt
	if from.After(start) {
		start = from
	}
	end := now
	if e.EndedAt != nil {
		end = *e.EndedAt
	}
	if to.Before(end) {
		end = to
	}
	if !end.After(start) {
		return 0
	}
	return end.Sub(start).Seconds()
}

type summaryAcc struct {
	item                    DowntimeSummaryItem
	offline, idle, totalSec float64
}

func (s *Service) DowntimeSummary(ctx context.Context, from, to time.Time, sensorID, siteID, workshopID *int64) (*DowntimeSummaryResponse, error) {
	now := s.now()
	var ids []int64
	if sensorID != nil {
		ids = []int64{*sensorID}
	}
	scopes, err := store.ListSensorScopes(ctx, s.Pool, ids, siteID, workshopID)
	if err != nil {
		return nil, err
	}
	scopeIDs := make([]int64, 0, len(scopes))
	for _, sc := range scopes {
		scopeIDs = append(scopeIDs, sc.Sensor.ID)
	}
	events, err := store.ListEventsInRange(ctx, s.Pool, from, to, scopeIDs, siteID, workshopID, nil)
	if err != nil {
		return nil, err
	}

	perSensor := map[int64]*summaryAcc{}
	order := make([]*summaryAcc, 0, len(scopes))
	for _, sc := range scopes {
		acc := &summaryAcc{item: DowntimeSummaryItem{
			SensorID: sc.Sensor.ID, SensorName: sc.Sensor.Name,
			SiteID: sc.SiteID, SiteName: sc.SiteName, WorkshopID: sc.WorkshopID, WorkshopName: sc.WorkshopName,
		}}
		perSensor[sc.Sensor.ID] = acc
		order = append(order, acc)
	}
	for i := range events {
		e := &events[i].Event
		acc := perSensor[e.SensorID]
		if acc == nil {
			continue
		}
		sec := clipSeconds(e, from, to, now)
		if e.Type == models.DowntimeOffline {
			acc.offline += sec
		} else {
			acc.idle += sec
		}
		acc.totalSec += sec
	}

	type wsAcc struct {
		item                    WorkshopDowntimeSummaryItem
		offline, idle, totalSec float64
	}
	workshops := map[int64]*wsAcc{}
	var wsOrder []*wsAcc
	for _, acc := range order {
		if acc.item.WorkshopID == nil {
			continue
		}
		w := workshops[*acc.item.WorkshopID]
		if w == nil {
			name := ""
			if acc.item.WorkshopName != nil {
				name = *acc.item.WorkshopName
			}
			w = &wsAcc{item: WorkshopDowntimeSummaryItem{WorkshopID: *acc.item.WorkshopID, WorkshopName: name}}
			workshops[*acc.item.WorkshopID] = w
			wsOrder = append(wsOrder, w)
		}
		w.offline += acc.offline
		w.idle += acc.idle
		w.totalSec += acc.totalSec
	}

	// Stable sort by name (code-point order, like Python's sorted()).
	sort.SliceStable(order, func(i, j int) bool { return order[i].item.SensorName < order[j].item.SensorName })
	sort.SliceStable(wsOrder, func(i, j int) bool { return wsOrder[i].item.WorkshopName < wsOrder[j].item.WorkshopName })

	resp := &DowntimeSummaryResponse{
		Sensors:   make([]DowntimeSummaryItem, 0, len(order)),
		Workshops: make([]WorkshopDowntimeSummaryItem, 0, len(wsOrder)),
	}
	for _, acc := range order {
		it := acc.item
		it.OfflineSeconds, it.IdleSeconds, it.TotalSeconds = jsonx.Float(acc.offline), jsonx.Float(acc.idle), jsonx.Float(acc.totalSec)
		resp.Sensors = append(resp.Sensors, it)
	}
	for _, w := range wsOrder {
		it := w.item
		it.OfflineSeconds, it.IdleSeconds, it.TotalSeconds = jsonx.Float(w.offline), jsonx.Float(w.idle), jsonx.Float(w.totalSec)
		resp.Workshops = append(resp.Workshops, it)
	}
	return resp, nil
}
