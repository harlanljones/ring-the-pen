#!/usr/bin/env python3
"""RE24 / leverage / wOBA->WPA bridge inputs (RTP-07, DEC-2 Option A).

Parses the pinned 2025 run-expectancy table (data/manifest.json id
``retrosheet-2025-re24``, 8 rows) into the 24 base-out states, and freezes the
wOBA->WPA bridge constants mirrored from the-tango (DEC-2 reuses
``matchup.woba_delta_to_wpa``):

    wpa = woba_delta * WOBA_TO_WPA_CRITICAL * (leverage_index / LI_CRITICAL_REFERENCE)

Every constant carries a provenance label (CALIBRATED / PRD_DEFAULT / GUESS)
copied verbatim from the-tango ``tango.params`` — no unlabeled constant. Values
are never invented here: the RE table comes only from the pinned CSV and the
bridge constants only from the cited the-tango source file.

Offline. Stdlib only. Deterministic across runs.
"""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPO_ROOT / "data" / "manifest.json"
DEFAULT_RAW_DIR = REPO_ROOT / "data" / "raw"
DEFAULT_ARTIFACT = REPO_ROOT / "data" / "derived" / "re24_leverage.json"

FORMULA_VERSION = "re24-leverage/1"
SOURCE_PIN_ID = "retrosheet-2025-re24"
RUNNERS_ORDER = (
    "-- -- --",
    "1B -- --",
    "-- 2B --",
    "-- -- 3B",
    "1B 2B --",
    "1B -- 3B",
    "-- 2B 3B",
    "1B 2B 3B",
)
OUT_COLUMNS = (("0_outs", 0), ("1_out", 1), ("2_outs", 2))

LICENSE = "Retrosheet data used under the Retrosheet notice (see NOTICE)"
PURPOSE = (
    "2025 base-out run-expectancy states, leverage convention constants, and the "
    "wOBA->WPA bridge for the D3 hook-card/pen inputs"
)

# the-tango packages/tango-engine/src/tango/params.py, engine 2.0.0 (DEC-2
# reuse table). provenance/source verbatim from that file; see the mirror tests.
BRIDGE_CONSTANTS: dict[str, dict] = {
    "woba_to_wpa_critical": {
        "value": 0.55,
        "provenance": "GUESS",
        "source": "the-tango tango.params.WOBA_TO_WPA_CRITICAL: converts a wOBA delta to a "
        "WPA delta in critical leverage; calibrated so that 0.022 wOBA maps into the "
        "PRD's stated -0.010..-0.014 WPA band. Scales with pLI. Uncalibrated.",
    },
    "li_critical_reference": {
        "value": 3.0,
        "provenance": "PRD_DEFAULT",
        "source": "the-tango tango.matchup.LI_CRITICAL_REFERENCE (=3.0): leverage at which "
        "WOBA_TO_WPA_CRITICAL is expressed.",
    },
    "delta_tango_woba": {
        "value": 0.022,
        "provenance": "PRD_DEFAULT",
        "source": "the-tango tango.params.DELTA_TANGO_WOBA: The Tango Cold-Bench Penalty, "
        "canonical figure from Tango et al., The Book (PRD 3.4).",
    },
    "woba_scale": {
        "value": 1.157,
        "provenance": "PRD_DEFAULT",
        "source": "the-tango tango.params.WOBA_SCALE: standard wOBA->runs scale (FanGraphs "
        "convention, ~1.15-1.30 by season).",
    },
    "high_li_threshold": {
        "value": 1.5,
        "provenance": "PRD_DEFAULT",
        "source": "the-tango tango.params.HIGH_LI_THRESHOLD: pLI above which pitches accrue "
        "the phi stress multiplier (PRD 3.2).",
    },
    "phi_high_li": {
        "value": 0.40,
        "provenance": "PRD_DEFAULT",
        "source": "the-tango tango.params.PHI_HIGH_LI: extra stress weight on pitches thrown "
        "at pLI > 1.5 (PRD 3.2).",
    },
    "runs_per_win": {
        "value": 9.8,
        "provenance": "PRD_DEFAULT",
        "source": "the-tango tango.params.RUNS_PER_WIN: runs per marginal win; converts "
        "run-scale costs to WPA.",
    },
}


