#!/usr/bin/env python3
"""ESP32 telemetry simulator — sends current readings to the ingest API."""

import argparse
import json
import random
import sys
import time
import urllib.error
import urllib.request
from datetime import UTC, datetime


class CurrentGenerator:
    """Base load + noise with occasional idle (zero-current) periods."""

    def __init__(self) -> None:
        self._base_load = random.uniform(2.5, 6.0)
        self._idle_remaining = 0

    def next_current(self) -> float:
        if self._idle_remaining > 0:
            self._idle_remaining -= 1
            return 0.0

        if random.random() < 0.05:
            self._idle_remaining = random.randint(3, 12)
            return 0.0

        if random.random() < 0.02:
            self._base_load = random.uniform(2.5, 6.0)

        noise = random.gauss(0, 0.15)
        return max(0.0, self._base_load + noise)


def send_reading(url: str, token: str, current_a: float, max_retries: int = 5) -> bool:
    payload = {
        "current_a": round(current_a, 3),
        "ts": datetime.now(UTC).isoformat(),
    }
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "X-Device-Token": token,
        },
        method="POST",
    )

    for attempt in range(1, max_retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                body = response.read().decode("utf-8")
                print(f"[{datetime.now(UTC).isoformat()}] {response.status} {body}")
                return True
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            print(f"[{datetime.now(UTC).isoformat()}] HTTP {exc.code}: {body}", file=sys.stderr)
            if exc.code == 401:
                return False
            if attempt < max_retries:
                time.sleep(min(2**attempt, 30))
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            print(
                f"[{datetime.now(UTC).isoformat()}] Network error (attempt {attempt}/{max_retries}): {exc}",
                file=sys.stderr,
            )
            if attempt < max_retries:
                time.sleep(min(2**attempt, 30))

    return False


def main() -> None:
    parser = argparse.ArgumentParser(description="ESP32 telemetry simulator")
    parser.add_argument(
        "--url",
        default="http://localhost:8000/api/v1/ingest",
        help="Ingest endpoint URL (default: http://localhost:8000/api/v1/ingest)",
    )
    parser.add_argument("--token", required=True, help="Device API token (X-Device-Token)")
    parser.add_argument(
        "--interval",
        type=float,
        default=5.0,
        help="Seconds between readings (default: 5)",
    )
    args = parser.parse_args()

    generator = CurrentGenerator()
    print(f"Sending telemetry to {args.url} every {args.interval}s (Ctrl+C to stop)")

    while True:
        current = generator.next_current()
        ok = send_reading(args.url, args.token, current)
        if not ok:
            print("Stopping: unrecoverable error or invalid token.", file=sys.stderr)
            sys.exit(1)
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
