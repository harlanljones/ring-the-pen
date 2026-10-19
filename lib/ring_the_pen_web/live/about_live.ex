defmodule RingThePenWeb.AboutLive do
  @moduledoc "Product, formula, provenance, and license notes for Ring The Pen."
  use RingThePenWeb, :live_view

  alias RingThePen.{Lock, Shrink}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "About Ring The Pen",
       thresholds: Lock.thresholds(),
       k_display: Shrink.k_display(),
       k_shrink_placeholder: Shrink.k_shrink_placeholder()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main id="main-content">
      <header class="panel">
        <p class="eyebrow">About · Phase H historical workbench</p>
        <h1>About Ring The Pen</h1>
        <p>
          Ring The Pen is an in-plate-appearance pitcher-removal decision workbench.
          Code assembles a hook card from precomputed state, TypeSafe Jev returns typed
          Choice, Score, and Noul answers about that state, and a confidence lock routes
          the result. Math is computed in code; Jev does not calculate rates or counts.
        </p>
      </header>

      <section class="panel" aria-labelledby="formula-heading">
        <p class="eyebrow">Versioned formulas</p>
        <h2 id="formula-heading">What goes into a hook card</h2>
        <p>
          <code>hook-card/1</code> identifies the versioned card format. Its inputs are
          assembled from precomputed values; it does not mean Jev derives or verifies
          those values.
        </p>
        <dl>
          <dt>Batter versus pitcher credibility blend · <code>bvp-shrink/1</code></dt>
          <dd>
            <code>posterior = (n × x̄ + k_shrink × m) / (n + k_shrink)</code>.
            Here <code>n</code> and <code>x̄</code> mean career-to-date plate appearances
            and rate against that pitcher, current through the artifact freshness date.
            The intended prior method defines <code>m</code> as an odds-ratio expected
            matchup rate: combine batter and pitcher overall rates, each adjusted for
            the opponent's hand, with a 3-year Marcel 5/4/3 window. The platoon rates
            are career-to-date.
          </dd>
          <dd>
            This describes the intended prior method, not a verified current input.
            The code accepts <code>m</code> as a supplied per-pair value; real prior
            extraction and pair wiring are pending, so this checkout has no verified
            real prior or frozen card embodying this method.
          </dd>
          <dt>Credibility weights</dt>
          <dd>
            <code>w_bvp = n / (n + k_shrink)</code>
            and <code>w_prior = k_shrink / (n + k_shrink)</code>. They sum to one and are
            shown with the card's prior and sample information.
          </dd>
          <dt>Run expectancy and leverage · <code>re24-leverage/1</code></dt>
          <dd>
            The RE24 table supplies expected runs for the base-out state. The wOBA to
            win-probability bridge is <code>ΔWPA = ΔwOBA × woba_to_wpa_critical × (leverage_index / li_critical_reference)</code>.
            Its bridge constants retain their source and calibration labels in the
            derived artifact.
          </dd>
        </dl>
        <div
          class="metrics-grid"
          aria-label="Provisional display gate and uncalibrated shrink placeholder"
        >
          <div>
            <p class="eyebrow">Display gate · provisional</p>
            <p><strong>k_display = {@k_display}</strong></p>
            <p>Below this BvP sample size, the card is marked underqualified.</p>
          </div>
          <div>
            <p class="eyebrow">Shrink prior strength</p>
            <p><strong>k_shrink ≈ {@k_shrink_placeholder} PA</strong></p>
            <p>This is an uncalibrated placeholder until the value is fitted.</p>
          </div>
          <div>
            <p class="eyebrow">Upcoming batters</p>
            <p><strong>N = 3</strong></p>
            <p>The next three batters are reconstructed in code.</p>
          </div>
        </div>
        <p>
          <code>k_display</code> is only the underqualified display gate; it is not the
          blend strength. Shrinkage applies continuously using <code>k_shrink</code>.
          The prior and shrink placeholder remain uncalibrated.
        </p>
      </section>

      <section class="panel" aria-labelledby="lock-heading">
        <p class="eyebrow">Confidence lock · all thresholds provisional</p>
        <h2 id="lock-heading">How a card is routed</h2>
        <p>
          Choice (<code>pull_decision</code>) and Score (<code>hook_urgency</code>) are
          the primary drivers. The lock uses the worse of their routes.
        </p>
        <dl>
          <dt>Choice and Score</dt>
          <dd>
            Confidence ≥ {@thresholds.choice_act} routes to act; confidence ≥ {@thresholds.choice_review} routes to review; lower confidence escalates.
            Choice <code>other</code> always escalates.
          </dd>
          <dt>Noul · secondary only</dt>
          <dd>
            A Noul routes to act when <code>max(p, 1 − p)</code>
            ≥ {@thresholds.noul_act}; otherwise it routes to review. It can reduce a
            primary act route to review, but it cannot escalate the card on its own.
          </dd>
          <dt>Sample and code gates</dt>
          <dd>
            An underqualified sample cannot act. Deterministic code gates for a known
            pitch cap, an injured pitcher, or an empty bullpen override judgment and
            force escalation. An unknown pitch count remains unknown; it is never
            treated as zero.
          </dd>
        </dl>
        <p>
          These thresholds are provisional. The model and prior are uncalibrated, and
          there is no accuracy or calibration claim before a real evaluation report.
        </p>
      </section>

      <section class="panel" aria-labelledby="provenance-heading">
        <p class="eyebrow">Data provenance</p>
        <h2 id="provenance-heading">Pinned sources and current limits</h2>
        <p>
          The source manifest records identifiers, source SHA-256 digests, and row counts for
          the pinned Retrosheet inputs. A manifest digest is a verification target; it
          does not show that raw source bytes have been checked in this checkout. The
          real hook-card artifact is not loaded here, and no raw inputs, cards, or real
          Jev recordings are presented as verified by this page. Each derived artifact
          must carry its formula version and source provenance.
        </p>
        <p>
          For historical cards, the 2025 play-by-play CSV is the authority for plate
          appearances and pitch counts. A plate appearance with blank or zero pitch
          count is unknown, not zero pitches. Event files supply historical lineup
          reconstruction, including substitutions and the next three batters. The
          pinned 2025 RE24 table supplies the run-expectancy states. Missing bullpen
          availability or lineup data stays explicitly unknown.
        </p>
      </section>

      <section class="panel" aria-labelledby="retrosheet-heading">
        <p class="eyebrow">Required attribution</p>
        <h2 id="retrosheet-heading">Retrosheet</h2>
        <blockquote>
          <p>
            The information used here was obtained free of charge from and is
            copyrighted by Retrosheet. Interested parties may contact Retrosheet at
            20 Sunset Rd., Newark, DE 19711.
          </p>
        </blockquote>
        <p>
          Retrosheet data is historical and delayed. It is never served or described as
          live. Raw Retrosheet bulk inputs are not redistributed here; only small
          derived artifacts with provenance are committed.
        </p>
      </section>

      <section class="panel" aria-labelledby="phases-heading">
        <p class="eyebrow">Availability and license</p>
        <h2 id="phases-heading">Historical now; live phases have limits</h2>
        <dl>
          <dt>Phase H · historical</dt>
          <dd>
            Retrosheet-backed historical work is delayed. Retrosheet is not a live
            feed, and no public live service is available from this checkout.
          </dd>
          <dt>Phase L · future private use</dt>
          <dd>
            Any Stats API use is limited to individual, non-commercial, non-bulk use:
            one private, single-user/password setup with polite polling and no bulk
            archive retention or redistribution.
          </dd>
          <dt>Phase P · public live</dt>
          <dd>
            Public live service is blocked until D6 clears in writing through MLBAM
            written authorization or a licensed feed, or the product is explicitly demoted to
            sim-live with delayed box or end-of-inning data and a stated staleness
            bound. No public-live service or release is claimed here.
          </dd>
        </dl>
      </section>

      <section class="panel" aria-labelledby="latency-heading">
        <p class="eyebrow">Latency and evaluation</p>
        <h2 id="latency-heading">What “instant” means</h2>
        <p>
          “Instant” means the page can update without a full page reload after new state
          arrives. It does not mean a decision arrives at pitch release. D7 latency
          instrumentation for feed delay, state building, Jev response, and UI paint is
          pending; no timing value is claimed.
        </p>
        <p>
          A real evaluation report is also pending. Until it exists, the model, prior,
          and lock thresholds remain uncalibrated or provisional, with no accuracy
          claim.
        </p>
      </section>
    </main>
    """
  end
end
