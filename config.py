"""Configuration for the single-RTX-5090 MiniMax H3 FL2VA deployment."""

from __future__ import annotations

import os
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent
MODEL_ID = os.getenv("MODEL_ID", "MiniMaxAI/MiniMax-H3")
MODEL_VARIANT = os.getenv("MODEL_VARIANT", "fl2va")
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "30010"))
HF_HOME = Path(os.getenv("HF_HOME", str(PROJECT_DIR / ".cache" / "huggingface")))
LOCAL_MODEL_DIR = Path(os.getenv("LOCAL_MODEL_DIR", str(PROJECT_DIR / "models" / "MiniMax-H3")))
HF_TOKEN = os.getenv("HF_TOKEN") or None

# Official SGLang single-RTX-5090 FL2VA memory/offload profile for a 96-GB-class host.
SGLANG_ARGS = [
    "--model-path", str(LOCAL_MODEL_DIR) if LOCAL_MODEL_DIR.exists() else MODEL_ID,
    "--model-variant", MODEL_VARIANT,
    "--performance-mode", "memory",
    "--layerwise-offload-components", "dit,text_encoder,vae",
    "--dit-layerwise-resident-layers", "4",
    "--layerwise-resident-layers", "video_vae=36",
    "--warmup-resolutions", "864x480",
    "--warmup-num-frames", "124",
    "--host", HOST,
    "--port", str(PORT),
]
