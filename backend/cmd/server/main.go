// Command server runs the TEC Sensor Monitor backend.
//
//	server [serve]      apply migrations, bootstrap users, serve HTTP + workers
//	server migrate      apply database migrations and exit
//	server healthcheck  GET /health on the local server (for Docker HEALTHCHECK)
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"tek-sensor-monitor/backend/internal/config"
	"tek-sensor-monitor/backend/internal/db"
	"tek-sensor-monitor/backend/internal/delivery"
	"tek-sensor-monitor/backend/internal/httpapi"
	"tek-sensor-monitor/backend/internal/logging"
	"tek-sensor-monitor/backend/internal/service"
	"tek-sensor-monitor/backend/internal/ws"
)

func main() {
	cmd := "serve"
	if len(os.Args) > 1 {
		cmd = os.Args[1]
	}
	var err error
	switch cmd {
	case "serve":
		err = serve()
	case "migrate":
		err = migrate()
	case "healthcheck":
		err = healthcheck()
	default:
		err = fmt.Errorf("unknown command %q (use serve, migrate or healthcheck)", cmd)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func loadConfig() (*config.Config, *slog.Logger, error) {
	cfg, err := config.Load()
	if err != nil {
		return nil, nil, err
	}
	if errs := cfg.ProductionErrors(); len(errs) > 0 {
		for _, e := range errs {
			fmt.Fprintln(os.Stderr, "PRODUCTION CONFIG ERROR: "+e)
		}
		os.Exit(1)
	}
	log := logging.Setup(cfg.JSONLogs, cfg.LogLevel)
	return cfg, log, nil
}

func migrate() error {
	cfg, _, err := loadConfig()
	if err != nil {
		return err
	}
	ctx := context.Background()
	pool, err := db.Open(ctx, cfg.PgxDatabaseURL(), 60*time.Second)
	if err != nil {
		return err
	}
	pool.Close()
	return db.Migrate(ctx, cfg.PgxDatabaseURL(), cfg.JWTSecret, logging.Named("migrate"))
}

func serve() error {
	cfg, log, err := loadConfig()
	if err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	pool, err := db.Open(ctx, cfg.PgxDatabaseURL(), 60*time.Second)
	if err != nil {
		return err
	}
	defer pool.Close()

	if err := db.Migrate(ctx, cfg.PgxDatabaseURL(), cfg.JWTSecret, logging.Named("migrate")); err != nil {
		return fmt.Errorf("migrations failed: %w", err)
	}

	hub := ws.NewHub(logging.Named("app.ws"))
	svc := service.New(cfg, pool, hub, delivery.New(cfg, logging.Named("app.delivery")), logging.Named("app.services"))
	if err := svc.EnsureBootstrapUsers(ctx); err != nil {
		return fmt.Errorf("bootstrap users: %w", err)
	}

	workersCtx, cancelWorkers := context.WithCancel(ctx)
	var wg sync.WaitGroup
	start := func(fn func(context.Context)) {
		wg.Add(1)
		go func() { defer wg.Done(); fn(workersCtx) }()
	}
	start(svc.RunDowntimeWorker)
	start(svc.RunOfflineWatchdog)
	if cfg.MQTTEnabled {
		start(svc.RunMQTTSubscriber)
	}

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           httpapi.New(svc, logging.Named("app.main")),
		ReadHeaderTimeout: 15 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	errCh := make(chan error, 1)
	go func() {
		log.Info("app_started", "app_env", cfg.AppEnv, "mqtt_enabled", cfg.MQTTEnabled,
			"allow_public_registration", cfg.AllowPublicRegistration, "addr", cfg.HTTPAddr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
		close(errCh)
	}()

	select {
	case <-ctx.Done():
	case err := <-errCh:
		if err != nil {
			cancelWorkers()
			wg.Wait()
			return err
		}
	}
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
	cancelWorkers()
	wg.Wait()
	log.Info("app_stopped")
	return nil
}

func healthcheck() error {
	addr := os.Getenv("HTTP_ADDR")
	if addr == "" {
		addr = ":8000"
	}
	host := addr
	if strings.HasPrefix(host, ":") {
		host = "127.0.0.1" + host
	}
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get("http://" + host + "/health")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("health returned %d", resp.StatusCode)
	}
	return nil
}
