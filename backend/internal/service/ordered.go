package service

import (
	"bytes"
	"encoding/json"

	"tek-sensor-monitor/backend/internal/jsonx"
)

// orderedStrings is a JSON object that keeps insertion order (Go maps would
// sort keys; Python dicts keep insertion order).
type orderedStrings [][2]string

func (o orderedStrings) MarshalJSON() ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteByte('{')
	for i, kv := range o {
		if i > 0 {
			buf.WriteByte(',')
		}
		k, _ := json.Marshal(kv[0])
		v, _ := json.Marshal(kv[1])
		buf.Write(k)
		buf.WriteByte(':')
		buf.Write(v)
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}

type floatPair struct {
	Key   string
	Value float64
}

type orderedFloatPairs []floatPair

func (o orderedFloatPairs) MarshalJSON() ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteByte('{')
	for i, kv := range o {
		if i > 0 {
			buf.WriteByte(',')
		}
		k, _ := json.Marshal(kv.Key)
		v, _ := jsonx.Float(kv.Value).MarshalJSON()
		buf.Write(k)
		buf.WriteByte(':')
		buf.Write(v)
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}
