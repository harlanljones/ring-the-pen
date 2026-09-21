# SYNTHETIC fixtures — NOT recorded model responses

Every file in this directory is a **hand-authored synthetic test input**. No
model produced any of these judgments; they were constructed locally to
satisfy the frozen validation rules in `RingThePen.Judgments` so offline
replay can be exercised without `TYPESAFE_API_KEY`.

- `states/*.json` — synthetic judgment states (inputs).
- `synthetic--*.json` — synthetic judgment records built from those states.
  Each carries `source_lineage.kind = "synthetic"` and a `note` saying so.

Recorded real Jev responses live in `priv/jev/recordings/` and carry
`source_lineage.kind = "recorded"` only. Nothing in this directory may be
presented as a recording, and `mix ring.record` never writes here.
