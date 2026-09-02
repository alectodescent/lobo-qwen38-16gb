#!/usr/bin/env python3
"""Verify that a saved KVarN/hybrid slot reproduces its greedy continuation."""

from __future__ import annotations

import argparse
from pathlib import Path

from common import atomic_json, complete, default_output, exact_depth_prompt, get_json, post_json, utc_now

PREFIX_TASK = "Record that the release state is deterministic, then provide one short checksum mnemonic."
CONTINUATION_TASK = "Using the same archive context, enumerate deterministic recovery checks in numbered order."


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", default="http://127.0.0.1:18080")
    parser.add_argument("--profile", default="balanced")
    parser.add_argument("--depth", type=int, default=2048)
    parser.add_argument("--prediction-tokens", type=int, default=96)
    parser.add_argument("--filename", default="lobo-public-state.bin")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    endpoint = args.endpoint.rstrip("/")
    output = args.output or default_output(f"save-reload-{args.profile}")

    first_prompt = exact_depth_prompt(endpoint, PREFIX_TASK, args.depth)
    next_prompt = exact_depth_prompt(endpoint, CONTINUATION_TASK, args.depth)
    prefix = complete(endpoint, first_prompt, 32, cache_prompt=True)
    saved = post_json(endpoint + "/slots/0?action=save", {"filename": args.filename})
    reference = complete(endpoint, next_prompt, args.prediction_tokens, cache_prompt=True)
    restored = post_json(endpoint + "/slots/0?action=restore", {"filename": args.filename})
    replay = complete(endpoint, next_prompt, args.prediction_tokens, cache_prompt=True)

    identical = reference.get("tokens") == replay.get("tokens")
    result = {
        "schema_version": 1,
        "benchmark": "slot save/reload greedy identity",
        "profile": args.profile,
        "started_utc": utc_now(),
        "server_props": get_json(endpoint + "/props"),
        "live_prompt_tokens": args.depth,
        "prefix_token_sha256": prefix["token_sha256"],
        "saved": saved,
        "restored": restored,
        "reference_token_sha256": reference["token_sha256"],
        "replay_token_sha256": replay["token_sha256"],
        "tokens_identical": identical,
        "reference_tokens": reference.get("tokens"),
        "replay_tokens": replay.get("tokens"),
        "finished_utc": utc_now(),
    }
    atomic_json(output, result)
    print(f"tokens_identical={identical} output={output}")
    return 0 if identical else 1


if __name__ == "__main__":
    raise SystemExit(main())
