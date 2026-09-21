# Data sources and pinning

Frozen, checksummed inputs for Ring The Pen. Bulk raw inputs are **not**
committed; they are pinned by digest in `data/manifest.json` and verified before
any ETL run. This file describes what is pinned, how to obtain it locally, and
how verification fails closed.

## Pinned inputs (Phase H, 2025)

| ID | Path | Contents | Rows (pinned) | License |
|---|---|---|---|---|
| `retrosheet-2025-events` | `2025eve/` | 30 event files (15 `.EVA` + 15 `.EVN`) | 216,845 `play` records | Retrosheet notice |
| `retrosheet-2025-box` | `2025box/` | 33 box/roster files (`.EBA`/`.EBN`/`.ROS`) | 314,622 lines | Retrosheet notice |
| `retrosheet-2025-plays` | `2025plays/2025plays.csv` | play-by-play CSV (literal `nump`, `pa`, `pitches`) | 193,767 data rows | Retrosheet notice |
| `retrosheet-2025-re24` | `2025_RE24_Values.csv` | run-expectancy (RE24) states | 8 data rows | Retrosheet notice |
| `chadwick-tools` | `bevent.exe`, `bgame.exe` | Win32 Chadwick parsers | — | Chadwick license |

The exact digests, byte sizes, and per-file `play` counts are in
`data/manifest.json`. The `NOTICE` file carries the required Retrosheet
attribution.

## Obtain and verify

Raw files live under `data/raw/` (gitignored). Fetch them from a local bundle,
then verify:

```bash
# Copy absent pinned inputs from a local source directory.
python3 scripts/verify_inputs.py fetch --source-dir "$HOME/Downloads"

# Verify every digest, size, and row count. Exit 1 on any mismatch.
python3 scripts/verify_inputs.py verify
```

`make fetch` and `make verify-inputs` wrap those commands. The ETL `make data`
target is added by RTP-05.

Re-pin only when the source changes intentionally:

```bash
python3 scripts/verify_inputs.py pin --source-dir "$HOME/Downloads"
```

## Why the raw data is not committed

- Retrosheet bulk data must not be redistributed from this repository; only small
  derived artifacts with provenance and the Retrosheet notice are committed.
- `data/raw/` is gitignored, so a clean clone re-fetches locally and re-verifies
  against the committed manifest.

## Fail-closed rules

`verify` fails (exit 1) when an input is missing, its SHA-256 differs, its byte
size differs, or its row count differs from the manifest. A missing input or
unavailable API is a blocker per `AGENTS.md`: report it and stop; never fabricate
a substitute artifact.

## Pitch-count semantics (universe A)

In `2025plays.csv`:

- `pa=1 & nump>0` — universe A candidate (**186,127** rows).
- `pa=1 & nump ∈ {blank, 0}` — the unknown pitch-count class (**513** rows),
  never counted as 0 pitches.

In the raw event files the 6th `play` field is the pitch sequence; a blank there
is overwhelmingly an `NP` (non-PA) record (20,405 of 20,406), so it is **not** an
unknown plate appearance. Always gate on the `pa` flag.

## Chadwick cross-check (DEC-4 A+C)

The stdlib/CSV parse is primary; Chadwick `cwevent` independently cross-checks it.
`cwevent` is GPL and is **not** redistributed here. Build it from a pinned
revision (network + autotools; not part of the offline suite):

```bash
git clone https://github.com/chadwickbureau/chadwick.git
cd chadwick && git checkout b4d3866f8d17b3d1245d619afd4bcdff76f0c52a
autoreconf -fi && ./configure && make
# then:
make crosscheck CWEVENT=/path/to/chadwick/src/cwtools/cwevent
```

Pinned tool revision: `b4d3866f8d17b3d1245d619afd4bcdff76f0c52a` (cwevent 0.11.0).

**Result (2026-09-21)** — `data/derived/crosscheck_cwevent.json`:

- Common games: **2,430**; games where CSV `pa=1` ≠ `cwevent` PA: **0**. On every
  shared game the two parses agree exactly, so the universe-A PA definition is
  supported by an independent tool.
- Games in `2025plays.csv` but not in the pinned `2025eve` event files: **48**
  (**43** postseason Oct/Nov, **1** All-Star `NLS202507150`, **4** late-September
  games dated 20250930). These account for the entire 3,714 PA delta.
- Consequence: universe A as pinned (186,127; `pa=1 & nump>0`) **includes
  postseason and All-Star rows**. If the demo should be regular-season only, add
  an explicit filter (tracked as a scope note, not a silent change).

## Decisions applied

- **DEC-3 (accepted: C)** — `2025plays.csv` is the counting authority for universe
  A; event files cross-check and supply D1b lineup. See
  `docs/decisions/0002-universe-a.md`.
- **DEC-4 (accepted: A+C)** — stdlib parser + CSV primary; Chadwick `cwevent`
  built and reconciled as a cross-check. `bevent.exe`/`bgame.exe` are not used.
  See `docs/decisions/0003-parsing.md`.
