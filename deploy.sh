#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
mkdir -p logs
LOG_FILE="$PROJECT_DIR/logs/deploy-$(date '+%Y%m%d-%H%M%S').log"
ln -sfn "$(basename "$LOG_FILE")" "$PROJECT_DIR/logs/latest.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { printf '\n[%s] [H3-DEPLOY] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
fail() { log "ERROR: $*"; exit 1; }
trap 'status=$?; if [[ $status -ne 0 ]]; then log "Deployment stopped with exit code $status. Review $LOG_FILE"; fi' EXIT

[[ "$(uname -s)" == "Linux" ]] || fail "Run this script on Linux/Ubuntu."

# Preserve explicit environment values; .env supplies defaults.
declare -A SHELL_OVERRIDES=()
RUNTIME_ENV_VARS=(
  HF_TOKEN HF_HOME HF_DOWNLOAD_MAX_WORKERS MODEL_ID MODEL_PATH MODEL_VARIANT LOCAL_MODEL_DIR HOST PORT
  ENABLE_OFFLOADING WARMUP_RESOLUTIONS WARMUP_NUM_FRAMES
  OFFLOAD_COMPONENTS RESIDENT_LAYERS PYTORCH_CUDA_ALLOC_CONF DRY_RUN
  PYTHON_BIN FORCE_INSTALL DOWNLOAD_ONLY HEALTH_TIMEOUT_SECONDS HEALTH_POLL_INTERVAL
)
for name in "${RUNTIME_ENV_VARS[@]}"; do
  if [[ -v "$name" ]]; then
    SHELL_OVERRIDES["$name"]="${!name}"
  fi
done
if [[ -f .env ]]; then
  set -a
  # .env is a trusted shell-style config file owned by the deployment.
  # shellcheck disable=SC1091
  source .env
  set +a
fi
for name in "${!SHELL_OVERRIDES[@]}"; do
  export "$name=${SHELL_OVERRIDES[$name]}"
done

export HF_HUB_DISABLE_PROGRESS_BARS=0

log "Hardware report only; no GPU, VRAM, CPU-core, or host-RAM minimum is enforced."
log "CPU threads: $(nproc 2>/dev/null || echo unknown)"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi || log "GPU query failed; continuing."
else
  log "nvidia-smi not found; continuing because model download does not require a GPU."
fi
if [[ -r /proc/meminfo ]]; then
  awk '/MemTotal/ {printf "[H3-DEPLOY] Host RAM: %.1f GiB\n", $2/1024/1024}' /proc/meminfo
fi
df -h "$PROJECT_DIR" || true

log "STEP 1/3: Preparing Python environment."
PYTHON_BIN="${PYTHON_BIN:-python3}"
command -v "$PYTHON_BIN" >/dev/null 2>&1 || fail "$PYTHON_BIN not found."
if ! "$PYTHON_BIN" -c 'import venv' >/dev/null 2>&1; then
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get update && apt-get install -y python3-venv
  elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y python3-venv
  else
    fail "python3-venv is missing and neither root nor sudo is available."
  fi
fi

[[ -d .venv ]] || "$PYTHON_BIN" -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

log "STEP 2/3: Checking/reusing MiniMax H3 FL2VA checkpoint."
python -u download_model.py
if [[ "${DOWNLOAD_ONLY:-0}" == "1" ]]; then
  log "DOWNLOAD_ONLY=1: download completed; skipping runtime installation and inference."
  exit 0
fi

log "STEP 3/3: Installing runtime and starting SGLang."
if [[ "${FORCE_INSTALL:-0}" == "1" || ! -f .install-complete ]] || ! command -v cargo >/dev/null 2>&1 || ! command -v rustc >/dev/null 2>&1; then
  bash install.sh
  [[ -f .install-complete ]] || fail "Installer finished but .install-complete marker is missing."
else
  log "SGLang dependencies and Rust toolchain appear installed; skipping installer. Set FORCE_INSTALL=1 to reinstall."
fi

[[ -x .venv/bin/python ]] || fail "Python environment not found. Run bash install.sh and inspect errors."
if [[ "${DRY_RUN:-0}" == "1" ]]; then
  log "DRY_RUN=1: printing the SGLang command without starting the server."
  bash start_server.sh
  exit 0
fi
log "Launching SGLang in the background. Explicit layer-wise CPU offloading is controlled by ENABLE_OFFLOADING (default: 1)."
SERVER_LOG="$PROJECT_DIR/logs/server.log"
HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-3600}"
HEALTH_POLL_INTERVAL="${HEALTH_POLL_INTERVAL:-10}"
PORT="${PORT:-30010}"

[[ "$HEALTH_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || fail "HEALTH_TIMEOUT_SECONDS must be a positive integer."
[[ "$HEALTH_POLL_INTERVAL" =~ ^[1-9][0-9]*$ ]] || fail "HEALTH_POLL_INTERVAL must be a positive integer."

bash start_server.sh >> "$SERVER_LOG" 2>&1 &
SERVER_PID=$!
log "SGLang process started (PID $SERVER_PID). Server output: $SERVER_LOG"
log "Waiting up to $HEALTH_TIMEOUT_SECONDS seconds for http://127.0.0.1:$PORT/health"

deadline=$((SECONDS + HEALTH_TIMEOUT_SECONDS))
while (( SECONDS < deadline )); do
  if python - "$PORT" <<'PY'
import sys
import urllib.error
import urllib.request

url = f"http://127.0.0.1:{int(sys.argv[1])}/health"
try:
    with urllib.request.urlopen(url, timeout=5) as response:
        body = response.read().decode("utf-8", errors="replace")
        if response.status == 200:
            print(body)
            raise SystemExit(0)
except (OSError, urllib.error.URLError, TimeoutError, ValueError):
    pass
raise SystemExit(1)
PY
  then
    log "SGLang health check passed. API is ready at http://127.0.0.1:$PORT"
    log "Keep this deploy process running. Follow server logs with: tail -f $SERVER_LOG"
    wait "$SERVER_PID"
    exit $?
  fi

  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    wait "$SERVER_PID" || true
    fail "SGLang exited before becoming healthy. Inspect $SERVER_LOG"
  fi
  sleep "$HEALTH_POLL_INTERVAL"
done

log "Health check timed out. Stopping SGLang."
kill "$SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
fail "SGLang did not become healthy within $HEALTH_TIMEOUT_SECONDS seconds. Inspect $SERVER_LOG"
