# MiniMax H3 on Vast.ai

One-command deployment for **MiniMax H3 FL2VA** with SGLang Diffusion on one Vast.ai host with **2× NVIDIA RTX 5090 (32 GB each)**.

## Hardware target

| Component | Target |
|---|---|
| GPUs | 2× RTX 5090, 32 GB each, same host |
| CPU | 16–24+ cores |
| Host RAM | 384 GiB class recommended for this SGLang offload recipe |
| Storage | 250 GB+ fast NVMe; keep at least 200 GiB free before installation |
| OS | Ubuntu 24.04 with working NVIDIA driver |
| API port | 30010 |

The exact SGLang launch arguments follow the [official SGLang MiniMax H3 cookbook](https://github.com/sgl-project/sglang/blob/main/docs/cookbook/diffusion/MiniMax/MiniMax-H3.mdx). Check the current upstream recipe before deployment because SGLang changes over time.

## 1. Connect and check the Vast.ai machine

SSH into your Vast.ai Ubuntu instance, then run:

```bash
nvidia-smi
free -h
df -h /
lscpu
```

Confirm two RTX 5090 GPUs, sufficient host RAM, and enough free disk. Do not run the Linux commands in Windows PowerShell before connecting over SSH.

## 2. Get this repository onto the instance

```bash
git clone https://github.com/Rohan9833/h3-vast-deploy.git
cd h3-vast-deploy
```

## 3. Configure optional Hugging Face settings

If you need a Hugging Face token or a custom cache location:

```bash
cp .env.example .env
nano .env
```

Put your token in `.env` as `HF_TOKEN=hf_...`. Never commit this file or share the token.

## 4. One-command install, download and launch

Run this single command:

```bash
bash deploy.sh
```

It performs these steps in order:

1. Creates a lightweight Python environment and installs only the small download utilities. **No GPU, CUDA, SGLang, or large-RAM requirement is checked yet.**
2. Downloads **only `model_index.json` and `FL2VA/*`** from Hugging Face. It deliberately excludes `Ref2VA` and unrelated repository files.
3. Checks inference hardware, installs SGLang Diffusion, and starts the server on port `30010`.

This means model downloading works independently of GPU vendor or GPU presence, provided the machine has Python, internet access, and sufficient free disk. An incompatible GPU will only stop the later inference-installation stage; the downloaded checkpoint is kept.

To download the model only, without GPU checks, SGLang installation, or server startup, run:

```bash
DOWNLOAD_ONLY=1 bash deploy.sh
```

To install and launch inference after the model has been downloaded on a compatible NVIDIA host, run:

```bash
bash deploy.sh
```

The Hugging Face per-file progress bars report downloaded bytes, percentage, transfer speed and ETA. The download can resume on a later run. The deployment script writes output to `logs/deploy-YYYYMMDD-HHMMSS.log`; `logs/latest.log` points to the latest run.

On later runs, a completed model download is skipped. SGLang dependencies are installed only after the inference hardware checks pass. To force dependency installation again, run:

```bash
FORCE_INSTALL=1 bash deploy.sh
```

## 5. Test the API

Keep the server terminal running. Open a second SSH terminal:

```bash
cd h3-vast-deploy
source .venv/bin/activate
python test_api.py --base-url http://127.0.0.1:30010
```

The health test does not submit a video-generation request.

## Operational notes

- Keep the Vast.ai instance running while downloading or generating.
- Use persistent storage so the model is not lost when the instance stops.
- The server listens on port `30010`. Expose it in Vast.ai only when needed; add authentication/firewall controls before public use.
- Stop the server with Ctrl+C. GPU rental charges continue while the instance is rented.
- The deployment scripts have not been validated on your actual rented host yet. Hardware checks and a real first run are still required.
- Review the [MiniMax H3 model card and license](https://huggingface.co/MiniMaxAI/MiniMax-H3) before use.

## References

- [Official MiniMax H3 model card](https://huggingface.co/MiniMaxAI/MiniMax-H3)
- [Official SGLang MiniMax H3 cookbook](https://github.com/sgl-project/sglang/blob/main/docs/cookbook/diffusion/MiniMax/MiniMax-H3.mdx)
- [SGLang](https://github.com/sgl-project/sglang)

## Windows CMD / PowerShell launcher (local PC only)

If you want to start the same workflow from Windows, use the included WSL launcher:

```cmd
deploy-windows.bat
```

The launcher checks for an installed Ubuntu WSL distribution. If Ubuntu is missing, it requests installation with `wsl --install -d Ubuntu`; Windows may require Administrator approval and a restart. After installation, open Ubuntu once to finish its first-time username/password setup, then run `deploy-windows.bat` again.

If WSL itself is not installed/enabled, open an elevated PowerShell and run:

```powershell
wsl --install -d Ubuntu
```

Restart if Windows requests it, open Ubuntu once, finish setup, and rerun the launcher.

**Important:** This Windows launcher runs the deployment on your local PC inside WSL. It does not connect to or deploy on your Vast.ai instance. Your local PC must independently pass the same GPU, RAM, disk and driver checks. To deploy on Vast.ai, SSH into the Vast.ai Ubuntu machine and run `bash deploy.sh` there.
