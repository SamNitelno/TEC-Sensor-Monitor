// Command tektool bundles the developer utilities that used to live in
// tools/*.py: ESP/MQTT simulators, test-data seeding, API smoke checks,
// firmware secrets generation and BLE provisioning.
package main

import (
	"fmt"
	"os"
	"sort"
	"strings"

	"tek-sensor-monitor/backend/internal/security"
)

type command struct {
	summary string
	run     func(args []string) error
}

var commands = map[string]command{
	"esp-sim":             {"HTTP telemetry simulator (replaces tools/esp_simulator.py)", runESPSim},
	"mqtt-sim":            {"MQTT telemetry simulator with LWT (replaces tools/mqtt_simulator.py)", runMQTTSim},
	"seed-test-sensor":    {"create test workshop/site/sensor TEST-ESP-001 in the DB (idempotent)", runSeedTestSensor},
	"repair-test-sensor":  {"restore TEST-ESP-001 placement and remove test pollution", runRepairTestSensor},
	"seed-demo":           {"seed demo workshops/sites/sensors/users and demo readings via API", runSeedDemo},
	"verify-demo":         {"re-seed demo readings and count raw points per demo sensor", runVerifyDemo},
	"smoke":               {"quick API smoke test (users, auth, colours, audit)", runSmoke},
	"prepare-esp-secrets": {"write firmware/src/secrets.h (ingest URL + device token)", runPrepareESPSecrets},
	"ble-provision":       {"provision an ESP32 over BLE (Wi-Fi + ingest URL + token)", runBLEProvision},
	"gen-secrets":         {"print strong JWT_SECRET / ADMIN_PASSWORD / VIEWER_PASSWORD for .env", runGenSecrets},
}

func runGenSecrets(args []string) error {
	fmt.Println("JWT_SECRET=" + security.TokenURLSafe(48))
	fmt.Println("ADMIN_PASSWORD=" + security.TokenURLSafe(16) + "A1")
	fmt.Println("VIEWER_PASSWORD=" + security.TokenURLSafe(16) + "B2")
	return nil
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: tektool <command> [flags]\n\ncommands:")
	names := make([]string, 0, len(commands))
	for n := range commands {
		names = append(names, n)
	}
	sort.Strings(names)
	for _, n := range names {
		fmt.Fprintf(os.Stderr, "  %-20s %s\n", n, commands[n].summary)
	}
	fmt.Fprintln(os.Stderr, "\nRun 'tektool <command> -h' for command flags.")
}

func main() {
	if len(os.Args) < 2 || strings.HasPrefix(os.Args[1], "-") {
		usage()
		os.Exit(2)
	}
	cmd, ok := commands[os.Args[1]]
	if !ok {
		fmt.Fprintf(os.Stderr, "unknown command %q\n\n", os.Args[1])
		usage()
		os.Exit(2)
	}
	loadDotEnv()
	if err := cmd.run(os.Args[2:]); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}
