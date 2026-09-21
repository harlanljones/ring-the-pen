# Recorded Jev responses — immutable

This directory holds **real recorded model responses** captured by
`mix ring.record --state FILE` with `TYPESAFE_API_KEY` set. Each record
carries `source_lineage.kind = "recorded"`, the state hash, the frozen
questions hash, the raw wire response, and the serialized typed answers.

Recordings are immutable: the recording task refuses to overwrite an
existing file. Hand-authored test fixtures do **not** live here — they are
in `priv/jev/fixtures/synthetic/` and are labeled `SYNTHETIC`.

Status: empty as of RTP-10 — no `TYPESAFE_API_KEY` was available in this
environment, so no real recordings exist yet. Run `mix ring.record` with a
key to populate this directory.
