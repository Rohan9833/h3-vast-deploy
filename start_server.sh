
#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Check virtual environment
[[ -d .venv ]] || {
  echo "Virtual environment missing. Run bash install.sh first." >&2
  exit 1
}

source .venv/bin/activate

# Load environment variables
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

# Hugging Face and PyTorch configuration
export HF_HOME="${HF_HOME:-$PROJECT_DIR/.cache/huggingface}"
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"

mkdir -p "$HF_HOME" logs

# Detect model path
if [[ -f "$PROJECT_DIR/models/MiniMax-H3/FL2VA/model_index.json" ]]; then
  DEFAULT_MODEL_PATH="$PROJECT_DIR/models/MiniMax-H3"
else
  DEFAULT_MODEL_PATH="MiniMaxAI/MiniMax-H3"
fi

# Offloading configuration
# 0 = OFF
# 1 = ON
ENABLE_OFFLOADING="${ENABLE_OFFLOADING:-0}"

# Build SGLang arguments
SGLANG_ARGS=(
  --model-path "${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
  --model-variant fl2va
  --performance-mode memory
  --warmup-resolutions "${WARMUP_RESOLUTIONS:-864x480}"
  --warmup-num-frames "${WARMUP_NUM_FRAMES:-124}"
  --host "${HOST:-0.0.0.0}"
  --port "${PORT:-30010}"
)

# Enable or disable layer-wise CPU offloading
if [[ "$ENABLE_OFFLOADING" == "1" ]]; then

  echo "Starting MiniMax H3 FL2VA WITH explicit layer-wise CPU offloading."

  SGLANG_ARGS+=(
    --layerwise-offload-components dit,text_encoder,vae
    --layerwise-resident-layers video_vae=36
  )

elif [[ "$ENABLE_OFFLOADING" == "0" ]]; then

  echo "Starting MiniMax H3 FL2VA WITHOUT explicit layer-wise CPU offloading."

else

  echo "Invalid ENABLE_OFFLOADING value: $ENABLE_OFFLOADING" >&2
  echo "Allowed values: 0 or 1" >&2
  exit 1

fi

# Display configuration
echo "=========================================="
echo "MiniMax H3 FL2VA Server Configuration"
echo "=========================================="
echo "Model path: ${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
echo "Offloading: $ENABLE_OFFLOADING"
echo "Performance mode: memory"
echo "Host: ${HOST:-0.0.0.0}"
echo "Port: ${PORT:-30010}"
echo "=========================================="

echo "Starting SGLang server..."

# Start inference server
exec sglang serve "${SGLANG_ARGS[@]}"
