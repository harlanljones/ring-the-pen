#!/usr/bin/env python3
"""BvP + shrink tables (RTP-06, DEC-7).

Credibility / empirical-Bayes blend over the frozen universe-A pair table::

    posterior = (n * xbar + k_shrink * m) / (n + k_shrink)
    w_bvp     = n / (n + k_shrink)
    w_prior   = k_shrink / (n + k_shrink)

``n`` = observed BvP PA, ``xbar`` = observed BvP rate, ``m`` = prior mean rate
(odds-ratio expected rate per DEC-7; supplied per pair, not computed here),
``k_shrink`` = prior PA fitted from the artifact via variance components
(``k = EPV / VHM``; see ``fit_k_shrink``).

The ``k=20`` pin is split per DEC-7 and never used as the blend constant:

* ``K_DISPLAY = 20`` — frozen display / underqualified gate (``n < 20`` flags
  the card underqualified). Labeled **provisional**.
* ``K_SHRINK_PLACEHOLDER = 1000`` — blend constant until fitted from the
  frozen artifact. Labeled **uncalibrated** (``GUESS`` provenance); never
  presented as calibrated.

Prior ``m`` via the-tango odds-ratio / Marcel machinery (DEC-2) is a per-pair
*input* to this module. The 2025plays.csv column mapping for batter/pitcher/
outcome has not been verified against the frozen file on this machine (pinned
raw inputs are absent here; ``make fetch`` needs the pinned layout), so pair
extraction from raw stays an explicit open follow-up for RTP-08 wiring — this
module aggregates an explicit pair table and never guesses columns.

Offline. Stdlib only. Deterministic across runs.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ARTIFACT = REPO_ROOT / "data" / "derived" / "bvp_shrink.json"

FORMULA_VERSION = "bvp-shrink/1"

#: Frozen display / underqualified gate (PRD pin, provisional per DEC-7).
K_DISPLAY = 20
#: Blend constant until fitted from the frozen artifact (GUESS, uncalibrated).
K_SHRINK_PLACEHOLDER = 1000

LICENSE = "Retrosheet data used under the Retrosheet notice (see NOTICE)"
PURPOSE = (
    "BvP credibility-shrink tables for the D1 hook-card input: per-pair "
    "posterior, weights, and underqualified flag with provenance"
)

CONSTANTS = {
    "k_display": {
        "value": K_DISPLAY,
        "provenance": "PRD_DEFAULT",
        "status": "provisional",
        "source": "PRD frozen pin k=20, reinterpreted by DEC-7 as the display / "
        "underqualified gate only; never the blend constant.",
    },
    "k_shrink": {
        "value": K_SHRINK_PLACEHOLDER,
        "provenance": "GUESS",
        "status": "uncalibrated",
        "source": "DEC-7 placeholder (~1000 PA, by analogy with The Book's LHB "
        "platoon constant); to be fitted from the frozen artifact via "
        "variance components (k = EPV / VHM) before any calibration claim.",
    },
}


def _require_n(n: int) -> None:
    if not isinstance(n, int) or isinstance(n, bool) or n < 0:
        raise ValueError(f"n must be a nonnegative integer of observed BvP PA; got {n!r}")


def _require_rate(value: float, name: str) -> None:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise ValueError(f"{name} must be a rate in [0,1]; got {value!r}")
    if not 0.0 <= float(value) <= 1.0:
        raise ValueError(f"{name} must be a rate in [0,1]; got {value!r}")


def _require_k(k: float) -> None:
    if not isinstance(k, (int, float)) or isinstance(k, bool) or not float(k) > 0:
        raise ValueError(f"k_shrink must be a positive number of prior PA; got {k!r}")


def blend(n: int, xbar: float, m: float, k_shrink: float) -> float:
    """Credibility posterior for one batter-pitcher pair.

    Unknown inputs are errors, never defaulted: pass an explicit ``m`` and a
    positive ``k_shrink``. When ``n == 0`` the posterior equals ``m`` (pass
    ``xbar=0.0``; its weight is zero).
    """
    _require_n(n)
    _require_rate(xbar, "xbar")
    _require_rate(m, "m")
    _require_k(k_shrink)
    return (n * float(xbar) + float(k_shrink) * float(m)) / (n + float(k_shrink))


def weights(n: int, k_shrink: float) -> tuple[float, float]:
    """Return ``(w_bvp, w_prior)``; they sum to 1."""
    _require_n(n)
    _require_k(k_shrink)
    k = float(k_shrink)
    w_bvp = n / (n + k)
    return w_bvp, k / (n + k)


def underqualified(n: int, k_display: int = K_DISPLAY) -> bool:
    """True when the BvP sample is below the display gate (flag, not math)."""
    _require_n(n)
    if not isinstance(k_display, int) or isinstance(k_display, bool) or k_display <= 0:
        raise ValueError(f"k_display must be a positive integer; got {k_display!r}")
    return n < k_display


def fit_k_shrink(pairs: list[tuple[int, float]]) -> dict | None:
    """Fit ``k = EPV / VHM`` from a pair table by variance components.

    ``pairs`` is a list of ``(n_i, xbar_i)``. EPV (within-pair variance) is the
    binomial ``p(1-p)`` at the pooled rate; VHM (between-pair variance) is the
    observed variance of the pair means minus the mean sampling variance::

        VHM = Var(xbar_i) - mean(EPV / n_i)

    Returns ``None`` when the between-pair variance is not positive (the
    observed spread is fully explained by sampling noise, so ``k -> infinity``
    and the posterior should stay at the prior). Returns a dict with ``k``,
    ``epv``, ``vhm``, and the pooled rate otherwise.
    """
    cleaned = [(n, float(x)) for n, x in pairs]
    for n, x in cleaned:
        _require_n(n)
        _require_rate(x, "xbar")
    usable = [(n, x) for n, x in cleaned if n > 0]
    if len(usable) < 2:
        raise ValueError("fit_k_shrink needs at least two pairs with n > 0")
    total_n = sum(n for n, _ in usable)
    pooled = sum(n * x for n, x in usable) / total_n
    epv = pooled * (1.0 - pooled)
    mean_x = sum(x for _, x in usable) / len(usable)
    obs_var = sum((x - mean_x) ** 2 for _, x in usable) / len(usable)
    vhm = obs_var - sum(epv / n for n, _ in usable) / len(usable)
    if vhm <= 0:
        return None
    return {"k": epv / vhm, "epv": epv, "vhm": vhm, "pooled_rate": pooled,
            "pairs": len(usable)}


def shrink_pair(pair_id: str, n: int, xbar: float, m: float,
                k_shrink: float = K_SHRINK_PLACEHOLDER) -> dict:
    """Shrink one pair into its card-ready row (posterior, weights, flags)."""
    if not str(pair_id).strip():
        raise ValueError("pair_id must be a nonempty string")
    _require_rate(m, "m")
    posterior = blend(n, xbar, m, k_shrink)
    w_bvp, w_prior = weights(n, k_shrink)
    return {
        "pair_id": pair_id,
        "n": n,
        "xbar": float(xbar),
        "m": float(m),
        "k_shrink": float(k_shrink),
        "posterior": posterior,
        "w_bvp": w_bvp,
        "w_prior": w_prior,
        "underqualified": underqualified(n),
        "uncalibrated": True,
    }


def build_artifact(pairs: list[dict],
                   k_shrink: float = K_SHRINK_PLACEHOLDER,
                   k_fit: dict | None = None) -> dict:
    """Build the derived bvp_shrink artifact from an explicit pair table.

    Each pair is ``{"pair_id": str, "n": int, "xbar": rate, "m": rate}``.
    ``k_fit`` optionally records a fitted ``fit_k_shrink`` result; until a fit
    from the frozen artifact lands, the placeholder applies and every row
    carries ``uncalibrated: true``.
    """
    _require_k(k_shrink)
    rows = [shrink_pair(p["pair_id"], p["n"], p["xbar"], p["m"], k_shrink) for p in pairs]
    rows.sort(key=lambda row: row["pair_id"])
    return {
        "schema_version": 1,
        "formula_version": FORMULA_VERSION,
        "generated_by": "scripts/bvp.py (RTP-06; offline)",
        "license": LICENSE,
        "purpose": PURPOSE,
        "formula": "posterior = (n * xbar + k_shrink * m) / (n + k_shrink)",
        "constants": {name: dict(const) for name, const in CONSTANTS.items()}
        | ({"k_shrink_fit": k_fit} if k_fit is not None else {}),
        "prior_spec": {
            "m": "odds-ratio expected rate: batter regressed overall rate "
            "(adjusted to pitcher hand) x pitcher regressed allowed rate "
            "(adjusted to batter hand); batter platoon regressed 1000/2200 PA, "
            "pitcher platoon ~700/450 BFP (DEC-7).",
            "provenance": "the-tango matchup.expected_woba_matrix / odds_ratio_woba "
            "(DEC-2 Option A reuse); m is a per-pair input here, not computed.",
            "status": "uncalibrated",
        },
        "open_follow_up": (
            "Pair extraction from 2025plays.csv (batter/pitcher/outcome column "
            "mapping) is unverified on this machine; wire it in RTP-08 once "
            "`make fetch` reproduces the pinned layout."
        ),
        "pairs": rows,
    }


def serialize(artifact: dict) -> str:
    return json.dumps(artifact, indent=2, sort_keys=True) + "\n"


def write_artifact(artifact: dict, path: Path = DEFAULT_ARTIFACT) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(serialize(artifact))
    return path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", default=str(DEFAULT_ARTIFACT))
    parser.add_argument("--k-shrink", type=float, default=K_SHRINK_PLACEHOLDER)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    path = write_artifact(build_artifact([], k_shrink=args.k_shrink), Path(args.artifact))
    print(f"wrote {path} (empty pair table; wire real pairs in RTP-08)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
