#!/usr/bin/env python3
"""Generate a 10-second MiniMax H3 FL2VA video from root-level start.png to end.png.

Run this script on the same machine/container where SGLang can read the input files.
The server must already be running with --model-variant fl2va.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

import requests


PROJECT_DIR = Path(__file__).resolve().parent
# Prefer repository-root images; accept the historical inputs/uploads layout too.
def resolve_keyframe(filename: str) -> Path:
    candidates = (PROJECT_DIR / filename, PROJECT_DIR / "inputs" / "uploads" / filename)
    return next((path for path in candidates if path.is_file()), candidates[0])


START_IMAGE = resolve_keyframe("start.png")
END_IMAGE = resolve_keyframe("end.png")
DEFAULT_OUTPUT = PROJECT_DIR / "outputs" / "doctor_gerd_transition.mp4"
DEFAULT_BASE_URL = os.getenv("SGLANG_BASE_URL", "http://127.0.0.1:30010").rstrip("/")
MODEL_ID = os.getenv("MODEL_ID", "MiniMaxAI/MiniMax-H3")

PROMPT = """Create a realistic 10-second image-to-video shot using the supplied START FRAME as the exact first frame and the supplied END FRAME as the exact final frame. The video must show one continuous, natural transition from the START FRAME to the END FRAME.

Maintain the exact same senior Indian male doctor throughout the entire video. Preserve exactly facial identity and facial proportions, age and skin tone, hairstyle and hairline, shirt tie and wristwatch, body proportions, consultation desk, monitor and keyboard, notebook, digestive anatomy model, chair, bookshelf books and plants, certificates and wall chart, window and clinic background, lighting shadows perspective and framing. Do not redesign regenerate replace or move any background object.

At the beginning the doctor is exactly in the START FRAME pose with both hands resting naturally on the desk facing the camera.

For approximately the first 6 seconds of the 10-second video, both hands must remain in the START FRAME position with only extremely subtle natural micro-movements. During this period he speaks naturally with realistic lip synchronization, subtle blinking, and very small head movements, but does not begin the explanatory hand gesture.

The arm and hand transition must begin at approximately 6 seconds into the video, independent of the timing of any specific spoken words. Before approximately 6 seconds, the hands should remain largely stationary in the starting pose.

From approximately 6 seconds until the end of the video, he gradually and smoothly performs the gesture transition toward the END FRAME. The majority of the arm movement should occur during the final 4 seconds of the shot. The movement timing must clearly feel delayed, gradual, and synchronized with the overall spoken explanation, without using any specific word or phrase as the trigger for the gesture.

While speaking he remains seated and gradually moves only his arms and hands from the starting position toward the gesture shown in the END FRAME. The hand movement must be slow controlled and anatomically natural.

His right hand gradually rises to the upper horizontal position while his left hand gradually rises to the lower horizontal position. The palms and fingers naturally transition until they precisely reach the positions orientation height and spacing shown in the END FRAME.

The gesture should look like a senior gastroenterologist calmly explaining reflux to a patient. Do not invent any additional gestures.

By the final moment the doctor's body arms hands head and facial orientation must closely match the supplied END FRAME.

Lip movement must be natural and accurately synchronized with the speech. His expression should remain calm professional and reassuring. Allow only subtle natural blinking and extremely small head movements while speaking.

The torso should remain largely stationary. The shoulders should move only as naturally required by the arm movement. Do not lean forward or backward. Do not turn the body. Do not introduce additional hand gestures. Do not point. Do not wave. Do not move the digestive anatomy model or interact with any object.

Locked-off static camera for the entire 10 seconds. No camera movement. No zoom. No push-in. No pull-out. No pan. No tilt. No shake. No reframing. No focus shift.

The doctor's facial identity must remain unchanged from beginning to end. No facial morphing. No face reshaping. No age change. No hairstyle change. No clothing change. No hand deformation. No extra or missing fingers. No fused fingers. No arm deformation. No body warping. No object deformation. No background movement. No flickering. No lighting changes. No exposure changes.

Maintain realistic skin texture sharp facial details and consistent image quality throughout the entire shot.

The END FRAME is a strict pose target not merely a visual reference. The movement must naturally converge toward it and finish in that exact gesture.

The doctor should remain very close to the START FRAME pose until approximately 60% of the video duration has elapsed, then progressively transition toward the END FRAME, reaching it precisely at the final frame.

No white coat. No text. No subtitles. No captions. No logos. No additional people. No added objects.

The doctor says: Correct. In GERD, stomach acid or food can come back up into the food pipe and cause discomfort."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Submit a 10-second FL2VA job using root-level start.png and end.png."
    )
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="SGLang base URL, e.g. http://127.0.0.1:30010")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="Output MP4 path")
    parser.add_argument("--poll-interval", type=float, default=5.0, help="Seconds between status checks")
    parser.add_argument("--timeout", type=float, default=7200.0, help="Maximum seconds to wait for generation")
    parser.add_argument("--steps", type=int, default=50, help="Video diffusion inference steps")
    parser.add_argument("--seed", type=int, default=2101, help="Generation seed")
    return parser.parse_args()


