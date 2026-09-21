# 0008 — Confidence lock thresholds (provisional)

Status: **ACCEPTED (provisional)** (2026-09-21). Closes ROADMAP DEC-5.

## Decision

The lock reuses the predecessor `SabrJev.Latch` mechanism and route rules:

| Answer type | Route rule |
|---|---|
| Choice | `other` → `escalate`; else confidence ≥ 0.80 → `act`; ≥ 0.50 → `review`; else `escalate` |
| Score | ≥ 0.80 → `act`; ≥ 0.50 → `review`; else `escalate` |
| Noul | `max(p, 1-p) ≥ 0.85` → `act`; else `review` (**never** `escalate` alone) |

- The card route = the **worst** Choice/Score route; a Noul `review` can pull an
  `act` down to `review` but cannot escalate. Noul never escalates a card.
- An underqualified sample (per D1 `k_display`) can never route `act`.
- Hard code gates (pitch cap when known, injured, empty pen) are not overridable.

Thresholds live in one module exposing `thresholds/0` as
`status: "provisional"`.

## Labeling

Until a D5 evaluation report exists, every threshold is shown as **provisional**
in the UI and `/about`. No calibration or accuracy claim is made. Re-tuning
requires a new decision record, never a silent edit.

## Rationale

Mirrors the verified `sabr-jev` latch (`lib/sabr_jev/latch.ex`): 0.8/0.5
Choice/Score, 0.85 Noul act, Noul act/review only. The predecessor's thresholds
were themselves provisional and untuned; nothing here claims calibration.
