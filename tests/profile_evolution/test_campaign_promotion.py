"""Policy propagation and explicit review gates for nine-player publication."""
from __future__ import annotations

import contextlib
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.profile_evolution.artifacts import create_artifact, validate_artifact_envelope
from tools.profile_evolution.confirmation import MEASURED_BEHAVIOR_FIELDS
from tools.profile_evolution.contracts import GENES
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.profile_publisher import publish_approved_profile
from tools.profile_evolution.promotion_review import (
    NINE_PLAYER_POLICY_VERSION, create_promotion_review, create_promotion_review_plan,
    finalize_promotion_review, validate_promotion_review_batch, validate_promotion_review_plan,
)


def _validated_evidence(identifier: str = "original_candidate", *, policy: str = NINE_PLAYER_POLICY_VERSION,
                        eligible: bool = True, value: int = 70) -> dict:
    """Unit fixture at the validated-confirmation boundary, not simulation evidence."""
    return create_artifact("nine_player_confirmation_v1" if policy == NINE_PLAYER_POLICY_VERSION else "confirmation", {
        "candidate": {"candidate_id": identifier, "model_id": "strategy_parameterized",
                      "parameters": {gene: value for gene in GENES}, "parent_ids": []},
        "simulated_profile_id": identifier + "__old_publication",
        "evidence_policy": {"policy_version": policy},
        "promotion_eligible": eligible, "review_required": True,
        "measured_behavior": {"metrics": {field: {"rate": 0.25} for field in MEASURED_BEHAVIOR_FIELDS}},
    })


def _fixture_context(artifact: dict) -> dict:
    validate_artifact_envelope(artifact)
    return artifact["payload"]


class CampaignPromotionTests(unittest.TestCase):
    def setUp(self) -> None:
        # Consumer unit tests isolate the strict simulation/confirmation producer.
        # Its real report ingestion and policy validation have separate tests.
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        for module in ("promotion_review", "profile_publisher"):
            self.stack.enter_context(patch(
                f"tools.profile_evolution.{module}.validate_confirmation", side_effect=_fixture_context))
        self.confirmation = _validated_evidence()

    def _approved(self, confirmation: dict | None = None) -> dict:
        confirmation = confirmation or self.confirmation
        plan = create_promotion_review_plan([confirmation], "independent_reviewer")
        plan["candidates"][0]["decision"] = "approve"
        plan["candidates"][0]["display_name"] = "Silver Current"
        return finalize_promotion_review(plan, [confirmation])

    def test_new_policy_is_explicit_through_plan_batch_and_provenance(self) -> None:
        plan = create_promotion_review_plan([self.confirmation], "independent_reviewer")
        self.assertEqual(plan["plan_version"], 3)
        self.assertEqual(plan["policy_version"], NINE_PLAYER_POLICY_VERSION)
        self.assertEqual(plan["candidates"][0]["policy_version"], NINE_PLAYER_POLICY_VERSION)
        self.assertEqual(plan["candidates"][0]["decision"], "pending")
        batch = self._approved()
        context = validate_promotion_review_batch(batch)
        self.assertEqual(context["policy_version"], NINE_PLAYER_POLICY_VERSION)
        self.assertEqual(context["decisions"][0]["policy_version"], NINE_PLAYER_POLICY_VERSION)
        with tempfile.TemporaryDirectory() as directory:
            result = publish_approved_profile(self.confirmation, batch, Path(directory), "new_version")
            self.assertEqual(result["profile_id"], "original_candidate__new_version")
            text = Path(result["resource_path"]).read_text()
            self.assertIn('display_name = "Silver Current"', text)
            self.assertNotIn("__old_publication__new_version", text)
            provenance = json.loads(Path(result["provenance_path"]).read_text())
            self.assertEqual(provenance["policy_version"], NINE_PLAYER_POLICY_VERSION)
            self.assertEqual(provenance["confirmation_checksum"], self.confirmation["checksum"])
            self.assertEqual(provenance["review_checksum"], batch["checksum"])
            with self.assertRaises(ToolError):
                publish_approved_profile(self.confirmation, batch, Path(directory), "new_version")

    def test_pending_and_ineligible_evidence_cannot_receive_final_approval(self) -> None:
        plan = create_promotion_review_plan([self.confirmation], "reviewer")
        with self.assertRaises(ToolError):
            finalize_promotion_review(plan, [self.confirmation])
        ineligible = _validated_evidence(eligible=False)
        plan = create_promotion_review_plan([ineligible], "reviewer")
        plan["candidates"][0]["decision"] = "approve"
        with self.assertRaises(ToolError):
            finalize_promotion_review(plan, [ineligible])
        plan["candidates"][0]["decision"] = "reject"
        review = finalize_promotion_review(plan, [ineligible])
        with tempfile.TemporaryDirectory() as directory, self.assertRaises(ToolError):
            publish_approved_profile(ineligible, review, Path(directory), "v1")

    def test_altered_plan_policy_snapshot_and_eligibility_fail_binding(self) -> None:
        for mutation in (
            lambda p: p.__setitem__("policy_version", "promotion_evidence_v1"),
            lambda p: p["candidates"][0].__setitem__("policy_version", "unknown_policy"),
            lambda p: p["candidates"][0].__setitem__("promotion_eligible", False),
            lambda p: p["candidates"][0]["candidate"]["parameters"].__setitem__(GENES[0], 2),
            lambda p: p["candidates"][0].__setitem__("confirmation_checksum", "0" * 64),
        ):
            plan = create_promotion_review_plan([self.confirmation], "reviewer")
            plan["candidates"][0]["decision"] = "approve"
            mutation(plan)
            with self.subTest(plan=plan), self.assertRaises(ToolError):
                finalize_promotion_review(plan, [self.confirmation])

    def test_review_cannot_drop_or_relabel_policy_before_publication(self) -> None:
        original = self._approved()
        for mode in ("drop", "relabel"):
            payload = copy.deepcopy(original["payload"])
            if mode == "drop":
                payload.pop("policy_version")
                payload["decisions"][0].pop("policy_version")
            else:
                payload["policy_version"] = "promotion_evidence_v1"
                payload["decisions"][0]["policy_version"] = "promotion_evidence_v1"
            changed = create_artifact("promotion_review_batch", payload)
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory, self.assertRaises(ToolError):
                publish_approved_profile(self.confirmation, changed, Path(directory), "v1")

    def test_single_review_and_mixed_policies_are_rejected(self) -> None:
        with self.assertRaises(ToolError):
            create_promotion_review(self.confirmation, "reviewer", True)
        old_confirmation = _validated_evidence("legacy_candidate", policy="promotion_evidence_v1")
        with self.assertRaises(ToolError):
            create_promotion_review_plan([old_confirmation, self.confirmation], "reviewer")
        old_plan = create_promotion_review_plan([old_confirmation], "reviewer")
        self.assertEqual(old_plan["plan_version"], 2)
        self.assertNotIn("policy_version", old_plan)
        self.assertNotIn("policy_version", old_plan["candidates"][0])

    def test_invalid_and_duplicate_names_are_rejected(self) -> None:
        for name in (" trailing ", "line\nbreak", "tab\tname", "control\x7f"):
            plan = create_promotion_review_plan([self.confirmation], "reviewer")
            plan["candidates"][0]["display_name"] = name
            with self.subTest(name=name), self.assertRaises(ToolError):
                validate_promotion_review_plan(plan, require_complete=False)
        second = _validated_evidence("another_candidate", value=30)
        plan = create_promotion_review_plan([self.confirmation, second], "reviewer")
        plan["candidates"][0]["display_name"] = "Same Name"
        plan["candidates"][1]["display_name"] = "same name"
        with self.assertRaises(ToolError):
            validate_promotion_review_plan(plan, require_complete=False)
        review = self._approved()
        for name in ("", " trimmed ", "bad\nname", 123):
            with self.subTest(override=name), tempfile.TemporaryDirectory() as directory, self.assertRaises(ToolError):
                publish_approved_profile(self.confirmation, review, Path(directory), "v1", name)

    def test_policy_version_type_and_unknown_versions_fail_closed(self) -> None:
        for version in (3.0, True, 4):
            plan = create_promotion_review_plan([self.confirmation], "reviewer")
            plan["plan_version"] = version
            with self.subTest(version=version), self.assertRaises(ToolError):
                validate_promotion_review_plan(plan, require_complete=False)
        unsupported = _validated_evidence(policy="unknown_policy")
        with self.assertRaises(ToolError):
            create_promotion_review_plan([unsupported], "reviewer")


