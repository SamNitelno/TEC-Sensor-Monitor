#!/usr/bin/env python3
"""Provision ESP32 via BLE (same GATT contract as Flutter provisioning screen)."""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
import urllib.error
import urllib.request

SERVICE_UUID = "aec0c101-5a56-4ef2-882b-d1e0e0b4d8ba"
CHAR_SSID = "aec0c102-5a56-4ef2-882b-d1e0e0b4d8ba"
CHAR_PASSWORD = "aec0c103-5a56-4ef2-882b-d1e0e0b4d8ba"
CHAR_SERVER_URL = "aec0c104-5a56-4ef2-882b-d1e0e0b4d8ba"
CHAR_DEVICE_TOKEN = "aec0c105-5a56-4ef2-882b-d1e0e0b4d8ba"
CHAR_COMMIT = "aec0c106-5a56-4ef2-882b-d1e0e0b4d8ba"
DEVICE_NAME_PREFIX = "TEC-ESP"


def api_json(method: str, url: str, body: dict | None = None, token: str | None = None) -> object:
    data = None if body is None else json.dumps(body).encode()
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode())


def fetch_provisioning_creds(api_base: str, device_id: str) -> tuple[str, str]:
    login = api_json("POST", f"{api_base}/api/v1/auth/login", {"login": "admin", "password": "admin"})
    token = login["access_token"]
    sensors = api_json("GET", f"{api_base}/api/v1/sensors", token=token)
    sensor = next((s for s in sensors if s["device_id"] == device_id), None)
    if sensor is None:
        raise SystemExit(f"Sensor {device_id!r} not found — run tools/seed_test_sensor.py")
    creds = api_json(
        "GET",
        f"{api_base}/api/v1/sensors/{sensor['id']}/provisioning-token",
        token=token,
    )
    return creds["api_token"], creds["ingest_url"]


async def find_esp(timeout: float = 20.0):
    from bleak import BleakScanner

    print(f"Scanning for BLE service {SERVICE_UUID} ({timeout}s)...")
    devices = await BleakScanner.discover(timeout=timeout, service_uuids=[SERVICE_UUID])
    if not devices:
        devices = await BleakScanner.discover(timeout=timeout)
        devices = [d for d in devices if (d.name or "").startswith(DEVICE_NAME_PREFIX)]
    if not devices:
        raise SystemExit("ESP not found — ensure BLE provisioning mode (serial: 'BLE provisioning started')")
    device = devices[0]
    rssi = getattr(device, "rssi", None)
    print(f"Found: {device.name or device.address} ({device.address}) RSSI={rssi}")
    return device


async def provision(
    address: str,
    ssid: str,
    password: str,
    server_url: str,
    device_token: str,
) -> None:
    from bleak import BleakClient

    async with BleakClient(address, timeout=30.0) as client:
        print("Connected, writing GATT characteristics...")
        await client.write_gatt_char(CHAR_SSID, ssid.encode(), response=True)
        await client.write_gatt_char(CHAR_PASSWORD, password.encode(), response=True)
        await client.write_gatt_char(CHAR_SERVER_URL, server_url.encode(), response=True)
        await client.write_gatt_char(CHAR_DEVICE_TOKEN, device_token.encode(), response=True)
        await client.write_gatt_char(CHAR_COMMIT, b"1", response=True)
        print("Commit sent — ESP should save NVS and connect Wi-Fi.")


def main() -> None:
    parser = argparse.ArgumentParser(description="BLE provision ESP32 for TEC sensor monitor")
    parser.add_argument("--api-base", default="http://localhost:8000")
    parser.add_argument("--device-id", default="TEST-ESP-001")
    parser.add_argument("--ssid", required=True)
    parser.add_argument("--password", default="")
    parser.add_argument("--server-url", default=None, help="Override ingest URL")
    args = parser.parse_args()

    try:
        device_token, ingest_url = fetch_provisioning_creds(args.api_base.rstrip("/"), args.device_id)
    except urllib.error.URLError as exc:
        raise SystemExit(f"API error: {exc}") from exc

    server_url = args.server_url or ingest_url
    print(f"Ingest URL: {server_url}")
    print(f"Device token: {device_token[:8]}... ({len(device_token)} chars)")

    device = asyncio.run(find_esp())
    asyncio.run(provision(device.address, args.ssid, args.password, server_url, device_token))
    print("Done.")


if __name__ == "__main__":
    main()
