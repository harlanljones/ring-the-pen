# Build-acceptance gates (GATES)

Executable acceptance gates for the build, in the predecessor `sabr-jev` style:
each gate has a `CHECK`, an `EXPECT`, and recorded `EVIDENCE`. These are distinct
from the product decision gates D0–D8 (`docs/gates/D0-D5.md`, ROADMAP §14).

Status legend: `DONE` (evidence recorded) · `PARTIAL` · `PENDING`.

## G1 — Offline Elixir app/lock tests pass without an API key

- **CHECK:** `env -u TYPESAFE_API_KEY mix test`
- **EXPECT:** all tests pass; no `TYPESAFE_API_KEY` required.
- **EVIDENCE (RTP-01, 2026-09-21):** 3 passed. Status: **DONE** (expands with the lock).

## G2 — Elixir formatting and strict compilation pass

- **CHECK:** `mix format --check-formatted && mix compile --warnings-as-errors`
- **EXPECT:** both exit 0.
- **EVIDENCE (RTP-01, 2026-09-21):** both exit 0. Status: **DONE**.

## G3 — ETL suite passes offline

- **CHECK:** `python3 -m unittest discover -s tests -v`
- **EXPECT:** `OK`.
- **EVIDENCE (RTP-05, 2026-09-21):** 7 passed. Status: **DONE**.

## G4 — Inputs pinned and fail closed

- **CHECK:** `make verify-inputs`
- **EXPECT:** every pinned input verifies; a missing/changed input fails with exit 1.
- **EVIDENCE (RTP-02, 2026-09-21):** all OK; negative test (empty dir) exit 1.
  Status: **DONE**.

## G5 — ETL is deterministic

- **CHECK:** `make data` twice; compare `data/derived/universe_a_summary.json`.
- **EXPECT:** byte-identical across runs; no timestamp in the artifact.
- **EVIDENCE (RTP-05, 2026-09-21):** byte-identical. Status: **DONE**.

## G6 — Universe A reconciled against an independent parser

- **CHECK:** `make crosscheck CWEVENT=/path/to/cwevent`
- **EXPECT:** 0 PA mismatches on common games; every discrepancy explained as scope.
- **EVIDENCE (RTP-05, 2026-09-21; Chadwick rev `b4d3866f…`, cwevent 0.11.0):**
  2,430 common games, 0 mismatches; 48 CSV-only games (43 postseason, 1 All-Star,
  4 late-Sept) = the 3,714 PA delta. Status: **DONE**.

## G7 — Cross-engine parity with the-tango

- **CHECK:** `TG-4` parity fixture (the-tango golden vector) in the ETL.
- **EXPECT:** hook-path numbers match the fixture within stated tolerance.
- **EVIDENCE:** none. Status: **PENDING** (TG-1…TG-5).

## G8 — Hook card reaches the lock; falsifier negative suite green

- **CHECK:** `mix test` (lock + negative falsifier suite, RTP-17).
- **EXPECT:** every card route passes the lock; one negative test per PRD §7
  falsifier; 0 violations.
- **EVIDENCE:** none. Status: **PENDING** (RTP-11…RTP-17).

## G9 — Latency panel (D7) and Phase H honesty

- **CHECK:** workbench LiveView tests + `/about` content tests (RTP-14/RTP-15).
- **EXPECT:** `feed_delay`/`state_build_ms`/`jev_rtt_ms`/`ui_paint_ms` shown; no
  "instant from pitch release" copy; Retrosheet never labeled live.
- **EVIDENCE:** none. Status: **PENDING**.

## G10 — Evaluation honesty (D5)

- **CHECK:** `mix test test/ring_the_pen/evaluation_test.exs` + refusal tests.
- **EXPECT:** Brier by class with frozen baseline, reliability buckets,
  coverage/missingness; "accuracy pending" until outcomes; no calibration claim.
- **EVIDENCE:** none. Status: **PENDING** (RTP-16).

## G11 — Phase L private live (D8) and Phase P license (D6)

- **CHECK:** one live `gamePk` private run (D8); D6 record before any public URL.
- **EXPECT:** no bulk archive; polite poll; D6 resolved or public path blocked.
- **EVIDENCE:** none. Status: **PENDING** (RTP-21/RTP-22); D6 deferred
  (`docs/decisions/0006-phase-p-license.md`).

## G12 — Release quality

- **CHECK:** independent spec review then quality review; parent re-runs the full
  offline suite, formatter, strict compile, and gate checks.
- **EXPECT:** both reviews approve; ≤ three review cycles.
- **EVIDENCE:** none. Status: **PENDING** (RTP-24/RTP-25).
