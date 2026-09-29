"""BvP + shrink tests (RTP-06, DEC-7).

Offline. Synthetic fixtures only: hand-computed credibility blends, the
k_display 19/20/21 boundary, weight-sum, variance-components k fitting, and
the derived artifact shape. No pinned raw input required.
"""

import json
import unittest

from scripts import bvp


class TestBlend(unittest.TestCase):
    def test_zero_sample_returns_prior(self):
        self.assertAlmostEqual(bvp.blend(0, 0.0, 0.320, 1000), 0.320, places=12)

    def test_hand_computed_blend_with_placeholder_k(self):
        # (20*0.400 + 1000*0.320) / 1020 = 328/1020.
        self.assertAlmostEqual(bvp.blend(20, 0.400, 0.320, 1000), 328 / 1020, places=12)

    def test_k_display_20_as_blend_constant_overweights(self):
        # (20*0.400 + 20*0.320) / 40 = 0.36: a 20-PA sample gets 50% weight.
        # This is why DEC-7 forbids 20 as the blend constant (guard test: the
        # formula is continuous, the split is policy, verified below).
        self.assertAlmostEqual(bvp.blend(20, 0.400, 0.320, 20), 0.36, places=12)

    def test_blend_is_monotone_in_sample(self):
        low = bvp.blend(5, 0.400, 0.320, 1000)
        high = bvp.blend(100, 0.400, 0.320, 1000)
        self.assertLess(low, high)
        self.assertLess(high, 0.400)

    def test_rejects_unknown_or_invalid_inputs(self):
        for args in [
            (-1, 0.4, 0.32, 1000),
            (20, None, 0.32, 1000),
            (20, 1.5, 0.32, 1000),
            (20, 0.4, -0.1, 1000),
            (20, 0.4, 0.32, 0),
            (20, 0.4, 0.32, -5),
            (20, 0.4, 0.32, None),
        ]:
            with self.assertRaises(ValueError, msg=str(args)):
                bvp.blend(*args)


class TestWeights(unittest.TestCase):
    def test_weights_sum_to_one(self):
        for n in (0, 1, 19, 20, 21, 100, 2000):
            w_bvp, w_prior = bvp.weights(n, 1000)
            self.assertAlmostEqual(w_bvp + w_prior, 1.0, places=12, msg=f"n={n}")

    def test_hand_computed_weights(self):
        w_bvp, w_prior = bvp.weights(20, 1000)
        self.assertAlmostEqual(w_bvp, 20 / 1020, places=12)
        self.assertAlmostEqual(w_prior, 1000 / 1020, places=12)

    def test_zero_sample_carries_zero_bvp_weight(self):
        w_bvp, w_prior = bvp.weights(0, 1000)
        self.assertEqual(w_bvp, 0.0)
        self.assertEqual(w_prior, 1.0)


class TestDisplayGate(unittest.TestCase):
    def test_pa_vs_19_20_21_boundary(self):
        self.assertTrue(bvp.underqualified(19))
        self.assertFalse(bvp.underqualified(20))
        self.assertFalse(bvp.underqualified(21))

    def test_gate_is_a_flag_not_shrinkage(self):
        # The gate never changes the posterior: same blend on both sides.
        self.assertAlmostEqual(
            bvp.blend(19, 0.4, 0.32, 1000), (19 * 0.4 + 1000 * 0.32) / 1019, places=12
        )
        self.assertAlmostEqual(
            bvp.blend(21, 0.4, 0.32, 1000), (21 * 0.4 + 1000 * 0.32) / 1021, places=12
        )


class TestConstants(unittest.TestCase):
    def test_k_display_is_20_provisional(self):
        self.assertEqual(bvp.K_DISPLAY, 20)
        const = bvp.CONSTANTS["k_display"]
        self.assertEqual(const["value"], 20)
        self.assertEqual(const["status"], "provisional")

    def test_k_shrink_placeholder_is_1000_uncalibrated(self):
        self.assertEqual(bvp.K_SHRINK_PLACEHOLDER, 1000)
        const = bvp.CONSTANTS["k_shrink"]
        self.assertEqual(const["value"], 1000)
        self.assertEqual(const["provenance"], "GUESS")
        self.assertEqual(const["status"], "uncalibrated")


class TestFitKShrink(unittest.TestCase):
    def test_recovers_k_from_spread_pair_table(self):
        # Ten pairs at 0.2 and ten at 0.4, n=200 each: observed variance 0.01,
        # EPV ~ 0.21, sampling ~0.00105, so k lands in the tens.
        pairs = [(200, 0.2)] * 10 + [(200, 0.4)] * 10
        fit = bvp.fit_k_shrink(pairs)
        self.assertIsNotNone(fit)
        self.assertGreater(fit["k"], 10)
        self.assertLess(fit["k"], 50)

    def test_returns_none_when_spread_is_sampling_noise(self):
        self.assertIsNone(bvp.fit_k_shrink([(50, 0.3)] * 8))

    def test_needs_at_least_two_nonempty_pairs(self):
        with self.assertRaises(ValueError):
            bvp.fit_k_shrink([(0, 0.0)])
        with self.assertRaises(ValueError):
            bvp.fit_k_shrink([(10, 0.3)])


class TestArtifact(unittest.TestCase):
    PAIRS = [
        {"pair_id": "batter-b:pitcher-p", "n": 20, "xbar": 0.400, "m": 0.320},
        {"pair_id": "batter-a:pitcher-p", "n": 0, "xbar": 0.0, "m": 0.310},
    ]

    def test_rows_carry_posterior_weights_flag_and_badge(self):
        artifact = bvp.build_artifact(self.PAIRS)
        self.assertEqual(artifact["formula_version"], "bvp-shrink/1")
        rows = {row["pair_id"]: row for row in artifact["pairs"]}
        row = rows["batter-b:pitcher-p"]
        self.assertAlmostEqual(row["posterior"], 328 / 1020, places=12)
        self.assertAlmostEqual(row["w_bvp"] + row["w_prior"], 1.0, places=12)
        self.assertFalse(row["underqualified"])
        self.assertTrue(row["uncalibrated"])
        zero = rows["batter-a:pitcher-p"]
        self.assertAlmostEqual(zero["posterior"], 0.310, places=12)
        self.assertTrue(zero["underqualified"])

    def test_artifact_serializes_deterministically(self):
        first = bvp.serialize(bvp.build_artifact(self.PAIRS))
        second = bvp.serialize(bvp.build_artifact(list(reversed(self.PAIRS))))
        self.assertEqual(first, second)
        parsed = json.loads(first)
        self.assertEqual(parsed["constants"]["k_display"]["value"], 20)
        self.assertEqual(parsed["constants"]["k_shrink"]["status"], "uncalibrated")


if __name__ == "__main__":
    unittest.main()
