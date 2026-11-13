#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Flexible Recipe A profile: 12 GB-class GPU VRAM + 32 GB-class host RAM.
MIN_RAM_GIB="${MIN_RAM_GIB:-29}"          # 32 GB decimal is about 29.8 GiB
MIN_GPU_VRAM_MIB="${MIN_GPU_VRAM_MIB:-12000}"
MIN_DISK_GIB="${MIN_DISK_GIB:-150}"
EXPECTED_GPUS="${EXPECTED_GPUS:-1}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

log() { printf '\n[H3-DEPLOY] %s\n' "$*"; }
fail() { printf '\n[H3-DEPLOY][ERROR] %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Linux" ]] || fail "This installer requires Linux/Ubuntu."
command -v nvidia-smi >/dev/null 2>&1 || fail "nvidia-smi not found. Recipe A requires an NVIDIA GPU with a working driver."
command -v "$PYTHON_BIN" >/dev/null 2>&1 || fail "$PYTHON_BIN not found."
command -v git >/dev/null 2>&1 || fail "git not found."

log "Checking NVIDIA GPU and VRAM"
GPU_COUNT="$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l | tr -d ' ')"
[[ "$GPU_COUNT" -eq "$EXPECTED_GPUS" ]] || fail "Expected $EXPECTED_GPUS visible GPU, found $GPU_COUNT."
nvidia-smi
GPU_VRAM_MIB="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1 | tr -d ' ')"
(( GPU_VRAM_MIB >= MIN_GPU_VRAM_MIB )) || fail "GPU has ${GPU_VRAM_MIB} MiB VRAM; Recipe A requires at least ${MIN_GPU_VRAM_MIB} MiB. Set MIN_GPU_VRAM_MIB to override intentionally."

log "Checking CPU availability"
printf 'Visible CPU threads: %s (no fixed CPU minimum is specified by Recipe A)\n' "$(nproc)"

log "Checking host RAM"
RAM_KIB="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
RAM_GIB="$((RAM_KIB / 1024 / 1024))"
free -h
if (( RAM_GIB < MIN_RAM_GIB )); then
  fail "Host RAM is about ${RAM_GIB} GiB; Recipe A targets 32 GB-class host RAM (minimum ${MIN_RAM_GIB} GiB detected)."
fi

log "Checking disk"
mkdir -p "$PROJECT_DIR/.cache"
AVAILABLE_KIB="$(df -Pk "$PROJECT_DIR" | awk 'NR==2 {print $4}')"
AVAILABLE_GIB="$((AVAILABLE_KIB / 1024 / 1024))"
df -h "$PROJECT_DIR"
if (( AVAILABLE_GIB < MIN_DISK_GIB )); then
  fail "Only ${AVAILABLE_GIB} GiB free; this deployment uses a conservative ${MIN_DISK_GIB} GiB free-space check for model and runtime files. Use a sufficiently large fast NVMe volume."
fi

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
  else
    fail "apt dependencies missing and neither root nor sudo is available."
  fi
fi

git lfs install --skip-repo >/dev/null 2>&1 || true

log "Creating virtual environment"
if [[ ! -d .venv ]]; then
  "$PYTHON_BIN" -m venv .venv
fi
source .venv/bin/activate
python -m pip install --upgrade pip setuptools wheel

log "Installing SGLang Diffusion from official source"
if [[ ! -d .deps/sglang ]]; then
  mkdir -p .deps
  git clone --depth 1 https://github.com/sgl-project/sglang.git .deps/sglang
else
  git -C .deps/sglang pull --ff-only
fi
python -m pip install -e ".deps/sglang/python[diffusion]" --upgrade

log "Installing project utilities"
python -m pip install -r requirements.txt

log "Creating runtime directories"
mkdir -p models outputs logs
chmod +x start_server.sh

touch .install-complete
log "Flexible Recipe A inference dependencies installed"
printf '\nNext step: run bash deploy.sh to download FL2VA (if needed) and start the server.\n'
