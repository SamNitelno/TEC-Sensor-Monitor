// Package ws implements the realtime broadcast hub behind GET /ws.
package ws

import (
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"time"

	"github.com/coder/websocket"

	"tek-sensor-monitor/backend/internal/jsonx"
)

// PingInterval: the server sends {"type":"ping"} after this much client silence.
const PingInterval = 60 * time.Second

type client struct {
	conn *websocket.Conn
	send chan []byte
}

// Hub fans out JSON messages to every connected client.
type Hub struct {
	mu      sync.Mutex
	clients map[*client]struct{}
	log     *slog.Logger
}

func NewHub(log *slog.Logger) *Hub {
	return &Hub{clients: map[*client]struct{}{}, log: log}
}

// Count returns the number of connected clients.
func (h *Hub) Count() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return len(h.clients)
}

func (h *Hub) add(c *client) {
	h.mu.Lock()
	h.clients[c] = struct{}{}
	h.mu.Unlock()
}

func (h *Hub) remove(c *client) {
	h.mu.Lock()
	if _, ok := h.clients[c]; ok {
		delete(h.clients, c)
		close(c.send)
	}
	h.mu.Unlock()
}

// Broadcast serialises msg once and queues it for every client; a client
// whose queue is full is dropped (it reconnects on its own).
func (h *Hub) Broadcast(msg any) {
	payload, err := json.Marshal(msg)
	if err != nil {
		h.log.Error("ws_marshal_failed", "error", err)
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	for c := range h.clients {
		select {
		case c.send <- payload:
		default:
			delete(h.clients, c)
			close(c.send)
			go c.conn.Close(websocket.StatusPolicyViolation, "slow consumer")
		}
	}
}

// Serve runs an accepted connection until the client disconnects.
func (h *Hub) Serve(ctx context.Context, conn *websocket.Conn) {
	c := &client{conn: conn, send: make(chan []byte, 256)}
	h.add(c)
	h.log.Info("ws_client_connected")
	defer func() {
		h.remove(c)
		_ = conn.CloseNow()
		h.log.Info("ws_client_disconnected")
	}()

	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	// Reader: any client frame resets the ping timer; content is ignored.
	activity := make(chan struct{}, 1)
	go func() {
		defer cancel()
		for {
			if _, _, err := conn.Read(ctx); err != nil {
				return
			}
			select {
			case activity <- struct{}{}:
			default:
			}
		}
	}()

	ping, _ := json.Marshal(map[string]string{"type": "ping"})
	timer := time.NewTimer(PingInterval)
	defer timer.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-activity:
			if !timer.Stop() {
				<-timer.C
			}
			timer.Reset(PingInterval)
		case <-timer.C:
			if !h.write(ctx, conn, ping) {
				return
			}
			timer.Reset(PingInterval)
		case msg, ok := <-c.send:
			if !ok || !h.write(ctx, conn, msg) {
				return
			}
		}
	}
}

func (h *Hub) write(ctx context.Context, conn *websocket.Conn, msg []byte) bool {
	wctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	return conn.Write(wctx, websocket.MessageText, msg) == nil
}

// ReadingMessage is the "reading" event payload.
type ReadingMessage struct {
	Type     string        `json:"type"`
	SensorID int64         `json:"sensor_id"`
	CurrentA jsonx.Float   `json:"current_a"`
	PowerW   *jsonx.Float  `json:"power_w"`
	TS       jsonx.ISOTime `json:"ts"`
}

// StatusMessage is the "sensor_status" event payload.
type StatusMessage struct {
	Type     string         `json:"type"`
	SensorID int64          `json:"sensor_id"`
	Status   string         `json:"status"`
	LastSeen *jsonx.ISOTime `json:"last_seen"`
}

func (h *Hub) BroadcastReading(sensorID int64, currentA float64, powerW *float64, ts time.Time) {
	h.Broadcast(ReadingMessage{
		Type: "reading", SensorID: sensorID, CurrentA: jsonx.Float(currentA),
		PowerW: jsonx.FloatPtr(powerW), TS: jsonx.ISOTime{Time: ts},
	})
}

func (h *Hub) BroadcastSensorStatus(sensorID int64, status string, lastSeen *time.Time) {
	h.Broadcast(StatusMessage{
		Type: "sensor_status", SensorID: sensorID, Status: status, LastSeen: jsonx.NewISOTimePtr(lastSeen),
	})
}
