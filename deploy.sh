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

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi
export HF_HUB_DISABLE_PROGRESS_BARS=0

log "STEP 1/3: Preparing lightweight Python environment."
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

log "STEP 2/3: Downloading MiniMax H3 FL2VA checkpoint (GPU-independent)."
python -u download_model.py
if [[ "${DOWNLOAD_ONLY:-0}" == "1" ]]; then
  log "DOWNLOAD_ONLY=1: download completed; skipping inference hardware checks and server startup."
  exit 0
fi

log "STEP 3/3: Validating flexible Recipe A inference hardware."
command -v nvidia-smi >/dev/null 2>&1 || fail "Inference requires NVIDIA drivers and nvidia-smi."
GPU_COUNT="$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l | tr -d ' ')"
EXPECTED_GPUS="${EXPECTED_GPUS:-1}"
[[ "$GPU_COUNT" -eq "$EXPECTED_GPUS" ]] || fail "Expected $EXPECTED_GPUS visible GPU(s), found $GPU_COUNT."
GPU_NAME="$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)"
GPU_VRAM_MIB="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1 | tr -d ' ')"
MIN_GPU_VRAM_MIB="${MIN_GPU_VRAM_MIB:-12000}"
(( GPU_VRAM_MIB >= MIN_GPU_VRAM_MIB )) || fail "$GPU_NAME has ${GPU_VRAM_MIB} MiB VRAM; need at least ${MIN_GPU_VRAM_MIB} MiB for the Recipe A target."
RAM_KIB="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
RAM_GIB="$((RAM_KIB / 1024 / 1024))"
MIN_RAM_GIB="${MIN_RAM_GIB:-29}"
(( RAM_GIB >= MIN_RAM_GIB )) || fail "Host RAM is about ${RAM_GIB} GiB; Recipe A targets 32 GB-class RAM (minimum ${MIN_RAM_GIB} GiB detected)."
FREE_KIB="$(df -Pk "$PROJECT_DIR" | awk 'NR==2 {print $4}')"
FREE_GIB="$((FREE_KIB / 1024 / 1024))"
MIN_DISK_GIB="${MIN_DISK_GIB:-150}"
(( FREE_GIB >= MIN_DISK_GIB )) || fail "Need ${MIN_DISK_GIB} GiB free disk by this project's conservative download/runtime check; found ${FREE_GIB} GiB."
log "GPU: $GPU_NAME (${GPU_VRAM_MIB} MiB VRAM); RAM: ${RAM_GIB} GiB; CPU threads: $(nproc)."
if [[ "${FORCE_INSTALL:-0}" == "1" || ! -f .install-complete ]]; then
  bash install.sh
  [[ -f .install-complete ]] || fail "Installer finished but .install-complete marker is missing."
else
  log "SGLang dependencies already installed; skipping. Set FORCE_INSTALL=1 to reinstall."
fi
[[ -x .venv/bin/python ]] || fail "Python environment not found. Run bash install.sh and inspect errors."
log "Starting SGLang MiniMax H3 FL2VA Recipe A server on port ${PORT:-30010}."
exec bash start_server.sh
