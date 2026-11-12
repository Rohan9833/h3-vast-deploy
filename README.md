# MiniMax H3 on Vast.ai

Manual Ubuntu + Python deployment for **MiniMax H3 FL2VA** using **SGLang Diffusion** on a single Vast.ai host with **2× NVIDIA RTX 5090 (32 GB each)**.

> **Important:** This repository is an installation/deployment starter, not a guarantee that every Vast.ai host will work. The two-RTX-5090 recipe is a memory-constrained, layerwise-offload configuration. It requires both GPUs on the same host and sufficient system RAM. The current SGLang cookbook specifies a 384-GiB-class host for this profile.

## Hardware target

| Component | Target |
|---|---|
| GPUs | 2× RTX 5090, 32 GB each |
| CPU | 16–24+ cores |
| Host RAM | 384 GiB class recommended for this recipe |
| Storage | 250 GB+ fast NVMe; more if retaining outputs/cache |
| OS | Ubuntu 24.04 |
| Runtime | NVIDIA driver on host; CUDA-compatible Python environment |
| Serving | SGLang Diffusion |
| Model variant | FL2VA |

The exact SGLang flags are taken from the [official SGLang MiniMax H3 cookbook](https://github.com/sgl-project/sglang/blob/main/docs/cookbook/diffusion/MiniMax/MiniMax-H3.mdx). That cookbook currently calls out `--encoder-parallel replicate` for the two-card RTX 5090 host topology.

## 1. Rent and prepare the Vast.ai instance

Choose one instance with both RTX 5090 GPUs on the **same host**. Use an Ubuntu 24.04 image with a working NVIDIA driver and GPU passthrough. Do not install NVIDIA kernel drivers inside the container.

Before running installation:

```bash
nvidia-smi
nvidia-smi -L
free -h
df -h /
lscpu
```

Confirm that exactly two RTX 5090 GPUs are visible, host memory is close to the intended 384-GiB class, and at least 200 GB of usable storage is available. If anything differs, stop and review before downloading model weights.

## 2. Get the project onto the instance

From the Vast.ai SSH terminal:

```bash
git clone https://github.com/Rohan9833/h3-vast-deploy.git
cd h3-vast-deploy
```

Alternatively, upload the folder with SCP from your local computer.

## 3. Install

Run the installer as the normal instance user (Vast containers commonly use `root`):

```bash
bash install.sh
```

The script checks the GPUs, host RAM, free disk and NVIDIA driver before creating a virtual environment. It installs SGLang Diffusion from the official SGLang source using its `python[diffusion]` extra. This follows the SGLang H3 cookbook's source-install approach; dependency resolution can take time and may change as upstream evolves.

To override the RAM/disk guardrails for a different test host, set the environment variables documented in `install.sh`. Do not override them unless you understand the memory and storage implications.

## 4. Hugging Face access and model download

The model is public in Hugging Face, but download access/rate limits can still apply. Set a token only if your environment needs one:

```bash
export HF_TOKEN="hf_..."
```

Do not commit tokens or put them in source files. The SGLang server downloads `MiniMaxAI/MiniMax-H3` on first launch. To pre-download/cache it:

```source .venv/bin/activate
python download_model.py
```

Model files are large. Keep the Hugging Face cache on persistent storage if your Vast instance supports it.

## 5. Start SGLang

```bash
bash start_server.sh
```

The server listens on port `30010`. Keep it private while testing. Only expose the port in Vast.ai when needed, and configure firewall/authentication before any public use.

## 6. Test the server

In a second SSH session:

```bash
source .venv/bin/activate
python test_api.py --base-url http://127.0.0.1:30010
```

The test script checks the server health endpoint and prints the available routes. It does not submit a long video-generation job automatically.

## Operational notes

- First startup downloads model weights and may take significant time.
- Initial model loading and first generation are slower than subsequent requests.
- Video generation is compute- and memory-intensive. Monitor `nvidia-smi`, RAM and disk.
- Use persistent storage or external object storage for generated videos and model caches.
- Stop or destroy the Vast instance when it is not needed; GPU rental costs continue while it is rented.
- Do not treat this setup as production-hardened. Add an authenticated API gateway, request queue, quotas, output storage, monitoring and recovery before serving users.
- Review the [MiniMax H3 Community License](https://huggingface.co/MiniMaxAI/MiniMax-H3) before commercial use.

## References

- [Official SGLang MiniMax H3 cookbook](https://github.com/sgl-project/sglang/blob/main/docs/cookbook/diffusion/MiniMax/MiniMax-H3.mdx)
- [MiniMax H3 on Hugging Face](https://huggingface.co/MiniMaxAI/MiniMax-H3)
- [SGLang project](https://github.com/sgl-project/sglang)
