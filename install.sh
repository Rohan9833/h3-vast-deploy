#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"

log() { printf '\n[H3-DEPLOY] %s\n' "$*"; }
fail() { printf '\n[H3-DEPLOY][ERROR] %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Linux" ]] || fail "This installer requires Linux."
command -v nvidia-smi >/dev/null 2>&1 || fail "nvidia-smi not found. A working NVIDIA driver is required for inference."
command -v "$PYTHON_BIN" >/dev/null 2>&1 || fail "$PYTHON_BIN not found."
command -v git >/dev/null 2>&1 || fail "git not found."

log "Detected NVIDIA GPUs (no fixed GPU count or model-name restriction)."
nvidia-smi

log "Checking available host memory and disk (informational only; no fixed minimum)."
free -h || true
df -h "$PROJECT_DIR" || true

log "Checking Python"
"$PYTHON_BIN" --version
"$PYTHON_BIN" -c 'import sys; assert sys.version_info >= (3, 10), "Python 3.10+ required by this project"'

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
    fail "OS packages are missing and neither root nor sudo is available."
  fi
fi

git lfs install --skip-repo >/dev/null 2>&1 || true

log "Creating virtual environment"
if [[ ! -d .venv ]]; then
  "$PYTHON_BIN" -m venv .venv
fi
# shellcheck disable=SC1091
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
log "Installation completed"
printf '\nNext step: run bash deploy.sh to download FL2VA (if needed) and start the server.\n'
