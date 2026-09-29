#!/usr/bin/env python3
"""Frozen hook-card artifact builder (RTP-08, D1/D1b/D2).

Assembles ``{schema_version, formula_version, provenance, cards}`` from
explicit precomputed inputs. Each card carries an exact outer key set, a
``judgment_state`` with exactly the ``RingThePen.Questions`` allowlist keys
(identity/outcome/oracle fields are structurally impossible — the builder
takes no such parameter), and ``samples`` count values the trusted catalog
(RTP-12) cross-checks.

Card id format (frozen here): ``hook:<game_id>:<pa_index>``. The
``role:player_id:year`` predecessor form addressed season cards, not PA cards;
RTP-12 enforces this format instead.

Fail-safe default: cards are ``synthetic: true`` unless the caller explicitly
passes ``synthetic=False`` with real source digests. Real pair wiring
(BvP table, D1b next-3 from the frozen files) lands once ``make fetch``
reproduces the pinned raw layout; until then no artifact file is committed.

Offline. Stdlib only. Deterministic across runs.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
if __package__ in (None, ""):
    sys.path.insert(0, str(REPO_ROOT))

from scripts import bvp as bvp_mod  # noqa: E402

FORMULA_VERSION = "hook-card/1"
SCHEMA_VERSION = 1
N_UPCOMING = 3  # PRD frozen pin (DEC-9)

LICENSE = "Retrosheet data used under the Retrosheet notice (see NOTICE)"
PURPOSE = (
    "Frozen precomputed hook cards for the Phase H card/lock path: "
    "each card pairs an exact judgment_state with its provenance"
)

CARD_KEYS = (
    "id",
    "game_id",
    "pa_index",
    "synthetic",
    "judgment_state",
    "bvp",
    "samples",
)
STATE_KEYS = (
    "inning",
    "outs",
    "runners_on",
    "score_diff",
    "pitch_count",
    "bullpen_state",
    "leverage_index",
    "w_bvp",
    "w_prior",
    "prior_rate",
    "upcoming",
)
BVP_KEYS = ("n", "xbar", "m", "k_shrink", "posterior", "underqualified")
BULLPEN_STATES = ("available", "limited", "unknown")


def _require_int(value: int, name: str, low: int, high: int | None = None) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise ValueError(f"{name} must be an integer; got {value!r}")
    if value < low or (high is not None and value > high):
        raise ValueError(f"{name} must be in [{low}, {high}]; got {value!r}")
    return value


def _require_rate(value: float, name: str) -> float:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise ValueError(f"{name} must be a rate in [0,1]; got {value!r}")
    if not 0.0 <= float(value) <= 1.0:
        raise ValueError(f"{name} must be a rate in [0,1]; got {value!r}")
    return float(value)


def _require_optional_rate(value: float | None, name: str) -> float | None:
    if value is None:
        return None
    return _require_rate(value, name)


def _require_optional_nonnegative(value: float | None, name: str) -> float | None:
    if value is None:
        return None
    if not isinstance(value, (int, float)) or isinstance(value, bool) or float(value) < 0:
        raise ValueError(f"{name} must be a nonnegative number or null; got {value!r}")
    return float(value)


def build_card(
    *,
    game_id: str,
    pa_index: int,
    inning: int,
    outs: int,
    runners_on: int,
    score_diff: int,
    pitch_count: int | None,
    bullpen_state: str,
    leverage_index: float | None,
    bvp_n: int,
    bvp_xbar: float,
    bvp_m: float,
    k_shrink: float = bvp_mod.K_SHRINK_PLACEHOLDER,
    upcoming: list[tuple[int | None, float | None]],
    synthetic: bool = True,
) -> dict:
    """Assemble one hook card. Unknowns are explicit nulls, never defaults."""
    if not str(game_id).strip():
        raise ValueError("game_id must be a nonempty string")
    _require_int(pa_index, "pa_index", 0)
    _require_int(inning, "inning", 1)
    _require_int(outs, "outs", 0, 2)
    _require_int(runners_on, "runners_on", 0, 3)
    _require_int(score_diff, "score_diff", -10**6, 10**6)
    if pitch_count is not None:
        _require_int(pitch_count, "pitch_count", 1)
    if bullpen_state not in BULLPEN_STATES:
        raise ValueError(f"bullpen_state must be one of {BULLPEN_STATES}; got {bullpen_state!r}")
    _require_optional_nonnegative(leverage_index, "leverage_index")
    if not isinstance(synthetic, bool):
        raise ValueError(f"synthetic must be a boolean; got {synthetic!r}")
    if len(upcoming) != N_UPCOMING:
        raise ValueError(f"upcoming must be exactly {N_UPCOMING} slots (frozen N=3)")
    slots = []
    for pos, (n, rate) in enumerate(upcoming):
        if n is not None:
            _require_int(n, f"upcoming[{pos}].n", 0)
        slots.append({"n": n, "rate": _require_optional_rate(rate, f"upcoming[{pos}].rate")})

    w_bvp, w_prior = bvp_mod.weights(bvp_n, k_shrink)
    posterior = bvp_mod.blend(bvp_n, bvp_xbar, bvp_m, k_shrink)
    underqualified = bvp_mod.underqualified(bvp_n)
    prior_rate = _require_rate(bvp_m, "bvp_m")

    state = {
        "inning": inning,
        "outs": outs,
        "runners_on": runners_on,
        "score_diff": score_diff,
        "pitch_count": pitch_count,
        "bullpen_state": bullpen_state,
        "leverage_index": leverage_index,
        "w_bvp": w_bvp,
        "w_prior": w_prior,
        "prior_rate": prior_rate,
        "upcoming": slots,
    }
    return {
        "id": f"hook:{game_id}:{pa_index}",
        "game_id": game_id,
        "pa_index": pa_index,
        "synthetic": synthetic,
        "judgment_state": state,
        "bvp": {
            "n": bvp_n,
            "xbar": float(bvp_xbar),
            "m": prior_rate,
            "k_shrink": float(k_shrink),
            "posterior": posterior,
            "underqualified": underqualified,
        },
        "samples": {
            "bvp_n": bvp_n,
            "upcoming_n": [slot["n"] for slot in slots],
        },
    }


def build_artifact(cards: list[dict], *, sources: list[dict], synthetic: bool = True) -> dict:
    """Wrap cards with provenance. Source digests are explicit, never guessed."""
    if not isinstance(synthetic, bool):
        raise ValueError(f"synthetic must be a boolean; got {synthetic!r}")
    for source in sources:
        if set(source) != {"id", "sha256"} or not str(source["id"]).strip():
            raise ValueError(f"source must be {{id, sha256}}; got {source!r}")
    for card in cards:
        if tuple(sorted(card)) != tuple(sorted(CARD_KEYS)):
            raise ValueError(f"card keys must be exactly {CARD_KEYS}")
        if tuple(sorted(card["judgment_state"])) != tuple(sorted(STATE_KEYS)):
            raise ValueError(f"judgment_state keys must be exactly {STATE_KEYS}")
        if card["synthetic"] != synthetic:
            raise ValueError("card synthetic flag disagrees with the artifact")
    ordered = sorted(cards, key=lambda card: card["id"])
    return {
        "schema_version": SCHEMA_VERSION,
        "formula_version": FORMULA_VERSION,
        "generated_by": "scripts/cards.py (RTP-08; offline)",
        "license": LICENSE,
        "purpose": PURPOSE,
        "provenance": {
            "sources": sorted(sources, key=lambda source: source["id"]),
            "bvp_formula": bvp_mod.FORMULA_VERSION,
            "k_display": bvp_mod.K_DISPLAY,
            "n_upcoming": N_UPCOMING,
        },
        "synthetic": synthetic,
        "cards": ordered,
    }


def serialize(artifact: dict) -> str:
    return json.dumps(artifact, indent=2, sort_keys=True) + "\n"
