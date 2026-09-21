"""Universe A and unknown-pitch-count tests (RTP-05, D2).

Offline. Requires pinned raw inputs under `data/raw/` (run `make fetch` first).
"""

import json
import unittest

from scripts import etl

PINNED = {
    "rows": 193767,
    "pa": 186640,
    "universe_a": 186127,
    "unknown": 513,
    "nump_blank": 568,
    "nump_zero": 761,
    "event_files": 30,
    "event_play_records": 216845,
    "event_blank_pitch": 20406,
    "event_blank_np": 20405,
}


class UniverseATest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.summary = etl.build_summary()
        cls.plays = cls.summary["plays_csv"]
        cls.events = cls.summary["events"]

    def test_pinned_counts_match(self):
        self.assertEqual(self.plays["rows"], PINNED["rows"])
        self.assertEqual(self.plays["pa"], PINNED["pa"])
        self.assertEqual(self.summary["universe_a"]["rows"], PINNED["universe_a"])
        self.assertEqual(self.summary["unknown_pitch_count"]["rows"], PINNED["unknown"])
        self.assertEqual(self.events["files"], PINNED["event_files"])
        self.assertEqual(self.events["play_records"], PINNED["event_play_records"])
        self.assertEqual(self.events["blank_pitch"], PINNED["event_blank_pitch"])
        self.assertEqual(self.events["blank_np"], PINNED["event_blank_np"])

    def test_universe_a_and_unknown_partition_the_pa_rows(self):
        self.assertEqual(self.plays["universe_a"] + self.plays["unknown"], self.plays["pa"])
        self.assertEqual(
            self.plays["pa_nump_blank"] + self.plays["pa_nump_zero"], self.plays["unknown"]
        )
        self.assertGreaterEqual(self.plays["nump_blank"], self.plays["pa_nump_blank"])
        self.assertGreaterEqual(self.plays["nump_zero"], self.plays["pa_nump_zero"])

    def test_blank_nump_is_never_counted_as_pitches(self):
        self.assertEqual(self.summary["universe_a"]["rows"], self.plays["pa_nump_positive"])
        self.assertEqual(self.summary["unknown_pitch_count"]["rows"], self.plays["unknown"])
        self.assertEqual(self.plays["nump_blank"], PINNED["nump_blank"])
        self.assertEqual(self.plays["nump_zero"], PINNED["nump_zero"])

    def test_event_blank_pitch_is_overwhelmingly_np(self):
        fraction = round(PINNED["event_blank_np"] / PINNED["event_blank_pitch"], 6)
        self.assertEqual(self.summary["reconciliation"]["event_blank_pitch_np_fraction"], fraction)
        self.assertGreater(self.events["blank_np"] / self.events["blank_pitch"], 0.99)

    def test_all_declared_invariants_hold(self):
        for name, ok in self.summary["invariants"].items():
            self.assertTrue(ok, f"invariant failed: {name}")

    def test_artifact_serialization_is_deterministic(self):
        self.assertEqual(etl.serialize(self.summary), etl.serialize(self.summary))
        self.assertNotIn("generated_at", self.summary)

    def test_round_trip_is_byte_identical(self):
        blob = etl.serialize(self.summary)
        self.assertEqual(json.loads(blob), self.summary)


if __name__ == "__main__":
    unittest.main()
