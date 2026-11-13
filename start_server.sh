#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
[[ -d .venv ]] || { echo "Virtual environment missing. Run bash install.sh first." >&2; exit 1; }
source .venv/bin/activate
if [[ -f .env ]]; then set -a; source .env; set +a; fi
export HF_HOME="${HF_HOME:-$PROJECT_DIR/.cache/huggingface}"
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"
mkdir -p "$HF_HOME" logs
if [[ -f "$PROJECT_DIR/models/MiniMax-H3/FL2VA/model_index.json" ]]; then DEFAULT_MODEL_PATH="$PROJECT_DIR/models/MiniMax-H3"; else DEFAULT_MODEL_PATH="MiniMaxAI/MiniMax-H3"; fi
PROFILE="${SGLANG_PROFILE:-recipe_a}"
case "$PROFILE" in
  recipe_a) PROFILE_ARGS=(); PROFILE_DESCRIPTION="Recipe A (memory-focused)" ;;
  recipe_b) PROFILE_ARGS=(--dit-layerwise-resident-layers 4); PROFILE_DESCRIPTION="Recipe B (faster path; higher memory pressure)" ;;
  *) echo "[H3-DEPLOY][ERROR] Unknown SGLANG_PROFILE '$PROFILE'. Use recipe_a or recipe_b." >&2; exit 2 ;;
esac
echo "Starting MiniMax H3 FL2VA using $PROFILE_DESCRIPTION."
echo "Model path: ${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
echo "No GPU/RAM preflight threshold is enforced; SGLang will determine whether this host can run the selected profile."
set +e
sglang serve \
  --model-path "${MODEL_PATH:-$DEFAULT_MODEL_PATH}" \
  --model-variant fl2va \
  --performance-mode memory \
  --layerwise-offload-components dit,text_encoder,vae \
  "${PROFILE_ARGS[@]}" \
  --layerwise-resident-layers video_vae=36 \
  --warmup-resolutions 864x480 \
  --warmup-num-frames 124 \
  --host "${HOST:-0.0.0.0}" \
  --port "${PORT:-30010}"
status=$?
set -e
if (( status != 0 )); then
  echo "[H3-DEPLOY][ERROR] SGLang exited with status $status." >&2
  echo "[H3-DEPLOY][ERROR] Review logs. Possible causes: unsupported GPU/driver, CUDA OOM, insufficient host RAM, or incompatible SGLang dependencies." >&2
  exit "$status"
fi
