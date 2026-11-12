#!/usr/bin/env python3
"""Download MiniMax H3 into the configured local model directory."""

from __future__ import annotations

import os
import shutil
import sys

from huggingface_hub import snapshot_download

from config import HF_HOME, HF_TOKEN, LOCAL_MODEL_DIR, MODEL_ID


def main() -> int:
    HF_HOME.mkdir(parents=True, exist_ok=True)
    LOCAL_MODEL_DIR.parent.mkdir(parents=True, exist_ok=True)

    total, used, free = shutil.disk_usage(LOCAL_MODEL_DIR.parent)
    free_gib = free / (1024**3)
    print(f"Free disk space: {free_gib:.1f} GiB")
    if free_gib < 150:
        print("ERROR: Less than 150 GiB free. Increase storage before downloading H3.", file=sys.stderr)
        return 2

    print(f"Downloading {MODEL_ID} to {LOCAL_MODEL_DIR}")
    print("This is a large model; keep the instance running and use persistent storage.")
    try:
        snapshot_download(
            repo_id=MODEL_ID,
            local_dir=str(LOCAL_MODEL_DIR),
            token=HF_TOKEN,
            max_workers=4,
        )
    except Exception as exc:  # noqa: BLE001 - surface Hub/network errors cleanly
        print(f"Download failed: {exc}", file=sys.stderr)
        return 1

    print("Model download completed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
