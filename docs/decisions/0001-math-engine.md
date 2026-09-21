# 0001 — Hook-card math engine: reuse vs port

Status: **ACCEPTED — Option A** (Harlan, 2026-09-21), conditioned on the
`TG-1…TG-5` the-tango completion milestones (ROADMAP §M0b). Those milestones
**block** RTP-06 and RTP-08 until finished.
Date: 2026-09-21.

## Context

The PRD pins the app stack as Elixir + Phoenix LiveView, with a Python Makefile
ETL (`PRD.md:94`), and requires "math in code only" — but it never says where the
hook-card math runs or whether an existing engine is reused (`PRD.md:36,50-55`).

Two existing assets are adjacent, not identical:

- **`sabr-jev`** — verified Elixir/Phoenix + Python ETL workbench with a typed
  Jev adapter, confidence **latch** (`SabrJev.Latch`), trusted catalog, immutable
  recordings, and prospective evaluation. This is the **architecture** to mirror.
- **`the-tango`** — Python/NumPy engine for substitution/bullpen decisions:
  - `matchup.py`: `odds_ratio_woba/2`, `expected_woba/2`, `expected_woba_matrix/2`,
    `woba_delta_to_wpa/2` (BvP projection + leverage bridge).
  - `compas.py`: `assess_starter/2` → `StarterAssessment.hazard_hook_probability`,
    `stuff_plus/3`, `predicted_velo_delta/1`, `_excess_pitches/1` (pitch-count decay,
    `N_THRESH`), `bullpen_fatigue/1`.
  - `gancho.py`: three-batter-minimum cascade using `THREE_BATTER_MINIMUM = 3`.
  - `params.py`: every constant carries a `Provenance`
    (`CALIBRATED`/`PRD_DEFAULT`/`GUESS`); production startup refuses uncalibrated
    parameters. `README.md:41` calls it **uncalibrated research software**.

Caveat: `the-tango` is built for the **offensive** substitution question (should
*we* pinch-hit). Ring The Pen asks the **defensive** question (should we remove
*our* pitcher). `hazard_hook_probability` is specifically the opponent's
self-directed hook risk (`compas.py:167`), so its output is a *feature*, not the
verdict. Only the pure matchup/decay/fatigue formulas transfer cleanly.

## Decision

Where does the hook-card math live, and how much of `the-tango` is reused?

## Options

| # | Option | Pros | Cons |
|---|---|---|---|
| A | **Precompute in Python ETL** (reuse `the-tango` formulas); keep shrink/leverage/gates/lock as small pure Elixir | Matches AGENTS ownership (ETL Python, card math Elixir); heavy NumPy fits ETL; frozen artifact = precomputed state | Requires a Python→JSON artifact contract and parity fixtures; runtime cannot recompute arbitrary live variants |
| B | **Port formulas to Elixir** | Single runtime language; live recompute easy | Re-implements tested NumPy code; parity risk; more Elixir surface |
| C | **Reimplement from scratch in Elixir** | Clean fit to the defensive question | Highest cost; discards tested formulas; invents a model the PRD never specified |
| D | **Python sidecar service called at runtime** | Reuse as-is | Two runtimes in the live path; latency and deployment cost; contradicts "small pure modules" and offline-first tests |

## Recommendation (proposed, not decided)

**Option A.** The Python ETL imports the *reusable* `the-tango` functions to build
the precomputed hook card, and the Elixir side owns the small deterministic
pieces it already must own per `AGENTS.md`: shrink blend, leverage application,
code gates, and the lock. This keeps the artifact the single source of numeric
truth for Phase H, keeps the live path free of a second runtime, and confines the
uncalibrated `the-tango` constants to the ETL where they can be labeled.

