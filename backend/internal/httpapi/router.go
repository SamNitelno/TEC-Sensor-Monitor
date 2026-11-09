// Package httpapi exposes the REST API (/api/v1), /health and /ws with the
// same contract the FastAPI backend had.
package httpapi

import (
	"log/slog"
	"net/http"
	"strings"

	"github.com/coder/websocket"
	"github.com/go-chi/chi/v5"

	"tek-sensor-monitor/backend/internal/service"
)

type API struct {
	svc     *service.Service
	log     *slog.Logger
	limiter *rateLimiter
	router  chi.Router
}

// handlerFunc returns (status, payload, error); payload nil + 204 -> empty.
type handlerFunc func(c *rc) (int, any, error)

func (a *API) wrap(h handlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		c := &rc{api: a, w: w, r: r}
		status, payload, err := h(c)
		if err != nil {
			writeError(w, a.log, err)
			return
		}
		if status == http.StatusNoContent {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		writeJSON(w, status, payload)
	}
}

// New builds the HTTP handler.
func New(svc *service.Service, log *slog.Logger) http.Handler {
	a := &API{svc: svc, log: log, limiter: newRateLimiter()}

	origins := svc.Cfg.CORSOriginList()
	if len(origins) == 0 {
		origins = []string{strings.TrimRight(svc.Cfg.APIPublicBaseURL, "/")}
	}

	r := chi.NewRouter()
	r.Use(requestLogger(log), cors(origins), recoverer(log))
	r.NotFound(a.notFound)
	r.MethodNotAllowed(func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusMethodNotAllowed, detail{Detail: "Method Not Allowed"})
	})

	r.Get("/health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	r.Get("/ws", a.websocket)

	r.Route("/api/v1", func(r chi.Router) {
		r.Get("/auth/capabilities", a.wrap(a.capabilities))
		r.Post("/auth/login", a.wrap(a.login))
		r.Post("/auth/register", a.wrap(a.register))
		r.Get("/auth/check-login", a.wrap(a.checkLogin))
		r.Get("/auth/me", a.wrap(a.me))
		r.Patch("/auth/me", a.wrap(a.updateMe))
		r.Post("/auth/me/password", a.wrap(a.changePassword))
		r.Post("/auth/password-reset/request", a.wrap(a.passwordResetRequest))
		r.Post("/auth/password-reset/confirm", a.wrap(a.passwordResetConfirm))
		r.Post("/auth/me/contact/send-codes", a.wrap(a.sendContactCodes))
		r.Post("/auth/me/contact/verify-email", a.wrap(a.verifyContact("email")))
		r.Post("/auth/me/contact/verify-phone", a.wrap(a.verifyContact("phone")))

		r.Get("/users", a.wrap(a.listUsers))
		r.Post("/users/{user_id}/reset-password", a.wrap(a.adminResetPassword))
		r.Post("/users/{user_id}/promote", a.wrap(a.promoteUser))
		r.Post("/users/{user_id}/demote", a.wrap(a.demoteUser))

		r.Get("/notifications", a.wrap(a.listNotifications))
		r.Get("/notifications/unread-count", a.wrap(a.unreadCount))
		r.Post("/notifications/ack-all", a.wrap(a.ackAll))
		r.Post("/notifications/{notification_id}/ack", a.wrap(a.ackNotification))

		r.Post("/ingest", a.wrap(a.ingest))

		r.Get("/sensors", a.wrap(a.listSensors))
		r.Post("/sensors", a.wrap(a.createSensor))
		r.Post("/sensors/notifications/bulk", a.wrap(a.sensorsBulkNotifications))
		r.Post("/sensors/seed-demo-readings", a.wrap(a.seedDemoReadings))
		r.Get("/sensors/{sensor_id}", a.wrap(a.getSensor))
		r.Patch("/sensors/{sensor_id}", a.wrap(a.updateSensor))
		r.Delete("/sensors/{sensor_id}", a.wrap(a.deleteSensor))
		r.Get("/sensors/{sensor_id}/audit", a.wrap(a.sensorAudit))
		r.Get("/sensors/{sensor_id}/provisioning-token", a.wrap(a.provisioningToken))
		r.Post("/sensors/{sensor_id}/rotate-token", a.wrap(a.rotateToken))
		r.Get("/sensors/{sensor_id}/readings", a.wrap(a.sensorReadings))

		r.Get("/readings", a.wrap(a.groupedReadings))

		r.Get("/downtime/events", a.wrap(a.downtimeEvents))
		r.Get("/downtime/summary", a.wrap(a.downtimeSummary))

		r.Get("/sites", a.wrap(a.listSites))
		r.Post("/sites", a.wrap(a.createSite))
		r.Post("/sites/notifications/bulk", a.wrap(a.sitesBulkNotifications))
		r.Patch("/sites/{site_id}", a.wrap(a.updateSite))
		r.Delete("/sites/{site_id}", a.wrap(a.deleteSite))

		r.Get("/workshops", a.wrap(a.listWorkshops))
		r.Post("/workshops", a.wrap(a.createWorkshop))
		r.Post("/workshops/notifications/bulk", a.wrap(a.workshopsBulkNotifications))
		r.Patch("/workshops/{workshop_id}", a.wrap(a.updateWorkshop))
		r.Delete("/workshops/{workshop_id}", a.wrap(a.deleteWorkshop))
	})
	a.router = r
	return r
}

// notFound returns FastAPI's 404, or a 307 redirect to the slash-less path
// when that path exists (Starlette's redirect_slashes).
func (a *API) notFound(w http.ResponseWriter, r *http.Request) {
	if p := r.URL.Path; len(p) > 1 && strings.HasSuffix(p, "/") {
		trimmed := strings.TrimRight(p, "/")
		rctx := chi.NewRouteContext()
		if a.router != nil && a.router.Match(rctx, r.Method, trimmed) {
			target := *r.URL
			target.Path = trimmed
			scheme := "http"
			if r.TLS != nil {
				scheme = "https"
			}
			target.Scheme, target.Host = scheme, r.Host
			// Starlette's RedirectResponse: Location only, empty body.
			w.Header().Set("Location", target.String())
			w.WriteHeader(http.StatusTemporaryRedirect)
			return
		}
	}
	writeJSON(w, http.StatusNotFound, detail{Detail: "Not Found"})
}

// websocket authenticates ?token= before accepting; a missing/invalid token
// is rejected during the handshake (HTTP 403), like uvicorn did for a close
// with 1008 before accept.
func (a *API) websocket(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	if token == "" {
		http.Error(w, "", http.StatusForbidden)
		return
	}
	if _, err := a.svc.UserFromToken(r.Context(), token); err != nil {
		http.Error(w, "", http.StatusForbidden)
		return
	}
	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		InsecureSkipVerify: true,
		CompressionMode:    websocket.CompressionDisabled,
	})
	if err != nil {
		return
	}
	a.svc.Hub.Serve(r.Context(), conn)
}
