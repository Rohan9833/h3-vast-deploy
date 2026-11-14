#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

if [[ ! -d .venv ]]; then
  echo "Virtual environment missing. Run bash install.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1091
source .venv/bin/activate

# Load optional local environment file without printing secrets.
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export HF_HOME="${HF_HOME:-$PROJECT_DIR/.cache/huggingface}"
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"
mkdir -p "$HF_HOME" logs

if [[ -f "$PROJECT_DIR/models/MiniMax-H3/FL2VA/model_index.json" ]]; then
  DEFAULT_MODEL_PATH="$PROJECT_DIR/models/MiniMax-H3"
else
  DEFAULT_MODEL_PATH="MiniMaxAI/MiniMax-H3"
fi

# Use all GPUs visible to this process by default. Override NUM_GPUS and TP_SIZE
# in .env when intentionally testing a different SGLang parallel configuration.
if [[ -z "${NUM_GPUS:-}" ]]; then
  command -v nvidia-smi >/dev/null 2>&1 || {
    echo "nvidia-smi not found; set NUM_GPUS explicitly or install a working NVIDIA driver." >&2
    exit 1
  }
  NUM_GPUS="$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l | tr -d ' ')"
fi
NUM_GPUS="${NUM_GPUS:-1}"
TP_SIZE="${TP_SIZE:-$NUM_GPUS}"

[[ "$NUM_GPUS" =~ ^[1-9][0-9]*$ ]] || { echo "NUM_GPUS must be a positive integer." >&2; exit 1; }
[[ "$TP_SIZE" =~ ^[1-9][0-9]*$ ]] || { echo "TP_SIZE must be a positive integer." >&2; exit 1; }

echo "Starting MiniMax H3 FL2VA without explicit layer-wise CPU offloading."
echo "Visible GPUs requested: $NUM_GPUS | Tensor parallel size: $TP_SIZE"
echo "Model path: ${MODEL_PATH:-$DEFAULT_MODEL_PATH}"

exec python -m sglang.launch_server \
  --model-path "${MODEL_PATH:-$DEFAULT_MODEL_PATH}" \
  --model-variant fl2va \
  --num-gpus "$NUM_GPUS" \
  --tp-size "$TP_SIZE" \
  --ulysses-degree "${ULYSSES_DEGREE:-1}" \
  --encoder-parallel "${ENCODER_PARALLEL:-auto}" \
  --performance-mode "${PERFORMANCE_MODE:-memory}" \
  --enable-torch-compile "${ENABLE_TORCH_COMPILE:-false}" \
  --host "${HOST:-0.0.0.0}" \
  --port "${PORT:-30010}"
