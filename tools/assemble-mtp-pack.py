#!/usr/bin/env python3
"""Assemble the frozen Lobo MTP deployment pack without changing tensor payloads."""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "runtime" / "gguf-py"))

from gguf import GGUFReader, GGUFValueType, GGUFWriter  # noqa: E402

BASE_SIZE = 11_771_546_784
BASE_SHA = "64b53b64c7aa39f20a7e54bd80582fe595b1d745624ee8a72e92508c0326d810"
DONOR_SIZE = 11_913_559_104
DONOR_SHA = "0a6129dcbbbe72f423dc67e0e3bbfbbdf3e923981a3637687ebb96a46c59d6be"
OUTPUT_SIZE = 11_975_960_640
OUTPUT_SHA = "4eb8482539194ed9bc1555c88613f39f2e65db37b16d9ab173f908e78d454512"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(16 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require_input(path: Path, size: int, expected: str, label: str) -> None:
    if not path.is_file():
        raise SystemExit(f"{label} not found: {path}")
    if path.stat().st_size != size:
        raise SystemExit(f"{label} byte count is {path.stat().st_size}, expected {size}")
    actual = sha256(path)
    if actual != expected:
        raise SystemExit(f"{label} SHA-256 is {actual}, expected {expected}")


def copy_metadata(base: GGUFReader, writer: GGUFWriter) -> None:
    # The frozen assembler deliberately moves the updated block_count to the end,
    # followed by nextn_predict_layers. Retaining that order reproduces the file hash.
    for key, field in base.fields.items():
        if key.startswith("GGUF.") or key == "qwen35.block_count":
            continue
        value_type = field.types[0]
        subtype = field.types[-1] if value_type == GGUFValueType.ARRAY else None
        writer.add_key_value(key, field.contents(), value_type, subtype)
    writer.add_uint32("qwen35.block_count", 65)
    writer.add_uint32("qwen35.nextn_predict_layers", 1)


def add_tensor(writer: GGUFWriter, tensor, endianess) -> None:
    writer.add_tensor(
        tensor.name,
        tensor.data,
        raw_dtype=tensor.tensor_type,
        tensor_endianess=endianess,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--donor", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    require_input(args.base, BASE_SIZE, BASE_SHA, "GSQ base")
    require_input(args.donor, DONOR_SIZE, DONOR_SHA, "MTP donor")
    if args.output.exists() and not args.force:
        raise SystemExit(f"output exists; pass --force to replace it: {args.output}")
    args.output.parent.mkdir(parents=True, exist_ok=True)

    base = GGUFReader(args.base)
    donor = GGUFReader(args.donor)
    mtp = [tensor for tensor in donor.tensors if tensor.name.startswith("blk.64.")]
    if len(base.tensors) != 851 or len(mtp) != 15:
        raise SystemExit(f"unexpected tensor counts: base={len(base.tensors)}, MTP={len(mtp)}")

    arch = str(base.fields["general.architecture"].contents())
    writer = GGUFWriter(args.output, arch=arch, endianess=base.endianess)
    copy_metadata(base, writer)
    for tensor in base.tensors:
        add_tensor(writer, tensor, base.endianess)
    for tensor in mtp:
        add_tensor(writer, tensor, donor.endianess)
    writer.write_header_to_file()
    writer.write_kv_data_to_file()
    writer.write_tensors_to_file()
    writer.close()

    actual_size = args.output.stat().st_size
    actual_hash = sha256(args.output)
    if actual_size != OUTPUT_SIZE or actual_hash != OUTPUT_SHA:
        raise SystemExit(
            f"assembled artifact did not reproduce the frozen pack: "
            f"bytes={actual_size} sha256={actual_hash}"
        )
    print(f"OK {args.output} {actual_size} {actual_hash}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
