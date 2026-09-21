# Ring The Pen — Development Agent Guide

Durable, imperative guide for every agent and human who writes code in this
repository. Keep it free of temporary milestones and speculative design; those
belong in `ROADMAP.md`.

## Project intent

Ring The Pen (renamed from **Pull Latch**) is an in-PA pitcher-removal decision
workbench. At a plate appearance, **code** assembles a "hook card" from
precomputed state (Phase H) or live state (Phases L/P); **TypeSafe Jev** returns
a typed `Choice` / `Score` / `Noul`; a **confidence lock** gates the verdict.
The product is the lock — without it the workbench is a stats table. **Math lives
in code only; Jev never computes numbers.**

Controlling spec: `docs/PRD.md` v0.1.2 (the renamed and controlling version of
`Pull Latch` v0.1.1). Repo is greenfield `harlanljones/ring-the-pen`.

Frozen pins from the PRD: **k=20** (BvP PA before shrink) · **N=3** upcoming
batters · **D1b reconstruct** lineup · demo universe **A** (`nump` present) ·
**Elixir + Phoenix LiveView**.

## Where to work

| Path | Purpose |
|---|---|
| `docs/README.md` | Documentation registry: every spec, gate, decision, research note with status + source digests. |
| `docs/PRD.md` | Controlling spec (v0.1.2). Read in full before any change. |
| `ROADMAP.md` | Executable plan: work items, waves, gates, traceability. |
| `docs/specs/` | Artifact/question contracts (e.g. `hook-card.md`, draft). |
| `docs/gates/` | Gate text: `D0-D5.md` (approved) and `GATES.md` (build-acceptance). |
| `docs/decisions/` | Append-only decision records `0001…` (accepted/superseded, never silently edited). |
| `docs/research/` | Primary-source research behind decisions. |
| `docs/data-sources.md` | Pinned inputs, fetch/verify, Chadwick cross-check, universe-A semantics. |
| `data/` | Frozen, checksummed inputs + manifests; bulk raw stays untracked. |
| `scripts/` + `Makefile` | Python, stdlib-first ETL and derived artifacts. |
| `lib/ring_the_pen/` | Hook-card assembly, shrink, leverage, gates, lock, Jev boundary, catalog. |
| `lib/ring_the_pen_web/` | Phoenix LiveView workbench, `/about`, latency panel. |
| `priv/jev/` | Offline recorded Jev fixtures (immutable). |
| `priv/data/` | Committed derived artifacts (small, deterministic, provenance-carrying). |
| `NOTICE` | Required data attribution (Retrosheet etc.). |

Planned module names (`RingThePen`, `RingThePenWeb`, OTP app `:ring_the_pen`)
are proposed; RTP-01 fixes them before any other task writes Elixir.

## Instruction precedence

1. This file — process, boundaries, ownership, escalation.
2. `docs/PRD.md` v0.1.2 — product intent, licensing, falsifiers, phases.
3. `ROADMAP.md` and approved `docs/gates/*`, `docs/decisions/*` — sequencing and
   frozen decisions.

On conflict: the PRD wins on product and licensing; the ROADMAP wins on
sequencing; this file wins on process. If a lower document contradicts a higher
one, stop and escalate rather than choosing silently.

## Non-negotiable boundaries (from the PRD falsifiers)

- **Math in code only.** Jev receives allowlisted precomputed state JSON and
  never rates, counts, or derived statistics. *(Falsifier: Jev invents
  rates/counts.)*
- **The pitch-count stop is a code gate, never a Noul.** Hard gates
  (pitch cap when known, injured, empty pen) are deterministic code and cannot be
  delegated to Jev. *(Falsifier: pitch-count stop as Noul.)*
- **A missing pitch count is unknown, never 0 pitches.** Unknown must be an
  explicit state, excluded from pitch counts. Universe A candidate is
  `pa=1 AND nump>0`; the unknown class is `pa=1 AND nump ∈ {blank, 0}`. In the
  raw event files a blank 6th field is overwhelmingly an `NP` (non-PA) record,
  not an unknown plate appearance — always gate on the `pa` flag. *(Falsifier:
  blank `nump` as pitches.)*
- **Retrosheet is historical/delayed only.** Never label, serve, or imply
  Retrosheet as live. *(Falsifier: Retrosheet claimed as live.)*
