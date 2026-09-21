# DEC-7 research: BvP prior, estimator, window, and the k=20 pin

Status: research findings, not a decision record. Prepared for the DEC-7 owner.
Scope: the batter-vs-pitcher (BvP) shrinkage input to the hook card
(`docs/PRD.md:54` `pa_vs < k=20`; freeze pin `docs/PRD.md:9`).
Method: primary sources where reachable; secondary only where labeled. Every
measured claim carries a source URL. Where a source could not be reached, the
claim is marked **UNVERIFIED** and no number is asserted.

Reading note: quantities named `k`, `m`, `n`, `x̄` use the PRD/DEC-7 notation:
`n` = observed BvP plate appearances, `x̄` = observed BvP rate, `m` = prior mean
rate, `k` = prior sample size ("prior PA").

---

## Summary recommendation

1. **BvP-specific rate is dominated by noise.** Primary-quality sources report
   that batter-pitcher matchup rates are not predictive of future matchups, and
   that the signal that does exist is batter quality + pitcher quality +
   platoon handedness, not the specific pair (Sources 2, 3, 6). The Book's own
   matchup chapter opens from exactly that premise (Source 1, chapter 3 preview).
2. **Use the empirical-Bayes / credibility estimator**, not a raw cutoff:
   `posterior = (n·x̄ + k·m) / (n + k)`, equivalently reliability
   `Z = n/(n+k)`, with `k = EPV/VHM` (process variance over between-pair
   variance). This is standard Bühlmann credibility and is the same arithmetic
   as Tango's "add `k` PA of average" rule (Sources 7, 8, 9, 10, 11, 12).
3. **Prior `m` should be a regressed model expectation, not raw league average
   and not the batter's raw platoon split.** Build `m` from the batter's
   regressed overall rate adjusted to the pitcher's hand, combined with the
   pitcher's regressed allowed rate (odds-ratio method), with the batter's
   platoon component itself regressed toward league. This is the same
   `expected_woba` / `odds_ratio_woba` machinery DEC-2/`the-tango` already
   names (Source 3; `docs/decisions/0001-math-engine.md`).
4. **Window: 3 years, Marcel 5/4/3 weights**, PA/IP-weighted, regressed to
   league with Marcel's 1200 PA (batters) component; platoon components regressed
   with The Book's 1000 PA (LHB) / 2200 PA (RHB) constants (Sources 6, 3).
5. **k=20 verdict: keep 20 only as a *display/gate* threshold, never as the
   shrinkage constant.** As an empirical-Bayes `k` it is far too small: it gives
   a 20-PA BvP sample 50% weight, i.e. it promotes a sample that The Book treats
   as the *top tail* of all BvP samples (Source 1, ch.3 preview). We did not
   find any source that supports 20 as a BvP prior PA. `k=20` is currently
   **unprovenanced**. Recommend labeling it provisional and splitting the
   concept into `k_display` (keep 20) and `k_shrink` (large; placeholder ~1000,
   to be fitted from the frozen artifact before any calibration claim).
6. **Display weights:** show `w_bvp = n/(n+k_shrink)` and
   `w_prior = k_shrink/(n+k_shrink)`, plus `n`, `k_shrink`, `m`, the posterior,
   and an "uncalibrated prior" label until a calibration report exists.

**Inference** (not measured): if the BvP-specific between-pair variance is
near zero, `k = EPV/VHM` is very large, so the correct posterior is close to the
prior for essentially all real BvP samples (max realistic BvP samples are a few
dozen PA; Source 1, ch.3 preview). This is the honest reading of the reliability
literature and it is why a small `k` is the wrong default.

---

## Reliability evidence (with citations)

### What is measured

- The Book's matchup chapter ("Mano a Mano") sets up the test as follows. Using
  1999-2002 Retrosheet play-by-play, excluding position players pitching,
  pitchers batting, bunts, and IBB, it forms pairs that appear in both a *before*
  (1999-2001) and *after* (2002) sample: **20,208 confrontation pairs**.
  Restricting to pairs with **at least 17 before PA and 9 after PA** leaves
  **exactly 300 pairs**, averaging **22 before PA and 11 after PA**, and the
  chapter then asks whether those extreme "owns" performances carry forward.
  (Source 1, chapter 3 preview.) *Inference:* the chapter's own floor of 17
  prior PA is already near the top of the real BvP-sample distribution, which
  makes any claim that ~20 PA is "enough" suspect.
