package main

import (
	"errors"
	"flag"
	"fmt"
	"strings"
	"time"

	"tinygo.org/x/bluetooth"
)

// GATT contract shared with the firmware and the Flutter provisioning screen.
const (
	bleServiceUUID     = "aec0c101-5a56-4ef2-882b-d1e0e0b4d8ba"
	bleCharSSID        = "aec0c102-5a56-4ef2-882b-d1e0e0b4d8ba"
	bleCharPassword    = "aec0c103-5a56-4ef2-882b-d1e0e0b4d8ba"
	bleCharServerURL   = "aec0c104-5a56-4ef2-882b-d1e0e0b4d8ba"
	bleCharDeviceToken = "aec0c105-5a56-4ef2-882b-d1e0e0b4d8ba"
	bleCharCommit      = "aec0c106-5a56-4ef2-882b-d1e0e0b4d8ba"
	bleNamePrefix      = "TEC-ESP"
)

func mustUUID(s string) bluetooth.UUID {
	u, err := bluetooth.ParseUUID(s)
	if err != nil {
		panic(err)
	}
	return u
}

func runBLEProvision(args []string) error {
	fs := flag.NewFlagSet("ble-provision", flag.ExitOnError)
	base, login, password := apiFlags(fs, "http://localhost:8000")
	deviceID := fs.String("device-id", "TEST-ESP-001", "sensor device_id")
	ssid := fs.String("ssid", "", "Wi-Fi SSID, required")
	wifiPassword := fs.String("wifi-password", "", "Wi-Fi password")
	serverURL := fs.String("server-url", "", "override ingest URL")
	token := fs.String("token", "", "device token to send (skips the API token step)")
	rotate := fs.Bool("rotate", false, "rotate the device token via API (invalidates the old token) — needed because tokens are hashed at rest")
	scanTimeout := fs.Duration("scan-timeout", 20*time.Second, "BLE scan timeout")
	_ = fs.Parse(args)
	if *ssid == "" {
		return errors.New("--ssid is required")
	}

	deviceToken, ingestURL, err := bleCredentials(*base, *login, *password, *deviceID, *token, *rotate)
	if err != nil {
		return err
	}
	if *serverURL != "" {
		ingestURL = *serverURL
	}
	fmt.Println("Ingest URL:", ingestURL)
	fmt.Printf("Device token: %s... (%d chars)\n", deviceToken[:min(8, len(deviceToken))], len(deviceToken))

	adapter := bluetooth.DefaultAdapter
	if err := adapter.Enable(); err != nil {
		return fmt.Errorf("enable Bluetooth adapter: %w", err)
	}
	result, err := scanForESP(adapter, *scanTimeout)
	if err != nil {
		return err
	}
	fmt.Printf("Found: %s (%s) RSSI=%d\n", nameOr(result.LocalName(), result.Address.String()), result.Address.String(), result.RSSI)

	device, err := adapter.Connect(result.Address, bluetooth.ConnectionParams{})
	if err != nil {
		return fmt.Errorf("connect: %w", err)
	}
	defer func() { _ = device.Disconnect() }()
	fmt.Println("Connected, writing GATT characteristics...")

	services, err := device.DiscoverServices([]bluetooth.UUID{mustUUID(bleServiceUUID)})
	if err != nil || len(services) == 0 {
		return fmt.Errorf("provisioning service not found: %v", err)
	}
	order := []string{bleCharSSID, bleCharPassword, bleCharServerURL, bleCharDeviceToken, bleCharCommit}
	uuids := make([]bluetooth.UUID, len(order))
	for i, s := range order {
		uuids[i] = mustUUID(s)
	}
	chars, err := services[0].DiscoverCharacteristics(uuids)
	if err != nil {
		return fmt.Errorf("discover characteristics: %w", err)
	}
	byUUID := map[string]bluetooth.DeviceCharacteristic{}
	for _, ch := range chars {
		byUUID[strings.ToLower(ch.UUID().String())] = ch
	}
	values := map[string][]byte{
		bleCharSSID:        []byte(*ssid),
		bleCharPassword:    []byte(*wifiPassword),
		bleCharServerURL:   []byte(ingestURL),
		bleCharDeviceToken: []byte(deviceToken),
		bleCharCommit:      []byte("1"),
	}
	for _, u := range order {
		ch, ok := byUUID[u]
		if !ok {
			return fmt.Errorf("characteristic %s not found", u)
		}
		if _, err := ch.Write(values[u]); err != nil {
			return fmt.Errorf("write %s: %w", u, err)
		}
	}
	fmt.Println("Commit sent — ESP should save NVS and connect Wi-Fi.")
	fmt.Println("Done.")
	return nil
}

func nameOr(name, fallback string) string {
	if name != "" {
		return name
	}
	return fallback
}

// bleCredentials resolves the ingest URL and device token to send.
func bleCredentials(base, login, password, deviceID, token string, rotate bool) (string, string, error) {
	c := newAPIClient(base, true)
	if err := c.login(login, password); err != nil {
		return "", "", err
	}
	sensors, err := c.sensors()
	if err != nil {
		return "", "", err
	}
	var id int64
	for _, s := range sensors {
		if s.DeviceID == deviceID {
			id = s.ID
		}
	}
	if id == 0 {
		return "", "", fmt.Errorf("sensor %q not found — run 'tektool seed-test-sensor' or create it in the admin UI", deviceID)
	}
	apiToken, ingestURL, err := c.deviceCredentials(id, rotate && token == "")
	if err != nil {
		return "", "", err
	}
	if token == "" {
		token = apiToken
	}
	if token == "" {
		return "", "", errors.New("device token is hashed at rest: pass --token <plaintext> or --rotate")
	}
	return token, ingestURL, nil
}

// scanForESP looks for the provisioning service UUID, falling back to the
// TEC-ESP name prefix.
func scanForESP(adapter *bluetooth.Adapter, timeout time.Duration) (bluetooth.ScanResult, error) {
	fmt.Printf("Scanning for BLE service %s (%s)...\n", bleServiceUUID, timeout)
	service := mustUUID(bleServiceUUID)
	found := make(chan bluetooth.ScanResult, 1)
	go func() {
		_ = adapter.Scan(func(a *bluetooth.Adapter, r bluetooth.ScanResult) {
			if r.HasServiceUUID(service) || strings.HasPrefix(r.LocalName(), bleNamePrefix) {
				select {
				case found <- r:
				default:
				}
				_ = a.StopScan()
			}
		})
	}()
	select {
	case r := <-found:
		return r, nil
	case <-time.After(timeout):
		_ = adapter.StopScan()
		return bluetooth.ScanResult{}, errors.New("ESP not found — ensure BLE provisioning mode (serial: 'BLE provisioning started')")
	}
}
