"""Round selection from fresh synthetic raw reports and producer receipts."""
from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tests.profile_evolution.test_campaign import _prepared_campaign
from tests.profile_evolution.test_campaign_runner import _report
from tools.profile_evolution.artifacts import canonical_json_bytes, create_artifact
from tools.profile_evolution.campaign import freeze_candidates
from tools.profile_evolution.campaign_generation import generate_candidates
from tools.profile_evolution.campaign_schedule import audit_manifest, build_round_manifest
from tools.profile_evolution.campaign_comparison import compare_round, validate_round_result
from tools.profile_evolution.campaign_runner import COMPLETE_TYPE, READY_TYPE, RUN_TYPE, START_TYPE, _digest
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.fitness import _simulation_manifest_checksum, evaluate_fitness


def _small_campaign(repetitions=36):
    prepared = _prepared_campaign()
    prepared["payload"]["config"]["round_repetitions"] = [repetitions, repetitions * 2]
    prepared = create_artifact(prepared["type"], prepared["payload"])
    return freeze_candidates(prepared, generate_candidates(prepared))


def _save(path, document):
    path.write_bytes(canonical_json_bytes(document))


def _receipts(directory, campaign, number=1, previous=None, workers=2, fallback_alias=None):
    directory.mkdir()
    survivors = previous["payload"]["survivor_ids"] if previous else None
    manifest = build_round_manifest(campaign, number, survivors)
    report = _report(manifest)
    if fallback_alias:
        for tournament in report["tournaments"]:
            for result in tournament["profile_results"]:
                if result["profile_id"] == fallback_alias:
                    result["invalid_action_fallbacks"] = 1
    checksum = _simulation_manifest_checksum(manifest)
    run = create_artifact(RUN_TYPE, {"manifest": manifest, "manifest_checksum": checksum,
        "workers": workers, "godot": "/synthetic-test-engine", "expected_provenance": report["execution_provenance"],
        "approval": {"approved": True, "manifest_checksum": checksum, "source": "user", "note": "synthetic test fixture"}})
    _save(directory / "run.json", run)
    _save(directory / "manifest.json", manifest)
    evidence = []
    for index in range(workers):
        shard = copy.deepcopy(report)
        shard["shard"] = {"index": index, "count": workers}
        shard["tournaments"] = [t for t in report["tournaments"] if t["tournament_index"] % workers == index]
        path = directory / f"shard_{index:04d}.json"
        _save(path, shard)
        row = {"path": str(path.absolute()), "sha256": _digest(path), "shard": shard["shard"], "tournament_count": len(shard["tournaments"])}
        evidence.append(row)
        _save(directory / f"shard_{index:04d}.started.json", create_artifact(START_TYPE, {"run_checksum": run["checksum"], "shard": shard["shard"]}))
        _save(directory / f"shard_{index:04d}.completed.json", create_artifact(COMPLETE_TYPE, {"run_checksum": run["checksum"], "exit_code": 0, "report": row}))
    ready = create_artifact(READY_TYPE, {"run_checksum": run["checksum"], "manifest_checksum": checksum,
        "manifest": manifest, "workers": workers, "reports": evidence,
        "execution_provenance": report["execution_provenance"], "tournament_count": len(report["tournaments"]),
        "schedule_audit": audit_manifest(manifest)})
    _save(directory / "readiness.json", ready)
    return ready


def _refresh_report_receipt(ready, index=0):
    payload = copy.deepcopy(ready["payload"])
    row = payload["reports"][index]
    path = Path(row["path"])
    row["sha256"] = _digest(path)
    _save(path.parent / f"shard_{index:04d}.completed.json", create_artifact(COMPLETE_TYPE, {"run_checksum": payload["run_checksum"], "exit_code": 0, "report": row}))
    updated = create_artifact(READY_TYPE, payload)
    _save(path.parent / "readiness.json", updated)
    return updated


class CampaignComparisonTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.campaign = _small_campaign()

    def test_one_evaluator_call_ranks_thirty_and_cuts_five_with_controls_protected(self):
        with tempfile.TemporaryDirectory() as temporary:
            ready = _receipts(Path(temporary) / "round1", self.campaign)
            with patch("tools.profile_evolution.campaign_comparison.evaluate_fitness", wraps=evaluate_fitness) as evaluate:
                result = compare_round(self.campaign, ready)
                self.assertEqual(1, evaluate.call_count)
                self.assertEqual(30, len(evaluate.call_args.args[0]["payload"]["candidates"]))
            context = validate_round_result(result, self.campaign)
            self.assertEqual(25, len(context["survivor_ids"]))
            self.assertEqual(5, len(context["rejected_ids"]))
            self.assertEqual(5, len(context["cuts"]))
            controls = {p["profile_id"] for p in self.campaign["payload"]["inventory"]["fixed_controls"]}
            self.assertTrue(controls.isdisjoint({r["profile_id"] for r in context["ranking"]}))
            self.assertEqual(35, len(context["completed_audit"]["appearances_by_profile"]))
            self.assertTrue(context["extension_recommended"])
            self.assertTrue(context["extension_requires_user_approval"])
            self.assertFalse(context["selection_policy"]["extensions_automatically_authorized"])
            self.assertEqual(sorted(r["candidate_id"] for r in context["ranking"]), [r["candidate_id"] for r in context["ranking"]])
            self.assertTrue(all(r["sample_count"] == 324 for r in context["ranking"]))

    def test_round2_uses_only_verified_survivors_and_rejects_forged_previous_result(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            first = compare_round(self.campaign, _receipts(root / "round1", self.campaign))
            ready2 = _receipts(root / "round2", self.campaign, 2, first)
            second = compare_round(self.campaign, ready2, 2, first)
            context = validate_round_result(second, self.campaign, first)
            self.assertEqual(20, len(context["survivor_ids"]))
            self.assertEqual(5, len(context["rejected_ids"]))
            self.assertEqual(set(first["payload"]["survivor_ids"]), {r["candidate_id"] for r in context["ranking"]})
            forged = copy.deepcopy(first["payload"])
            forged["survivor_ids"][0] = first["payload"]["rejected_ids"][0]
            with self.assertRaises(ToolError):
                compare_round(self.campaign, ready2, 2, create_artifact(first["type"], forged))
            with self.assertRaises(ToolError):
                compare_round(self.campaign, ready2, 2)

    def test_contender_fallback_is_ineligible_and_control_fallback_blocks_round(self):
        contender = self.campaign["payload"]["contenders"][0]
        control = self.campaign["payload"]["inventory"]["fixed_controls"][0]
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            ready = _receipts(root / "contender", self.campaign, fallback_alias=contender["profile"]["profile_id"])
            context = compare_round(self.campaign, ready)["payload"]
            self.assertIn(contender["candidate_id"], context["rejected_ids"])
            row = next(r for r in context["ranking"] if r["candidate_id"] == contender["candidate_id"])
            self.assertFalse(row["eligible"])
            self.assertIn("invalid_action_fallbacks", row["ineligibility_reasons"])
            ready = _receipts(root / "control", self.campaign, fallback_alias=control["profile_id"])
            with self.assertRaisesRegex(ToolError, "protected handcrafted control"):
                compare_round(self.campaign, ready)

    def test_missing_changed_or_unsuccessful_producer_evidence_blocks_selection(self):
        for mutation in ("missing_report", "changed_report", "missing_receipt", "missing_ready", "failed_receipt"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                directory = Path(temporary) / "round1"
                ready = _receipts(directory, self.campaign)
                if mutation == "missing_report":
                    (directory / "shard_0000.json").unlink()
                elif mutation == "changed_report":
                    with (directory / "shard_0000.json").open("a") as output:
                        output.write("\n")
                elif mutation == "missing_receipt":
                    (directory / "shard_0000.completed.json").unlink()
                elif mutation == "missing_ready":
                    (directory / "readiness.json").unlink()
                else:
                    path = directory / "shard_0000.completed.json"
                    receipt = json.loads(path.read_text())
                    receipt["payload"]["exit_code"] = 1
                    _save(path, create_artifact(receipt["type"], receipt["payload"]))
                with self.assertRaises(ToolError):
                    compare_round(self.campaign, ready)

    def test_resealed_receipts_cannot_hide_missing_tournament_nonfinite_metrics_or_mixed_provenance(self):
        for mutation in ("missing", "nan", "provenance", "seat"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                ready = _receipts(Path(temporary) / "round1", self.campaign)
                path = Path(ready["payload"]["reports"][0]["path"])
                report = json.loads(path.read_text())
                if mutation == "missing":
                    report["tournaments"].pop()
                elif mutation == "nan":
                    report["tournaments"][0]["profile_results"][0]["vpip_rate"] = float("nan")
                elif mutation == "provenance":
                    report["execution_provenance"]["engine_version"] = "different"
                else:
                    report["tournaments"][0]["seat_map"][0]["profile_id"] = "missing"
                path.write_text(json.dumps(report))
                ready = _refresh_report_receipt(ready)
                with self.assertRaises(ToolError):
                    compare_round(self.campaign, ready)

    def test_resealed_ranking_cutoff_and_creation_changes_fail_validation(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = compare_round(self.campaign, _receipts(Path(temporary) / "round1", self.campaign))
            changes = (
                lambda p: p["survivor_ids"].reverse(),
                lambda p: p["ranking"][0].__setitem__("fitness", 1),
                lambda p: p["ranking"][0].__setitem__("original_creation_checksum", "0" * 64),
                lambda p: p["selection_policy"].__setitem__("rejection_count", 4),
                lambda p: p.__setitem__("extension_recommended", False),
            )
            for index, change in enumerate(changes):
                payload = copy.deepcopy(result["payload"])
                change(payload)
                with self.subTest(index=index), self.assertRaises(ToolError):
                    validate_round_result(create_artifact(result["type"], payload), self.campaign)

    def test_too_few_eligible_and_wrong_round_manifests_fail(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            campaign = _small_campaign(9)
            ready = _receipts(root / "short", campaign)
            with self.assertRaisesRegex(ToolError, "Too few eligible"):
                compare_round(campaign, ready)
            ready = _receipts(root / "valid", self.campaign)
            payload = copy.deepcopy(ready["payload"])
            payload["manifest"]["batch_id"] = "another_manifest"
            with self.assertRaises(ToolError):
                compare_round(self.campaign, create_artifact(READY_TYPE, payload))
            for number in (0, 3, True, 1.0):
                with self.subTest(number=number), self.assertRaises(ToolError):
                    compare_round(self.campaign, ready, number)


if __name__ == "__main__":
    unittest.main()
