#!/usr/bin/env python3
"""Capture or compare the frozen 12-case spatial/compositional firewall."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from common import atomic_json, complete, default_output, exact_depth_prompt, get_json, utc_now


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
    parser.add_argument("--profile", choices=("target", "mtp", "dflash"), required=True)
    parser.add_argument("--depth", type=int, default=32000)
    parser.add_argument("--prediction-tokens", type=int, default=96)
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    endpoint = args.endpoint.rstrip("/")
    panel = json.loads(Path(__file__).with_name("spatial-firewall-v1.json").read_text(encoding="utf-8"))
    reference_rows = {}
    if args.reference:
        reference = json.loads(args.reference.read_text(encoding="utf-8"))
        reference_rows = {row["id"]: row for row in reference.get("results", [])}

    output = args.output or default_output(f"firewall-{args.profile}")
    result = {
        "schema_version": 1,
        "benchmark": "spatial/compositional exact-token firewall",
        "panel_id": panel["panel_id"],
        "profile": args.profile,
        "started_utc": utc_now(),
        "server_props": get_json(endpoint + "/props"),
        "live_prompt_tokens": args.depth,
        "reference": str(args.reference) if args.reference else None,
        "results": [],
    }
    for case in panel["cases"]:
        task = case["prompt"] + "\n\n" + panel["response_contract"]
        response = complete(endpoint, exact_depth_prompt(endpoint, task, args.depth), args.prediction_tokens)
        row = {
            "id": case["id"],
            "stratum": case["stratum"],
            "expected": case["expected"],
            "parsed": extract_json(str(response.get("content", ""))),
            "strict_expected": False,
            "tokens": response.get("tokens") or [],
            "token_sha256": response["token_sha256"],
            "timings": response.get("timings"),
        }
        row["strict_expected"] = row["parsed"] == row["expected"]
        if args.reference:
            prior = reference_rows.get(case["id"])
            row["reference_token_identical"] = prior is not None and row["tokens"] == prior.get("tokens")
        result["results"].append(row)
        atomic_json(output, result)
        print(
            f"{row['id']}: strict={row['strict_expected']} "
            f"reference={row.get('reference_token_identical', 'capture')}",
            flush=True,
        )
    result["strict_expected_count"] = sum(row["strict_expected"] for row in result["results"])
    if args.reference:
        result["all_reference_tokens_identical"] = all(
            row["reference_token_identical"] for row in result["results"]
        )
    result["finished_utc"] = utc_now()
    atomic_json(output, result)
    print(output)
    if args.reference and not result["all_reference_tokens_identical"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
