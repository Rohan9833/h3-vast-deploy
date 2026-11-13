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
if [[ -f .env ]]; then set -a; source .env; set +a; fi
export HF_HUB_DISABLE_PROGRESS_BARS=0
log "Hardware report only; GPU, VRAM and RAM are not used as rejection checks."
log "CPU threads: $(nproc 2>/dev/null || echo unknown)"
if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi || log "GPU query failed; continuing."; else log "nvidia-smi not found; continuing because model download does not require a GPU."; fi
if [[ -r /proc/meminfo ]]; then awk '/MemTotal/ {printf "[H3-DEPLOY] Host RAM: %.1f GiB\n", $2/1024/1024}' /proc/meminfo; fi
df -h "$PROJECT_DIR"
log "STEP 1/3: Preparing Python environment."
PYTHON_BIN="${PYTHON_BIN:-python3}"
command -v "$PYTHON_BIN" >/dev/null 2>&1 || fail "$PYTHON_BIN not found."
if ! "$PYTHON_BIN" -c 'import venv' >/dev/null 2>&1; then
  if [[ "$(id -u)" -eq 0 ]]; then apt-get update && apt-get install -y python3-venv
  elif command -v sudo >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y python3-venv
  else fail "python3-venv is missing and neither root nor sudo is available."; fi
fi
[[ -d .venv ]] || "$PYTHON_BIN" -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
log "STEP 2/3: Downloading MiniMax H3 FL2VA checkpoint (GPU/RAM-independent)."
python -u download_model.py
if [[ "${DOWNLOAD_ONLY:-0}" == "1" ]]; then log "DOWNLOAD_ONLY=1: download completed; skipping runtime installation and inference."; exit 0; fi
log "STEP 3/3: Installing runtime and attempting SGLang startup."
if [[ "${FORCE_INSTALL:-0}" == "1" || ! -f .install-complete ]]; then
  bash install.sh
  [[ -f .install-complete ]] || fail "Installer finished but .install-complete marker is missing."
else log "SGLang dependencies already installed; skipping. Set FORCE_INSTALL=1 to reinstall."; fi
[[ -x .venv/bin/python ]] || fail "Python environment not found. Run bash install.sh and inspect errors."
log "Attempting FL2VA inference with profile: ${SGLANG_PROFILE:-recipe_a}"
log "A successful download does not guarantee that this host can load or run the model."
exec bash start_server.sh
