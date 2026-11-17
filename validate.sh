#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "[VALIDATE] Checking Bash syntax..."
for script in deploy.sh install.sh start_server.sh monitor.sh; do
  bash -n "$script"
  echo "[VALIDATE] OK: $script"
done

echo "[VALIDATE] Checking Python syntax..."
PYTHON_BIN="${PYTHON_BIN:-python3}"
"$PYTHON_BIN" -m py_compile config.py download_model.py test_api.py generate_doctor_video.py scripts/patch_torch_sys_cxx20.py
echo "[VALIDATE] Python syntax OK."

echo "[VALIDATE] Checking configuration defaults and offloading switch..."
"$PYTHON_BIN" - <<'PY'
import os
import subprocess
import sys

def load_config(offloading: str):
    env = os.environ.copy()
    env["ENABLE_OFFLOADING"] = offloading
    result = subprocess.run(
        [
            sys.executable,
            "-c",
            "import config; print(' '.join(config.SGLANG_ARGS))",
        ],
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()

enabled = load_config("1")
disabled = load_config("0")

required_flags = ("--layerwise-offload-components", "--layerwise-resident-layers")
if not all(flag in enabled for flag in required_flags):
    raise SystemExit("Offloading=1 did not add the expected layer-wise flags.")
if any(flag in disabled for flag in required_flags):
    raise SystemExit("Offloading=0 unexpectedly included layer-wise flags.")

print("[VALIDATE] Offloading ON/OFF configuration checks passed.")
PY

echo "[VALIDATE] All local checks passed. This does not test CUDA, SGLang CLI compatibility, model loading, or inference."
