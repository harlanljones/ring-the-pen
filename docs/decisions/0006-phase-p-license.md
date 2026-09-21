# 0006 — Phase P license / public URL

Status: **DEFERRED to publish** (Harlan, 2026-09-21). Closes ROADMAP DEC-6
decision timing, not the license itself.

## Decision

- **No license right now.** No public URL, no public redistribution of the MLB
  Stats API live feed.
- Phase P stays blocked. Revisit this record **at publish time**, choosing one of:
  1. MLBAM written authorization, or
  2. a licensed feed, or
  3. a documented **sim-live** demotion (delayed box / end-of-inning) with a stated
     staleness bound and exact `/about` copy.
- Until then, only Phase H (Retrosheet, historical) and Phase L (private,
  single-user/password) may ship.

## Consequences

- RTP-23 (public deploy) remains blocked; RTP-22 records this deferral.
- `/about` must state the current phase and that no live feed is publicly served.
- Re-opening this record is a publish-time gate, not a build task.