- FanGraphs' splits reference states plainly: "A great cautionary tale is
  batter-pitcher matchup stats. You see these featured on lots of broadcasts,
  but most research has found they are not predictive of future matchups. This
  is because these matchup stats are based on a small number of PA and occur
  over a long period of time in which the players change." It gives the
  example of facing a pitcher 40 times over five years. (Source 2.)
- Platoon *handedness* is real and measurable, unlike the specific pair:
  "**most hitters do better against pitchers of the opposite hand** ... The
  inverse is true for pitchers" (Source 2). The Book quantifies the typical
  left-handed-hitter platoon split at about **25 points of wOBA**, and notes
  that in **150 PA a typical player's wOBA can move ~40 points from randomness
  alone** (Source 1, chapter 6 preview).
- The Book's platoon-skill regression constants: **LHB platoon skill == regress
  against 1000 PA vs LHP of league-average splits; RHB against 2200 PA vs LHP**;
  switch-hitters reach a good read after ~600 career PA vs LHP. Pitcher platoon
  splits are more reliable: **~700 BFP vs LHP for RHP, ~450 for LHP** (Source 3,
  reporting The Book). *Inference:* even the real, measurable platoon
  interaction needs on the order of 1000+ PA to be half-signal, so a specific
  batter-pitcher interaction (which is weaker than the platoon) cannot be
  trusted at 20 PA.
- Reliability/stabilization is continuous, not a threshold. FanGraphs' sample
  size reference (following Carleton) reports the PA at which a stat's
  split-half correlation reaches ~0.7 (R^2 ~ .49): **K% ~60 PA, BB% ~120 PA,
  single rate ~290 PA, HR rate ~170 PA, AVG ~910 AB, BABIP ~820 BIP (batters)**;
  for pitchers, **K% ~70 BF, BB% ~170 BF, HR ~1320 BF, BABIP ~2000 BIP**.
  Carleton's own caution is that no stat "stabilizes" at a point; it only becomes
  *more* stable. (Source 4.)
- Regression to the mean is explicitly "not a formulaic rule" but a required
  correction for randomness in short samples (Source 5).

### What we could not verify

- **The Book's numeric conclusion for chapter 3** (e.g. the regression slope or
  R^2 for prior BvP predicting later BvP) was not reachable. The publisher
  preview hosts only the first page of the chapter (Source 1); the full text is
  borrow-only and OCR-locked on the Internet Archive. We therefore assert the
  *direction* (matchup rates are not predictive) from Source 2 and from the
  chapter's framing, and mark the chapter's specific coefficients **UNVERIFIED**.
- **Albert & Bennett, *Curve Ball*** (the requested primary statistical
  reference) could not be opened during this research: no reachable full text or
  preview was found, and the library listings returned were either wrong
  editions or blocked. Any claim that Curve Ball contains a specific BvP
  stabilization number is **UNVERIFIED** here. The book is real and is the
  standard statistics-of-baseball reference (Source 13); treat its BvP content as
  a to-do to read before finalizing DEC-7, not as evidence in this file.

---

## Estimator (formula + derivation + citation)

### The formula

Empirical-Bayes / credibility blend:

```
posterior = Z · x̄ + (1 − Z) · m
Z         = n / (n + k)
k         = EPV / VHM
```

which is algebraically identical to

```
posterior = (n·x̄ + k·m) / (n + k)
```

with

- `n` = observed BvP PA,
- `x̄` = observed BvP rate,
- `m` = prior mean rate,
- `k` = prior sample size ("prior PA" in the PRD).

(Source 9, Bühlmann model; Source 11, Loss Data Analytics credibility chapter;
Source 12, textbook treatment.)

### What k represents

`k` is the ratio of the **expected process variance** (EPV, within-pair random
variation, ~ `p(1-p)` per Bernoulli PA) to the **variance of the hypothetical
means** (VHM, the real spread in true per-pair talent):

