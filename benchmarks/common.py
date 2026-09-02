"""Dependency-free helpers for the Lobo public benchmark harness."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SYSTEM = "You are a deterministic state evaluator. Follow the instructions exactly."
FILLER = (
    "Archive segment: identifiers remain distinct; coordinate conventions and state "
    "updates are applied only when explicitly requested. "
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def post_json(url: str, payload: dict[str, Any], timeout: float = 3600.0) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload, separators=(",", ":")).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read())


def get_json(url: str) -> dict[str, Any]:
    with urllib.request.urlopen(url, timeout=30.0) as response:
        return json.loads(response.read())


def tokenize(endpoint: str, text: str) -> list[int]:
    response = post_json(endpoint.rstrip("/") + "/tokenize", {"content": text, "add_special": False}, 60.0)
    tokens = response.get("tokens")
    if not isinstance(tokens, list) or not all(isinstance(token, int) for token in tokens):
        raise RuntimeError(f"unexpected tokenize response: {response!r}")
    return tokens


def exact_depth_prompt(endpoint: str, task: str, depth: int) -> list[int]:
    prefix = f"<|im_start|>system\n{SYSTEM}<|im_end|>\n<|im_start|>user\n"
    suffix = f"{task}<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
    prefix_tokens = tokenize(endpoint, prefix)
    suffix_tokens = tokenize(endpoint, suffix)
    filler = tokenize(endpoint, FILLER)
    available = depth - len(prefix_tokens) - len(suffix_tokens)
    if available < 0:
        raise ValueError(f"depth {depth} is too short for the task")
    tokens = prefix_tokens + (filler * ((available + len(filler) - 1) // len(filler)))[:available] + suffix_tokens
    if len(tokens) != depth:
        raise AssertionError((len(tokens), depth))
    return tokens


def complete(
    endpoint: str,
    tokens: list[int],
    n_predict: int,
    ignore_eos: bool = False,
    cache_prompt: bool = False,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "prompt": tokens,
        "n_predict": n_predict,
        "temperature": 0,
        "seed": 1,
        "cache_prompt": cache_prompt,
        "return_tokens": True,
        "id_slot": 0,
        "stream": False,
    }
    if ignore_eos:
        payload["ignore_eos"] = True
    started = time.perf_counter()
    response = post_json(endpoint.rstrip("/") + "/completion", payload)
    response["client_wall_seconds"] = time.perf_counter() - started
    response["token_sha256"] = hashlib.sha256(
        ",".join(str(token) for token in response.get("tokens", [])).encode()
    ).hexdigest()
    return response


def gpu_snapshot() -> dict[str, Any] | None:
    try:
        output = subprocess.check_output(
            [
                "nvidia-smi",
                "--query-gpu=name,driver_version,memory.used,memory.free,utilization.gpu,power.draw",
                "--format=csv,noheader,nounits",
            ],
            text=True,
            stderr=subprocess.DEVNULL,
        ).splitlines()[0]
        name, driver, used, free, util, power = [value.strip() for value in output.split(",")]
        return {
            "name": name,
            "driver": driver,
            "used_mib": float(used),
            "free_mib": float(free),
            "utilization_pct": float(util),
            "power_w": float(power),
        }
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        return None


def atomic_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def default_output(prefix: str) -> Path:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    return Path(__file__).with_name("results") / f"local-{prefix}-{stamp}.json"
