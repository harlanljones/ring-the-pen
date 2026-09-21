#!/usr/bin/env python3
"""Pin, fetch, and verify the frozen external inputs for Ring The Pen.

Raw inputs are bulk data and stay out of git (see `data/raw/` in `.gitignore`).
This script records them in `data/manifest.json` with a SHA-256, byte size, and
row count, then verifies those digests before any ETL run. It fails closed: a
missing input, a changed digest, or a changed row count is an error.

Stdlib only. Deterministic across runs (no timestamps in the manifest).

Usage:
    python3 scripts/verify_inputs.py pin    --source-dir /path/to/inputs
    python3 scripts/verify_inputs.py fetch  --source-dir /path/to/inputs
    python3 scripts/verify_inputs.py verify
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPO_ROOT / "data" / "manifest.json"
DEFAULT_RAW_DIR = REPO_ROOT / "data" / "raw"

RETROSHEET_NOTICE = (
    "The information used here was obtained free of charge from and is "
    "copyrighted by Retrosheet. Interested parties may contact Retrosheet at "
    "20 Sunset Rd., Newark, DE 19711."
)

# Logical inputs pinned by this project. Each spec is resolved against the
# source dir; `files` is a glob or an explicit list.
INPUT_SPECS = [
    {
        "id": "retrosheet-2025-events",
        "kind": "directory",
        "path": "2025eve",
        "pattern": "*.EV*",
        "source": "Retrosheet 2025 regular-season event files (.EVA/.EVN)",
        "license": "Retrosheet notice",
        "row_kind": "play_records",
    },
    {
        "id": "retrosheet-2025-box",
        "kind": "directory",
        "path": "2025box",
        "pattern": "*",
        "source": "Retrosheet 2025 box/roster files (.EBA/.EBN/.ROS)",
        "license": "Retrosheet notice",
        "row_kind": "text_lines",
    },
    {
        "id": "retrosheet-2025-plays",
        "kind": "file",
        "path": "2025plays/2025plays.csv",
        "source": "Retrosheet 2025 play-by-play CSV (includes nump, pa, pitches)",
        "license": "Retrosheet notice",
        "row_kind": "csv_data",
    },
    {
        "id": "retrosheet-2025-re24",
        "kind": "file",
        "path": "2025_RE24_Values.csv",
        "source": "Retrosheet 2025 run-expectancy (RE24) values",
        "license": "Retrosheet notice",
        "row_kind": "csv_data",
    },
    {
        "id": "chadwick-tools",
        "kind": "file_group",
        "paths": ["bevent.exe", "bgame.exe"],
        "source": "Chadwick bevent/bgame binaries (Win32; Linux execution UNVERIFIED)",
        "license": "Chadwick (see bevent/bgame), not Retrosheet",
        "row_kind": None,
    },
]


def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(chunk), b""):
            digest.update(block)
    return digest.hexdigest()


def count_rows(path: Path, row_kind: str | None) -> int:
    if row_kind is None:
        return 0
    if row_kind == "play_records":
        total = 0
        with path.open("rb") as handle:
            for line in handle:
                if line.startswith(b"play,"):
                    total += 1
        return total
    if row_kind == "csv_data":
        with path.open("rb") as handle:
            lines = sum(1 for _ in handle)
        return max(lines - 1, 0)
    if row_kind == "text_lines":
        with path.open("rb") as handle:
            return sum(1 for _ in handle)
    raise ValueError(f"unknown row_kind: {row_kind}")


def combined_digest(files: list[dict]) -> str:
    digest = hashlib.sha256()
    for entry in sorted(files, key=lambda item: item["name"]):
        digest.update(entry["name"].encode("utf-8"))
        digest.update(b"\t")
        digest.update(entry["sha256"].encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def build_input(source_dir: Path, spec: dict) -> dict:
    if spec["kind"] == "directory":
        directory = source_dir / spec["path"]
        if not directory.is_dir():
            raise FileNotFoundError(f"missing input directory: {directory}")
        files = [p for p in sorted(directory.glob(spec["pattern"])) if p.is_file()]
        if not files:
            raise FileNotFoundError(f"no files match {spec['pattern']} in {directory}")
        entries = [
            {
                "name": p.name,
                "bytes": p.stat().st_size,
                "rows": count_rows(p, spec["row_kind"]),
                "sha256": sha256_file(p),
            }
            for p in files
        ]
        return {
            "id": spec["id"],
            "kind": "directory",
            "path": spec["path"],
            "pattern": spec["pattern"],
            "source": spec["source"],
            "license": spec["license"],
            "row_kind": spec["row_kind"],
            "files": entries,
            "bytes": sum(item["bytes"] for item in entries),
            "rows": sum(item["rows"] for item in entries),
            "sha256": combined_digest(entries),
        }

    if spec["kind"] == "file":
        path = source_dir / spec["path"]
        if not path.is_file():
            raise FileNotFoundError(f"missing input file: {path}")
        return {
            "id": spec["id"],
            "kind": "file",
            "path": spec["path"],
            "source": spec["source"],
            "license": spec["license"],
            "row_kind": spec["row_kind"],
            "bytes": path.stat().st_size,
            "rows": count_rows(path, spec["row_kind"]),
            "sha256": sha256_file(path),
        }

    if spec["kind"] == "file_group":
        entries = []
        for relative in spec["paths"]:
            path = source_dir / relative
            if not path.is_file():
                raise FileNotFoundError(f"missing input file: {path}")
            entries.append(
                {
                    "name": relative,
                    "bytes": path.stat().st_size,
                    "rows": 0,
                    "sha256": sha256_file(path),
                }
            )
        return {
            "id": spec["id"],
            "kind": "file_group",
            "paths": spec["paths"],
            "source": spec["source"],
            "license": spec["license"],
            "row_kind": None,
            "files": entries,
            "bytes": sum(item["bytes"] for item in entries),
            "rows": 0,
            "sha256": combined_digest(entries),
        }

    raise ValueError(f"unknown input kind: {spec['kind']}")


def cmd_pin(args: argparse.Namespace) -> int:
    source_dir = Path(args.source_dir).expanduser().resolve()
    if not source_dir.is_dir():
        print(f"ERROR: source dir not found: {source_dir}", file=sys.stderr)
        return 1
    manifest = {
        "schema_version": 1,
        "description": "Frozen external inputs for Ring The Pen; raw bulk stays out of git.",
        "retrosheet_notice": RETROSHEET_NOTICE,
        "raw_dir_default": str(DEFAULT_RAW_DIR.relative_to(REPO_ROOT)),
        "inputs": [build_input(source_dir, spec) for spec in INPUT_SPECS],
    }
    manifest_path = Path(args.manifest)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"pinned {len(manifest['inputs'])} inputs -> {manifest_path}")
    for item in manifest["inputs"]:
        print(f"  {item['id']}: {item['bytes']} bytes, rows={item['rows']}, sha256={item['sha256'][:12]}…")
    return 0


def _copy_file(src: Path, dst: Path) -> None:
    if dst.exists():
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def cmd_fetch(args: argparse.Namespace) -> int:
    source_dir = Path(args.source_dir).expanduser().resolve()
    raw_dir = Path(args.raw_dir)
    manifest = json.loads(Path(args.manifest).read_text())
    copied = 0
    for item in manifest["inputs"]:
        if item["kind"] == "directory":
            src = source_dir / item["path"]
            for entry in item["files"]:
                dst = raw_dir / item["path"] / entry["name"]
                if not dst.exists():
                    _copy_file(src / entry["name"], dst)
                    copied += 1
        elif item["kind"] == "file":
            dst = raw_dir / item["path"]
            if not dst.exists():
                _copy_file(source_dir / item["path"], dst)
                copied += 1
        elif item["kind"] == "file_group":
            for relative in item["paths"]:
                dst = raw_dir / relative
                if not dst.exists():
                    _copy_file(source_dir / relative, dst)
                    copied += 1
    print(f"fetch complete: {copied} file(s) copied into {raw_dir}")
    return 0


def _verify_input(raw_dir: Path, item: dict) -> list[str]:
    errors: list[str] = []
    if item["kind"] == "directory":
        directory = raw_dir / item["path"]
        files: list[dict] = []
        for entry in item["files"]:
            path = directory / entry["name"]
            if not path.is_file():
                errors.append(f"{item['id']}: missing {path}")
                continue
            files.append(_measure(path, entry["name"], item["row_kind"]))
        if files:
            if combined_digest(files) != item["sha256"]:
                errors.append(f"{item['id']}: combined digest mismatch")
            if sum(x["bytes"] for x in files) != item["bytes"]:
                errors.append(f"{item['id']}: total bytes mismatch")
            if sum(x["rows"] for x in files) != item["rows"]:
                errors.append(f"{item['id']}: total rows mismatch")
        return errors

    if item["kind"] == "file":
        path = raw_dir / item["path"]
        if not path.is_file():
            return [f"{item['id']}: missing {path}"]
        measured = _measure(path, item["path"], item["row_kind"])
        if measured["sha256"] != item["sha256"]:
            errors.append(f"{item['id']}: sha256 mismatch")
        if measured["bytes"] != item["bytes"]:
            errors.append(f"{item['id']}: bytes mismatch")
        if measured["rows"] != item["rows"]:
            errors.append(f"{item['id']}: rows mismatch")
        return errors

    if item["kind"] == "file_group":
        files = []
        for entry in item["files"]:
            path = raw_dir / entry["name"]
            if not path.is_file():
                errors.append(f"{item['id']}: missing {path}")
                continue
            files.append(_measure(path, entry["name"], None))
        if files and combined_digest(files) != item["sha256"]:
            errors.append(f"{item['id']}: combined digest mismatch")
        return errors

    return [f"{item['id']}: unknown kind {item['kind']}"]


def _measure(path: Path, name: str, row_kind) -> dict:
    return {
        "name": name,
        "bytes": path.stat().st_size,
        "rows": count_rows(path, row_kind),
        "sha256": sha256_file(path),
    }


def cmd_verify(args: argparse.Namespace) -> int:
    manifest_path = Path(args.manifest)
    if not manifest_path.is_file():
        print(f"ERROR: manifest not found: {manifest_path}", file=sys.stderr)
        return 1
    manifest = json.loads(manifest_path.read_text())
    raw_dir = Path(args.raw_dir)
    failures: list[str] = []
    for item in manifest["inputs"]:
        errors = _verify_input(raw_dir, item)
        status = "OK  " if not errors else "FAIL"
        print(f"[{status}] {item['id']} ({item['kind']}, {item['bytes']} bytes, rows={item['rows']})")
        failures.extend(errors)
    if failures:
        print("\nverification FAILED:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    print("\nall pinned inputs verified")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    pin = sub.add_parser("pin", help="compute digests and write the manifest")
    pin.add_argument("--source-dir", required=True)
    pin.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    pin.set_defaults(func=cmd_pin)

    fetch = sub.add_parser("fetch", help="copy absent pinned inputs into data/raw")
    fetch.add_argument("--source-dir", default=str(Path.home() / "Downloads"))
    fetch.add_argument("--raw-dir", default=str(DEFAULT_RAW_DIR))
    fetch.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    fetch.set_defaults(func=cmd_fetch)

    verify = sub.add_parser("verify", help="verify digests, sizes, and row counts")
    verify.add_argument("--raw-dir", default=str(DEFAULT_RAW_DIR))
    verify.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    verify.set_defaults(func=cmd_verify)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
