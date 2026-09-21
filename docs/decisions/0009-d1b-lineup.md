# 0009 — D1b lineup reconstruction

Status: **ACCEPTED** (2026-09-21). Closes ROADMAP DEC-9.

## Decision

**Historical first, live later.**

### Historical (Phase H) — from event files
- Parse `start` records: the nine batting-order slots and each starter's defensive
  position, per team, per game.
- Parse `sub` records: a substitute replaces the player in that batting-order slot
  (pinch hitter takes the slot; defensive replacements keep the slot).
- Maintain the **current on-deck pointer** by walking the game's `play` records in
  order: after the current plate appearance, the next **N=3** distinct batters in
  the reconstructed order are the upcoming batters.
- Handle **order wrap** (slot 9 → slot 1) and skip any slot that is empty due to a
  substitution without a replacement.
- If the order cannot be reconstructed (missing `start`, unresolved sub), the state
  is **unknown** and the card is flagged — never guessed.

### Live (Phase L) — from the Stats API
- Read lineup / on-deck from the live feed. This may be **partial** (e.g. the feed
  may expose only the current batter and on-deck); mark missing upcoming batters as
  unknown rather than inferring.

## Consequences

- `N=3` comes from the PRD freeze pin; the reconstruction is code, never Jev.
- RTP-08 emits reconstructed upcoming batters (historical); RTP-18 does the live
  path. Historical ships first; the live path may be marked partial.
- A fixed, hand-checked fixture (one game with a pinch hitter and an order wrap)
  is the required test.
