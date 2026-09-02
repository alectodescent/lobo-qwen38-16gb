#!/usr/bin/env python3
"""Scan the release tree for credentials, private provenance, and identity leaks."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

FATAL = {
    "github_token": re.compile(r"(?:ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})"),
    "huggingface_token": re.compile(r"\bhf_[A-Za-z0-9]{20,}\b"),
    "bearer_credential": re.compile(r"(?i)Authorization\s*:\s*Bearer\s+(?!YOUR_|EXAMPLE|REDACTED)[A-Za-z0-9._~+/=-]{12,}"),
    "private_key": re.compile(r"-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----"),
    "user_profile_path": re.compile(r"(?i)[A-Za-z]:\\Users\\[^\\\s]+"),
}
REVIEW = {
    "email": re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
    "private_ipv4": re.compile(r"\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})\b"),
    "drive_path": re.compile(r"\b[A-Za-z]:\\"),
    "sensitive_word": re.compile(r"(?i)\b(?:password|api_key|secret|token=|private)\b"),
}
TEXT_SUFFIXES = {
    ".c", ".cc", ".cpp", ".cu", ".cuh", ".h", ".hpp", ".md", ".txt",
    ".py", ".ps1", ".json", ".toml", ".yml", ".yaml", ".cmake", ".sh",
    ".bat", ".in", ".html", ".css", ".js", ".ts", ".xml", ".ini",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--forbid", action="append", default=[], help="additional literal that must not occur")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    report = {"root": str(root), "files_scanned": 0, "fatal": {}, "review": {}}
    extra = [(f"caller_forbidden_{index}", re.compile(re.escape(value), re.IGNORECASE)) for index, value in enumerate(args.forbid)]
    try:
        raw = subprocess.check_output(["git", "-C", str(root), "ls-files", "-z"])
        candidates = [root / item.decode("utf-8") for item in raw.split(b"\0") if item]
    except (OSError, subprocess.SubprocessError):
        candidates = list(root.rglob("*"))
    for path in candidates:
        if not path.is_file() or ".git" in path.parts or "_build" in path.parts or "dist" in path.parts:
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES and path.name not in {"LICENSE", "AUTHORS", "CMakeLists.txt", "Makefile"}:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        report["files_scanned"] += 1
        relative = path.relative_to(root).as_posix()
        for group, patterns in (("fatal", FATAL), ("review", REVIEW)):
            for name, pattern in patterns.items():
                found = list(pattern.finditer(text))
                if found:
                    report[group].setdefault(name, []).append({"file": relative, "count": len(found)})
        for name, pattern in extra:
            found = list(pattern.finditer(text))
            if found:
                report["fatal"].setdefault(name, []).append({"file": relative, "count": len(found)})
    report["fatal_count"] = sum(item["count"] for rows in report["fatal"].values() for item in rows)
    report["review_count"] = sum(item["count"] for rows in report["review"].values() for item in rows)
    encoded = json.dumps(report, indent=2)
    if not args.quiet:
        print(encoded)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded + "\n", encoding="utf-8")
    if args.quiet:
        print(f"files={report['files_scanned']} fatal={report['fatal_count']} review={report['review_count']}")
    return 1 if report["fatal_count"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
