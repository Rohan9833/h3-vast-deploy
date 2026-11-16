#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

[[ -d .venv ]] || { echo "Virtual environment missing. Run bash install.sh first." >&2; exit 1; }
source .venv/bin/activate

# Preserve explicitly exported shell settings; values in .env act as defaults.
declare -A SHELL_OVERRIDES=()
RUNTIME_ENV_VARS=(
  ENABLE_OFFLOADING MODEL_PATH MODEL_VARIANT MODEL_ID HOST PORT
  WARMUP_RESOLUTIONS WARMUP_NUM_FRAMES OFFLOAD_COMPONENTS
  RESIDENT_LAYERS PYTORCH_CUDA_ALLOC_CONF HF_HOME
)
for name in "${RUNTIME_ENV_VARS[@]}"; do
  if [[ -v "$name" ]]; then
    SHELL_OVERRIDES["$name"]="${!name}"
  fi
done

if [[ -f .env ]]; then
  set -a
  # .env is a trusted shell-style config file owned by the deployment.
  # shellcheck disable=SC1091
  source .env
  set +a
fi
for name in "${!SHELL_OVERRIDES[@]}"; do
  export "$name=${SHELL_OVERRIDES[$name]}"
done

export HF_HOME="${HF_HOME:-$PROJECT_DIR/.cache/huggingface}"
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"
mkdir -p "$HF_HOME" logs

if [[ -f "$PROJECT_DIR/models/MiniMax-H3/FL2VA/model_index.json" ]]; then
  DEFAULT_MODEL_PATH="$PROJECT_DIR/models/MiniMax-H3"
else
  DEFAULT_MODEL_PATH="MiniMaxAI/MiniMax-H3"
fi

ENABLE_OFFLOADING="${ENABLE_OFFLOADING:-1}"
case "${ENABLE_OFFLOADING,,}" in
  1|true|yes|on)
    ENABLE_OFFLOADING=1
    echo "Starting MiniMax H3 FL2VA WITH layer-wise CPU offloading."
    ;;
  0|false|no|off)
    ENABLE_OFFLOADING=0
    echo "Starting MiniMax H3 FL2VA WITHOUT explicit layer-wise CPU offloading."
    ;;
  *)
    echo "Invalid ENABLE_OFFLOADING value: $ENABLE_OFFLOADING" >&2
    echo "Use ENABLE_OFFLOADING=1 (on) or ENABLE_OFFLOADING=0 (off)." >&2
    exit 1
    ;;
esac

MODEL_VARIANT="${MODEL_VARIANT:-fl2va}"
WARMUP_RESOLUTIONS="${WARMUP_RESOLUTIONS:-864x480}"
WARMUP_NUM_FRAMES="${WARMUP_NUM_FRAMES:-124}"
OFFLOAD_COMPONENTS="${OFFLOAD_COMPONENTS:-dit,text_encoder,vae}"
RESIDENT_LAYERS="${RESIDENT_LAYERS:-video_vae=36}"

if ! [[ "$WARMUP_NUM_FRAMES" =~ ^[1-9][0-9]*$ ]]; then
  echo "WARMUP_NUM_FRAMES must be a positive integer; got: $WARMUP_NUM_FRAMES" >&2
  exit 1
fi

SGLANG_ARGS=(
  --model-path "${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
  --model-variant "$MODEL_VARIANT"
  --performance-mode memory
  --warmup-resolutions "$WARMUP_RESOLUTIONS"
  --warmup-num-frames "$WARMUP_NUM_FRAMES"
  --host "${HOST:-0.0.0.0}"
  --port "${PORT:-30010}"
)

if [[ "$ENABLE_OFFLOADING" == "1" ]]; then
  SGLANG_ARGS+=(
    --layerwise-offload-components "$OFFLOAD_COMPONENTS"
    --layerwise-resident-layers "$RESIDENT_LAYERS"
  )
fi

echo "Model path: ${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
echo "Model variant: $MODEL_VARIANT"
echo "Offloading: $ENABLE_OFFLOADING"
echo "Warmup: $WARMUP_RESOLUTIONS, $WARMUP_NUM_FRAMES frames"
echo "CUDA allocator configuration: $PYTORCH_CUDA_ALLOC_CONF"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  printf 'DRY_RUN=1; SGLang command:'
  printf ' %q' sglang serve "${SGLANG_ARGS[@]}"
  printf '\n'
  exit 0
fi

exec sglang serve "${SGLANG_ARGS[@]}"
