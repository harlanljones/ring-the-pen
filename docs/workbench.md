# Historical workbench

The Phase H workbench is available at `/`; a selected card uses `/cards/:id`.
`/about` publishes the formulas, provisional thresholds, attribution, and phase
limits. Card selection updates through LiveView without a full page reload.

## Inputs and server configuration

By default, the workbench looks for `priv/data/hook_cards.json` and saved JSON
judgments in `priv/jev/recordings`. Missing inputs show an unavailable state;
they are never replaced with sample data. This checkout still lacks genuine
historical hook cards and real Jev recordings.

Paths can be configured on the server before starting the application:

```elixir
config :ring_the_pen, :workbench,
  catalog_path: "/srv/ring-the-pen/hook_cards.json",
  recordings_dir: "/srv/ring-the-pen/recordings",
  allow_synthetic: false
```

Browser parameters select a card id, not a file path. Synthetic catalogs are
disabled by default. Explicit `allow_synthetic: true` is honored only in a
development/test build, and the UI prominently labels the data synthetic.

## Trust and unavailable states

`RingThePen.Workbench.open/1` validates the whole catalog, finds a saved judgment
by the selected card's state hash, validates it against the frozen state and
question pack, checks synthetic/recorded lineage, and runs the confidence lock.
Only a successful complete path exposes card metrics and a verdict. Missing,
invalid, or ambiguous judgments show an unavailable state; changing selection
or reloading after an error clears the previous verdict. Validation and replay
make no Jev or feed request.

The frozen `hook-card/1` schema does not carry player names, pitch cap, injury,
or empty-pen inputs. These remain explicitly Unknown. Known pitch count reaches
the code gates; bullpen availability is never treated as proof of an empty pen.
Prior/model values remain uncalibrated, and confidence/display thresholds remain
provisional. Source digests still require the ETL's separate byte verification.

All Choice/Score probabilities, binary Noul probabilities, confidence values,
and the hash/model/time audit are visible on a validated card. Review/escalate
show no single primary recommendation. Real-card/recording replay, D7 latency,
evaluation, and all live phases remain separate pending work.
