#!/usr/bin/env python3
"""Create a read-only DOCX migration inventory with SHA-256 hashes."""

from __future__ import annotations

import argparse
import csv
import hashlib
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="Read-only export directory")
    parser.add_argument("output", type=Path, help="CSV inventory to create")
    args = parser.parse_args()

    source = args.source.expanduser().resolve()
    output = args.output.expanduser().resolve()
    if not source.is_dir():
        parser.error(f"source is not a directory: {source}")
    try:
        output.relative_to(source)
    except ValueError:
        pass
    else:
        parser.error("output must be outside the source export directory")
    if output.exists():
        parser.error(f"refusing to overwrite existing output: {output}")

    files = sorted(
        path for path in source.rglob("*") if path.is_file() and path.suffix.lower() == ".docx"
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["source_path", "size_bytes", "sha256", "approved", "target_collection", "notes"],
        )
        writer.writeheader()
        for path in files:
            writer.writerow(
                {
                    "source_path": path.relative_to(source).as_posix(),
                    "size_bytes": path.stat().st_size,
                    "sha256": sha256(path),
                    "approved": "PENDING",
                    "target_collection": "",
                    "notes": "",
                }
            )
    print(f"Wrote {len(files)} DOCX records to {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