class CampaignPromotionIntegrationTests(unittest.TestCase):
    def test_real_nine_player_confirmation_reaches_consolidated_review_and_publication(self) -> None:
        from tests.profile_evolution.test_campaign_confirmation import _confirmation_fixture
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, candidate_id, _, confirmation = _confirmation_fixture(root)
            plan = create_promotion_review_plan([confirmation], "fixture_independent_reviewer")
            self.assertEqual(plan["plan_version"], 3)
            with self.assertRaises(ToolError):
                finalize_promotion_review(plan, [confirmation])
            plan["candidates"][0]["decision"] = "approve"
            plan["candidates"][0]["display_name"] = "Fixture Current"
            review = finalize_promotion_review(plan, [confirmation])
            published = publish_approved_profile(confirmation, review, root / "project", "fixture_version")
            self.assertEqual(published["profile_id"], candidate_id + "__fixture_version")
            provenance = json.loads(Path(published["provenance_path"]).read_text())
            self.assertEqual(provenance["policy_version"], NINE_PLAYER_POLICY_VERSION)
            self.assertEqual(provenance["confirmation_checksum"], confirmation["checksum"])

    def test_real_ineligible_nine_player_confirmation_and_forged_policy_cannot_be_approved(self) -> None:
        from tests.profile_evolution.test_campaign_confirmation import _confirmation_fixture
        with tempfile.TemporaryDirectory() as directory:
            _, _, _, confirmation = _confirmation_fixture(Path(directory), candidate_wins=False)
            plan = create_promotion_review_plan([confirmation], "fixture_independent_reviewer")
            self.assertFalse(plan["candidates"][0]["promotion_eligible"])
            plan["candidates"][0]["decision"] = "approve"
            with self.assertRaises(ToolError):
                finalize_promotion_review(plan, [confirmation])
            payload = copy.deepcopy(confirmation["payload"])
            payload["confirmation"]["evidence_policy"]["policy_version"] = "promotion_evidence_v1"
            forged = create_artifact(confirmation["type"], payload)
            with self.assertRaises(ToolError):
                create_promotion_review_plan([forged], "fixture_independent_reviewer")


if __name__ == "__main__":
    unittest.main()
