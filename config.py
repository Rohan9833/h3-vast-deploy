"""Configuration for MiniMax H3 FL2VA deployment."""

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


def _env_bool(name: str, default: bool) -> bool:
    """Read a boolean environment variable with explicit validation."""
    value = os.getenv(name)
    if value is None:
        return default

    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    raise ValueError(f"{name} must be set to 1/on or 0/off; got {value!r}")


# Enabled by default for the 64 GB host-RAM optimization profile.
ENABLE_OFFLOADING = _env_bool("ENABLE_OFFLOADING", default=True)

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

if ENABLE_OFFLOADING:
    SGLANG_ARGS.extend(
        [
            "--layerwise-offload-components",
            "dit,text_encoder,vae",
            "--layerwise-resident-layers",
            "video_vae=36",
        ]
    )
