"""Artifact-level tests for the RE24/leverage/bridge ETL (RTP-07).

Offline. Real-data tests require the pinned input under data/raw/.
"""

import json
import subprocess
import sys
import unittest
from pathlib import Path

from scripts import re24

REPO = Path(__file__).resolve().parent.parent
SCRATCH = Path(__file__).resolve().parent / "__re24_tmp__"


class TestBuildArtifact(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not (REPO / "data" / "raw" / "2025_RE24_Values.csv").exists():
            raise unittest.SkipTest("pinned input missing; run make fetch")
        cls.artifact_path = SCRATCH / "re24_leverage.json"
        cls.artifact = re24.build_artifact(artifact_path=cls.artifact_path)

    def test_artifact_written_and_valid_json(self):
        loaded = json.loads(self.artifact_path.read_text())
        self.assertEqual(loaded, self.artifact)

    def test_24_states_in_artifact(self):
        self.assertEqual(len(self.artifact["re24_states"]), 24)

    def test_states_reproduce_source_table(self):
        first = self.artifact["re24_states"][0]
        self.assertEqual(first["runners"], "-- -- --")
        self.assertEqual(first["outs"], 0)
        self.assertAlmostEqual(first["run_expectancy"], 0.500445544719696, places=12)

    def test_every_constant_labeled_in_artifact(self):
        constants = self.artifact["constants"]
        self.assertGreater(len(constants), 0)
        for name, const in constants.items():
            self.assertIn(const["provenance"], ("CALIBRATED", "PRD_DEFAULT", "GUESS"), name)
            self.assertTrue(str(const["source"]).strip(), name)

    def test_source_provenance_records_pin_and_digest(self):
        source = self.artifact["source"]
        self.assertEqual(source["manifest_id"], "retrosheet-2025-re24")
        self.assertEqual(source["sha256"], re24.sha256_file(REPO / "data" / "raw" / "2025_RE24_Values.csv"))
        self.assertEqual(source["rows"], 8)

    def test_bridge_convention_cited(self):
        convention = self.artifact["bridge_convention"]
        self.assertIn("the-tango", convention["provenance"])

    def test_deterministic_byte_identical_regeneration(self):
        first = self.artifact_path.read_bytes()
        re24.build_artifact(artifact_path=self.artifact_path)
        self.assertEqual(first, self.artifact_path.read_bytes())

    def test_fail_closed_on_digest_mismatch(self):
        # A manifest pointing at a wrong digest must abort, never emit numbers.
        import tempfile

        manifest = json.loads((REPO / "data" / "manifest.json").read_text())
        for item in manifest["inputs"]:
            if item["id"] == "retrosheet-2025-re24":
                item["sha256"] = "0" * 64
                break
        with tempfile.TemporaryDirectory() as tmp:
            bad_manifest = Path(tmp) / "manifest.json"
            bad_manifest.write_text(json.dumps(manifest))
            with self.assertRaises(ValueError):
                re24.build_artifact(manifest_path=bad_manifest, artifact_path=Path(tmp) / "out.json")


class TestEtlBuildWiring(unittest.TestCase):
    """make data (scripts/etl.py build) regenerates the re24 artifact."""

    @classmethod
    def setUpClass(cls):
        if not (REPO / "data" / "raw" / "2025_RE24_Values.csv").exists():
            raise unittest.SkipTest("pinned input missing; run make fetch")

    def test_etl_build_produces_re24_artifact(self):
        result = subprocess.run(
            [sys.executable, str(REPO / "scripts" / "etl.py"), "build", "--offline"],
            capture_output=True,
            text=True,
            cwd=REPO,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        artifact = json.loads((REPO / "data" / "derived" / "re24_leverage.json").read_text())
        self.assertEqual(len(artifact["re24_states"]), 24)
        for const in artifact["constants"].values():
            self.assertIn(const["provenance"], ("CALIBRATED", "PRD_DEFAULT", "GUESS"))


if __name__ == "__main__":
    unittest.main()
