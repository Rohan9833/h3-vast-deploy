"""Configuration for MiniMax H3 FL2VA deployment."""

import os
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent
MODEL_ID = os.getenv("MODEL_ID", "MiniMaxAI/MiniMax-H3")
MODEL_VARIANT = os.getenv("MODEL_VARIANT", "fl2va")
HOST = os.getenv("HOST", "0.0.0.0")


def _env_int(name: str, default: int, *, minimum: int = 1) -> int:
    """Read and validate a positive integer environment variable."""
    raw_value = os.getenv(name)
    try:
        value = default if raw_value is None else int(raw_value)
    except ValueError as exc:
        raise ValueError(f"{name} must be an integer; got {raw_value!r}") from exc
    if value < minimum:
        raise ValueError(f"{name} must be >= {minimum}; got {value}")
    return value


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


PORT = _env_int("PORT", 30010, minimum=1)
if PORT > 65535:
    raise ValueError(f"PORT must be <= 65535; got {PORT}")

HF_HOME = Path(os.getenv("HF_HOME", str(PROJECT_DIR / ".cache" / "huggingface")))
LOCAL_MODEL_DIR = Path(os.getenv("LOCAL_MODEL_DIR", str(PROJECT_DIR / "models" / "MiniMax-H3")))
HF_TOKEN = os.getenv("HF_TOKEN") or None

# An explicit MODEL_PATH wins; otherwise use the local checkpoint when present.
_default_model_path = (
    str(LOCAL_MODEL_DIR)
    if (LOCAL_MODEL_DIR / "FL2VA" / "model_index.json").exists()
    else MODEL_ID
)
MODEL_PATH = os.getenv("MODEL_PATH") or _default_model_path

ENABLE_OFFLOADING = _env_bool("ENABLE_OFFLOADING", default=True)
WARMUP_RESOLUTIONS = os.getenv("WARMUP_RESOLUTIONS", "864x480")
WARMUP_NUM_FRAMES = _env_int("WARMUP_NUM_FRAMES", 124)
OFFLOAD_COMPONENTS = os.getenv("OFFLOAD_COMPONENTS", "dit,text_encoder,vae")
RESIDENT_LAYERS = os.getenv("RESIDENT_LAYERS", "video_vae=36")

# Kept as a reusable argument list for Python entry points. start_server.sh
# builds the equivalent CLI arguments directly so it can run without Python.
SGLANG_ARGS = [
    "--model-path", MODEL_PATH,
    "--model-variant", MODEL_VARIANT,
    "--performance-mode", "memory",
    "--warmup-resolutions", WARMUP_RESOLUTIONS,
    "--warmup-num-frames", str(WARMUP_NUM_FRAMES),
    "--host", HOST,
    "--port", str(PORT),
]

if ENABLE_OFFLOADING:
    SGLANG_ARGS.extend(
        [
            "--layerwise-offload-components", OFFLOAD_COMPONENTS,
            "--layerwise-resident-layers", RESIDENT_LAYERS,
        ]
    )
