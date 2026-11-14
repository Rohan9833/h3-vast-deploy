"""Configuration for MiniMax H3 FL2VA deployment without layer-wise offloading."""

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

# Intentionally contains no layer-wise CPU offloading or resident-layer flags.
SGLANG_ARGS = [
    "--model-path",
    str(LOCAL_MODEL_DIR) if (LOCAL_MODEL_DIR / "FL2VA" / "model_index.json").exists() else MODEL_ID,
    "--model-variant",
    MODEL_VARIANT,
    "--performance-mode",
    "memory",
    "--warmup-resolutions",
    os.getenv("WARMUP_RESOLUTIONS", "864x480"),
    "--warmup-num-frames",
    os.getenv("WARMUP_NUM_FRAMES", "124"),
    "--host",
    HOST,
    "--port",
    str(PORT),
]
