# MiniMax H3 FL2VA on Vast.ai — 64 GB RAM Optimization, Clang Build

This experimental branch starts from `nooffloading-with-clang`. It keeps the Clang-based native build configuration and adds a runtime switch for SGLang layer-wise CPU offloading. The default is **enabled** for testing on memory-constrained hosts; it can be disabled through an environment variable.

The installer does not enforce GPU model/count, VRAM, CPU-core, host-RAM, or disk-space minimums. Passing installation does not guarantee that the model will fit or run: actual memory and hardware limits still apply.

## Deployment behavior

1. Reuse the existing FL2VA checkpoint when the completion marker is present and `FL2VA/model_index.json` parses as valid JSON.
2. Otherwise download only `model_index.json` and `FL2VA/*` from the configured model repository; Hugging Face Hub resumes existing files on rerun.
3. Report available hardware without rejecting the host based on GPU, VRAM, CPU, or RAM.
4. Install OS build dependencies (including Clang), stable Rust, Cargo, and SGLang Diffusion. Before the native build, fetch the radix-tree Rust dependencies and apply the `torch-sys 0.24.0` C++20 identifier compatibility patch automatically. The SGLang native-extension build uses `CC=clang`, `CXX=clang++`, and `CARGO_BUILD_JOBS=2` by default.
5. Start SGLang with configurable warmup and layer-wise CPU offloading settings. `deploy.sh` waits for the `/health` endpoint and reports when the API is ready. `DRY_RUN=1` prints the launch command without starting inference when using `start_server.sh` directly.

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

The normal `deploy.sh` flow installs/reuses the Python environment, downloads or reuses the FL2VA checkpoint, installs the native SGLang runtime (including the automatic `torch-sys` compatibility patch when installation runs), starts SGLang, and waits for `/health` before reporting readiness. The deployment process stays attached while the server runs; server output is written to `logs/server.log`.

Health-check timing can be adjusted with:

~~~bash
HEALTH_TIMEOUT_SECONDS=5400 HEALTH_POLL_INTERVAL=10 bash deploy.sh
~~~

Use `DRY_RUN=1 bash deploy.sh` to print the SGLang launch command without starting the server.

## Layer-wise CPU offloading switch

The switch is read by `start_server.sh` from the environment or the optional `.env` file. Explicit environment variables take precedence over `.env` values in both `deploy.sh` and `start_server.sh`.

| Setting | Behavior |
|---|---|
| `ENABLE_OFFLOADING=1` | Enables layer-wise CPU offloading (default) |
| `ENABLE_OFFLOADING=0` | Disables the layer-wise offloading flags |

When enabled, the launch command adds:

~~~bash
--layerwise-offload-components dit,text_encoder,vae
--layerwise-resident-layers video_vae=36
~~~

When disabled, those two arguments are omitted. The script accepts `1/0`, `true/false`, `yes/no`, and `on/off`; any other value causes a clear startup error. `deploy.sh` keeps the SGLang process attached to the deployment session after the health check succeeds and writes its output to `logs/server.log`.

To enable offloading in `.env`:

~~~bash
ENABLE_OFFLOADING=1
OFFLOAD_COMPONENTS=dit,text_encoder,vae
RESIDENT_LAYERS=video_vae=36
~~~

To disable it:

~~~bash
ENABLE_OFFLOADING=0
~~~

You can also set it for a single launch without editing `.env`:

~~~bash
ENABLE_OFFLOADING=1 bash start_server.sh
~~~

or:

~~~bash
ENABLE_OFFLOADING=0 bash start_server.sh
~~~

**Note:** This switch controls explicit layer-wise CPU offloading flags. It does not disable every possible SGLang/PyTorch memory-management behavior, nor does it guarantee that either mode fits a particular machine.

## Configuration

Optional values can be set in `.env`:

~~~bash
HF_TOKEN=
HF_DOWNLOAD_MAX_WORKERS=4
MODEL_ID=MiniMaxAI/MiniMax-H3
MODEL_PATH=/workspace/h3-vast-deploy/models/MiniMax-H3
HOST=0.0.0.0
PORT=30010
WARMUP_RESOLUTIONS=864x480
WARMUP_NUM_FRAMES=124
ENABLE_OFFLOADING=1
~~~

## Download tuning

`HF_DOWNLOAD_MAX_WORKERS` controls the number of concurrent Hugging Face file downloads (default: `4`). Lower it if network or disk activity needs to be gentler; it does not reduce the model checkpoint's total size.