```
Z = VHM / (VHM + EPV/n)      (Bühlmann credibility factor)
k = EPV / VHM
```

(Source 9, "Credibility theory" gives `z = VHM/(VHM + EPV/n)`; Source 10 is the
1967 origin.) Interpret as: **`k` is the number of observed PA at which the
observed rate and the prior get equal weight** (Z = 0.5 when n = k).

### Why this is the same as Tango's method

Tango's "add `k` games/PA of league-average performance to the observed record"
rule is exactly the credibility posterior mean for a binomial variable. Phil
Birnbaum's proof derives the constant: with `var(overall) = var(talent) +
var(luck)` and `var(luck) = p(1-p)/n`, the number of average observations to add
is `p(1-p)/var(talent)` — independent of the observed sample size `n` — and that
number is the `k` for which `SD(luck) = SD(talent)`. (Source 7.) Andrew Gelman's
commentary identifies this as hierarchical Bayes with a point estimate of the
group-level variance, and the actuary's `N/(N+K)` credibility formula; the
`K` there is "based on the ratio of within-individual and between-individual
variance", i.e. EPV/VHM. (Source 8.)

### How k is estimated from data (method of moments)

For a beta-binomial view, `posterior mean = (successes + α)/(PA + α + β)`, so
the prior parameters satisfy `m = α/(α+β)` and `k = α + β`; this is the
beta-binomial equivalent of the Bühlmann posterior mean (Source 7 comments;
Source 8). Practical variance-components recipe for the ETL (no code here, just
the estimator):

1. Over the frozen window, form cells (e.g. batter × pitcher × handedness, or
   batter × pitcher), each with observed rate `x̄_i` and `n_i`.
2. Estimate the within-cell variance `EPV` as the mean of `x̄_i(1−x̄_i)` (or the
   binomial `p(1−p)` at the pooled rate).
3. Estimate total variance of the observed means, `Var(x̄_i)`, then
   `VHM = Var(x̄_i) − mean(EPV/n_i)`. (For balanced `n`, this is the
   `var(overall) = var(talent) + var(luck)` identity of Source 7.)
4. `k = EPV / VHM`.

Equivalent empirical routes: split-half / Cronbach-alpha reliability curves
(Source 4) or an R^2 from regressing future BvP on past BvP (Source 7 framework),
inverting `reliability = n/(n+k)` to solve for `k`.

**Key consequence for BvP:** the reliability sources say the BvP-specific
between-pair component is near zero, so `VHM → 0` and `k → ∞`: the observed BvP
rate should carry near-zero weight. **Inference**, not a quoted number.

---

## Prior choice

Options and what the sources support:

| Candidate prior `m` | Assessment | Source |
|---|---|---|
| League average rate | Safe but discards real, well-measured information about the batter and pitcher. Should not be the *only* prior. | Source 3, Source 6 |
| Batter's overall (regressed, multi-year) rate, adjusted to the pitcher's hand | Supported. Batter talent is a real signal; regress it (Marcel-style) rather than use raw. | Source 6, Source 3 |
| Batter's raw platoon split vs the pitcher's handedness | Use only *after* regressing the split: The Book regresses LHB splits against 1000 PA and RHB against 2200 PA of league-average splits. Raw platoon splits overfit (Source 3). | Source 3, Source 5 |
| League average only | Rejected as sole prior (loses pitcher/batter signal). | — |
| Multi-year weighted batter rate × pitcher's regressed allowed rate (odds-ratio) | **Recommended.** This is the `expected_woba` / `odds_ratio_woba` construction already named for the hook path. | Source 3; DEC-2 (`docs/decisions/0001-math-engine.md`) |

**Role of the pitcher's side:** sources treat the pitcher's true rate as a
required component of the matchup expectation, not just the batter's. The Book's
odds-ratio method combines batter and pitcher true rates to form an expected
matchup rate; the pitcher's own platoon split is measurable and more reliable
than a batter's (Source 3). So `m` must include the pitcher's regressed allowed
rate vs the batter's handedness.

**Recommended `m` (inference, but grounded):**

```
m = odds_ratio_expected_rate(
      batter = regress_marcel(batter_overall, adjusted_to(pitcher_hand)),
      pitcher = regress_marcel(pitcher_allowed, adjusted_to(batter_hand))
    )
