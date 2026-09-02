#!/usr/bin/env python3
"""Run repeatable prose and coding generations at short/medium context depths."""

from __future__ import annotations

import argparse
from pathlib import Path

from common import atomic_json, complete, default_output, exact_depth_prompt, get_json, utc_now

TASKS = {
    "prose": "In two concise paragraphs, explain how a write-ahead log helps a service recover after a crash.",
    "code": "Write a correct Python function that topologically sorts a directed acyclic graph, with a short explanation and one example.",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", default="http://127.0.0.1:18080")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--depths", nargs="+", type=int, default=[2048, 8192, 32000])
    parser.add_argument("--prediction-tokens", type=int, default=256)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    endpoint = args.endpoint.rstrip("/")
    result = {
        "schema_version": 1,
        "benchmark": "normal prose and coding generation",
        "profile": args.profile,
        "started_utc": utc_now(),
        "server_props": get_json(endpoint + "/props"),
        "results": [],
    }
    output = args.output or default_output(f"normal-{args.profile}")
    for depth in args.depths:
        for name, task in TASKS.items():
            response = complete(endpoint, exact_depth_prompt(endpoint, task, depth), args.prediction_tokens)
            timings = response.get("timings") or {}
            result["results"].append(
                {
                    "task": name,
                    "live_prompt_tokens": depth,
                    "prompt_tps": timings.get("prompt_per_second"),
                    "committed_tps": timings.get("predicted_per_second"),
                    "committed_tokens": timings.get("predicted_n"),
                    "drafts": timings.get("draft_n"),
                    "drafts_accepted": timings.get("draft_n_accepted"),
                    "client_wall_seconds": response["client_wall_seconds"],
                    "token_sha256": response["token_sha256"],
                    "content": response.get("content"),
                }
            )
            atomic_json(output, result)
    result["finished_utc"] = utc_now()
    atomic_json(output, result)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

