# MiniMax H3 FL2VA on Vast.ai — No Layer-wise Offloading, Clang Build

This branch starts from `nooffloading` and configures SGLang to run MiniMax H3 FL2VA **without explicit layer-wise CPU offloading**. It also installs Clang and selects `clang`/`clang++` for SGLang's native C++ extension build, with Cargo build parallelism defaulting to 4 jobs.

The installer does not enforce GPU model/count, VRAM, CPU-core, host-RAM, or disk-space minimums. Hardware and disk information are printed for diagnostics only. The software still needs compatible Linux/Python dependencies, a working NVIDIA driver for CUDA inference, and enough actual resources to load and run the model.

## Deployment behavior

1. Reuse the existing FL2VA checkpoint when the completion marker and model index are present.
2. Otherwise download only `model_index.json` and `FL2VA/*` from `MiniMaxAI/MiniMax-H3`.
3. Report available hardware without rejecting the host based on GPU, VRAM, CPU, or RAM.
4. Install OS build dependencies (including Clang), stable Rust, Cargo, and SGLang Diffusion. The SGLang native-extension build uses `CC=clang`, `CXX=clang++`, and `CARGO_BUILD_JOBS=4` by default.
5. Start SGLang without `--layerwise-offload-components`, `--dit-layerwise-resident-layers`, or `--layerwise-resident-layers`.

There is no promise that every machine can run the model. With offloading disabled, insufficient GPU memory can cause CUDA out-of-memory errors during model loading or inference. Removing preflight restrictions does not remove real hardware limits.

## Install and run

On an Ubuntu/Linux instance:

~~~bash
bash deploy.sh
~~~

To force the installer to run again (including checking/installing Clang, Rust, and Cargo):

~~~bash
FORCE_INSTALL=1 bash deploy.sh
~~~

To download/reuse the checkpoint without installing SGLang or starting inference:

~~~bash
DOWNLOAD_ONLY=1 bash deploy.sh
~~~

## Configuration

Optional values can be set in `.env`:

~~~bash
HF_TOKEN=
MODEL_ID=MiniMaxAI/MiniMax-H3
MODEL_PATH=/workspace/h3-vast-deploy/models/MiniMax-H3
HOST=0.0.0.0
PORT=30010
WARMUP_RESOLUTIONS=864x480
WARMUP_NUM_FRAMES=124
~~~

No GPU count or model-name setting is required. SGLang chooses its own runtime behavior and reports unsupported configurations when it starts.

## Native build compiler

- The installer installs the Ubuntu `clang` package and verifies that both `clang` and `clang++` are available.
- Before building SGLang, it exports `CC=clang` and `CXX=clang++` so native C/C++ build steps can use Clang instead of the default GCC toolchain.
- Cargo build parallelism defaults to 4 jobs (`CARGO_BUILD_JOBS=4`); override it by exporting `CARGO_BUILD_JOBS` before running the installer.
- This is a compiler workaround to test, not a guarantee that the SGLang build will succeed. A failure may still come from source, PyTorch, Rust, or other toolchain compatibility issues.

## Hardware notes

- No project-level minimum GPU model, GPU count, VRAM, CPU cores, host RAM, or free-disk threshold is enforced.
- A working NVIDIA driver/CUDA stack is still needed for GPU inference.
- Model weights and inference activations require real memory. A host can pass the installer and still fail with CUDA OOM or host OOM.
- Without layer-wise offloading, the model must fit using the available GPU/runtime memory arrangement. Waiting longer cannot resolve a hard memory shortage.
- CPU count, host RAM, and storage speed can still affect startup and runtime, but this branch does not reject the host based on them.

## API health check

After the server starts, test it from the instance:

~~~bash
./.venv/bin/python test_api.py --base-url http://127.0.0.1:30010
~~~

## References

- [SGLang MiniMax H3 cookbook](https://github.com/sgl-project/sglang/blob/main/docs/cookbook/diffusion/MiniMax/MiniMax-H3.mdx)
- [MiniMax H3 model repository](https://huggingface.co/MiniMaxAI/MiniMax-H3)
