# MiniMax H3 FL2VA on Vast.ai — Single RTX 5090

One-command deployment for **MiniMax H3 FL2VA** with SGLang Diffusion on one Vast.ai host with **1× NVIDIA RTX 5090 (32 GB)**.

## Target machine

| Component | Target |
|---|---|
| GPU | 1× NVIDIA RTX 5090, 32 GB VRAM |
| CPU | 16–24 cores / at least 16 visible CPU threads |
| Host RAM | 96 GB recommended (the installer accepts about 88 GiB detected) |
| Storage | 250 GB+ NVMe; keep at least 150 GiB free |
| OS | Ubuntu 24.04 with a working NVIDIA driver |
| Model | MiniMaxAI/MiniMax-H3, FL2VA partition |
| API port | 30010 |

This branch uses the official SGLang single-RTX-5090 recipe: memory performance mode, layerwise offload for DiT/text encoder/VAE, four resident DiT layers for the 96-GB host tier, and 36 resident video-VAE layers. The upstream cookbook reports a physical RTX 5090 run at 864×480 and 124 frames on a 60 GB host with 8 GB swap; its consumer-hardware selector adds four resident DiT layers for the 96 GB+ host tier. These are workload-specific measurements, not a guarantee for every resolution, frame count, or request.

Official recipe: [SGLang MiniMax H3 cookbook](https://github.com/sgl-project/sglang/blob/main/docs/cookbook/diffusion/MiniMax/MiniMax-H3.mdx).

## 1. Rent and verify the Vast.ai instance

Choose one host with:
- 1× RTX 5090 (32 GB)
- 96 GB system RAM
- 16–24 CPU cores
- 250 GB+ NVMe
- Ubuntu 24.04

SSH into the instance and run:

```bash
nvidia-smi
free -h
df -h /
nproc
```

Do not proceed if the GPU, RAM, CPU, or storage differs materially from the target. Vast offers can report decimal GB while Linux reports GiB; the installer uses an 88-GiB minimum to accommodate that unit conversion for a nominal 96-GB host.

## 2. Clone this branch

```bash
git clone --branch feature/single-rtx5090-96gb https://github.com/Rohan9833/h3-vast-deploy.git
cd h3-vast-deploy
```

If the repository is private, use your configured GitHub SSH access instead of the HTTPS URL.

## 3. Optional Hugging Face token

If Hugging Face requires authentication for your account:

```bash
cp .env.example .env
nano .env
```

Set `HF_TOKEN=hf_...`. Never commit or share `.env`.

## 4. Install, download and launch

```bash
bash deploy.sh
```

The script:
1. Creates a lightweight Python environment and installs download utilities.
2. Downloads only `model_index.json` and `FL2VA/*` (Ref2VA is excluded).
3. Checks for exactly one RTX 5090, at least 16 CPU threads, about 96 GB host RAM, and at least 150 GiB free disk.
4. Installs SGLang Diffusion and starts the single-GPU layerwise-offload server on port 30010.

The model download happens before inference hardware validation. If the inference checks fail, the downloaded checkpoint remains on disk.

To download only, without installing SGLang or starting inference:

```bash
DOWNLOAD_ONLY=1 bash deploy.sh
```

The Hugging Face progress bars report per-file bytes, percentage, transfer speed and ETA. Re-running the downloader resumes completed files. Logs are written to `logs/deploy-YYYYMMDD-HHMMSS.log`; `logs/latest.log` points to the latest log.

## 5. Test the API

Keep the server running and open a second SSH terminal:

```bash
cd h3-vast-deploy
source .venv/bin/activate
python test_api.py --base-url http://127.0.0.1:30010
```

This health test does not generate a video. Submit a separate generation request to validate end-to-end video generation.

## Important notes

- This branch is specifically for **one RTX 5090**, not two-GPU TP2. It intentionally removes `--num-gpus 2`, `--tp-size 2`, and the two-GPU resident-layer setting.
- The 96 GB RAM target is a recommended host tier, not a claim that the model mathematically requires exactly 96 GB. SGLang's upstream single-5090 physical run reports 60 GB RAM plus 8 GB swap at a specific 480p workload; this branch uses the upstream 96-GB host-tier tuning.
- The upstream single-card result is not a guarantee for arbitrary resolution, duration, concurrency, or simultaneous workloads. Start with the documented 864×480, 124-frame warmup/workload and test before increasing settings.
- Keep the Vast instance and persistent volume while downloading or generating. Rental charges continue while the instance is rented.
- The deployment has not yet been tested on your rented Vast instance. Do not assume successful generation until a real request completes.
- Review the [MiniMax H3 model card and license](https://huggingface.co/MiniMaxAI/MiniMax-H3) before use.

## References

- [Official SGLang MiniMax H3 cookbook](https://github.com/sgl-project/sglang/blob/main/docs/cookbook/diffusion/MiniMax/MiniMax-H3.mdx)
- [MiniMax H3 model card](https://huggingface.co/MiniMaxAI/MiniMax-H3)
- [SGLang](https://github.com/sgl-project/sglang)