def require_inputs() -> None:
    missing = [str(path) for path in (START_IMAGE, END_IMAGE) if not path.is_file()]
    if missing:
        raise FileNotFoundError(
            "Required keyframe image(s) not found:\n  "
            + "\n  ".join(missing)
            + "\nPlace start.png and end.png in the repository root folder."
        )


def submit_job(session: requests.Session, base_url: str, steps: int, seed: int) -> str:
    # file:// URIs are resolved by the SGLang server process. These paths must
    # therefore exist inside the same host/container that runs SGLang.
    payload: dict[str, Any] = {
        "model": MODEL_ID,
        "prompt": PROMPT,
        "seconds": 10,
        "task": "fl2va",
        "conditions": [
            {
                "type": "image",
                "uri": START_IMAGE.resolve().as_uri(),
                "role": "keyframe",
                "frame_index": 0,
            },
            {
                "type": "image",
                "uri": END_IMAGE.resolve().as_uri(),
                "role": "keyframe",
                "frame_index": -1,
            },
        ],
        "target": {
            "short_edge": 768,
            "aspect_ratio": "auto",
            "duration_seconds": 10.0,
        },
        "num_outputs_per_prompt": 1,
        "num_inference_steps": steps,
        "flow_shift": 12.0,
        "audio_flow_shift": 3.0,
        "seed": seed,
    }

    url = f"{base_url.rstrip('/')}/v1/videos"
    print(f"[H3] Submitting FL2VA request to {url}", flush=True)
    print(f"[H3] Start frame: {START_IMAGE.resolve()}", flush=True)
    print(f"[H3] End frame:   {END_IMAGE.resolve()}", flush=True)

    response = session.post(url, json=payload, timeout=(15, 120))
    if not response.ok:
        raise RuntimeError(
            f"Video creation failed (HTTP {response.status_code}): {response.text}"
        )

    result = response.json()
    video_id = result.get("id")
    if not video_id:
        raise RuntimeError(f"API response did not contain a video job id: {result}")
    print(f"[H3] Job created: {video_id}", flush=True)
    print(f"[H3] Initial response: {json.dumps(result, ensure_ascii=False)}", flush=True)
    return str(video_id)


def wait_for_job(
    session: requests.Session,
    base_url: str,
    video_id: str,
    poll_interval: float,
    timeout: float,
) -> dict[str, Any]:
    status_url = f"{base_url.rstrip('/')}/v1/videos/{video_id}"
    deadline = time.monotonic() + timeout

    while time.monotonic() < deadline:
        response = session.get(status_url, timeout=(15, 60))
        if not response.ok:
            raise RuntimeError(
                f"Status request failed (HTTP {response.status_code}): {response.text}"
            )

        result = response.json()
        status = str(result.get("status", "unknown")).lower()
        progress = result.get("progress")
        print(
            f"[H3] Status: {status}"
            + (f" | progress: {progress}" if progress is not None else ""),
            flush=True,
        )

        if status == "completed":
            return result
        if status in {"failed", "cancelled", "canceled"}:
            raise RuntimeError(
                "Video generation did not complete: "
                + json.dumps(result, ensure_ascii=False)
            )
        time.sleep(poll_interval)

    raise TimeoutError(
        f"Timed out after {timeout:.0f}s waiting for job {video_id}. "
        f"Check its status at {status_url}"
    )


def download_video(
    session: requests.Session, base_url: str, video_id: str, output: Path
) -> None:
    content_url = f"{base_url.rstrip('/')}/v1/videos/{video_id}/content"
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary_output = output.with_suffix(output.suffix + ".part")

    print(f"[H3] Downloading completed video to {output}", flush=True)
    with session.get(content_url, stream=True, timeout=(15, 300)) as response:
        if not response.ok:
            raise RuntimeError(
                f"Video download failed (HTTP {response.status_code}): {response.text}"
            )
        with temporary_output.open("wb") as file_handle:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    file_handle.write(chunk)

    if not temporary_output.exists() or temporary_output.stat().st_size == 0:
        temporary_output.unlink(missing_ok=True)
        raise RuntimeError("The API returned an empty video file.")
    temporary_output.replace(output)
    print(
        f"[H3] Video saved: {output.resolve()} "
        f"({output.stat().st_size / (1024 * 1024):.1f} MiB)",
        flush=True,
    )


def main() -> int:
    args = parse_args()
    base_url = args.base_url.rstrip("/")

    if args.poll_interval <= 0 or args.timeout <= 0:
        print("[ERROR] --poll-interval and --timeout must be greater than zero.", file=sys.stderr)
        return 2
    if args.steps < 1:
        print("[ERROR] --steps must be at least 1.", file=sys.stderr)
        return 2

    try:
        require_inputs()
        with requests.Session() as session:
            video_id = submit_job(session, base_url, args.steps, args.seed)
            wait_for_job(
                session,
                base_url,
                video_id,
                args.poll_interval,
                args.timeout,
            )
            download_video(session, base_url, video_id, args.output)
    except (OSError, requests.RequestException, RuntimeError, TimeoutError, ValueError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    print("[H3] Generation completed successfully.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
