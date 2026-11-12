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

[[ "$(uname -s)" == "Linux" ]] || fail "Run this script on the Vast.ai Ubuntu server, not Windows PowerShell."

# Load optional secrets/settings for both the downloader and server.
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export HF_HUB_DISABLE_PROGRESS_BARS=0

log "Deployment log: $LOG_FILE"

if [[ "${FORCE_INSTALL:-0}" == "1" || ! -f .install-complete ]]; then
  log "STEP 1/3: Installing system packages, Python environment and SGLang."
  bash install.sh
  [[ -f .install-complete ]] || fail "Installer finished but .install-complete marker is missing."
else
  log "STEP 1/3: Dependencies already installed; skipping. Set FORCE_INSTALL=1 to reinstall."
fi

[[ -x .venv/bin/python ]] || fail "Python environment not found. Run bash install.sh and inspect its errors."

log "STEP 2/3: Downloading MiniMax H3 FL2VA checkpoint if it is not already complete."
log "The Hugging Face aggregate progress bar shows percentage, downloaded bytes, speed and ETA."
source .venv/bin/activate
python -u download_model.py

log "STEP 3/3: Starting the SGLang MiniMax H3 FL2VA API server."
log "Server port: ${PORT:-30010}"
log "To stop the server, press Ctrl+C. Full output is being saved to $LOG_FILE"
exec bash start_server.sh
