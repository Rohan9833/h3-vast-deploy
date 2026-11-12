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

echo "Starting MiniMax H3 FL2VA with two RTX 5090 GPUs."
echo "Model path: ${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
exec python -m sglang.launch_server \
  --model-path "${MODEL_PATH:-$DEFAULT_MODEL_PATH}" \
  --model-variant fl2va \
  --num-gpus 2 \
  --tp-size 2 \
  --ulysses-degree 1 \
  --encoder-parallel replicate \
  --performance-mode memory \
  --layerwise-offload-components dit,text_encoder,vae \
  --dit-offload-prefetch-size 1 \
  --dit-layerwise-resident-layers 20 \
  --enable-torch-compile false \
  --host "${HOST:-0.0.0.0}" \
  --port "${PORT:-30010}"
