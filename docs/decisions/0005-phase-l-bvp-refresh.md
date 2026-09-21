# 0005 — Phase L in-season BvP refresh

Status: **ACCEPTED — Option A** (Harlan, 2026-09-21). Closes ROADMAP DEC-10.

## Decision

Phase L keeps BvP/shrink **precomputed**: a scheduled **daily** job rebuilds the
BvP/shrink artifact from the current in-season play-by-play source, so a live card
joins a table that includes games through the previous day.

- No live scrape on the request path; the join is to a frozen artifact.
- The job records the **freshness** (latest game included) and provenance in the
  artifact; the card and `/about` show that date.
- **License:** individual, non-commercial, single-user/password Phase L only; no
  bulk archive retention; polite polling. No public redistribution before D6
  (DEC-6 deferred).
- Retrosheet remains historical-only and is never the in-season source.

## Consequences

- If the daily job fails, the card shows the artifact's age and the state is
  labeled stale — never silently served as current.
- The refresh source and cadence are added to the RTP-19 validation.
