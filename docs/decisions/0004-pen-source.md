# 0004 — Injury / bullpen-availability source

Status: **ACCEPTED — Option A+C** (Harlan, 2026-09-21). Closes ROADMAP DEC-8.

## Decision

- **Live (Phases L/P) — A:** MLB Stats API box score + roster endpoints are the
  primary source for active-roster and bullpen-usage state. **C:** a third-party
  source may supplement injury/availability, but only if it is licensed for use;
  it must be named and pinned before it is trusted.
- **Historical (Phase H):** availability data does not exist in Retrosheet. Pen
  **usage** is derived from Retrosheet box files; **availability** is an explicit
  `unknown` state with an honesty label. Never inferred as "available".
- An unavailable source is a blocker or an explicit unknown — never defaulted and
  never fabricated.

## Consequences

- The empty-pen hard gate fires only when the source positively says the pen is
  empty, or when state is `unknown` and the card labels it as such.
- D3's requirement text (`docs/gates/D0-D5.md`) already scopes the unknown case;
  this record names the sources.
- Any third-party source must be added to `NOTICE` and pinned if redistributed.

## Open detail

Named third-party vendor: **TBD** — record before use; do not scrape.
