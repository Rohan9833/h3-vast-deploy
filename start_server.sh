#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

[[ -d .venv ]] || { echo "Virtual environment missing. Run bash install.sh first." >&2; exit 1; }
source .venv/bin/activate

if [[ -f .env ]]; then
  set -a
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

echo "Starting MiniMax H3 FL2VA WITHOUT explicit layer-wise CPU offloading."
echo "Model path: ${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
echo "No GPU model/count, VRAM, CPU-core, or host-RAM preflight restriction is enforced."
echo "SGLang will attempt startup; the host may still fail at runtime due to memory or compatibility limits."

exec sglang serve \
  --model-path "${MODEL_PATH:-$DEFAULT_MODEL_PATH}" \
  --model-variant fl2va \
  --performance-mode memory \
  --warmup-resolutions "${WARMUP_RESOLUTIONS:-864x480}" \
  --warmup-num-frames "${WARMUP_NUM_FRAMES:-124}" \
  --host "${HOST:-0.0.0.0}" \
  --port "${PORT:-30010}"