## Startup tuning and dry run

The following values are configurable in `.env` or as exported environment variables:

- `WARMUP_RESOLUTIONS` and `WARMUP_NUM_FRAMES` control startup warmup only; they do not set the requested output video's resolution or duration.
- `OFFLOAD_COMPONENTS` and `RESIDENT_LAYERS` control the explicit layer-wise offloading CLI values when offloading is enabled. Their defaults retain the existing FL2VA settings and must be validated against the installed SGLang revision.
- `PYTORCH_CUDA_ALLOC_CONF` defaults to `expandable_segments:True` and can be overridden for controlled tests.

To inspect the exact launch command without loading the model:

~~~bash
DRY_RUN=1 bash start_server.sh
~~~

The virtual environment must exist, but SGLang does not need to be launched for this check. The validation also compiles the automatic `torch-sys` patch helper.

## Local validation (no GPU required)

Run the repository's shell/Python syntax and configuration checks before renting hardware:

~~~bash
bash validate.sh
~~~

These checks validate local code and environment-variable behavior only. They do not prove that the installed SGLang revision accepts every runtime flag or that the checkpoint fits in a given machine.

## Monitoring

Run the optional resource monitor in another terminal while starting or generating:

~~~bash
bash monitor.sh 2
~~~

It reports system RAM, swap, GPU memory/utilization (when `nvidia-smi` is available), and the SGLang process RSS. It does not alter runtime settings.

## Native build compiler

- The installer installs the Ubuntu `clang` package and verifies that both `clang` and `clang++` are available.
- Before building SGLang, it exports `CC=clang` and `CXX=clang++` so native C/C++ build steps can use Clang instead of the default GCC toolchain.
- Cargo build parallelism defaults to 2 jobs (`CARGO_BUILD_JOBS=2`) to limit concurrent native-build memory use on the target host; override it by exporting `CARGO_BUILD_JOBS` before running the installer.
- This is a compiler workaround to test, not a guarantee that the SGLang build will succeed. A failure may still come from source, PyTorch, Rust, or other toolchain compatibility issues.

## Hardware notes

- No project-level minimum GPU model, GPU count, VRAM, CPU cores, host RAM, or free-disk threshold is enforced.
- A working NVIDIA driver/CUDA stack is still needed for GPU inference.
- Model weights and inference activations require real memory. A host can pass the installer and still fail with CUDA OOM or host OOM.
- Layer-wise offloading can reduce GPU residency but increases host-memory use and may increase latency. Disabling it may increase GPU-memory pressure.
- CPU count, host RAM, and storage speed can still affect startup and runtime.

## Generate the doctor GERD explanation video

Place the two keyframe images either directly in the repository root (preferred) or in `inputs/uploads/`. The script checks the repository root first, then falls back to `inputs/uploads/`:

~~~text
h3-vast-deploy/
├── generate_doctor_video.py
├── start.png
└── end.png
~~~

Start the server first, then run:

~~~bash
python generate_doctor_video.py
~~~

The script submits a 10-second `fl2va` job to `POST /v1/videos`, using `start.png` as frame index `0` and `end.png` as frame index `-1`. It polls `GET /v1/videos/{id}` until completion and downloads `GET /v1/videos/{id}/content` to:

~~~text
outputs/doctor_gerd_transition.mp4
~~~

Optional arguments:

~~~bash
python generate_doctor_video.py --base-url http://127.0.0.1:30010 --output outputs/doctor.mp4 --poll-interval 5 --timeout 7200 --steps 50 --seed 2101
~~~

Set `SGLANG_BASE_URL` if the API is not at `http://127.0.0.1:30010`. The selected image paths are resolved on the SGLang server itself: if the server runs in a container, the selected image directory must be inside that container or mounted there at the same path. The script uses the supplied doctor prompt and includes the spoken line verbatim. It requests the 768-pixel short-edge profile; generated identity, timing, and exact endpoint matching remain model outputs and are not guaranteed by the API client.

## API health check

After the server starts, test it from the instance:

~~~bash
./.venv/bin/python test_api.py --base-url http://127.0.0.1:30010
~~~

## References

- [SGLang MiniMax H3 cookbook](https://github.com/sgl-project/sglang/blob/main/docs/cookbook/diffusion/MiniMax/MiniMax-H3.mdx)
- [MiniMax H3 model repository](https://huggingface.co/MiniMaxAI/MiniMax-H3)
