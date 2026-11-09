package service

import (
	"context"
	"time"

	"tek-sensor-monitor/backend/internal/apperr"
	"tek-sensor-monitor/backend/internal/jsonx"
	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/store"
)

// AutoSelectBucket picks the coarsest resolution that keeps a range within
// MaxPoints (raw readings arrive every ~5 s).
func AutoSelectBucket(from, to time.Time) string {
	d := to.Sub(from).Seconds()
	switch {
	case d <= store.MaxPoints*5:
		return "raw"
	case d/60 <= store.MaxPoints:
		return "minute"
	case d/3600 <= store.MaxPoints:
		return "hour"
	default:
		return "day"
	}
}

func toPoints(points []store.ReadingPoint) []ReadingPoint {
	out := make([]ReadingPoint, 0, len(points))
	for _, p := range points {
		out = append(out, ReadingPoint{
			Time: jsonx.NewTime(p.Time), Avg: jsonx.Float(p.Avg), Min: jsonx.Float(p.Min),
			Max: jsonx.Float(p.Max), PowerW: jsonx.FloatPtr(p.PowerW),
		})
	}
	return out
}

const fromBeforeTo = "'from' must be before 'to'"

func (s *Service) SensorReadings(ctx context.Context, sensorID int64, from, to time.Time, bucket *string) (*ReadingsResponse, error) {
	if from.After(to) {
		return nil, apperr.Unprocessable(fromBeforeTo)
	}
	if _, err := s.getSensor(ctx, s.Pool, sensorID); err != nil {
		return nil, err
	}
	resolved := AutoSelectBucket(from, to)
	if bucket != nil {
		resolved = *bucket
	}
	points, err := store.FetchReadings(ctx, s.Pool, sensorID, from, to, resolved)
	if err != nil {
		return nil, err
	}
	return &ReadingsResponse{Bucket: resolved, Points: toPoints(points)}, nil
}

func (s *Service) GroupedReadings(ctx context.Context, sensorIDs []int64, from, to time.Time, bucket *string, siteID, workshopID *int64) (*GroupedReadingsResponse, error) {
	if from.After(to) {
		return nil, apperr.Unprocessable(fromBeforeTo)
	}
	var sensors []models.Sensor
	var err error
	if len(sensorIDs) > 0 {
		sensors, err = store.GetSensorsByIDs(ctx, s.Pool, sensorIDs)
	} else {
		sensors, err = store.ListSensors(ctx, s.Pool, siteID, workshopID)
	}
	if err != nil {
		return nil, err
	}
	resp := &GroupedReadingsResponse{Series: []SensorSeries{}}
	if len(sensors) == 0 {
		return resp, nil
	}
	resolved := AutoSelectBucket(from, to)
	if bucket != nil {
		resolved = *bucket
	}
	for _, sensor := range sensors {
		points, err := store.FetchReadings(ctx, s.Pool, sensor.ID, from, to, resolved)
		if err != nil {
			return nil, err
		}
		resp.Series = append(resp.Series, SensorSeries{
			SensorID: sensor.ID, SensorName: sensor.Name, Bucket: resolved, Points: toPoints(points),
		})
	}
	return resp, nil
}
