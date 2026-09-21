# 0007 — BvP shrinkage: prior, estimator, window, and the k=20 pin

Status: **ACCEPTED** (2026-09-21). Closes ROADMAP DEC-7.
Research: `docs/research/bvp-shrink.md` (citations there).

## Decision

**Estimator (credibility / empirical Bayes).**

```
posterior = (n·x̄ + k_shrink·m) / (n + k_shrink)
Z         = n / (n + k_shrink)
```

`n` = observed BvP PA, `x̄` = observed BvP rate, `m` = prior mean,
`k_shrink` = prior PA (`= EPV/VHM`, fitted from the frozen artifact).

**Prior `m`.** Odds-ratio expected rate combining the batter's regressed overall
rate (adjusted to the pitcher's hand) with the pitcher's regressed allowed rate
(adjusted to the batter's hand). Platoon components are regressed toward league:
batter **1000 PA (LHB) / 2200 PA (RHB)**; pitcher **~700 / ~450 BFP**. Reuse
`the-tango` `matchup.expected_woba_matrix` / `odds_ratio_woba` (DEC-2), after the
TG milestones.

**Window.** Overall rates: 3-year, Marcel 5/4/3, PA/IP-weighted, regressed to
league with ~1200 PA. Platoon components: career-to-date with the constants above.
Observed BvP `x̄`: frozen artifact, career vs pitcher, current as of the artifact
freshness date (DEC-10).

**The k=20 pin is split.** The research found no source supporting 20 as a
shrinkage constant; 20 prior PA would give a 20-PA sample 50% weight.
- `k_display = 20` — the frozen pin, kept as the **display / underqualified gate**
  (below it the card is flagged underqualified). Labeled **provisional**.
- `k_shrink` — the blend constant, **fitted from the artifact** via variance
  components. Until fitted, use a placeholder of **~1000 PA labeled
  `uncalibrated`**; never present it as calibrated.

**Weights shown per card.** `w_bvp = n/(n + k_shrink)`, `w_prior = k_shrink/(n + k_shrink)`
(sum 1), plus `n`, `k_shrink` + provenance, `m`, the posterior, an
`underqualified` flag when `n < k_display`, and an `uncalibrated prior` badge until
a D5 calibration report exists.

## Deviation from the literal PRD line

`docs/PRD.md:54` reads "`pa_vs < k=20` → blend", i.e. a hard cutoff at 20 PA. That
literal reading is **not adopted**: 20 PA is far too small to stop shrinking.
Instead shrinkage is applied continuously to all `n`, and 20 serves only as the
display/underqualified gate. This is a documented reinterpretation of the frozen
pin, flagged for review — not a silent change.

## Open follow-ups

- [ ] Fit `k_shrink` from the frozen universe-A artifact (variance components /
      split-half inverted through `n/(n+k)`); replace the ~1000 placeholder.
- [ ] Read The Book ch.3 and Albert & Bennett *Curve Ball* from a physical/library
      copy (both UNVERIFIED in the research) and update this record if they change
      the picture.
- [ ] D1 gate fixtures: `pa_vs = 19/20/21` boundary tests attach to `k_display`;
      weight-sum tests attach to `k_shrink`.
