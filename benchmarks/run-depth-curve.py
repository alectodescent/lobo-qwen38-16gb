#!/usr/bin/env python3
"""Run an exact-token-depth controlled systems curve against a running Lobo server."""

from __future__ import annotations

import argparse
from pathlib import Path

from common import atomic_json, complete, default_output, exact_depth_prompt, get_json, gpu_snapshot, utc_now

TASK = "Write exactly one compact sentence explaining why deterministic state tracking matters."


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", default="http://127.0.0.1:18080")
    parser.add_argument("--profile", choices=("target", "balanced", "mtp", "dflash"), required=True)
    parser.add_argument("--depths", nargs="+", type=int, default=[2048, 8192, 16000, 32000, 64000, 128000, 160000, 200000, 230000])
    parser.add_argument("--prediction-tokens", type=int, default=96)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    endpoint = args.endpoint.rstrip("/")
    output = args.output or default_output(f"depth-{args.profile}")
    result = {
        "schema_version": 1,
        "benchmark": "synthetic / controlled systems benchmark",
        "profile": args.profile,
        "started_utc": utc_now(),
        "server_props": get_json(endpoint + "/props"),
        "results": [],
    }
    for depth in args.depths:
        tokens = exact_depth_prompt(endpoint, TASK, depth)
        before = gpu_snapshot()
        response = complete(endpoint, tokens, args.prediction_tokens)
        after = gpu_snapshot()
        timings = response.get("timings") or {}
        row = {
            "live_prompt_tokens": depth,
            "prompt_tokens_evaluated": timings.get("prompt_n"),
            "prompt_tps": timings.get("prompt_per_second"),
            "committed_tokens": timings.get("predicted_n"),
            "committed_tps": timings.get("predicted_per_second"),
            "drafts": timings.get("draft_n"),
            "drafts_accepted": timings.get("draft_n_accepted"),
            "client_wall_seconds": response["client_wall_seconds"],
            "token_sha256": response["token_sha256"],
            "gpu_before": before,
            "gpu_after": after,
        }
        result["results"].append(row)
        atomic_json(output, result)
        print(f"{depth}: pp={row['prompt_tps']} tg={row['committed_tps']}", flush=True)
    result["finished_utc"] = utc_now()
    atomic_json(output, result)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

