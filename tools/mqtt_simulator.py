#!/usr/bin/env python3
"""Publish JSY-MK-194G telemetry to MQTT (alternative to HTTP ingest)."""

from __future__ import annotations

import argparse
import json
import math
import random
import time
from datetime import UTC, datetime

try:
    import paho.mqtt.client as mqtt
except ImportError:
    raise SystemExit("Install paho-mqtt: pip install paho-mqtt")


def main() -> None:
    parser = argparse.ArgumentParser(description="MQTT telemetry simulator for TEC Sensor Monitor")
    parser.add_argument("--device-id", required=True, help="Sensor device_id from admin UI")
    parser.add_argument("--host", default="localhost", help="MQTT broker host")
    parser.add_argument("--port", type=int, default=1883)
    parser.add_argument("--interval", type=float, default=5.0)
    parser.add_argument("--current", type=float, default=0.0, help="Fixed current_a (A)")
    parser.add_argument("--power", type=float, default=0.0, help="Fixed power_w (W)")
    parser.add_argument("--simulate", action="store_true", help="Sine-wave demo values")
    args = parser.parse_args()

    telemetry_topic = f"sensors/{args.device_id}/telemetry"
    status_topic = f"sensors/{args.device_id}/status"
    lwt_payload = json.dumps({"status": "offline"})

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=f"sim-{args.device_id}")
    client.will_set(status_topic, lwt_payload, qos=1, retain=True)
    client.connect(args.host, args.port, keepalive=30)
    client.loop_start()

    client.publish(status_topic, json.dumps({"status": "online"}), qos=1, retain=True)
    print(f"Publishing to {telemetry_topic} every {args.interval}s (Ctrl+C to stop)")

    tick = 0
    try:
        while True:
            if args.simulate:
                current_a = 5.0 + 4.0 * math.sin(tick / 10.0) + random.uniform(-0.1, 0.1)
                power_w = current_a * 230.0
            else:
                current_a = args.current
                power_w = args.power

            payload = {
                "current_a": round(current_a, 3),
                "power_w": round(power_w, 1),
                "ts": datetime.now(UTC).isoformat(),
            }
            client.publish(telemetry_topic, json.dumps(payload), qos=0)
            tick += 1
            time.sleep(args.interval)
    except KeyboardInterrupt:
        pass
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
