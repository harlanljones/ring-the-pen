"""RE24 / leverage / wOBA->WPA bridge ETL tests (RTP-07, DEC-2).

Offline. Tests for the derived re24_leverage artifact: the 24 base-out run
expectancy states must reproduce the pinned 2025_RE24_Values.csv table, and
every bridge constant must carry its provenance label (CALIBRATED / PRD_DEFAULT
/ GUESS) matching the-tango's params.py convention (DEC-2 Option A).

Real-data tests require the pinned input under data/raw/ (make fetch first).
"""

import json
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

from scripts import re24


class TestParseRE24(unittest.TestCase):
    """The 8 source rows x 3 out columns = 24 base-out states."""

    @classmethod
    def setUpClass(cls):
        cls.csv_path = REPO / "data" / "raw" / "2025_RE24_Values.csv"
        if not cls.csv_path.exists():
            raise unittest.SkipTest("pinned input missing; run make fetch")
        cls.states = re24.parse_re24(cls.csv_path)

    def test_exactly_24_states(self):
        self.assertEqual(len(self.states), 24)

    def test_empty_bases_zero_outs_matches_source(self):
        state = self.states[("-- -- --", 0)]
        self.assertAlmostEqual(state["run_expectancy"], 0.500445544719696, places=12)

    def test_bases_loaded_two_outs_matches_source(self):
        state = self.states[("1B 2B 3B", 2)]
        self.assertAlmostEqual(state["run_expectancy"], 0.7471064925193787, places=12)

    def test_all_states_reproduce_source_values(self):
        import csv

        with self.csv_path.open(newline="") as handle:
            for row in csv.DictReader(handle):
                runners = row["runners"]
                for col, outs in (("0_outs", 0), ("1_out", 1), ("2_outs", 2)):
                    expected = float(row[col])
                    self.assertAlmostEqual(
                        self.states[(runners, outs)]["run_expectancy"], expected, places=12
                    )

    def test_run_expectancy_nonincreasing_in_outs(self):
        runners_keys = {runners for runners, _ in self.states}
        for runners in runners_keys:
            re0 = self.states[(runners, 0)]["run_expectancy"]
            re1 = self.states[(runners, 1)]["run_expectancy"]
            re2 = self.states[(runners, 2)]["run_expectancy"]
            self.assertGreaterEqual(re0, re1, runners)
            self.assertGreaterEqual(re1, re2, runners)


@unittest.skipIf(re24 is None, "scripts.re24 not implemented yet")
class TestBridgeConstants(unittest.TestCase):
    """Every constant is provenance-labeled per DEC-2; no unlabeled constant."""

    @classmethod
    def setUpClass(cls):
        cls.csv_path = REPO / "data" / "raw" / "2025_RE24_Values.csv"
        cls.constants = re24.bridge_constants()

    def test_every_constant_has_allowed_provenance(self):
        for name, const in self.constants.items():
            self.assertIn(const["provenance"], ("CALIBRATED", "PRD_DEFAULT", "GUESS"), name)
            self.assertTrue(str(const["source"]).strip(), name)

    def test_woba_to_wpa_critical_matches_tango_convention(self):
        # the-tango params.WOBA_TO_WPA_CRITICAL = 0.55, GUESS, pinned at pLI=3.0.
        const = self.constants["woba_to_wpa_critical"]
        self.assertEqual(const["value"], 0.55)
        self.assertEqual(const["provenance"], "GUESS")

    def test_li_critical_reference_is_3(self):
        const = self.constants["li_critical_reference"]
        self.assertEqual(const["value"], 3.0)

    def test_bridge_math_matches_the_tango(self):
        # woba_delta_to_wpa: wpa = woba_delta * critical * (li / 3.0).
        # 0.022 wOBA at li=3.0 -> 0.0121 WPA, inside the PRD 0.010..0.014 band.
        wpa = re24.woba_delta_to_wpa(-0.022, 3.0)
        self.assertAlmostEqual(wpa, -0.0121, places=10)
        self.assertTrue(0.010 <= abs(wpa) <= 0.014)

    def test_bridge_scales_linearly_in_li(self):
        self.assertAlmostEqual(
            re24.woba_delta_to_wpa(-0.022, 1.5) * 2.0,
            re24.woba_delta_to_wpa(-0.022, 3.0),
            places=12,
        )


if __name__ == "__main__":
    unittest.main()
