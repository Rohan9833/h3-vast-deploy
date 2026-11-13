# MiniMax H3 FL2VA on Vast.ai — Flexible Recipe A

Flexible deployment profile for **MiniMax H3 FL2VA** using the SGLang Recipe A memory-offload command.

## Recipe A hardware target

| Component | Target |
|---|---|
| GPU | One compatible NVIDIA GPU |
| GPU VRAM | 12 GB-class minimum (configurable check: 12000 MiB) |
| Host RAM | 32 GB-class minimum (about 29 GiB detected) |
| CPU | No fixed minimum specified by the Recipe A excerpt |
| Storage | Fast NVMe strongly recommended |
| Free disk | This project's downloader/installer conservatively checks for 150 GiB free |
| Model | MiniMaxAI/MiniMax-H3, FL2VA variant |
| Initial warmup | 864×480, 124 frames |
| Server | 0.0.0.0:30010 by default |

**Important:** 12 GB VRAM + 32 GB host RAM is the cookbook's Recipe A memory-fitting configuration, not a guarantee of identical performance on every GPU or host. The cookbook's low-host-memory benchmark used a machine with very large RAM for caching; a real 32 GB host may be substantially slower due to repeated NVMe reads. Use fast NVMe storage.

## Recipe A command used

```bash
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
sglang serve --model-path MiniMaxAI/MiniMax-H3 --model-variant fl2va \
  --performance-mode memory \
  --layerwise-offload-components dit,text_encoder,vae \
  --layerwise-resident-layers video_vae=36
```

The server script uses this Recipe A configuration and adds host, port and warmup options. It deliberately does **not** add `--dit-layerwise-resident-layers 4`, which belongs to the separate faster Recipe B.

## Setup on Vast.ai

1. Use a Linux/Ubuntu instance with a working NVIDIA driver, one GPU with at least 12 GB VRAM, at least 32 GB system RAM, and fast NVMe storage.
2. Upload this project folder using JupyterLab.
3. Create/configure `.env` from `.env.example` and set `HF_TOKEN` if Hugging Face requires authentication.
4. Run:

```bash
bash deploy.sh
```

The script downloads the FL2VA checkpoint, validates the configured hardware thresholds, installs SGLang Diffusion and starts the API server. Set `DOWNLOAD_ONLY=1` to download without starting inference.

## Flexible hardware thresholds

The defaults are intentionally set for Recipe A. You can override them when running the scripts:

```bash
MIN_GPU_VRAM_MIB=12000 MIN_RAM_GIB=29 MIN_DISK_GIB=150 bash deploy.sh
```

For a deliberate experiment on a different host, these variables can be adjusted. Lowering them does not make an underpowered machine compatible; it only changes the script's preflight checks.

## Generate videos

This repository currently deploys and health-checks the SGLang server. A dedicated prompt-to-video client still needs to be implemented and tested against the exact SGLang API before command-line video generation is available.

## References

- [SGLang MiniMax H3 cookbook](https://github.com/sgl-project/sglang/blob/main/docs/cookbook/diffusion/MiniMax/MiniMax-H3.mdx)
- [MiniMax H3 model repository](https://huggingface.co/MiniMaxAI/MiniMax-H3)