- **No public redistribution of the MLB Stats API live feed until D6 clears in
  writing** (MLBAM auth, a licensed feed, or a documented sim-live demotion).
  *(Falsifier: public Stats API live redistribute without D6.)*
- **Never market "instant from pitch release".** "Instant" means no full page
  reload when new state arrives; the poll interval (2–5s) dominates feel.
  *(Falsifier: "instant from pitch".)*
- **No lock, no demo.** Every card route passes the confidence lock; the lock may
  escalate but never fabricate a verdict. *(Falsifier: no lock.)*
- **Precomputed-only joins.** BvP/shrink/leverage come from the frozen ETL
  artifact. No live Fangraphs scrape, no chat scout.
- **License-honest phases.** H = Retrosheet notice; L = individual
  non-commercial, single-user/password, polite poll, no bulk archive; P = D6
  before any public URL.

## Terminology

- Use "hook card", not "season card". Use "lock" / "confidence lock"; the
  predecessor's word "latch" appears only in historical documents.
- `Choice pull_decision` (`pull_now|ride|soft_hook|emergency_hook|other`) is the
  **primary** lock driver.
- `Score hook_urgency` (`calm|watch|warm|pull_window|yank`) is a primary
  driver alongside the Choice.
- `Noul danger_pa_now` / `Noul danger_window_next3` are **secondary only** and
  never escalate a card on their own.
- "Instant" is defined by PRD §4 (no full reload), not by pitch-release latency.

## Phases (see PRD §1)

- **H — Historical:** Retrosheet universe A + LiveView. License: Retrosheet
  notice.
- **L — Late-season private live:** poll Stats API into the same card/lock;
  single-user/password; polite cache. License: individual non-commercial, no bulk.
- **P — Playoff public:** public URL only after D6. Otherwise ship the sim-live
  demotion (delayed box / end-of-inning) and say so in `/about`.

## Commands

The Elixir commands below are **verified as of RTP-01** (Elixir 1.20.3-otp-28,
OTP 29; see `mise.toml`). Record new evidence before claiming any other command.

```bash
mix deps.get                               # network; Hex
mix format --check-formatted               # exit 0
mix compile --warnings-as-errors           # exit 0
mix test                                   # offline; no TYPESAFE_API_KEY
mix assets.build                           # esbuild -> priv/static/assets
```

RTP-01 evidence (2026-09-21): `mix format --check-formatted` → 0;
`mix compile --warnings-as-errors` → 0; `env -u TYPESAFE_API_KEY mix test` →
3 passed; `mix assets.setup && mix assets.build` → app.css/app.js emitted.

ETL commands (RTP-02/RTP-05, 2026-09-21):

```bash
make fetch                                 # copy absent pinned inputs; verify digests
make verify-inputs                         # fail closed on missing/changed input
make data                                  # offline ETL -> data/derived/*.json
python3 -m unittest discover -s tests -v   # ETL suite; 7 passed (RTP-05)
```

Evidence: `make verify-inputs` all OK; `make data` byte-identical across runs;
`python3 -m unittest discover -s tests -v` → 7 passed.

Cross-check (needs a locally built GPL tool, so not in the offline suite):

```bash
make crosscheck CWEVENT=/path/to/chadwick/src/cwtools/cwevent
```

Evidence (2026-09-21, Chadwick rev `b4d3866f…`, cwevent 0.11.0): 2,430 common
games, 0 PA mismatches; 48 CSV-only games (43 postseason, 1 All-Star, 4 late-Sept)
= the entire 3,714 PA delta. See `data/derived/crosscheck_cwevent.json`.

Still unverified (do not claim): anything under Phase L live ingest.

## Quality gates

- Formatting and strict compilation are law once RTP-01 verifies them.
- Offline by default: recorded Jev fixtures must cover the lock UI so `mix test`
  needs no `TYPESAFE_API_KEY`. Anything requiring a key is a live check, never
  part of the offline suite.
- No derived artifact is trusted until it passes the trusted catalog boundary
  (exact keys, `id == role:player_id:year`, outer metrics equal judgment-state
  metrics, counts equal sample values).
- Data lineage is real: every derived artifact carries source digests,
  `formula_version`, license, and purpose.
- Rename/config changes must not overwrite project instructions.

