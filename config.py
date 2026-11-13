"""Configuration for flexible MiniMax H3 FL2VA deployment."""
from __future__ import annotations
import os
from pathlib import Path
PROJECT_DIR = Path(__file__).resolve().parent
MODEL_ID = os.getenv("MODEL_ID", "MiniMaxAI/MiniMax-H3")
MODEL_VARIANT = os.getenv("MODEL_VARIANT", "fl2va")
SGLANG_PROFILE = os.getenv("SGLANG_PROFILE", "recipe_a").lower()
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "30010"))
HF_HOME = Path(os.getenv("HF_HOME", str(PROJECT_DIR / ".cache" / "huggingface")))
LOCAL_MODEL_DIR = Path(os.getenv("LOCAL_MODEL_DIR", str(PROJECT_DIR / "models" / "MiniMax-H3")))
HF_TOKEN = os.getenv("HF_TOKEN") or None
if SGLANG_PROFILE not in {"recipe_a", "recipe_b"}:
    raise ValueError("SGLANG_PROFILE must be 'recipe_a' or 'recipe_b'")
SGLANG_ARGS = [
    "--model-path", str(LOCAL_MODEL_DIR) if (LOCAL_MODEL_DIR / "FL2VA" / "model_index.json").exists() else MODEL_ID,
    "--model-variant", MODEL_VARIANT,
    "--performance-mode", "memory",
    "--layerwise-offload-components", "dit,text_encoder,vae",
]
if SGLANG_PROFILE == "recipe_b":
    SGLANG_ARGS.extend(["--dit-layerwise-resident-layers", "4"])
SGLANG_ARGS.extend([
    "--layerwise-resident-layers", "video_vae=36",
    "--warmup-resolutions", "864x480",
    "--warmup-num-frames", "124",
    "--host", HOST,
    "--port", str(PORT),
])