Formulas that are purely the defensive question and absent from `the-tango`
(e.g. our own hook hazard given our pitcher's decay and our pen) are **new** and
must be specified in D0 before use — not silently borrowed.

## Validation / guardrails

- Reproduce or explicitly scope out `the-tango/tests/golden/prd_request.json` as a
  cross-engine **parity fixture**.
- Preserve `Provenance`; every borrowed constant is labeled
  `CALIBRATED`/`PRD_DEFAULT`/`GUESS` and shown as uncalibrated until a D5 report.
- No borrowed constant is presented as calibrated; the lock may gate an
  uncalibrated model only with the "uncalibrated" label visible.

## Decision record

- [x] Harlan selects **A** (2026-09-21).
- [x] Condition: finish the-tango on the hook path before trusting any number.
- [x] TG-1 classify hook path — appendix below
- [x] TG-2 defensive hook formula implemented
- [x] TG-3 provenance on hook path
- [x] TG-4 parity fixture pinned
- [x] TG-5 evidence recorded

## Appendix — TG-1 hook-path inventory (complete, 2026-09-21)

| Hook-card input | the-tango source | Classification |
|---|---|---|
| Batter-vs-pitcher expected rate | `matchup.expected_woba/2`, `expected_woba_matrix/2` | reuse |
| Offense/pitcher platoon odds | `matchup.odds_ratio_woba/2` | reuse |
| wOBA→WPA leverage bridge | `matchup.woba_delta_to_wpa/2` | reuse |
| Starter decay from pitch count | `compas.stuff_plus/3`, `predicted_velo_delta/1`, `_excess_pitches/1` | reuse |
| Bullpen fatigue | `compas.bullpen_fatigue/1`, `fatigue_velo_penalty/1` | reuse |
| Three-batter window | `params.THREE_BATTER_MINIMUM` (=3), `gancho` cascade shape | reuse (constant) / adapt |
| Opponent's self-hook risk (feature, not verdict) | `compas.assess_starter.hazard_hook_probability` | reuse |
| **Our-pitcher removal hazard** | **NEW → `tango.defensa.defensive_hook_hazard` (TG-2)** | **new** |

Exit: every hook-card input is mapped to a named function; only the defensive
removal hazard is new, and it now exists (below).

## Appendix — TG-2 defensive hook formula (landed)

`the-tango/packages/tango-engine/src/tango/defensa.py`:
`defensive_hook_hazard(telemetry, *, leverage_index=1.0, bullpen_readiness=0.5)`
→ `DefensiveHookAssessment` (hazard probability, decay state, inputs echoed for
audit). Logistic over pitch count vs `DEF_HOOK_PITCH_MIDPOINT`, observed velo/IVB
deficits, leverage above 1.0, and bullpen readiness in [0,1] — a hook needs an
arm to catch the ball, which the opponent's *self*-hook model does not model.
Exported from the `tango` package (`__init__.__all__`). Tests:
`tests/unit/test_defensive_hook.py` (monotone in pitch count, rising under
velo/IVB loss, readiness monotonicity, readiness bounds rejected, provenance of
every `DEF_HOOK_*` constant, export check) — written failing first (RED:
`ModuleNotFoundError: tango.defensa`), then implemented (GREEN). The formula is
a placeholder shape pending Gate 2's change-point calibration, mirroring the
self-hook model's own status.

## Appendix — TG-3 provenance on the hook path (landed)

- `compas.assess_starter`'s inline logistic literals (0.045/85.0/0.55/0.30/0.35/−0.8)
  were extracted to `params.SELF_HOOK_*` (`GUESS`, "inline literal before TG-3;
  pending Gate 2") — byte-identical behavior, no number changed.
- `params.DEF_HOOK_*` (7 constants) added, all `GUESS`.
- `params.HOOK_PATH_PARAMS` inventory (N_THRESH, ALPHA_VELO, BETA_IVB, ETA_SLOT,
  LAMBDA_STUFF, DELTA_TTOP, SELF_HOOK_*, DEF_HOOK_*) merged into
  `HOT_PATH_PARAMS`, so the existing production guard refuses uncalibrated
  startup on the whole hook path.
- Test: `tests/golden/test_parity_vector.py::test_hook_path_is_uncalibrated_until_gate_2`
  asserts every SELF_HOOK_/DEF_HOOK_ constant is `GUESS` (not `CALIBRATED`); exit
  condition "served only with the uncalibrated label" holds.

## Appendix — TG-4 parity fixture (pinned)

- the-tango: `tests/golden/parity_vector.json` pinned;
  `tests/dump_parity_vector.py` regenerates it;
  `tests/golden/test_parity_vector.py` asserts (a) byte-identical regeneration,
  (b) the recorded sha256 of `prd_request.json` still matches the source fixture.
- ring-the-pen: **`priv/data/tango_hook_parity.json`** — the pinned vector plus
  both digests:
  - source fixture `the-tango tests/golden/prd_request.json`
    sha256 `a9ee64ff21f7961815ec1686dd57b235db236fa6e984c12a3032e43f1d147b13`
  - parity vector sha256 `6d777520ef3eb81070df1973f8301173d56c0bd5c1ee87f9ba3663b91c31a1e2`
- Pinned key values (engine 2.0.0): leverage 4.905225 (CRITICAL), WE baseline
  0.493526, starter stuff 88.747613 (Δ −11.252387, COMPROMISED), opponent
  self-hook 0.934124, **defensive hook hazard 0.843772**, action PIVOT_SUBSTITUTION
  (best 680777, net_wpa 0.018126). All values carry the GUESS provenance above.

## Appendix — TG-5 evidence (2026-09-21)

```
$ cd the-tango && uv run pytest tests/unit tests/property tests/golden -q
63 passed in 1.34s
$ uv run ruff check packages tests      → All checks passed!
$ uv run mypy packages/tango-engine/src → Success: no issues found in 12 source files
$ uv run pytest -m gate -k 35ms -v      → test_gate_3_full_evaluation_under_35ms PASSED
```

Gate 3 (latency < 35 ms full evaluation) passes. Gates 1, 2, 4 still fail
exactly as `the-tango/README.md` documents — pinch-hit sample, change-point
detector, and postseason audit are unimplemented calibration work *outside* the
hook path; they were failing before TG-1..TG-5 and are not a regression. Suite
green; TG-1..TG-5 exit conditions met. RTP-06/RTP-08 unblocked.
