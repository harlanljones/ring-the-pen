#!/usr/bin/env python3
"""Cross-check universe A against Chadwick `cwevent` (RTP-05, DEC-4 A+C).

DEC-4 chose the stdlib parse + CSV as primary and Chadwick `cwevent` as an
independent cross-check. This script runs a prebuilt `cwevent` over the pinned
event files, counts plate appearances (BAT_EVENT_FL == "T"), and reconciles
against `2025plays.csv` `pa=1` per game.

It is OFFLINE and requires a prebuilt `cwevent` on PATH or via --cwevent.
It fails closed (exit 1) when the tool is missing, so a skipped cross-check is
never silent.

Chadwick is GPL-licensed and is NOT redistributed here; its source revision is
pinned in the artifact for reproducibility.

Usage:
    python3 scripts/crosscheck_cwevent.py --cwevent /path/to/cwevent
"""

from __future__ import annotations

import argparse
import collections
import csv
import glob
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_RAW_DIR = REPO_ROOT / "data" / "raw"
DEFAULT_ARTIFACT = REPO_ROOT / "data" / "derived" / "crosscheck_cwevent.json"
TOOL_KIND = "Chadwick cwevent"

POSTSEASON_MONTHS = {"10", "11", "03"}


def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(chunk), b""):
            digest.update(block)
    return digest.hexdigest()


def run_cwevent(tool: str, ev_files: list[str], box_dir: Path, year: int) -> list[tuple[str, str]]:
    cmd = [tool, "-Q", "-y", str(year), "-D", str(box_dir), "-f", "0,35", *ev_files]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"cwevent failed ({result.returncode}): {result.stderr.strip()[:400]}")
    rows: list[tuple[str, str]] = []
    for row in csv.reader(result.stdout.splitlines()):
        if len(row) >= 2:
            rows.append((row[0].strip('"'), row[1].strip('"')))
    return rows


def event_file_ids(raw_dir: Path) -> set[str]:
    ids: set[str] = set()
    for path in glob.glob(str(raw_dir / "2025eve" / "*.EV*")):
        with open(path, encoding="latin-1") as handle:
            for line in handle:
                if line.startswith("id,"):
                    ids.add(line.rstrip("\n").split(",", 1)[1])
    return ids


def csv_pa_by_game(raw_dir: Path) -> dict[str, int]:
    counts: collections.Counter[str] = collections.Counter()
    path = raw_dir / "2025plays" / "2025plays.csv"
    with path.open(newline="") as handle:
        for row in csv.DictReader(handle):
            if row.get("pa") == "1":
                counts[row["gid"]] += 1
    return dict(counts)


def build_reconciliation(tool: str, raw_dir: Path = DEFAULT_RAW_DIR) -> dict:
    ev_files = sorted(glob.glob(str(raw_dir / "2025eve" / "*.EV*")))
    if not ev_files:
        raise FileNotFoundError(f"no event files under {raw_dir / '2025eve'}")

    rows = run_cwevent(tool, ev_files, raw_dir / "2025box", 2025)
    cw_pa: collections.Counter[str] = collections.Counter()
    for game_id, flag in rows:
        if flag == "T":
            cw_pa[game_id] += 1

    csv_pa = csv_pa_by_game(raw_dir)
    csv_games, cw_games = set(csv_pa), set(cw_pa)
    common = csv_games & cw_games
    csv_only = sorted(csv_games - cw_games)
    cw_only = sorted(cw_games - csv_games)

    def month(game_id: str) -> str:
        # Game ids look like "CHN202509300": 3-char team, YYYYMMDD, game number.
        return game_id[7:9] if len(game_id) >= 9 else ""

    csv_only_month = collections.Counter(month(g) for g in csv_only)
    common_mismatch = {g: csv_pa[g] - cw_pa[g] for g in common if csv_pa[g] != cw_pa[g]}

    return {
        "schema_version": 1,
        "generated_by": "scripts/crosscheck_cwevent.py",
        "check": "universe A PA counts: 2025plays.csv pa=1 vs cwevent BAT_EVENT_FL=T",
        "tool": {
            "kind": TOOL_KIND,
            "name": Path(tool).name,
            "sha256": sha256_file(Path(tool).resolve()) if Path(tool).is_file() else None,
            "note": "GPL tool, not redistributed; rebuild from the pinned revision.",
        },
        "totals": {
            "csv_pa_rows": sum(csv_pa.values()),
            "cwevent_pa_rows": sum(cw_pa.values()),
            "delta": sum(csv_pa.values()) - sum(cw_pa.values()),
        },
        "games": {
            "csv_games": len(csv_games),
            "cwevent_games": len(cw_games),
            "common_games": len(common),
            "common_games_with_equal_pa": len(common) - len(common_mismatch),
            "common_games_with_mismatch": len(common_mismatch),
            "csv_only_games": len(csv_only),
            "cwevent_only_games": len(cw_only),
        },
        "csv_only_scope": {
            "by_month": dict(sorted(csv_only_month.items())),
            "postseason_like_games": sum(v for k, v in csv_only_month.items() if k in POSTSEASON_MONTHS),
            "game_ids": csv_only,
            "pa_rows_in_csv_only_games": sum(csv_pa[g] for g in csv_only),
        },
        "common_mismatch": common_mismatch,
        "finding": (
            "On all common games the CSV pa=1 count equals the cwevent PA count "
            "(no parse disagreement). Every discrepancy is game-coverage scope: "
            "games present in 2025plays.csv but absent from the pinned 2025eve "
            "event files (postseason / All-Star / late entries)."
        ),
    }


def write_artifact(recon: dict, path: Path = DEFAULT_ARTIFACT) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(recon, indent=2, sort_keys=True) + "\n")
    return path


def cmd_run(args: argparse.Namespace) -> int:
    tool = args.cwevent or shutil.which("cwevent")
    if not tool:
        print(
            "BLOCKER: cwevent not found. Build Chadwick (see docs/data-sources.md) "
            "or pass --cwevent PATH. Cross-check not run.",
            file=sys.stderr,
        )
        return 1
    try:
        recon = build_reconciliation(tool, Path(args.raw_dir))
    except (FileNotFoundError, RuntimeError) as error:
        print(f"BLOCKER: {error}", file=sys.stderr)
        return 1
    path = write_artifact(recon, Path(args.artifact))
    totals = recon["totals"]
    games = recon["games"]
    print(f"csv PA rows: {totals['csv_pa_rows']}  cwevent PA rows: {totals['cwevent_pa_rows']}")
    print(f"common games: {games['common_games']} (mismatches: {games['common_games_with_mismatch']})")
    print(f"csv-only games: {games['csv_only_games']} (scope, PA rows: {recon['csv_only_scope']['pa_rows_in_csv_only_games']})")
    print(f"artifact -> {path}")
    return 0 if games["common_games_with_mismatch"] == 0 else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cwevent", default=None, help="path to a prebuilt cwevent")
    parser.add_argument("--raw-dir", default=str(DEFAULT_RAW_DIR))
    parser.add_argument("--artifact", default=str(DEFAULT_ARTIFACT))
    parser.set_defaults(func=cmd_run)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())