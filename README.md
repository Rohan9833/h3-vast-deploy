# MiniMax H3 FL2VA on Vast.ai — Flexible Hardware / Recipe Mix

This project downloads the **MiniMax H3 FL2VA** checkpoint without enforcing GPU, VRAM, CPU, or host-RAM minimums. It then attempts to install the runtime and start SGLang. Whether inference succeeds depends on the actual GPU, driver, host memory, storage speed, and SGLang compatibility.

## Deployment behavior

1. Check available disk space against the configurable download target (MIN_DISK_GIB, default 150 GiB).
2. Download only model_index.json and FL2VA/* from MiniMaxAI/MiniMax-H3.
3. Detect and print available hardware as informational diagnostics; do not reject the machine based on GPU or RAM.
4. Install SGLang Diffusion and attempt to start the selected inference profile.
5. If SGLang cannot start, preserve its error output in the deployment log. A successful download is not proof that inference will work.

The 150 GiB download target is a conservative project setting, not a published universal minimum. Lower or raise it deliberately:

~~~bash
MIN_DISK_GIB=100 bash deploy.sh
~~~

Only lower the target if you have independently confirmed the model files, runtime, cache, and outputs will fit. The installer separately checks for 10 GiB of runtime headroom after downloading; this can be changed with MIN_INSTALL_DISK_GIB.

## Select an inference profile

Set SGLANG_PROFILE in .env or before running deployment.

### Recipe A (default)

~~~bash
SGLANG_PROFILE=recipe_a bash deploy.sh
~~~

~~~bash
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
sglang serve --model-path MiniMaxAI/MiniMax-H3 --model-variant fl2va \
  --performance-mode memory \
  --layerwise-offload-components dit,text_encoder,vae \
  --layerwise-resident-layers video_vae=36
~~~

### Recipe B (faster path; higher memory pressure)

~~~bash
SGLANG_PROFILE=recipe_b bash deploy.sh
~~~

~~~bash
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
sglang serve --model-path MiniMaxAI/MiniMax-H3 --model-variant fl2va \
  --performance-mode memory \
  --layerwise-offload-components dit,text_encoder,vae \
  --dit-layerwise-resident-layers 4 \
  --layerwise-resident-layers video_vae=36
~~~

Recipe B can use more GPU and host memory. Selecting it does not guarantee it will work on a given machine. There is no automatic fallback to Recipe A; change SGLANG_PROFILE explicitly if startup fails.

## Setup on Vast.ai

1. Choose a Linux/Ubuntu instance with enough attached storage for the model and runtime. A working supported NVIDIA driver is needed for CUDA inference, but the installer does not reject hosts without one.
2. Upload this project folder.
3. Create .env from .env.example; configure HF_TOKEN if Hugging Face requires authentication.
4. Optionally set MIN_DISK_GIB and SGLANG_PROFILE in .env.
5. Run:

~~~bash
bash deploy.sh
~~~

To download the checkpoint without installing SGLang or attempting inference:

~~~bash
DOWNLOAD_ONLY=1 bash deploy.sh
~~~

## Hardware and performance notes

- GPU/VRAM and host RAM are reported but are not hard preflight blockers.
- Insufficient memory can cause CUDA OOM, host out-of-memory termination, or model-loading failure. Waiting longer cannot fix a hard memory limit.
- Layerwise offloading may allow some lower-VRAM configurations to run, but can substantially increase generation time, especially when host RAM is limited and data must repeatedly be read from NVMe.
- CPU core count and storage speed affect loading and offloading performance. This project does not claim a universal minimum CPU configuration.
- Hardware-independent downloading does not mean hardware-independent inference.

## Video generation status

This repository currently deploys and health-checks the SGLang server. A dedicated prompt-to-video client still needs to be implemented and tested against the exact SGLang API before command-line video generation is available.

## References

- [SGLang MiniMax H3 cookbook](https://github.com/sgl-project/sglang/blob/main/docs/cookbook/diffusion/MiniMax/MiniMax-H3.mdx)
- [MiniMax H3 model repository](https://huggingface.co/MiniMaxAI/MiniMax-H3)
