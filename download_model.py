#!/usr/bin/env python3
"""Download only MiniMax H3 FL2VA files with Hugging Face per-file progress."""
from __future__ import annotations

import sys

from huggingface_hub import snapshot_download
from config import HF_TOKEN, LOCAL_MODEL_DIR, MODEL_ID


def main() -> int:
    LOCAL_MODEL_DIR.mkdir(parents=True, exist_ok=True)

    marker = LOCAL_MODEL_DIR / ".fl2va-download-complete"
    expected_index = LOCAL_MODEL_DIR / "FL2VA" / "model_index.json"

    # Reuse an already completed checkpoint instead of downloading it again.
    if marker.exists() and expected_index.exists():
        print(
            f"[MODEL] FL2VA checkpoint already present at {LOCAL_MODEL_DIR}; skipping download.",
            flush=True,
        )
        return 0

    print(f"[MODEL] Repository: {MODEL_ID}", flush=True)
    print("[MODEL] Scope: model_index.json + FL2VA/* ONLY (Ref2VA is excluded).", flush=True)
    print("[MODEL] Disk-space pre-check is disabled; download will start and may fail if storage runs out.", flush=True)
    print("[MODEL] Hugging Face progress bars show file progress, speed and ETA.", flush=True)

    try:
        snapshot_download(
            repo_id=MODEL_ID,
            local_dir=str(LOCAL_MODEL_DIR),
            token=HF_TOKEN,
            allow_patterns=["model_index.json", "FL2VA/*"],
            max_workers=4,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"[MODEL][ERROR] Download failed: {exc}", file=sys.stderr, flush=True)
        print("[MODEL] Run the same command again to resume completed files.", flush=True)
        return 1

    if not expected_index.exists():
        print(f"[MODEL][ERROR] Expected file missing: {expected_index}", file=sys.stderr, flush=True)
        return 1

    marker.touch()
    print(f"[MODEL] FL2VA download completed: {LOCAL_MODEL_DIR}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
