"""D1b lineup reconstruction tests (RTP-05 remainder, DEC-9).

Offline. Synthetic fixtures cover wrap/sub/NP/unknown; real-data tests require
pinned raw inputs under `data/raw/` (run `make fetch` first).
"""

import json
import unittest
from pathlib import Path

from scripts import etl
from scripts import lineup

REPO = Path(__file__).resolve().parent.parent

# Synthetic game: visitor bats in half 0. Slot 9 batter bats twice across the
# wrap into the next inning; a pinch hitter replaces slot 4 mid-game; an NP
# record repeats the same batter and must not advance the order.
GAME_WRAP_SUB = """
id,SYN20250001
version,2
info,visteam,VIS
info,hometeam,HOM
info,date,2025/04/04
start,v001,"V One",0,1,7
start,v002,"V Two",0,2,5
start,v003,"V Three",0,3,3
start,v004,"V Four",0,4,10
start,v005,"V Five",0,5,8
start,v006,"V Six",0,6,9
start,v007,"V Seven",0,7,2
start,v008,"V Eight",0,8,4
start,v009,"V Nine",0,9,6
start,vpit,"V Pitcher",0,0,1
start,h001,"H One",1,1,7
start,h002,"H Two",1,2,5
start,h003,"H Three",1,3,3
start,h004,"H Four",1,4,10
start,h005,"H Five",1,5,8
start,h006,"H Six",1,6,9
start,h007,"H Seven",1,7,2
start,h008,"H Eight",1,8,4
start,h009,"H Nine",1,9,6
start,hpit,"H Pitcher",1,0,1
play,1,0,v001,01,CX,S8
play,1,0,v002,01,CX,K
play,1,0,v003,01,CX,K
play,1,0,v004,01,CX,K
play,1,0,v005,01,CX,K
play,1,0,v006,01,CX,K
play,1,0,v007,01,CX,K
play,1,0,v008,01,CX,K
play,1,0,v009,01,CX,HR
play,1,0,v001,01,CX,K
play,1,1,h001,01,CX,K
play,1,1,h002,01,CX,K
play,1,1,h003,01,CX,K
sub,vph001,"V Pinch",0,4,10
play,2,0,v002,01,CX,K
play,2,0,v003,01,CX,K
play,2,0,vph001,01,CX,K
play,2,0,v005,01,CX,K
"""

# Same game but v003 never has a start record: reconstruction must fail
# explicitly, not guess.
GAME_MISSING_START = GAME_WRAP_SUB.replace(
    'start,v003,"V Three",0,3,3\n', ""
)

# A slot can be empty in a *reconstructed* game when a player has no start
# record but also never bats (e.g. a listed starter removed before the game
# with no recorded sub). The probe must skip the empty slot instead of
# emitting a guessed batter. h009 is absent from the order and from the plays.
GAME_EMPTY_SLOT = GAME_WRAP_SUB.replace(
    'start,h009,"H Nine",1,9,6\n', ""
) + "play,1,1,h008,01,CX,K\n"


def lines(text):
    return [ln for ln in text.strip().splitlines()]


