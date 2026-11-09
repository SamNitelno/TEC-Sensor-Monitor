//go:build integration

package apitest

import (
	"context"
	"io"
	"log/slog"
	"net/url"
	"testing"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/db"
)

// TestAdoptsAlembicHistory simulates a database created by the Python backend:
// the schema exists and alembic_version says 014. Migrate must record the
// history without re-running any DDL and leave the data untouched.
func TestAdoptsAlembicHistory(t *testing.T) {
	ctx := context.Background()
	u, _ := url.Parse(env.dbURL)
	u.Path = "/" + "tek_sensor_test_alembic"
	target := u.String()
	if err := recreateDatabase(ctx, target); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = dropDatabase(context.Background(), target) })
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	if err := db.Migrate(ctx, target, "pepper", log); err != nil {
		t.Fatal(err)
	}
	conn, err := pgx.Connect(ctx, target)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close(ctx)
	// Turn it into an "Alembic database": drop goose's table, add alembic_version.
	for _, stmt := range []string{
		`DROP TABLE goose_db_version`,
		`CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL PRIMARY KEY)`,
		`INSERT INTO alembic_version VALUES ('014')`,
		`INSERT INTO users (login, password_hash, role) VALUES ('legacy', 'x', 'viewer')`,
	} {
		if _, err := conn.Exec(ctx, stmt); err != nil {
			t.Fatal(stmt, err)
		}
	}
	if err := db.Migrate(ctx, target, "pepper", log); err != nil {
		t.Fatalf("migrate over alembic db: %v", err)
	}
	var maxVersion, rows int
	if err := conn.QueryRow(ctx, `SELECT max(version_id), count(*) FROM goose_db_version`).Scan(&maxVersion, &rows); err != nil {
		t.Fatal(err)
	}
	if maxVersion != db.LatestVersion || rows != db.LatestVersion+1 {
		t.Fatalf("goose version %d rows %d", maxVersion, rows)
	}
	var n int
	_ = conn.QueryRow(ctx, `SELECT count(*) FROM users WHERE login = 'legacy'`).Scan(&n)
	if n != 1 {
		t.Fatal("data lost")
	}
	// Idempotent on the next start.
	if err := db.Migrate(ctx, target, "pepper", log); err != nil {
		t.Fatal(err)
	}
}

// TestAdoptPartialAlembicHistory: a database at 012 gets 013 and 014 applied.
func TestAdoptPartialAlembicHistory(t *testing.T) {
	ctx := context.Background()
	u, _ := url.Parse(env.dbURL)
	u.Path = "/" + "tek_sensor_test_alembic12"
	target := u.String()
	if err := recreateDatabase(ctx, target); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = dropDatabase(context.Background(), target) })
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	if err := db.Migrate(ctx, target, "pepper", log); err != nil {
		t.Fatal(err)
	}
	conn, err := pgx.Connect(ctx, target)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close(ctx)
	for _, stmt := range []string{
		// Roll back 014 and 013 by hand, then pretend Alembic stopped at 012.
		`DROP TABLE password_reset_batches`,
		`DROP INDEX ix_users_phone`,
		`DROP INDEX ix_users_email_lower`,
		`ALTER TABLE contact_verification_batches DROP COLUMN failed_attempts`,
		`DROP TABLE goose_db_version`,
		`CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL PRIMARY KEY)`,
		`INSERT INTO alembic_version VALUES ('012')`,
		`INSERT INTO users (login, password_hash, role) VALUES ('u1', 'x', 'admin')`,
		`INSERT INTO sensors (name, device_id, api_token) VALUES ('s', 'd', 'plain-token')`,
	} {
		if _, err := conn.Exec(ctx, stmt); err != nil {
			t.Fatal(stmt, err)
		}
	}
	if err := db.Migrate(ctx, target, "pepper", log); err != nil {
		t.Fatal(err)
	}
	var token string
	_ = conn.QueryRow(ctx, `SELECT api_token FROM sensors WHERE device_id = 'd'`).Scan(&token)
	if len(token) != 64 {
		t.Fatalf("legacy token not hashed by migration 013: %q", token)
	}
	var exists bool
	_ = conn.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'password_reset_batches')`).Scan(&exists)
	if !exists {
		t.Fatal("migration 014 not applied")
	}
}
