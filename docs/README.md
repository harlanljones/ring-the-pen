# Ring The Pen — documentation registry

Single index of every spec, gate, decision, and research record for this project.
If a document is not listed here, it is not a controlling artifact. Status values:
`CONTROLLING` · `ACCEPTED` · `APPROVED` · `DRAFT` · `DEFERRED` · `REFERENCE`.

## Controlling spec

| Doc | Version | Status | Notes |
|---|---|---|---|
| `docs/PRD.md` | v0.1.2 | **CONTROLLING** | Renamed from "Pull Latch". Defines phases H/L/P, falsifiers, D0–D8. |
| `AGENTS.md` | — | **CONTROLLING (process)** | Instruction precedence, boundaries, ownership, verified commands. |
| `ROADMAP.md` | — | **CONTROLLING (sequencing)** | Work items RTP-01…25, TG milestones, waves, gates, risks. |

**Rename / provenance.** "Ring The Pen" is the renamed **Pull Latch** v0.1.2. The
prior-name v0.1.1 PRD is **not on disk anywhere**; D0–D5 are therefore re-derived in
`docs/gates/D0-D5.md`, not inherited. See *External source provenance* below.

## Specs

| Doc | Status | Purpose |
|---|---|---|
| `docs/specs/hook-card.md` | **DRAFT** | Hook-card artifact + judgment-state contract (frozen by RTP-08/RTP-09). |
| `docs/gates/D0-D5.md` | **APPROVED** | Re-derived gates D0 formulas, D1 BvP/shrink(+D1b), D2 pitch-unknown, D3 pen, D4 lock, D5 Brier. |
| `docs/gates/GATES.md` | **LIVE** | Build-acceptance gates G1…G8 with `CHECK`/`EXPECT`/`EVIDENCE`. |
| `docs/data-sources.md` | **LIVE** | Pinned inputs, fetch/verify, Chadwick cross-check, universe-A semantics. |

Gate records not yet written (tracked in ROADMAP §14): `docs/gates/D6.md`
(Phase P license — deferred) is covered by `docs/decisions/0006-phase-p-license.md`;
D7 (latency) → RTP-15; D8 (live test) → RTP-21.

## Decision records (`docs/decisions/`)

| ID | Decision | Status |
|---|---|---|
| 0001 | Math engine: ETL precompute reusing the-tango + Elixir lock; TG milestones | **ACCEPTED (A)** |
| 0002 | Universe A authority: both sources, reconciled (CSV counts, event-file lineup) | **ACCEPTED (C)** |
| 0003 | Parsing: stdlib + CSV primary, Chadwick `cwevent` cross-check | **ACCEPTED (A+C)** |
| 0004 | Injury / pen source: Stats API + third-party; Phase H unknown-labeled | **ACCEPTED (A+C)** |
| 0005 | Phase L in-season BvP refresh: scheduled daily precompute | **ACCEPTED (A)** |
| 0006 | Phase P license: deferred to publish; no public URL | **DEFERRED** |
| 0007 | BvP shrinkage: credibility blend; `k` split `k_display=20`/`k_shrink` | **ACCEPTED** |
| 0008 | Lock thresholds: 0.8/0.5 Choice/Score, 0.85 Noul, provisional | **ACCEPTED (provisional)** |
| 0009 | D1b lineup: historical-first from `start`/`sub`, live may be partial | **ACCEPTED** |

## Research (`docs/research/`)

| Doc | Status | Purpose |
|---|---|---|
| `docs/research/bvp-shrink.md` | **REFERENCE** | Primary-source findings behind DEC-7 (credibility theory, BvP reliability, Marcel, platoon constants). Marks unverified claims explicitly. |

## Data artifacts (`data/`)

| Path | Tracked | Purpose |
|---|---|---|
| `data/manifest.json` | yes | Pinned inputs: SHA-256, bytes, row counts, license. |
| `data/raw/**` | **no (gitignored)** | Bulk Retrosheet inputs, fetched and verified locally. |
| `data/derived/universe_a_summary.json` | yes | Universe A + unknown-class counts, provenance, invariants. |
| `data/derived/crosscheck_cwevent.json` | yes | CSV vs Chadwick `cwevent` PA reconciliation. |
| `NOTICE` | yes | Required Retrosheet attribution + license notes. |

## External source provenance

| Source | SHA-256 (2026-09-21) | Relationship |
|---|---|---|
| `/home/harlan/Downloads/PRD-pull-latch.md` | `b87bae1b…` | Prior-name copy, content-identical to `docs/PRD.md` modulo name/repo. |
| `docs/PRD.md` | `5afe4d13…` | Controlling v0.1.2 spec. |
| `tapowe-pull-latch-specs.tar.gz` | `014c8e1d…` | Holds only the v0.1.2 pull-latch copy (no v0.1.1). |
| `/home/harlan/Downloads/PRD-sabr-jev.md` | `184b9505…` | Predecessor product spec (latch pattern, D0–D4 gate style). |
| `sabr-jev/{AGENTS,GATES,PLAN,PRODUCT}.md` | `becd56f9…`/`0ffc3519…`/`810c67ca…`/`48589377…` | Predecessor process + gate template. |
| Chadwick `cwevent` git rev | `b4d3866f8d17b3d1245d619afd4bcdff76f0c52a` | Cross-check tool (GPL, not redistributed). |

## Update rules

- The PRD wins on product and licensing; `ROADMAP.md` wins on sequencing; `AGENTS.md`
  wins on process (`AGENTS.md` precedence section).
- Decision records are append-only: an accepted decision is superseded by a new
  numbered record, never silently edited.
- Gate text is edited only with a dated approval line.
- Every derived artifact carries source digests, `formula_version`, license, and
  purpose.
