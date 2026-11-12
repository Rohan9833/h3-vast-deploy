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

echo "Starting MiniMax H3 FL2VA with the single RTX 5090 layerwise-offload recipe."
echo "Model path: ${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
echo "Profile: 1x RTX 5090 32 GB VRAM, 96 GB-class host RAM"
exec sglang serve \\
  --model-path "${MODEL_PATH:-$DEFAULT_MODEL_PATH}" \
  --model-variant fl2va \
  --performance-mode memory \
  --layerwise-offload-components dit,text_encoder,vae \
  --dit-layerwise-resident-layers 4 \
  --layerwise-resident-layers video_vae=36 \
  --warmup-resolutions 864x480 \
  --warmup-num-frames 124 \
  --host "${HOST:-0.0.0.0}" \
  --port "${PORT:-30010}"
