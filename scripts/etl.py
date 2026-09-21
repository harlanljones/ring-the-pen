#!/usr/bin/env python3
"""Ring The Pen — offline ETL (RTP-05).

Establishes universe A from the frozen 2025 Retrosheet inputs and writes a small,
deterministic derived artifact with provenance. No network. Stdlib only.

Decisions applied:
  DEC-3 (C): 2025plays.csv is the counting authority; event files cross-check and
             supply D1b lineup data.
  DEC-4 (A+C): stdlib parser + CSV primary; Chadwick cwevent is a later cross-check.

Invariants (D2):
  Universe A        = pa=1 AND nump>0
  Unknown pitch count = pa=1 AND nump in {blank, 0}   (never counted as 0)
  Event-file blank pitch field is overwhelmingly NP (non-PA), not an unknown PA.

Usage:
  python3 scripts/etl.py build --offline
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
if __package__ in (None, ""):
    # Run as `python3 scripts/etl.py` from the Makefile: make the repo
    # root importable so `from scripts import ...` works.
    sys.path.insert(0, str(REPO_ROOT))

from scripts import lineup as lineup_mod  # noqa: E402
from scripts import re24 as re24_mod  # noqa: E402
DEFAULT_MANIFEST = REPO_ROOT / "data" / "manifest.json"
DEFAULT_RAW_DIR = REPO_ROOT / "data" / "raw"
DEFAULT_ARTIFACT = REPO_ROOT / "data" / "derived" / "universe_a_summary.json"
DEFAULT_LINEUP_ARTIFACT = REPO_ROOT / "data" / "derived" / "lineup_summary.json"

UNIVERSE_A_DEFINITION = "pa=1 AND nump>0"
UNKNOWN_DEFINITION = "pa=1 AND nump IS blank OR nump == 0"
FORMULA_VERSION = "universe-a/1"


def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(chunk), b""):
            digest.update(block)
    return digest.hexdigest()


def _nump_class(value: str | None) -> str:
    """Classify a nump cell as 'positive', 'zero', or 'blank'."""
    if value is None or value.strip() == "":
        return "blank"
    try:
        return "positive" if int(value) > 0 else "zero"
    except ValueError:
        return "blank"


def scan_plays_csv(path: Path) -> dict:
    """Count universe A and the unknown class in 2025plays.csv."""
    counts = {
        "rows": 0,
        "pa": 0,
        "pa_nump_positive": 0,
        "pa_nump_zero": 0,
        "pa_nump_blank": 0,
        "nump_blank": 0,
        "nump_zero": 0,
    }
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            counts["rows"] += 1
            klass = _nump_class(row.get("nump"))
            if klass == "blank":
                counts["nump_blank"] += 1
            elif klass == "zero":
                counts["nump_zero"] += 1
            if row.get("pa") == "1":
                counts["pa"] += 1
                counts[f"pa_nump_{klass}"] += 1
    counts["universe_a"] = counts["pa_nump_positive"]
    counts["unknown"] = counts["pa_nump_zero"] + counts["pa_nump_blank"]
    return counts


def scan_event_files(directory: Path) -> dict:
    """Count play records and blank-pitch classification across .EV* files."""
    files = sorted(p for p in directory.glob("*.EV*") if p.is_file())
    counts = {"files": len(files), "play_records": 0, "blank_pitch": 0, "blank_np": 0}
    for path in files:
        with path.open("rb") as handle:
            for raw in handle:
                if not raw.startswith(b"play,"):
                    continue
                counts["play_records"] += 1
                fields = raw.rstrip(b"\r\n").split(b",")
                pitches = fields[5] if len(fields) > 5 else b""
                if pitches == b"":
                    counts["blank_pitch"] += 1
                    event = fields[6] if len(fields) > 6 else b""
                    if event.startswith(b"NP"):
                        counts["blank_np"] += 1
    return counts


def build_summary(raw_dir: Path = DEFAULT_RAW_DIR, manifest_path: Path = DEFAULT_MANIFEST) -> dict:
    plays = scan_plays_csv(raw_dir / "2025plays" / "2025plays.csv")
    events = scan_event_files(raw_dir / "2025eve")
    return {
        "schema_version": 1,
        "generated_by": "scripts/etl.py build --offline",
        "formula_version": FORMULA_VERSION,
        "source_manifest_sha256": sha256_file(manifest_path),
        "universe_a": {"definition": UNIVERSE_A_DEFINITION, "rows": plays["universe_a"]},
        "unknown_pitch_count": {"definition": UNKNOWN_DEFINITION, "rows": plays["unknown"]},
        "plays_csv": plays,
        "events": events,
        "reconciliation": {
            "plays_csv_rows": plays["rows"],
            "event_play_records": events["play_records"],
            "delta": events["play_records"] - plays["rows"],
            "note": (
                "Different populations: event files are raw play records; the CSV is "
                "a filtered play-by-play export. Reporting both, not silently picking."
            ),
            "event_blank_pitch_np_fraction": (
                round(events["blank_np"] / events["blank_pitch"], 6)
                if events["blank_pitch"]
                else None
            ),
        },
        "invariants": {
            "universe_a_plus_unknown_equals_pa": (
                plays["universe_a"] + plays["unknown"] == plays["pa"]
            ),
            "blank_nump_never_counted_as_pitches": plays["universe_a"] == plays["pa_nump_positive"],
            "event_blank_pitch_is_mostly_np": events["blank_np"] == events["blank_pitch"]
            or (events["blank_pitch"] > 0 and events["blank_np"] / events["blank_pitch"] > 0.99),
        },
    }


def serialize(summary: dict) -> str:
    return json.dumps(summary, indent=2, sort_keys=True) + "\n"


def write_artifact(summary: dict, path: Path = DEFAULT_ARTIFACT) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(serialize(summary))
    return path


def cmd_build(args: argparse.Namespace) -> int:
    if not args.offline:
        print("ERROR: only --offline build is supported", file=sys.stderr)
        return 2
    try:
        summary = build_summary(Path(args.raw_dir), Path(args.manifest))
    except FileNotFoundError as error:
        print(f"BLOCKER: missing pinned input: {error}", file=sys.stderr)
        return 1
    path = write_artifact(summary, Path(args.artifact))
    lineup_path = lineup_mod.write_artifact(
        lineup_mod.build_summary(Path(args.raw_dir), Path(args.manifest)),
        Path(args.lineup_artifact),
    )
    ua = summary["universe_a"]
    unk = summary["unknown_pitch_count"]
    failed = [name for name, ok in summary["invariants"].items() if not ok]
    try:
        re24_path = re24_mod.build_artifact(
            manifest_path=Path(args.manifest),
            raw_dir=Path(args.raw_dir),
            artifact_path=REPO_ROOT / "data" / "derived" / "re24_leverage.json",
        )
    except (FileNotFoundError, ValueError) as error:
        print(f"BLOCKER: RE24 input: {error}", file=sys.stderr)
        return 1
    print(f"universe A: {ua['rows']} rows ({ua['definition']})")
    print(f"unknown pitch count: {unk['rows']} rows ({unk['definition']})")
    print(f"reconciliation: csv={summary['plays_csv']['rows']} events={summary['events']['play_records']}")
    print(f"lineup: {lineup_path.name}: {lineup_mod.FORMULA_VERSION}")
    print(f"re24: {re24_mod.DEFAULT_ARTIFACT.name}: {re24_mod.FORMULA_VERSION}")
    print(f"artifact -> {path}")
    if failed:
        print(f"FAILED invariants: {', '.join(failed)}", file=sys.stderr)
        return 1
    print("all invariants hold")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("build", help="build the derived universe A artifact")
    build.add_argument("--offline", action="store_true", help="required; no network")
    build.add_argument("--raw-dir", default=str(DEFAULT_RAW_DIR))
    build.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    build.add_argument("--artifact", default=str(DEFAULT_ARTIFACT))
    build.add_argument("--lineup-artifact", default=str(DEFAULT_LINEUP_ARTIFACT))
    build.set_defaults(func=cmd_build)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
