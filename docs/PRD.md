# PRD: Ring The Pen — in-PA pitcher removal × TypeSafe Jev

| | |
|---|---|
| Product | Ring The Pen |
| Version | **0.1.2** |
| Status | **CONDITIONAL APPROVE (with D6).** Historical v0.1.1 holds. Late-season **private** live (Phase L) OK under MLBAM individual non-commercial. **Public playoff redistribute of Stats API live feed = KILL until D6 clears** (auth / licensed feed / sim-live demotion). |
| Repo | greenfield `harlanljones/ring-the-pen` |
| Freeze pins | **k=20** (BvP PA before shrink) · **N=3** upcoming batters · **D1b reconstruct** · demo universe **A** (`nump` present) · Elixir LiveView |
| Siblings | Sabr-Jev / Count Gate parked · ChatDirector frozen elsewhere |
| Do not | Jev invents rates; pitch-count stop as Noul; blank `nump` as pitches; claim Retrosheet is live; public Stats API live redistribute without MLBAM auth; “instant from pitch release” |

Audit live bump 2026-09-21. Does not implement.

---

## Spec verdict (this bump)

| Claim | Spec |
|---|---|
| Retrosheet powers September/October live | **KILL** — historical/delayed only |
| Stats API `feed/live` exists | **True** (e.g. `statsapi.mlb.com/api/v1.1/game/{gamePk}/feed/live`) |
| Free public playoff site on that feed | **KILL** without D6 — `copyright.txt`: *individual, non-commercial, non-bulk* only; other use needs prior written MLBAM auth |
| Phase L private late-season test | **APPROVE** — personal/password dugout OK if polite poll, no bulk archive redistribute |
| Phase P public playoffs | **CONDITIONAL** — D6 must clear first |
| “Instant” UI | **Rewrite** — LiveView after state ready; show `feed_delay` + `jev_rtt` (D7); not pitch-release latency |

**Overall: CONDITIONAL APPROVE with D6** — do not greenlight unconstrained live-public.

Opened: http://gdx.mlb.com/components/copyright.txt ; prior Retrosheet audit; v0.1.1 rewrite.

---

## 1. Frozen product bet

At a PA, **code** builds hook card → **Jev** Choice/Score/Noul → **confidence lock**. Math in code only.

### Phases

| Phase | Ships | License |
|---|---|---|
| **H — Historical** | Retrosheet universe A + LiveView | Retrosheet notice |
| **L — Late-season private live** | Poll Stats API → same card/lock; **single-user / password** | Individual non-commercial; no bulk; polite cache |
| **P — Playoff public** | Public URL | **D6:** MLBAM written auth **or** licensed feed **or** **sim-live** (delayed box / end-of-inning) with `/about` saying so |

---

## 2. Hook card + Jev (unchanged from v0.1.1)

- Choice `pull_decision`: `pull_now|ride|soft_hook|emergency_hook|other` → **primary lock**  
- Score `hook_urgency`: `calm|watch|warm|pull_window|yank`  
- Noul `danger_pa_now` / `danger_window_next3` → secondary only  
- Code gates: pitch cap (when known), injured, empty pen  
- Shrink: `pa_vs < k=20` → blend to platoon/season prior; show weights  
- Next batters: **N=3**; D1b reconstruct lineup  

---

## 3. Live ingest (Phase L/P)

1. Resolve `gamePk`.  
2. Poll/diff live feed → pitcher, pitch count, lineup/on-deck, inning/score.  
3. Join **precomputed** BvP/shrink (Retrosheet/Statcast ETL).  
4. State JSON → Jev → lock → LiveView.  
5. Hard code gates unchanged.

**Not live:** Retrosheet, Lahman, Savant CSV firehose.

---

## 4. Latency honesty (D7)

“Instant” = **no full page reload** when new state arrives.

Display/document: `feed_delay` + `state_build_ms` + `jev_rtt_ms` + `ui_paint_ms`.

NFR: **post-state-ready** decision+UI ≤ ~1–2s typical. Poll interval (2–5s) dominates feel. **Falsifier:** marketing sub-second from pitch release.

---

## 5. Gates

| Gate | Requirement |
|---|---|
| D0–D5 | As v0.1.1 (formulas, BvP/shrink, pitch unknown, pen, lock, Brier/uncalibrated) |
| **D6** | Phase P: auth / licensed / sim-live demotion in `/about` — else **no public playoff** |
| **D7** | Latency panel: feed age + Jev RTT |
| **D8** | Phase L: one live `gamePk` private test; no bulk archive dump |

---

## 6. Stack

Elixir + Phoenix LiveView · Python ETL Makefile · `jev-latest` + offline fixtures · no chat scout · no live FG scrape.

---

## 7. Falsifiers

- Retrosheet claimed as live  
- Public Stats API live redistribute without D6  
- “Instant from pitch”  
- Jev invents rates/counts  
- Pitch-count stop as Noul  
- Blank `nump` as pitches  
- No lock  

---

## 8. One-liner

**Historical + private live OK; public playoff live needs D6 — Stats API is not a free redistribute license.**
