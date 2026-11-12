#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

mkdir -p logs
LOG_FILE="$PROJECT_DIR/logs/deploy-$(date '+%Y%m%d-%H%M%S').log"
ln -sfn "$(basename "$LOG_FILE")" "$PROJECT_DIR/logs/latest.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  printf '\n[%s] [H3-DEPLOY] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

trap 'status=$?; if [[ $status -ne 0 ]]; then log "Deployment stopped with exit code $status. Review $LOG_FILE"; fi' EXIT

[[ "$(uname -s)" == "Linux" ]] || fail "Run this script on a Linux server/WSL environment."

# Load optional secrets/settings for both downloader and server.
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export HF_HUB_DISABLE_PROGRESS_BARS=0

log "Deployment log: $LOG_FILE"
log "STEP 1/3: Preparing lightweight Python environment for model download."

PYTHON_BIN="${PYTHON_BIN:-python3}"
command -v "$PYTHON_BIN" >/dev/null 2>&1 || fail "$PYTHON_BIN not found."

# A downloader needs no GPU, CUDA, SGLang, or large host RAM.
if ! "$PYTHON_BIN" -c 'import venv' >/dev/null 2>&1; then
  log "python3-venv is missing; installing this small OS package."
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get update
    apt-get install -y python3-venv
  elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y python3-venv
  else
    fail "python3-venv is missing and neither root nor sudo is available."
  fi
fi

if [[ ! -d .venv ]]; then
  "$PYTHON_BIN" -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

log "STEP 2/3: Downloading MiniMax H3 FL2VA checkpoint (GPU-independent)."
log "No GPU, CUDA driver, SGLang installation, or inference RAM check is required for this step."
python -u download_model.py

if [[ "${DOWNLOAD_ONLY:-0}" == "1" ]]; then
  log "DOWNLOAD_ONLY=1: download completed; skipping GPU checks, SGLang installation and server startup."
  log "To run inference later on a compatible NVIDIA host, run: bash deploy.sh"
  exit 0
fi

log "STEP 3/3: Checking inference hardware and installing SGLang."
log "The model is already downloaded; an incompatible GPU will stop here without deleting the checkpoint."
if [[ "${FORCE_INSTALL:-0}" == "1" || ! -f .install-complete ]]; then
  bash install.sh
  [[ -f .install-complete ]] || fail "Installer finished but .install-complete marker is missing."
else
  log "SGLang dependencies already installed; skipping. Set FORCE_INSTALL=1 to reinstall."
fi

[[ -x .venv/bin/python ]] || fail "Python environment not found. Run bash install.sh and inspect its errors."

log "Starting the SGLang MiniMax H3 FL2VA API server."
log "Server port: ${PORT:-30010}"
log "Full output is being saved to $LOG_FILE"
exec bash start_server.sh
