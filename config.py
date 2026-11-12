"""Configuration for the MiniMax H3 FL2VA Vast.ai deployment."""

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

# SGLang's verified 2x RTX 5090 TP2 + layerwise-offload profile.
SGLANG_ARGS = [
    "--model-path", str(LOCAL_MODEL_DIR) if LOCAL_MODEL_DIR.exists() else MODEL_ID,
    "--model-variant", MODEL_VARIANT,
    "--num-gpus", "2",
    "--tp-size", "2",
    "--ulysses-degree", "1",
    "--encoder-parallel", "auto",
    "--performance-mode", "memory",
    "--layerwise-offload-components", "dit,text_encoder,vae",
    "--dit-offload-prefetch-size", "1",
    "--dit-layerwise-resident-layers", "20",
    "--enable-torch-compile", "false",
    "--host", HOST,
    "--port", str(PORT),
]
