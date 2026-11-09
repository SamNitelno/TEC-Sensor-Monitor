// Package logging configures log/slog to emit the same JSON shape the
// structlog setup produced: {"event", "level", "logger", "timestamp", ...}.
package logging

import (
	"io"
	"log/slog"
	"os"
	"strings"
	"time"
)

func parseLevel(s string) slog.Level {
	switch strings.ToUpper(strings.TrimSpace(s)) {
	case "DEBUG":
		return slog.LevelDebug
	case "WARNING", "WARN":
		return slog.LevelWarn
	case "ERROR", "CRITICAL":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

// Setup installs the default logger and returns it.
func Setup(jsonLogs bool, level string) *slog.Logger {
	return SetupWriter(os.Stdout, jsonLogs, level)
}

func SetupWriter(w io.Writer, jsonLogs bool, level string) *slog.Logger {
	opts := &slog.HandlerOptions{
		Level: parseLevel(level),
		ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
			if len(groups) > 0 {
				return a
			}
			switch a.Key {
			case slog.MessageKey:
				a.Key = "event"
			case slog.TimeKey:
				a.Key = "timestamp"
				a.Value = slog.StringValue(a.Value.Time().UTC().Format(time.RFC3339Nano))
			case slog.LevelKey:
				a.Value = slog.StringValue(strings.ToLower(a.Value.String()))
			}
			return a
		},
	}
	var h slog.Handler
	if jsonLogs {
		h = slog.NewJSONHandler(w, opts)
	} else {
		h = slog.NewTextHandler(w, opts)
	}
	logger := slog.New(h)
	slog.SetDefault(logger)
	return logger
}

// Named returns a child logger tagged like structlog's add_logger_name.
func Named(name string) *slog.Logger {
	return slog.Default().With("logger", name)
}
