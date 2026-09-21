#!/usr/bin/env python3
"""D1b lineup reconstruction (RTP-05 remainder, DEC-9).

Reconstructs batting orders from the frozen 2025 Retrosheet event files:
`start` seeds the nine slots per team, `sub` replaces the player in a slot,
and `play` records walk the on-deck pointer. The next N=3 distinct batters in
the reconstructed order (PRD pin) follow each plate appearance; an NP record
is a non-PA and never advances the pointer. If the order cannot be
reconstructed (missing `start`, unresolved sub) the state is explicit
`unknown` — never guessed. No network. Stdlib only.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPO_ROOT / "data" / "manifest.json"
DEFAULT_RAW_DIR = REPO_ROOT / "data" / "raw"


def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(chunk), b""):
            digest.update(block)
    return digest.hexdigest()

FORMULA_VERSION = "lineup/1"
N_UPCOMING = 3  # PRD frozen pin
DEFAULT_ARTIFACT = Path(__file__).resolve().parent.parent / "data" / "derived" / "lineup_summary.json"
SAMPLE_LIMIT = 12

LICENSE = "Retrosheet data used under the Retrosheet notice (see NOTICE)"
PURPOSE = "Reconstructed batting orders and next-3 upcoming batters for the D1b hook-card input"


def parse_line(raw: str) -> tuple[str, list[str]] | None:
    """Split an event-file record into (record type, fields).

    Commas inside quoted name fields are handled with a minimal scanner;
    Retrosheet quotes only the player-name field.
    """
    record = raw.rstrip("\r\n")
    if not record:
        return None
    fields: list[str] = []
    buf: list[str] = []
    in_quotes = False
    for ch in record:
        if ch == '"':
            in_quotes = not in_quotes
        elif ch == "," and not in_quotes:
            fields.append("".join(buf))
            buf = []
        else:
            buf.append(ch)
    fields.append("".join(buf))
    return fields[0], fields[1:]


def reconstruct_game(lines: list[str]) -> dict:
    """Reconstruct one game's batting orders and next-3 sequences.

    Returns a dict with `reconstructed` (False = explicit unknown state with a
    reason), per-PA samples of (current batter, next3), and counts.
    """
    game_id: str | None = None
    order: dict[int, dict[int, str]] = {0: {}, 1: {}}  # home flag -> slot -> player
    samples: list[dict] = []
    pa_count = 0
    np_count = 0
    sub_count = 0
    reconstructed = True
    unknown_reason: str | None = None

    def fail(reason: str) -> None:
        nonlocal reconstructed, unknown_reason
        if reconstructed:
            reconstructed = False
            unknown_reason = reason

    for raw in lines:
        parsed = parse_line(raw)
        if parsed is None:
            continue
        kind, fields = parsed
        if kind == "id":
            game_id = fields[0]
        elif kind in ("start", "sub"):
            # start/sub fields: playerID, name, homeFlag, battingOrder, position.
            # battingOrder is 0 for a pitcher who does not bat (DH games).
            player, _name = fields[0], fields[1]
            home, slot = int(fields[2]), int(fields[3])
            if kind == "sub":
                sub_count += 1
            if slot == 0:
                continue  # pitcher who does not bat (DH games)
            if kind == "start" and slot in order[home]:
                fail(f"duplicate start slot {slot} for team {home}")
            order[home][slot] = player
        elif kind == "play":
            # play: inning, half, player, count, pitches, event...
            inning, half, player = int(fields[0]), int(fields[1]), fields[2]
            event = fields[5] if len(fields) > 5 else ""
            if event == "NP" or event == "":
                # Non-PA: the batter does not change; the pointer must not advance.
                if event == "NP":
                    np_count += 1
                continue
            pa_count += 1
            team = order[half]
            slot = next((s for s, p in team.items() if p == player), None)
            if slot is None:
                fail(f"batter {player} has no start/sub slot (inning {inning} half {half})")
                continue
            nxt: list[str] = []
            seen: set[int] = set()
            probe = slot
            while len(nxt) < N_UPCOMING and len(seen) < 9:
                probe = probe % 9 + 1  # wrap: slot 9 -> slot 1
                seen.add(probe)
                batter = team.get(probe)
                if batter is None:
                    continue  # empty slot (sub without replacement): skip
                nxt.append(batter)
            if len(nxt) < N_UPCOMING:
                fail(f"cannot fill {N_UPCOMING} upcoming batters after {player}")
                continue
            if reconstructed:
                samples.append(
                    {
                        "game": game_id,
                        "inning": inning,
                        "half": half,
                        "current": player,
                        "slot": slot,
                        "next3": nxt,
                    }
                )

    if not reconstructed:
        # Explicit unknown state: emit no sequences for this game
        # rather than a partially-guessed reconstruction.
        samples = []
    return {
        "game_id": game_id,
        "reconstructed": reconstructed,
        "unknown_reason": unknown_reason,
        "pa_count": pa_count,
        "np_count": np_count,
        "sub_count": sub_count,
        "samples": samples,
    }


def iter_games(path: Path):
    """Yield each game as a list of its record lines."""
    current: list[str] = []
    with path.open("r", encoding="latin-1") as handle:
        for line in handle:
            if line.startswith("id,") and current:
                yield current
                current = [line]
            else:
                current.append(line)
    if current:
        yield current


def scan_directory(raw_dir: Path) -> dict:
    eve_dir = raw_dir / "2025eve"
    files = sorted(p for p in eve_dir.glob("*.EV*") if p.is_file())
    counts = {
        "files": len(files),
        "games_parsed": 0,
        "orders_reconstructed": 0,
        "orders_unknown": 0,
        "pa_count": 0,
        "np_skipped": 0,
        "subs_applied": 0,
        "unknown_reasons": {},
    }
    samples: list[dict] = []
    for path in files:
        for game_lines in iter_games(path):
            game = reconstruct_game(game_lines)
            counts["games_parsed"] += 1
            counts["pa_count"] += game["pa_count"]
            counts["np_skipped"] += game["np_count"]
            counts["subs_applied"] += game["sub_count"]
            if game["reconstructed"]:
                counts["orders_reconstructed"] += 1
                remaining = SAMPLE_LIMIT - len(samples)
                if remaining > 0:
                    samples.extend(game["samples"][:remaining])
            else:
                counts["orders_unknown"] += 1
                reason = game["unknown_reason"] or "unknown"
                counts["unknown_reasons"][reason] = counts["unknown_reasons"].get(reason, 0) + 1
    counts["games_parsed"] = counts["orders_reconstructed"] + counts["orders_unknown"]
    return {"counts": counts, "samples": samples}


def build_summary(raw_dir: Path = DEFAULT_RAW_DIR, manifest_path: Path = DEFAULT_MANIFEST) -> dict:
    scan = scan_directory(raw_dir)
    return {
        "schema_version": 1,
        "generated_by": "scripts/lineup.py (called by scripts/etl.py build --offline)",
        "formula_version": FORMULA_VERSION,
        "source_manifest_sha256": sha256_file(manifest_path),
        "license": LICENSE,
        "purpose": PURPOSE,
        "n_upcoming": N_UPCOMING,
        "unknown_pitch_count_gate": (
            "NP records are non-PA and never advance the on-deck pointer; a blank "
            "pitch field on an NP record is not an unknown PA."
        ),
        "counts": scan["counts"],
        "samples": scan["samples"],
    }


def serialize(summary: dict) -> str:
    return json.dumps(summary, indent=2, sort_keys=True) + "\n"


def write_artifact(summary: dict, path: Path = DEFAULT_ARTIFACT) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(serialize(summary))
    return path


if __name__ == "__main__":
    summary = build_summary()
    print(write_artifact(summary))
