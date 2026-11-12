#!/usr/bin/env python3
"""Check that the SGLang server is reachable and healthy."""

from __future__ import annotations

import argparse
import sys
import time

import requests


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:30010")
    parser.add_argument("--timeout", type=int, default=10)
    parser.add_argument("--retries", type=int, default=3)
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")
    candidates = ["/health", "/health_generate"]

    for attempt in range(1, args.retries + 1):
        for path in candidates:
            try:
                response = requests.get(f"{base_url}{path}", timeout=args.timeout)
                print(f"{path}: HTTP {response.status_code}")
                if response.ok:
                    print("SGLang health check passed.")
                    return 0
            except requests.RequestException as exc:
                print(f"{path}: {exc}")
        if attempt < args.retries:
            time.sleep(3)

    print("Health check failed. Inspect the SGLang server logs.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
