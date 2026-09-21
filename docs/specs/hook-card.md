# Hook card + judgment-state contract

Status: **DRAFT — not frozen.** Fields marked **[FROZEN]** come from `docs/PRD.md`
v0.1.2 or an accepted decision record; fields marked **[UNFROZEN]** are proposals to
be fixed by RTP-08 (artifact) and RTP-09 (questions). Do not treat any
[UNFROZEN] field as settled.

## 1. What the card is

At a plate appearance, **code** assembles a hook card from precomputed state
(Phase H) or live state (Phases L/P). **TypeSafe Jev** consumes only the
allowlisted `judgment_state` and returns typed answers; a **confidence lock**
routes the card. **Math lives in code only; Jev never computes numbers.**
[FROZEN: PRD §1, §2]

## 2. Card inputs (all code-computed)

| Input | Status | Source |
|---|---|---|
| Pitcher identity + handedness | [UNFROZEN] shape; identity stays out of `judgment_state` | Retrosheet (H) / Stats API (L/P) |
| Pitch count | [FROZEN] unknown ≠ 0; explicit unknown state | Derived per universe A (DEC-2/0002) |
| Inning, score, outs, count | [UNFROZEN] shape | Feed (H replay / L live) |
| Next **N=3** batters (upcoming) | [FROZEN] N=3; reconstructed per DEC-9 | Event files `start`/`sub` (H); feed (L) |
| BvP observed `n`, `x̄` | [FROZEN] credibility blend per DEC-7 | `data/derived` BvP table |
| Shrink weights `w_bvp`, `w_prior`, prior `m`, `k_shrink`/`k_display` | [FROZEN] DEC-7 | BvP table |
| Leverage / RE24 inputs | [UNFROZEN] shape | `2025_RE24_Values.csv` (RTP-07) |
| Bullpen availability / usage | [FROZEN] unknown when unavailable; never "available" by default | DEC-8 source set |
| Code-gate state (pitch cap, injured, empty pen) | [FROZEN] deterministic code, not Jev | DEC-8 / D3 |

## 3. Artifact shape

[UNFROZEN — frozen by RTP-08. Predecessor shape for reference:]

```
{
  "schema_version": <int>,
  "provenance": { "sources": [...], "formula_version": "...", "license": "...", "purpose": "..." },
  "cards": [ { ... card ... } ]
}
```

Required per-card invariants (enforced by the trusted catalog, RTP-12):
- exact outer key set (unknown keys rejected);
- stable card id; **[UNFROZEN]** format — candidates: `hook:<game_id>:<pa_index>`
  or `pitcher:<player_id>:<game_id>` (predecessor used `role:player_id:year`);
- outer metrics **equal** the corresponding `judgment_state` metrics for shared
  fields;
- counts (BvP `n`, IP/PA) equal the `sample` values;
- no oracle/T+1 field reachable from the judgment state.

## 4. `judgment_state` allowlist

[FROZEN rule: PRD falsifier "Jev invents rates"; AGENTS boundary.]

Allowed: precomputed **numeric** context produced by code (rates, counts, weights,
leverage, sample sizes, gate flags as typed enums).

Forbidden: player/team identity, names, years that leak outcomes, next-PA or
T+1 outcomes, oracle fields, anything the model would have to compute.

The state is hashed (`state_hash`) and the question set is hashed
(`questions_hash`) so a recorded judgment cannot drift silently.

## 5. Jev questions

IDs and options are **[FROZEN]**: PRD §2.

| Kind | ID | Options |
|---|---|---|
| Choice (primary lock driver) | `pull_decision` | `pull_now \| ride \| soft_hook \| emergency_hook \| other` |
| Score (primary driver) | `hook_urgency` | `calm \| watch \| warm \| pull_window \| yank` |
| Noul (secondary only) | `danger_pa_now` | probability |
| Noul (secondary only) | `danger_window_next3` | probability |

**[UNFROZEN]** — RTP-09 must freeze, per question: the criteria sentence for each
option, the Noul target/horizon (what "danger" is, over which PA window), and the
exact `questions_hash` input. No question may encode a deterministic code check
(the pitch-cap stop is a code gate, never a Noul).

## 6. Lock

Routing is **[FROZEN]** by `docs/decisions/0008-lock-thresholds.md`:
Choice/Score drive `act|review|escalate` (0.8/0.5, `other`→escalate); Noul is
`act|review` only (0.85) and never escalates alone; underqualified sample cannot
`act`; code gates are not overridable. Thresholds labeled **provisional**.

## 7. Provenance

Every card carries: source digests (from `data/manifest.json`), `formula_version`,
license (Retrosheet notice where used), purpose, and the BvP/prior provenance
labels (`k_shrink` = `uncalibrated` until fitted). No uncalibrated constant is
presented as calibrated.
