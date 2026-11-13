#!/usr/bin/env python3
"""Download only MiniMax H3 FL2VA files with Hugging Face per-file progress."""
from __future__ import annotations
import os
import shutil
import sys
from huggingface_hub import snapshot_download
from config import HF_TOKEN, LOCAL_MODEL_DIR, MODEL_ID

def main() -> int:
    LOCAL_MODEL_DIR.mkdir(parents=True, exist_ok=True)
    _, _, free = shutil.disk_usage(LOCAL_MODEL_DIR.parent)
    free_gib = free / (1024**3)
    min_disk_gib = float(os.getenv("MIN_DISK_GIB", "150"))
    print(f"[MODEL] Free disk space: {free_gib:.1f} GiB", flush=True)
    print(f"[MODEL] Configured free-space target: {min_disk_gib:.1f} GiB", flush=True)
    if free_gib < min_disk_gib:
        print(f"[MODEL][ERROR] Only {free_gib:.1f} GiB free; configured target is {min_disk_gib:.1f} GiB. Set MIN_DISK_GIB to adjust.", file=sys.stderr, flush=True)
        return 2
    marker = LOCAL_MODEL_DIR / ".fl2va-download-complete"
    expected_index = LOCAL_MODEL_DIR / "FL2VA" / "model_index.json"
    if marker.exists() and expected_index.exists():
        print(f"[MODEL] FL2VA checkpoint already present at {LOCAL_MODEL_DIR}; skipping download.", flush=True)
        return 0
    print(f"[MODEL] Repository: {MODEL_ID}", flush=True)
    print("[MODEL] Scope: model_index.json + FL2VA/* ONLY (Ref2VA is excluded).", flush=True)
    print("[MODEL] Hugging Face progress bars show file progress, speed and ETA.", flush=True)
    try:
        snapshot_download(repo_id=MODEL_ID, local_dir=str(LOCAL_MODEL_DIR), token=HF_TOKEN,
                          allow_patterns=["model_index.json", "FL2VA/*"], max_workers=4)
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
