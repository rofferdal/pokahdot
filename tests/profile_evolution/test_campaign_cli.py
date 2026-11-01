"""Campaign command integration without actual poker or ignored input files."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tests.profile_evolution.test_campaign import _prepared_campaign
from tests.profile_evolution.test_campaign_confirmation import _confirmation_fixture
from tools.profile_evolution.artifacts import canonical_json_bytes, load_artifact
from tools.profile_evolution.campaign import freeze_candidates
from tools.profile_evolution.campaign_generation import generate_candidates
from tools.profile_evolution.campaign_confirmation import validate_nine_player_confirmation

ROOT = Path(__file__).resolve().parents[2]


class CampaignCliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        prepared = _prepared_campaign()
        campaign = freeze_candidates(prepared, generate_candidates(prepared))
        self.campaign = self.folder / "campaign.json"
        self.campaign.write_bytes(canonical_json_bytes(campaign))

    def command(self, *arguments: str) -> subprocess.CompletedProcess:
        return subprocess.run([sys.executable, "-B", str(ROOT / "tools/roster-campaign"), *arguments],
                              cwd=ROOT, capture_output=True, text=True, check=False)

    def prepare_round_one(self) -> Path:
        output = self.folder / "round_one"
        result = self.command("prepare-round", "--campaign", str(self.campaign), "--output-dir", str(output))
        self.assertEqual(0, result.returncode, result.stderr)
        return output

    def test_round_one_emits_one_competitive_manifest_with_user_pattern(self) -> None:
        output = self.prepare_round_one()
        self.assertEqual({"manifest.json", "fairness.json"}, {p.name for p in output.iterdir()})
        manifest = json.loads((output / "manifest.json").read_text())
        ids = [p["profile_id"] for p in manifest["profiles"]]
        self.assertEqual([ids[i] for i in (0, 1, 4, 6, 11, 17, 23, 31, 32)], manifest["matchups"][0]["profile_ids"])
        self.assertEqual(35, len(manifest["matchups"]))
        self.assertFalse((self.folder / "round_two").exists())

    def test_actual_round_two_requires_verified_round_one_results(self) -> None:
        output = self.folder / "round_two"
        result = self.command("prepare-round", "--campaign", str(self.campaign), "--round", "2", "--output-dir", str(output))
        self.assertEqual(2, result.returncode, result.stderr)
        self.assertEqual("round_one_result_required", json.loads(result.stderr)["error"]["code"])
        self.assertFalse(output.exists())
        fake = self.folder / "fake_survivors.json"
        fake.write_text(json.dumps({"survivor_ids": ["invented"] * 25}))
        result = self.command("prepare-round", "--campaign", str(self.campaign), "--round", "2",
                              "--previous-result", str(fake), "--output-dir", str(output))
        self.assertEqual(2, result.returncode, result.stderr)
        self.assertFalse(output.exists())

    def test_unapproved_manifest_cannot_launch_or_create_run_outputs(self) -> None:
        prepared = self.prepare_round_one()
        certificate = json.loads((prepared / "fairness.json").read_text())
        approval = self.folder / "approval.json"
        approval.write_text(json.dumps({"approved": False, "manifest_checksum": certificate["manifest_checksum"]}))
        output = self.folder / "execution"
        result = self.command("run-round", "--manifest", str(prepared / "manifest.json"),
                              "--approval", str(approval), "--godot", "must-not-launch",
                              "--output-dir", str(output))
        self.assertEqual(2, result.returncode, result.stderr)
        self.assertEqual("campaign_approval_required", json.loads(result.stderr)["error"]["code"])
        self.assertFalse(output.exists())

    def test_confirm_cli_reports_nested_eligibility_after_successful_publication(self) -> None:
        for wins in (True, False):
            with self.subTest(promotion_eligible=wins):
                reports = self.folder / ("eligible_reports" if wins else "ineligible_reports")
                reports.mkdir()
                campaign, candidate_id, paths, _ = _confirmation_fixture(reports, candidate_wins=wins)
                self.campaign.write_bytes(canonical_json_bytes(campaign))
                output = reports / "confirmation.json"
                result = self.command("confirm", "--campaign", str(self.campaign),
                                      "--candidate-id", candidate_id,
                                      "--report-a", str(paths["a"]), "--report-b", str(paths["b"]),
                                      "--output", str(output))
                self.assertTrue(output.is_file(), result.stderr)
                artifact = load_artifact(output, "nine_player_confirmation_v1")
                confirmation = validate_nine_player_confirmation(artifact)
                self.assertEqual(wins, confirmation["promotion_eligible"])
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual("", result.stderr)
                summary = json.loads(result.stdout)
                self.assertEqual(str(output), summary["confirmation"])
                self.assertEqual(artifact["checksum"], summary["checksum"])
                self.assertEqual(confirmation["promotion_eligible"], summary["promotion_eligible"])

    def test_preparation_does_not_overwrite_a_manifest_under_review(self) -> None:
        output = self.prepare_round_one()
        before = {p.name: p.read_bytes() for p in output.iterdir()}
        result = self.command("prepare-round", "--campaign", str(self.campaign), "--output-dir", str(output))
        self.assertEqual(3, result.returncode)
        self.assertEqual(before, {p.name: p.read_bytes() for p in output.iterdir()})


if __name__ == "__main__":
    unittest.main()
