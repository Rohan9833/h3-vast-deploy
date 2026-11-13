#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
MIN_DISK_GIB="${MIN_DISK_GIB:-150}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
log() { printf '\n[H3-DEPLOY] %s\n' "$*"; }
fail() { printf '\n[H3-DEPLOY][ERROR] %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == "Linux" ]] || fail "This installer requires Linux/Ubuntu."
command -v "$PYTHON_BIN" >/dev/null 2>&1 || fail "$PYTHON_BIN not found."
command -v git >/dev/null 2>&1 || fail "git not found."
log "Hardware report (informational only; no GPU/RAM minimum is enforced)"
printf 'Visible CPU threads: %s\n' "$(nproc 2>/dev/null || echo unknown)"
if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi || true; else printf 'nvidia-smi not found; CUDA inference may not be available.\n'; fi
if [[ -r /proc/meminfo ]]; then awk '/MemTotal/ {printf "Host RAM: %.1f GiB\n", $2/1024/1024}' /proc/meminfo; fi
log "Checking disk space"
mkdir -p "$PROJECT_DIR/.cache"
AVAILABLE_KIB="$(df -Pk "$PROJECT_DIR" | awk 'NR==2 {print $4}')"
AVAILABLE_GIB="$((AVAILABLE_KIB / 1024 / 1024))"
df -h "$PROJECT_DIR"
(( AVAILABLE_GIB >= MIN_DISK_GIB )) || fail "Only ${AVAILABLE_GIB} GiB free; configured disk target is ${MIN_DISK_GIB} GiB. Adjust MIN_DISK_GIB if appropriate."
log "Checking Python"
"$PYTHON_BIN" --version
"$PYTHON_BIN" -c 'import sys; assert sys.version_info >= (3, 10), "Python 3.10+ required"'
log "Installing OS packages"
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get update
    apt-get install -y --no-install-recommends git git-lfs build-essential pkg-config ffmpeg libgl1 libglib2.0-0 python3-venv python3-dev curl ca-certificates
  elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends git git-lfs build-essential pkg-config ffmpeg libgl1 libglib2.0-0 python3-venv python3-dev curl ca-certificates
  else fail "apt dependencies missing and neither root nor sudo is available."; fi
fi
git lfs install --skip-repo >/dev/null 2>&1 || true
log "Creating virtual environment"
[[ -d .venv ]] || "$PYTHON_BIN" -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip setuptools wheel
log "Installing SGLang Diffusion from official source"
if [[ ! -d .deps/sglang ]]; then mkdir -p .deps; git clone --depth 1 https://github.com/sgl-project/sglang.git .deps/sglang; else git -C .deps/sglang pull --ff-only; fi
python -m pip install -e ".deps/sglang/python[diffusion]" --upgrade
log "Installing project utilities"
python -m pip install -r requirements.txt
mkdir -p models outputs logs
chmod +x start_server.sh
touch .install-complete
log "Dependencies installed. Hardware compatibility will be determined when SGLang starts."
printf '\nNext step: run bash deploy.sh to download FL2VA and attempt server startup.\n'
