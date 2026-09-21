# 0002 — Universe A authority

Status: **ACCEPTED — Option C (both sources, reconciled)** (Harlan, 2026-09-21).
Closes ROADMAP DEC-3.

## Decision

Use **both** sources, with a clear division of authority:

- **`2025plays.csv` is the counting authority** for universe A, because it carries
  the literal `nump` and `pa` columns.
  - Universe A: `pa=1 AND nump>0` → **186,127** rows.
  - Unknown pitch-count class: `pa=1 AND nump ∈ {blank, 0}` → **513** rows.
- **Raw event files are the cross-check and the lineup authority**, because they
  carry `start`/`sub` records needed for D1b (next N=3 batters). Event files:
  216,845 `play` records; 20,406 blank 6th (pitch) fields of which **20,405 are
  `NP`** — a blank pitch there is a non-PA, not an unknown PA.
- The two populations differ (216,845 `play` vs 193,767 CSV rows); the difference
  is reconciled and reported, never silently resolved.

## Consequences

- RTP-05 emits a reconciliation report with both counts and the residual delta.
- A blank/zero `nump` is never counted as 0 pitches; an `NP` blank is never an
  unknown PA. Both are asserted by negative tests.
- D1b reads lineup from event files; D1 (BvP counts) reads `2025plays.csv`.

## Evidence

Pinned digests and row counts: `data/manifest.json`; measured candidates in
`docs/data-sources.md`.