## Prohibited shortcuts

- Computing a number in prose, in a prompt, or in Jev instead of code.
- Sending identity, outcomes, or oracle/T+1 fields into the judgment state.
- Treating missing data (blank pitch sequence, missing `nump`, unavailable
  metric) as zero or as a negative.
- Presenting an uncalibrated constant as calibrated, or implying threshold
  calibration before an evaluation report exists.
- Committing bulk raw inputs, API keys, or `.env*`.
- Serving public live data before D6, or describing Retrosheet as live.

## Evidence and data rules

- Pin every external input with a revision plus SHA-256 and row counts; verify
  before use and fail closed on mismatch (saberkit's
  `season_constants.rs` revision/SHA pattern is the model).
- A missing input or unavailable API is a **blocker**: report it and stop. Never
  fabricate a substitute artifact, fixture, or number.
- Keep raw Retrosheet data out of the repository; commit only small derived
  artifacts with provenance and the required Retrosheet notice in `NOTICE`.
- Distinguish synthetic test inputs from recorded real responses explicitly.
- Preserve null/unknown semantics end to end; an unknown is never defaulted.

## Escalation conditions

Escalate (do not guess) when:

- A required input, fixture, or API is unavailable.
- A D-gate cannot be satisfied with current evidence.
- Math-engine reuse vs port is ambiguous for a specific formula (see RTP-04).
- The two data sources disagree (event files vs `2025plays.csv`) in a way that
  changes the universe A definition.
- D6 licensing is unresolved and someone wants a public URL.
- Review cycles do not converge (max three; then ask Harlan).

## Architectural ownership

- **Data/ETL (Python):** owns `scripts/**`, `Makefile`, `data/**`, `NOTICE`,
  `docs/data*.md`. Stdlib-first, deterministic, checksum-verified.
- **Hook-card + lock math (Elixir):** owns `lib/ring_the_pen/{cards,shrink,`
  `leverage,gates,lock}.ex`. Math is pure functions with ExUnit tests beside them.
- **Jev boundary:** owns `lib/ring_the_pen/{questions,judgments}.ex`, `priv/jev/**`.
  Validates; never computes math.
- **Catalog boundary:** owns `lib/ring_the_pen/catalog.ex`. No card reaches the
  lock or UI without passing it.
- **Web:** owns `lib/ring_the_pen_web/**`, `assets/**`, `priv/static/**`.
- **Live ingest:** owns `lib/ring_the_pen/live/**`.
- **Evaluation:** owns `lib/ring_the_pen/evaluation.ex`.
- **Decisions/docs:** owned by the planner (`docs/**`, `ROADMAP.md`).

Code may depend on a downstream module's interface, but only the owner writes its
files. If you need a change in a file you do not own, request it.

## Coordination protocol

1. **Decompose by dependency.** Build the predecessor lists from `ROADMAP.md`;
   do not start a task whose dependencies are unmet.
2. **One writer per file/component.** Never edit a file another task owns.
3. **Run independent tasks concurrently** only when their exclusive ownership is
   disjoint (ETL vs Jev boundary vs web, for example).
4. **Integrate in dependency order** using the integration checkpoints.
5. **Revalidate after merging.** Re-run the full offline suite, formatter,
   strict compile, and the relevant gate checks; a merge invalidates prior
   evidence for touched components.
6. **Reviews:** each sizable leaf gets a spec review then a quality review; for
   non-convergence after three cycles, escalate.

## Progress reporting

Report against the PRD, never by activity count. For any completed work state:

- Which hook-card inputs are real and from which frozen source, with digests.
- That Jev received only precomputed state and returned typed answers.
- The lock route produced from frozen recordings, and why.
- Which of the seven falsifiers were exercised by negative tests and the result.
- Which D-gate/phase exit the work advances, with the exact check and output.
- Any uncalibrated/provisional labeling still shown to users.
- Any pending or blocked item, and the blocker.

## Style and commits

Elixir + Phoenix LiveView; `mix format` is law once RTP-01 establishes it.
Prefer small pure modules with tests. Match surrounding code; comment *why*.
Do not add comments merely to restate code. Conventional Commits only if a hook
enforces it; otherwise plain imperative messages. Never commit unless the human
explicitly asks. Do not commit bulk data, secrets, or keys.
