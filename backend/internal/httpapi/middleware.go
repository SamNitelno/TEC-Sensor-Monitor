package httpapi

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"net/http"
	"runtime/debug"
	"slices"
	"strings"

	"tek-sensor-monitor/backend/internal/apperr"
)

// writeJSON writes compact JSON with raw UTF-8 (like FastAPI's JSONResponse).
func writeJSON(w http.ResponseWriter, status int, v any) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	body := bytes.TrimRight(buf.Bytes(), "\n")
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(body)
}

type detail struct {
	Detail any `json:"detail"`
}

// writeError renders service/validation errors.
func writeError(w http.ResponseWriter, log *slog.Logger, err error) {
	if ae, ok := apperr.As(err); ok {
		writeJSON(w, ae.Status, detail{Detail: ae.Detail})
		return
	}
	switch e := err.(type) {
	case *validationError:
		writeJSON(w, http.StatusUnprocessableEntity, detail{Detail: e.errs})
		return
	case *rateLimitError:
		writeJSON(w, http.StatusTooManyRequests, map[string]string{"error": e.Error()})
		return
	}
	log.Error("unhandled_error", "error", err)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusInternalServerError)
	_, _ = w.Write([]byte("Internal Server Error"))
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	if s.status == 0 {
		s.status = code
	}
	s.ResponseWriter.WriteHeader(code)
}

func (s *statusRecorder) Write(b []byte) (int, error) {
	if s.status == 0 {
		s.status = http.StatusOK
	}
	return s.ResponseWriter.Write(b)
}

// Unwrap lets http.ResponseController / websocket hijack the connection.
func (s *statusRecorder) Unwrap() http.ResponseWriter { return s.ResponseWriter }

// requestLogger logs every request as {"event":"http_request", ...}.
func requestLogger(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			rec := &statusRecorder{ResponseWriter: w}
			next.ServeHTTP(rec, r)
			status := rec.status
			if status == 0 {
				status = http.StatusOK
			}
			log.Info("http_request", "method", r.Method, "path", r.URL.Path, "status_code", status)
		})
	}
}

func recoverer(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if p := recover(); p != nil {
					if p == http.ErrAbortHandler {
						panic(p)
					}
					log.Error("panic", "error", p, "stack", string(debug.Stack()))
					w.Header().Set("Content-Type", "text/plain; charset=utf-8")
					w.WriteHeader(http.StatusInternalServerError)
					_, _ = w.Write([]byte("Internal Server Error"))
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}

var corsAllMethods = []string{"DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"}

// cors reproduces Starlette's CORSMiddleware with allow_credentials=True,
// allow_methods=["*"], allow_headers=["*"], max_age=600.
func cors(origins []string) func(http.Handler) http.Handler {
	allowAll := slices.Contains(origins, "*")
	allowed := func(origin string) bool { return allowAll || slices.Contains(origins, origin) }
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			if origin == "" {
				next.ServeHTTP(w, r)
				return
			}
			if r.Method == http.MethodOptions && r.Header.Get("Access-Control-Request-Method") != "" {
				h := w.Header()
				h.Set("Access-Control-Allow-Methods", strings.Join(corsAllMethods, ", "))
				h.Set("Access-Control-Max-Age", "600")
				h.Set("Access-Control-Allow-Credentials", "true")
				h.Add("Vary", "Origin")
				var failures []string
				if allowed(origin) {
					h.Set("Access-Control-Allow-Origin", origin)
				} else {
					failures = append(failures, "origin")
				}
				if !slices.Contains(corsAllMethods, r.Header.Get("Access-Control-Request-Method")) {
					failures = append(failures, "method")
				}
				if reqHeaders := r.Header.Get("Access-Control-Request-Headers"); reqHeaders != "" {
					h.Set("Access-Control-Allow-Headers", reqHeaders)
				}
				h.Set("Content-Type", "text/plain; charset=utf-8")
				if len(failures) > 0 {
					w.WriteHeader(http.StatusBadRequest)
					_, _ = w.Write([]byte("Disallowed CORS " + strings.Join(failures, ", ")))
					return
				}
				w.WriteHeader(http.StatusOK)
				_, _ = w.Write([]byte("OK"))
				return
			}
			h := w.Header()
			h.Set("Access-Control-Allow-Credentials", "true")
			switch {
			case allowAll && r.Header.Get("Cookie") == "":
				h.Set("Access-Control-Allow-Origin", "*")
			case allowed(origin):
				h.Set("Access-Control-Allow-Origin", origin)
				h.Add("Vary", "Origin")
			}
			next.ServeHTTP(w, r)
		})
	}
}