```

with the batter's platoon deviation regressed toward league using The Book's
1000/2200 PA constants. This is `the-tango` `matchup.expected_woba_matrix` /
`odds_ratio_woba` (DEC-2) — reuse rather than re-derive.

---

## Window

- **1 year:** too noisy for rate stats that behave like BABIP; pitcher BABIP can
  take ~3 years to stabilize (Source 4). Reject as the sole window.
- **3 years, Marcel 5/4/3 weights:** recommended. Marcel weights the last three
  seasons 5/4/3 (2003 = 5, 2001 = 3), PA-weighting the player's league average,
  then **forces in that player's league average to a total of 1200 PA** as the
  regression-to-the-mean component (Source 6). This is a published, minimal,
  reproducible scheme and it matches the project's move-fast ETL.
- **5 years:** only for the batter's platoon split, and then only with The
  Book's regression constants (1000/2200 PA) and aging caveats; player talent
  changes over five years (Source 2's "players change" warning).
- **BvP observed sample itself:** career-to-date vs that pitcher, from the frozen
  artifact, current as of the artifact's `freshness` date (DEC-10,
  `docs/decisions/0005-phase-l-bvp-refresh.md`).

Recommended, concretely:

- Batter and pitcher overall priors: **3-year, 5/4/3, PA/IP-weighted, regressed
  to league with ~1200 PA** (Marcel; Source 6).
- Batter platoon component: **career-to-date, regressed 1000/2200 PA** (Source 3).
- Pitcher platoon component: **regressed ~700 BFP (RHP) / ~450 BFP (LHP)**
  (Source 3).

---

## k=20 verdict

**20 is too small to be the shrinkage `k`, and we found no source that
provenances it.**

Evidence and reasoning:

- The Book's published reliability constants for a *real* interaction
  (platoon skill) are 1000 PA (LHB) and 2200 PA (RHB); pitcher platoon
  700/450 BFP (Source 3). A specific batter-pitcher interaction is weaker than
  the platoon (Sources 2, 1-ch.3), so its `k` cannot be smaller than these —
  it should be larger.
- Marcel's regression component for a plain batter rate is 1200 PA (Source 6),
  again orders of magnitude above 20.
- The Book's matchup analysis only becomes "presumably more relevant" at
  >=17 prior PA / >=9 after PA, averaging 22/11 — i.e. 20 prior PA is the top
  tail of BvP samples, not a trust threshold (Source 1, ch.3 preview).
- With `k = 20`, a 20-PA sample gets Z = 0.50, and 40 PA gets Z = 0.67 — this
  asserts that a couple dozen observations are half to two-thirds of the truth.
  That is precisely the error the reliability sources warn against (Sources 2, 4).

**Recommendation (choose one, explicitly, in DEC-7):**

- **Preferred:** split the constant.
  - `k_display = 20` — keep the frozen pin strictly as the minimum PA below
    which a raw BvP line is not shown (and the card is flagged underqualified).
    Label it *provisional*.
  - `k_shrink` — the prior PA in the blend. Do **not** set it to 20. Until the
    ETL fits it, use a clearly labeled uncalibrated placeholder on the order of
    **1000 PA** (consistent with The Book's LHB platoon constant, Source 3, and
    below Marcel's 1200, Source 6), shown in `/about` as uncalibrated.
- **If a single number must be retained:** re-pin `k` to the fitted
  `k_shrink` and re-purpose `20` only as the display gate; record the change in
  DEC-7 with the source above.

For either option the card must carry the `uncalibrated` label until a
calibration report exists (PRD D5; AGENTS "never present an uncalibrated
constant as calibrated").

---

## Weights to display

Expose the credibility split directly:

```
w_bvp   = n / (n + k_shrink)      # weight on observed BvP
w_prior = k_shrink / (n + k_shrink)  # weight on the prior
```

Display, per card:

- `n` (observed BvP PA) and `pa_vs`,
- `k_shrink` (prior PA) with its provenance label,
- `m` (prior mean rate) and the model components used to build it,
- `w_bvp` and `w_prior` (they sum to 1; round to two decimals or percent),
- the posterior rate `(n·x̄ + k·m)/(n+k)`,
- the "uncalibrated prior" badge while no D5 calibration report exists,
- an "underqualified / k_display" flag when `pa_vs < k_display`.

D1 (`docs/gates/D0-D5.md:44-64`) requires hand-computed fixtures at the
`pa_vs = 19/20/21` boundary and that weights "sum as specified in DEC-7". With
this recommendation the boundary tests apply to `k_display` (gate) and the weight
tests apply to `k_shrink` (blend) — state both explicitly so the fixtures are
unambiguous.

---

## Sources

1. Tom Tango, Mitchel Lichtman, Andrew Dolphin, *The Book: Playing the
   Percentages in Baseball* (Potomac Books, 2007). Chapter 3 "Mano a Mano"
   preview: <https://www.insidethebook.com/c03.shtml> · Chapter 6 "Left, Right,
   Left, Right" preview: <https://www.insidethebook.com/c06.shtml> · book record
   (borrow-only): <https://archive.org/details/bookplayingperce0000tang> ·
   chapter list: <https://www.insidethebook.com/reviews.shtml>
2. Piper Slowinski, "Splits," FanGraphs Sabermetrics Library, 2010:
   <https://library.fangraphs.com/principles/split/>
3. Matt Klaassen, "Estimating Hitter Platoon Skill," FanGraphs, 2010:
   <https://blogs.fangraphs.com/estimating-hitter-platoon-skill/>
4. Piper Slowinski, "Sample Size," FanGraphs Sabermetrics Library, 2010:
   <https://library.fangraphs.com/principles/sample-size/>
5. Piper Slowinski, "Regression toward the Mean," FanGraphs Sabermetrics
   Library, 2010: <https://library.fangraphs.com/principles/regression/>
6. Tom Tango, "The 2004 Marcels" (Marcel methodology), tangotiger.net archive,
   2004: <https://tangotiger.net/archives/stud0346.shtml>
7. Phil Birnbaum, "The Tango method of regression to the mean -- a proof,"
   Sabermetric Research, 2011:
   <http://blog.philbirnbaum.com/2011/08/tango-method-of-regression-to-mean-kind.html>
8. Andrew Gelman, "Quantifying luck vs. skill in sports," Statistical Modeling,
   Causal Inference, and Social Science, 2014:
   <https://statmodeling.stat.columbia.edu/2014/06/27/quantifying-luck-vs-skill-sports/>
9. "Bühlmann model," Wikipedia:
   <https://en.wikipedia.org/wiki/B%C3%BChlmann_model> · "Credibility theory,"
   Wikipedia (gives `z = VHM/(VHM + EPV/n)`):
   <https://en.wikipedia.org/wiki/Credibility_theory>
10. Hans Bühlmann, "Experience rating and credibility," *ASTIN Bulletin* 4(3),
    1967, pp. 199-207:
    <https://www.casact.org/library/astin/vol4no3/199.pdf>
11. *Loss Data Analytics* (open actuarial textbook), credibility chapter:
    <https://openacttexts.github.io/Loss-Data-Analytics/>
12. Hans Bühlmann & Alois Gisler, *A Course in Credibility Theory and its
    Applications* (Springer, 2005), ISBN 978-3-540-25753-0.
13. Jim Albert & Jay Bennett, *Curve Ball: Baseball, Statistics, and the Role of
    Chance in the Game* (Springer; rev. ed. 2003) — **not accessed this session;
    no claim in this file rests on it.** Recommended reading before DEC-7 is
    frozen.
14. Tom Tango, "Pitching Around Batters" (excerpt from The Book), The Hardball
    Times, 2006: <https://tht.fangraphs.com/pitching-around-batters/>
    (background on pitcher approach; not used for a BvP number).
15. Chad Evely, "Lopsided batter/pitcher match-ups," The Hardball Times, 2012:
    <https://tht.fangraphs.com/lopsided-batter-pitcher-matchups/> (career
    matchups can look extreme and still be within season expectation; motivates
    the "expectation vs actual" framing).

---

## Confidence and gaps

**High confidence (measured, primary or primary-adjacent):**

- The credibility/empirical-Bayes formula and `k = EPV/VHM` (Sources 9, 10, 11).
- Tango's add-`k`-of-average rule and its proof (Source 7); hierarchical-Bayes
  identification (Source 8).
- Marcel 5/4/3 and the 1200 PA regression component (Source 6).
- The Book's platoon regression constants 1000/2200 PA and 600 switch, and
  pitcher 700/450 BFP (Source 3, reporting The Book).
- FanGraphs' statement that BvP matchup stats are not predictive (Source 2).

**Medium confidence (inference or single-source):**

- "BvP `k` should be >= the platoon `k` (>= ~1000)." This is inference from
  Sources 1/2/3/4, not a published BvP-specific constant.
- The specific placeholder `k_shrink ~ 1000`. Reasonable by analogy; not fitted.

**Gaps / UNVERIFIED:**

- The Book chapter 3's numeric conclusion (regression coefficient / R^2) —
  book not accessible; only the first-page preview is online.
- *Curve Ball*'s treatment of batter-pitcher matchups — book not accessed.
- No source was found that states a BvP stabilization PA directly. The
  reliability claim is supported by (a) the explicit "not predictive" statement
  (Source 2), (b) the platoon constants (Source 3), and (c) the continuous
  reliability findings (Source 4). A project-specific fit on the frozen Retrosheet
  artifact is the correct way to get a real BvP `k`; do not import a number from
  this file as calibrated.
- Web-search engines (DuckDuckGo, Google, Mojeek, Bing) were partially
  bot-blocked; some primary articles may exist that were not surfaced here.

**Concrete next step to close the gap:** before DEC-7 is final, fit `k_shrink`
from the frozen universe-A artifact using the method-of-moments recipe above
(variance components, or split-half reliability inverted through `n/(n+k)`), and
re-verify The Book chapter 3 and Curve Ball's BvP chapter from a physical or
library copy. Record both in the DEC-7 rationale.

---

## DEC-7 implementable recommendation (copy-ready)

- **Estimator.** Credibility/empirical-Bayes blend:
  `posterior = (n·x̄ + k_shrink·m)/(n + k_shrink)`, reliability
  `Z = n/(n + k_shrink)`.
- **Prior `m`.** Odds-ratio expected rate combining the batter's regressed
  overall rate (adjusted to the pitcher's hand) with the pitcher's regressed
  allowed rate (adjusted to the batter's hand); batter platoon component
  regressed toward league using The Book's 1000 PA (LHB) / 2200 PA (RHB)
  constants; pitcher platoon regressed ~700/450 BFP. Reuse `the-tango`
  `expected_woba_matrix` / `odds_ratio_woba` (DEC-2).
- **Window.** Batter and pitcher overall: 3 years, Marcel 5/4/3, PA/IP-weighted,
  regressed to league with ~1200 PA (Source 6). Platoon components: career-to-date
  with the constants above. BvP observed `x̄`: frozen artifact, career vs pitcher,
  current as of the artifact freshness date.
- **k provenance.** `k=20` is unprovenanced and is **not** usable as the shrinkage
  constant. Split it: `k_display = 20` (provisional display/gate), `k_shrink`
  fitted from the artifact; until fitted, use ~1000 PA labeled **uncalibrated**.
  Record the design split in DEC-7 so D1's 19/20/21 boundary tests attach to
  `k_display` and the weight tests to `k_shrink`.
- **Weights shown.** `w_bvp = n/(n + k_shrink)`, `w_prior = k_shrink/(n + k_shrink)`;
  also show `n`, `k_shrink`, `m`, posterior, the underqualified flag when
  `n < k_display`, and the "uncalibrated prior" badge until D5 calibration.
- **Language discipline.** Until a calibration report exists, do not describe
  the prior or `k_shrink` as calibrated; do not describe 20 PA as reliable.
