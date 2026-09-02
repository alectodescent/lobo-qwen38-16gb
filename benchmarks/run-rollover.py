#!/usr/bin/env python3
"""Capture or compare a >768-token greedy stream for the bounded-MTP rollover gate."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from common import atomic_json, complete, default_output, exact_depth_prompt, get_json, utc_now

TASK = (
    "Return a JSON object with exactly one key named sequence. Its value must be an array "
    "containing every integer from 1 through 400, in ascending order, with no omissions "
    "and no extra values."
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", default="http://127.0.0.1:18080")
    parser.add_argument("--profile", choices=("target", "mtp"), default="mtp")
    parser.add_argument("--tokens", type=int, default=924)
    # 100 prompt tokens + 924 generated tokens + one 128-token KVarN body fits
    # the frozen 1,152-token rollover fixture exactly.
    parser.add_argument("--prompt-depth", type=int, default=100)
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.tokens <= 768:
        raise SystemExit("rollover gate requires more than 768 output tokens")
    endpoint = args.endpoint.rstrip("/")
    prompt = exact_depth_prompt(endpoint, TASK, args.prompt_depth)
    response = complete(endpoint, prompt, args.tokens, ignore_eos=True)
    result = {
        "schema_version": 1,
        "benchmark": "bounded MTP rollover identity",
        "profile": args.profile,
        "started_utc": utc_now(),
        "server_props": get_json(endpoint + "/props"),
        "requested_tokens": args.tokens,
        "draft_window": 256,
        "minimum_rollovers": args.tokens // 256,
        "tokens": response.get("tokens") or [],
        "token_sha256": response["token_sha256"],
        "timings": response.get("timings"),
        "client_wall_seconds": response["client_wall_seconds"],
        "finished_utc": utc_now(),
    }
    if args.reference:
        reference = json.loads(args.reference.read_text(encoding="utf-8"))
        result["reference"] = str(args.reference)
        result["target_identical"] = result["tokens"] == reference.get("tokens")
    output = args.output or default_output(f"rollover-{args.profile}")
    atomic_json(output, result)
    print(f"tokens={len(result['tokens'])} sha256={result['token_sha256']} output={output}")
    if args.reference and not result["target_identical"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