def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(chunk), b""):
            digest.update(block)
    return digest.hexdigest()


def resolve_source(manifest_path: Path = DEFAULT_MANIFEST, raw_dir: Path = DEFAULT_RAW_DIR) -> dict:
    """Locate the pinned RE24 input and verify its digest (fail closed)."""
    manifest = json.loads(manifest_path.read_text())
    entry = None
    for item in manifest.get("inputs", []):
        if item.get("id") == SOURCE_PIN_ID:
            entry = item
            break
    if entry is None:
        raise ValueError(f"manifest has no input pinned as {SOURCE_PIN_ID}")
    path = raw_dir / entry["path"]
    if not path.exists():
        raise FileNotFoundError(f"pinned input missing: {path}; run make fetch")
    digest = sha256_file(path)
    if digest != entry["sha256"]:
        raise ValueError(f"digest mismatch for {path}: expected {entry['sha256']}, got {digest}")
    return {"entry": entry, "path": path, "sha256": digest}


def parse_re24(csv_path: Path) -> dict[tuple[str, int], dict]:
    """Parse the 8 source rows into 24 base-out states keyed (runners, outs)."""
    states: dict[tuple[str, int], dict] = {}
    with csv_path.open(newline="") as handle:
        for row in csv.DictReader(handle):
            runners = row["runners"]
            if runners not in RUNNERS_ORDER:
                raise ValueError(f"unexpected runners label in source: {runners!r}")
            for col, outs in OUT_COLUMNS:
                states[(runners, outs)] = {"run_expectancy": float(row[col])}
    if len(states) != 24:
        raise ValueError(f"expected 24 base-out states, parsed {len(states)}")
    return states


def woba_delta_to_wpa(woba_delta: float, leverage_index: float) -> float:
    """Bridge from the-tango ``matchup.woba_delta_to_wpa/2`` (DEC-2: reuse).

    Linear in pLI; the critical constant is pinned at pLI = LI_CRITICAL_REFERENCE.
    """
    scale = BRIDGE_CONSTANTS["woba_to_wpa_critical"]["value"] * (
        leverage_index / BRIDGE_CONSTANTS["li_critical_reference"]["value"]
    )
    return woba_delta * scale


def bridge_constants() -> dict[str, dict]:
    """Provenance-labeled bridge constants (dicts, JSON-ready)."""
    return {name: dict(const) for name, const in BRIDGE_CONSTANTS.items()}


def build_artifact(
    manifest_path: Path = DEFAULT_MANIFEST,
    raw_dir: Path = DEFAULT_RAW_DIR,
    artifact_path: Path = DEFAULT_ARTIFACT,
) -> dict:
    """Build the derived re24_leverage artifact and write it deterministically."""
    source = resolve_source(manifest_path, raw_dir)
    states = parse_re24(source["path"])
    artifact = {
        "schema_version": 1,
        "formula_version": FORMULA_VERSION,
        "purpose": PURPOSE,
        "license": LICENSE,
        "source": {
            "manifest_id": SOURCE_PIN_ID,
            "filename": source["entry"]["path"],
            "sha256": source["sha256"],
            "rows": source["entry"].get("rows"),
            "description": source["entry"].get("description"),
        },
        "bridge_convention": {
            "formula": "wpa = woba_delta * woba_to_wpa_critical * (leverage_index / li_critical_reference)",
            "provenance": "the-tango tango.matchup.woba_delta_to_wpa/2 (DEC-2 Option A reuse); "
            "linear in pLI, critical constant pinned at pLI = li_critical_reference = 3.0. "
            "Sanity: 0.022 wOBA at li=3.0 -> 0.0121 WPA magnitude, inside the PRD's stated "
            "-0.010..-0.014 band.",
        },
        "constants": bridge_constants(),
        "re24_states": [
            {
                "runners": runners,
                "outs": outs,
                "run_expectancy": states[(runners, outs)]["run_expectancy"],
            }
            for runners in RUNNERS_ORDER
            for _, outs in OUT_COLUMNS
        ],
    }
    artifact_path.parent.mkdir(parents=True, exist_ok=True)
    artifact_path.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    return artifact


def main() -> int:
    build_artifact()
    print(f"wrote {DEFAULT_ARTIFACT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
