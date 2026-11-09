package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/db"
	"tek-sensor-monitor/backend/internal/security"
)

const (
	testWorkshopName = "Тестовый цех"
	testSiteName     = "Тестовая площадка"
	testDeviceID     = "TEST-ESP-001"
	testSensorName   = "Тестовый датчик ESP"
)

func openDB(ctx context.Context, flagValue string) (*pgxPool, error) {
	url, err := databaseURL(flagValue)
	if err != nil {
		return nil, err
	}
	pool, err := db.Open(ctx, url, 15*time.Second)
	if err != nil {
		return nil, err
	}
	return &pgxPool{pool}, nil
}

// ensureTestGroup finds or creates the test workshop and site; returns ids.
func ensureTestGroup(ctx context.Context, tx pgx.Tx, enableNotifications bool) (workshopID, siteID int64, err error) {
	err = tx.QueryRow(ctx, `SELECT id FROM workshops WHERE name = $1 ORDER BY id LIMIT 1`, testWorkshopName).Scan(&workshopID)
	if errors.Is(err, pgx.ErrNoRows) {
		err = tx.QueryRow(ctx, `INSERT INTO workshops (name, notifications_enabled) VALUES ($1, true) RETURNING id`, testWorkshopName).Scan(&workshopID)
		if err == nil && enableNotifications {
			fmt.Println("Created workshop:", testWorkshopName)
		}
	} else if err == nil && enableNotifications {
		_, err = tx.Exec(ctx, `UPDATE workshops SET notifications_enabled = true WHERE id = $1`, workshopID)
	}
	if err != nil {
		return 0, 0, err
	}
	err = tx.QueryRow(ctx, `SELECT id FROM sites WHERE name = $1 AND workshop_id = $2 ORDER BY id LIMIT 1`, testSiteName, workshopID).Scan(&siteID)
	if errors.Is(err, pgx.ErrNoRows) {
		err = tx.QueryRow(ctx, `INSERT INTO sites (name, workshop_id, notifications_enabled) VALUES ($1, $2, true) RETURNING id`,
			testSiteName, workshopID).Scan(&siteID)
		if err == nil && enableNotifications {
			fmt.Println("Created site:", testSiteName)
		}
	} else if err == nil && enableNotifications {
		_, err = tx.Exec(ctx, `UPDATE sites SET notifications_enabled = true WHERE id = $1`, siteID)
	}
	return workshopID, siteID, err
}

// runSeedTestSensor creates TEST-ESP-001 with a plaintext token (accepted by
// the backend's legacy-token path) so repeated runs print the same token.
func runSeedTestSensor(args []string) error {
	fs := flag.NewFlagSet("seed-test-sensor", flag.ExitOnError)
	dbURL := fs.String("db", "", "database URL (default $DATABASE_URL from .env)")
	_ = fs.Parse(args)
	ctx := context.Background()
	pool, err := openDB(ctx, *dbURL)
	if err != nil {
		return err
	}
	defer pool.Close()

	return db.InTx(ctx, pool.Pool, func(tx pgx.Tx) error {
		var deviceID, token string
		err := tx.QueryRow(ctx, `SELECT device_id, api_token FROM sensors WHERE device_id = $1`, testDeviceID).Scan(&deviceID, &token)
		if err == nil {
			fmt.Println("device_id:", deviceID)
			if security.IsHashedDeviceToken(token) {
				fmt.Println("api_token: <hashed — rotate it in the admin UI or via POST /sensors/{id}/rotate-token>")
			} else {
				fmt.Println("api_token:", token)
			}
			return nil
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		_, siteID, err := ensureTestGroup(ctx, tx, false)
		if err != nil {
			return err
		}
		token = security.TokenURLSafe(32)
		if _, err := tx.Exec(ctx, `INSERT INTO sensors (name, device_id, api_token, site_id) VALUES ($1, $2, $3, $4)`,
			testSensorName, testDeviceID, token, siteID); err != nil {
			return err
		}
		fmt.Println("device_id:", testDeviceID)
		fmt.Println("api_token:", token)
		return nil
	})
}

func runRepairTestSensor(args []string) error {
	fs := flag.NewFlagSet("repair-test-sensor", flag.ExitOnError)
	dbURL := fs.String("db", "", "database URL (default $DATABASE_URL from .env)")
	_ = fs.Parse(args)
	ctx := context.Background()
	pool, err := openDB(ctx, *dbURL)
	if err != nil {
		return err
	}
	defer pool.Close()

	return db.InTx(ctx, pool.Pool, func(tx pgx.Tx) error {
		var sensorID int64
		var name string
		var oldSite *int64
		err := tx.QueryRow(ctx, `SELECT id, name, site_id FROM sensors WHERE device_id = $1`, testDeviceID).Scan(&sensorID, &name, &oldSite)
		if errors.Is(err, pgx.ErrNoRows) {
			fmt.Printf("Sensor %s not found\n", testDeviceID)
			return nil
		}
		if err != nil {
			return err
		}
		workshopID, siteID, err := ensureTestGroup(ctx, tx, true)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `UPDATE sensors SET site_id = $2, notifications_enabled = true WHERE id = $1`, sensorID, siteID); err != nil {
			return err
		}
		old := "None"
		if oldSite != nil {
			old = fmt.Sprint(*oldSite)
		}
		fmt.Printf("Sensor %s: site_id %s -> %d, notifications on\n", name, old, siteID)

		rows, err := tx.Query(ctx, `SELECT id FROM sites WHERE name = 'S-notify-test' AND id <> $1`, siteID)
		if err != nil {
			return err
		}
		siteIDs, err := pgx.CollectRows(rows, pgx.RowTo[int64])
		if err != nil {
			return err
		}
		for _, id := range siteIDs {
			var has bool
			if err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM sensors WHERE site_id = $1)`, id).Scan(&has); err != nil {
				return err
			}
			if has {
				fmt.Println("Skip delete site 'S-notify-test': still has sensors")
				continue
			}
			if _, err := tx.Exec(ctx, `UPDATE sensor_placement_history SET site_id = NULL WHERE site_id = $1`, id); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `DELETE FROM sites WHERE id = $1`, id); err != nil {
				return err
			}
			fmt.Println("Deleted site: S-notify-test")
		}

		rows, err = tx.Query(ctx, `SELECT id FROM workshops WHERE name = 'W-notify-test' AND id <> $1`, workshopID)
		if err != nil {
			return err
		}
		wsIDs, err := pgx.CollectRows(rows, pgx.RowTo[int64])
		if err != nil {
			return err
		}
		for _, id := range wsIDs {
			var has bool
			if err := tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM sites WHERE workshop_id = $1)`, id).Scan(&has); err != nil {
				return err
			}
			if has {
				fmt.Println("Skip delete workshop 'W-notify-test': still has sites")
				continue
			}
			if _, err := tx.Exec(ctx, `DELETE FROM workshops WHERE id = $1`, id); err != nil {
				return err
			}
			fmt.Println("Deleted workshop: W-notify-test")
		}
		fmt.Println("Done.")
		return nil
	})
}
