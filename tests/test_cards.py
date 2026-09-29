"""Hook-card artifact tests (RTP-08, D1/D1b/D2).

Offline. Synthetic fixtures only: exact key sets, outer/state metric
equality, count/sample equality, unknown preservation, id format, and
deterministic serialization. No pinned raw input required.
"""

import json
import unittest

from scripts import cards


def make_card(**overrides):
    params = {
        "game_id": "SYN20250001",
        "pa_index": 7,
        "inning": 7,
        "outs": 1,
        "runners_on": 2,
        "score_diff": -1,
        "pitch_count": 84,
        "bullpen_state": "available",
        "leverage_index": 2.4,
        "bvp_n": 20,
        "bvp_xbar": 0.400,
        "bvp_m": 0.320,
        "upcoming": [(18, 0.312), (7, 0.25), (None, None)],
    }
    params.update(overrides)
    return cards.build_card(**params)


SOURCES = [{"id": "synthetic", "sha256": "0" * 64}]


class TestCardShape(unittest.TestCase):
    def test_exact_outer_and_state_keys(self):
        card = make_card()
        self.assertEqual(tuple(sorted(card)), tuple(sorted(cards.CARD_KEYS)))
        self.assertEqual(tuple(sorted(card["judgment_state"])), tuple(sorted(cards.STATE_KEYS)))

    def test_id_format_is_hook_game_pa(self):
        card = make_card(game_id="SYN20250001", pa_index=7)
        self.assertEqual(card["id"], "hook:SYN20250001:7")

    def test_no_identity_or_oracle_field_anywhere(self):
        blob = json.dumps(make_card())
        for forbidden in ("player", "batter_name", "team", "outcome", "oracle", "result"):
            self.assertNotIn(forbidden, blob)


class TestInvariants(unittest.TestCase):
    def test_outer_metrics_equal_state_metrics(self):
        card = make_card()
        state = card["judgment_state"]
        self.assertAlmostEqual(state["w_bvp"] + state["w_prior"], 1.0, places=12)
        self.assertAlmostEqual(state["prior_rate"], card["bvp"]["m"], places=12)
        self.assertAlmostEqual(card["bvp"]["posterior"], 328 / 1020, places=12)

    def test_counts_equal_sample_values(self):
        card = make_card()
        self.assertEqual(card["samples"]["bvp_n"], card["bvp"]["n"])
        self.assertEqual(card["samples"]["bvp_n"], 20)
        self.assertEqual(
            card["samples"]["upcoming_n"],
            [slot["n"] for slot in card["judgment_state"]["upcoming"]],
        )

    def test_underqualified_flag_at_display_boundary(self):
        self.assertTrue(make_card(bvp_n=19)["bvp"]["underqualified"])
        self.assertFalse(make_card(bvp_n=20)["bvp"]["underqualified"])
        # The flag never changes the blend.
        self.assertAlmostEqual(
            make_card(bvp_n=19)["bvp"]["posterior"],
            (19 * 0.4 + 1000 * 0.32) / 1019,
            places=12,
        )

    def test_unknown_pitch_count_is_null_never_zero(self):
        card = make_card(pitch_count=None)
        self.assertIsNone(card["judgment_state"]["pitch_count"])

    def test_synthetic_defaults_true(self):
        self.assertTrue(make_card()["synthetic"])


class TestRejection(unittest.TestCase):
    def test_rejects_bad_situation_and_state(self):
        for overrides in [
            {"outs": 3},
            {"inning": 0},
            {"bullpen_state": "fine"},
            {"pitch_count": 0},
            {"upcoming": [(1, 0.3), (2, 0.3)]},
            {"upcoming": [(1, 0.3), (2, 0.3), (3, 0.3), (4, 0.3)]},
            {"upcoming": [(-1, 0.3), (2, 0.3), (3, 0.3)]},
            {"bvp_m": 1.5},
            {"game_id": "  "},
        ]:
            with self.assertRaises(ValueError, msg=str(overrides)):
                make_card(**overrides)


class TestArtifact(unittest.TestCase):
    def test_provenance_and_deterministic_order(self):
        first = cards.build_artifact([make_card(pa_index=9), make_card(pa_index=7)],
                                     sources=SOURCES, synthetic=True)
        second = cards.build_artifact([make_card(pa_index=7), make_card(pa_index=9)],
                                      sources=SOURCES, synthetic=True)
        self.assertEqual(cards.serialize(first), cards.serialize(second))
        self.assertEqual([card["id"] for card in first["cards"]],
                         ["hook:SYN20250001:7", "hook:SYN20250001:9"])
        self.assertEqual(first["formula_version"], "hook-card/1")
        self.assertEqual(first["provenance"]["k_display"], 20)
        self.assertEqual(first["provenance"]["n_upcoming"], 3)

    def test_synthetic_disagreement_refused(self):
        with self.assertRaises(ValueError):
            cards.build_artifact([make_card(synthetic=False)], sources=SOURCES, synthetic=True)

    def test_source_shape_enforced(self):
        with self.assertRaises(ValueError):
            cards.build_artifact([make_card()], sources=[{"id": "x"}], synthetic=True)


if __name__ == "__main__":
    unittest.main()
