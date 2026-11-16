#!/usr/bin/env python3
"""Download the MiniMax H3 FL2VA checkpoint with resumable per-file progress."""
from __future__ import annotations

import json
import os
import sys

from huggingface_hub import snapshot_download
from config import HF_TOKEN, LOCAL_MODEL_DIR, MODEL_ID


def _download_workers() -> int:
    raw_value = os.getenv("HF_DOWNLOAD_MAX_WORKERS", "4")
    try:
        workers = int(raw_value)
    except ValueError as exc:
        raise ValueError(
            f"HF_DOWNLOAD_MAX_WORKERS must be a positive integer; got {raw_value!r}"
        ) from exc
    if workers < 1:
        raise ValueError(
            f"HF_DOWNLOAD_MAX_WORKERS must be >= 1; got {workers}"
        )
    return workers


def main() -> int:
    LOCAL_MODEL_DIR.mkdir(parents=True, exist_ok=True)

    marker = LOCAL_MODEL_DIR / ".fl2va-download-complete"
    expected_index = LOCAL_MODEL_DIR / "FL2VA" / "model_index.json"

    # A successful prior run writes the marker only after snapshot_download
    # completes and the FL2VA model index has been parsed successfully.
    if marker.exists() and expected_index.is_file():
        try:
            json.loads(expected_index.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            marker.unlink(missing_ok=True)
        else:
            print(
                f"[MODEL] FL2VA checkpoint already marked complete at {LOCAL_MODEL_DIR}; skipping download.",
                flush=True,
            )
            return 0

    workers = _download_workers()
    print(f"[MODEL] Repository: {MODEL_ID}", flush=True)
    print("[MODEL] Scope: model_index.json + FL2VA/* ONLY (Ref2VA is excluded).", flush=True)
    print(f"[MODEL] Parallel file downloads: {workers}", flush=True)
    print("[MODEL] Hugging Face Hub resumes existing completed files on rerun.", flush=True)

    try:
        snapshot_download(
            repo_id=MODEL_ID,
            local_dir=str(LOCAL_MODEL_DIR),
            token=HF_TOKEN,
            allow_patterns=["model_index.json", "FL2VA/*"],
            max_workers=workers,
        )
        if not expected_index.is_file():
            raise FileNotFoundError(f"Expected file missing: {expected_index}")
        json.loads(expected_index.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        marker.unlink(missing_ok=True)
        print(f"[MODEL][ERROR] Download/validation failed: {exc}", file=sys.stderr, flush=True)
        print("[MODEL] Rerun the same command to resume files already downloaded.", flush=True)
        return 1

    marker.write_text(
        f"repo_id={MODEL_ID}\nvariant=fl2va\n",
        encoding="utf-8",
    )
    print(f"[MODEL] FL2VA download completed and model index validated: {LOCAL_MODEL_DIR}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
