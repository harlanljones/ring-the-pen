# 0003 — Retrosheet parsing path

Status: **ACCEPTED — Option A+C** (Harlan, 2026-09-21). Closes ROADMAP DEC-4.

## Decision

- **Primary (A):** parse `2025plays.csv` with the Python standard library, and
  parse event files with a stdlib parser. No new runtime dependency; deterministic
  and offline.
- **Cross-check (C):** also build/run Chadwick `cwevent` and reconcile its output
  against the stdlib parse on the same games. `cwevent` is a *verification* tool,
  not the primary path.
- Do **not** depend on `bevent.exe`/`bgame.exe` (Win32 binaries; Linux execution
  unverified). They remain pinned for provenance only.

## Consequences

- If `cwevent` cannot be built or run offline, the stdlib + CSV path still stands,
  and the reconciliation is reported as partial (never fabricated).
- Reconciliation deltas become a tracked metric (RTP-05).

## Follow-up

`cwevent` build instructions and its pinned revision are recorded in
`docs/data-sources.md` when RTP-05 lands.
