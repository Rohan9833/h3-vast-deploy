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

1. Checks/installs OS packages, creates `.venv`, and installs SGLang Diffusion.
2. Downloads **only `model_index.json` and `FL2VA/*`** from Hugging Face. It deliberately excludes `Ref2VA` and unrelated repository files.
3. Starts the SGLang server on port `30010`.

The Hugging Face aggregate progress bar reports downloaded bytes, percentage, transfer speed and ETA. The download can resume on a later run. The deployment script writes output to `logs/deploy-YYYYMMDD-HHMMSS.log`; `logs/latest.log` points to the latest run.

On later runs, successful dependencies and a completed model download are skipped; the script proceeds to start the server. To force dependency installation again, run:

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