class SyntheticLineupTest(unittest.TestCase):
    def setUp(self):
        self.wrap = lineup.reconstruct_game(lines(GAME_WRAP_SUB))
        self.missing = lineup.reconstruct_game(lines(GAME_MISSING_START))

    def test_order_wrap_slots_9_to_1(self):
        # After v009 (slot 9) bats, the order wraps to slot 1 = v001. The
        # pitcher (battingOrder 0, DH game) is not part of the order.
        seq = [s for s in self.wrap["samples"] if s["current"] == "v009"][0]
        self.assertEqual(seq["next3"], ["v001", "v002", "v003"])

    def test_np_record_does_not_advance_order(self):
        # v001's second PA follows an NP-free sequence here; construct directly:
        game = lineup.reconstruct_game(
            lines(GAME_WRAP_SUB.replace(
                "play,1,0,v001,01,CX,S8\n",
                "play,1,0,v001,01,CX,S8\nplay,1,0,v001,01,,NP\n",
            ))
        )
        seq = [s for s in game["samples"] if s["current"] == "v001"][0]
        # NP is a non-PA: the next batters after v001 are unchanged.
        self.assertEqual(seq["next3"], ["v002", "v003", "v004"])

    def test_sub_replaces_the_slot(self):
        # After the sub, slot 4 holds vph001; when the order wraps to slot 4
        # the pinch hitter appears as an upcoming batter.
        seq = [s for s in self.wrap["samples"] if s["current"] == "v003" and s["inning"] == 2]
        self.assertEqual(seq[0]["next3"], ["vph001", "v005", "v006"])

    def test_empty_slot_is_skipped_not_guessed(self):
        # h009 has no start record and never bats: slot 9 stays empty, the
        # game still reconstructs, and probing past h008 skips slot 9 to the
        # wrap (slot 1) instead of guessing a batter.
        game = lineup.reconstruct_game(lines(GAME_EMPTY_SLOT))
        self.assertTrue(game["reconstructed"])
        seq = [s for s in game["samples"] if s["current"] == "h008"]
        self.assertEqual(seq[0]["next3"], ["h001", "h002", "h003"])

    def test_missing_start_is_unknown_not_guessed(self):
        self.assertFalse(self.missing["reconstructed"])
        self.assertIn("v003", self.missing["unknown_reason"])
        self.assertEqual(self.missing["samples"], [])
        # The wrap case is reconstructed.
        self.assertTrue(self.wrap["reconstructed"])

    def test_pa_and_np_counts(self):
        self.assertEqual(self.wrap["pa_count"], 17)
        self.assertEqual(self.wrap["np_count"], 0)


class LineupSummaryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.summary = lineup.build_summary()

    def test_counts_present(self):
        for key in ("games_parsed", "orders_reconstructed", "orders_unknown"):
            self.assertIn(key, self.summary["counts"])
        self.assertGreater(self.summary["counts"]["games_parsed"], 0)
        self.assertEqual(
            self.summary["counts"]["orders_reconstructed"]
            + self.summary["counts"]["orders_unknown"],
            self.summary["counts"]["games_parsed"],
        )

    def test_provenance(self):
        self.assertEqual(self.summary["formula_version"], "lineup/1")
        self.assertEqual(self.summary["schema_version"], 1)
        self.assertIn("source_manifest_sha256", self.summary)
        self.assertIn("license", self.summary)
        self.assertIn("purpose", self.summary)
        self.assertIn("unknown_pitch_count_gate", self.summary)
        self.assertIn("NP", self.summary["unknown_pitch_count_gate"])

    def test_sample_of_next3_sequences(self):
        samples = self.summary["samples"]
        self.assertGreater(len(samples), 0)
        for seq in samples:
            self.assertEqual(len(seq["next3"]), 3)

    def test_byte_identical_regeneration(self):
        blob = lineup.serialize(self.summary)
        self.assertEqual(json.loads(blob), self.summary)
        again = lineup.serialize(lineup.build_summary())
        self.assertEqual(blob, again)

    def test_universe_summary_unaffected(self):
        # etl.build_summary must not include lineup fields: existing artifact
        # stays byte-identical.
        self.assertNotIn("lineup", etl.build_summary())


class EtlIntegrationTest(unittest.TestCase):
    """make data must emit data/derived/lineup_summary.json."""

    def test_cmd_build_writes_lineup_artifact(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "universe_a_summary.json"
            rc = etl.main(["build", "--offline", "--artifact", str(out)])
            self.assertEqual(rc, 0)
            self.assertTrue(out.exists())
            self.assertTrue((REPO / "data" / "derived" / "lineup_summary.json").exists())


if __name__ == "__main__":
    unittest.main()
