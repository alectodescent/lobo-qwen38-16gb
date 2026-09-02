#!/usr/bin/env python3
"""Run the public fragile long-binding qualification against a running server."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from common import atomic_json, complete, default_output, exact_depth_prompt, get_json, gpu_snapshot, utc_now


def extract_json(text: str):
    decoder = json.JSONDecoder()
    for offset, character in enumerate(text):
        if character in "[{":
            try:
                value, _ = decoder.raw_decode(text[offset:])
                return value
            except json.JSONDecodeError:
                pass
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", default="http://127.0.0.1:18080")
    parser.add_argument("--profile", default="balanced")
    parser.add_argument("--depth", type=int, default=230000)
    parser.add_argument("--prediction-tokens", type=int, default=96)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    panel = json.loads(Path(__file__).with_name("spatial-firewall-v1.json").read_text(encoding="utf-8"))
    case = next(item for item in panel["cases"] if item["id"] == "long-binding-01")
    task = case["prompt"] + "\n\n" + panel["response_contract"]
    endpoint = args.endpoint.rstrip("/")
    tokens = exact_depth_prompt(endpoint, task, args.depth)
    before = gpu_snapshot()
    response = complete(endpoint, tokens, args.prediction_tokens)
    after = gpu_snapshot()
    parsed = extract_json(str(response.get("content", "")))
    result = {
        "schema_version": 1,
        "benchmark": "public long-binding qualification",
        "profile": args.profile,
        "started_utc": utc_now(),
        "server_props": get_json(endpoint + "/props"),
        "live_prompt_tokens": args.depth,
        "expected": case["expected"],
        "parsed": parsed,
        "exact": parsed == case["expected"],
        "content": response.get("content"),
        "tokens": response.get("tokens"),
        "token_sha256": response["token_sha256"],
        "timings": response.get("timings"),
        "client_wall_seconds": response["client_wall_seconds"],
        "gpu_before": before,
        "gpu_after": after,
        "finished_utc": utc_now(),
    }
    output = args.output or default_output(f"long-binding-{args.profile}")
    atomic_json(output, result)
    print(f"exact={result['exact']} output={output}")
    return 0 if result["exact"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

