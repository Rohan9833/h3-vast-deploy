#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
PYTHON_BIN="${PYTHON_BIN:-python3}"

log() { printf '\n[H3-DEPLOY] %s\n' "$*"; }
fail() { printf '\n[H3-DEPLOY][ERROR] %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Linux" ]] || fail "This installer requires Linux/Ubuntu."
command -v "$PYTHON_BIN" >/dev/null 2>&1 || fail "$PYTHON_BIN not found."

log "Hardware report (informational only; no GPU, VRAM, CPU, or RAM minimum is enforced)"
printf 'Visible CPU threads: %s\n' "$(nproc 2>/dev/null || echo unknown)"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi || true
else
  printf 'nvidia-smi not found; CUDA inference may not be available. Continuing.\n'
fi
if [[ -r /proc/meminfo ]]; then
  awk '/MemTotal/ {printf "Host RAM: %.1f GiB\n", $2/1024/1024}' /proc/meminfo
fi
df -h "$PROJECT_DIR" || true

log "Installing operating-system build and runtime dependencies"
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get update
    apt-get install -y --no-install-recommends \
      git git-lfs curl ca-certificates build-essential pkg-config clang \
      ffmpeg libgl1 libglib2.0-0 python3-venv python3-dev
  elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
      git git-lfs curl ca-certificates build-essential pkg-config clang \
      ffmpeg libgl1 libglib2.0-0 python3-venv python3-dev
  else
    fail "OS dependencies are missing and neither root nor sudo is available."
  fi
fi

command -v git >/dev/null 2>&1 || fail "git is required to obtain SGLang."
command -v curl >/dev/null 2>&1 || fail "curl is required to install Rust/Cargo."

log "Installing/checking stable Rust toolchain (rustc and Cargo)"
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
export PATH="$CARGO_HOME/bin:$PATH"

if ! command -v cargo >/dev/null 2>&1 || ! command -v rustc >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
fi

if [[ -f "$CARGO_HOME/env" ]]; then
  # shellcheck disable=SC1090
  source "$CARGO_HOME/env"
fi
export PATH="$CARGO_HOME/bin:$PATH"
command -v cargo >/dev/null 2>&1 || fail "Cargo installation failed or Cargo is not in PATH."
command -v rustc >/dev/null 2>&1 || fail "Rust compiler installation failed or rustc is not in PATH."
cargo --version
rustc --version

git lfs install --skip-repo >/dev/null 2>&1 || true

log "Checking Python"
"$PYTHON_BIN" --version
"$PYTHON_BIN" -c 'import sys; assert sys.version_info >= (3, 10), "Python 3.10+ required by SGLang"'

log "Creating virtual environment"
[[ -d .venv ]] || "$PYTHON_BIN" -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip setuptools wheel

log "Installing SGLang Diffusion from official source"
mkdir -p .deps
if [[ ! -d .deps/sglang/.git ]]; then
  rm -rf .deps/sglang
  git clone --depth 1 https://github.com/sgl-project/sglang.git .deps/sglang
else
  git -C .deps/sglang pull --ff-only
fi

# Cargo and Clang are selected explicitly for the SGLang native-extension build.
# Keep build parallelism configurable because native compilation consumes host RAM.
command -v clang >/dev/null 2>&1 || fail "clang is required for the SGLang native build."
command -v clang++ >/dev/null 2>&1 || fail "clang++ is required for the SGLang native build."
export PATH="$CARGO_HOME/bin:$PATH"
export CC=clang
export CXX=clang++
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-2}"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-2}"
log "Building SGLang with Clang: CC=$CC, CXX=$CXX, Cargo jobs=$CARGO_BUILD_JOBS, CMake jobs=$CMAKE_BUILD_PARALLEL_LEVEL"
python -m pip install -e ".deps/sglang/python[diffusion]" --upgrade

log "Installing project utilities"
python -m pip install -r requirements.txt

mkdir -p models outputs logs
chmod +x start_server.sh
touch .install-complete
log "Dependencies installed. No GPU/VRAM/CPU/RAM eligibility checks were applied."
printf '\nNext step: configure .env (or export settings) and run bash start_server.sh.\n'
