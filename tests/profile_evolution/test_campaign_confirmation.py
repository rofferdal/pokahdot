"""Strict nine-player confirmation fixtures generated entirely in the test run."""
from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

from tests.profile_evolution.test_campaign import _prepared_campaign
from tests.profile_evolution.test_confirmation import _provenance, _result
from tools.profile_evolution.artifacts import create_artifact
from tools.profile_evolution.campaign import freeze_candidates
from tools.profile_evolution.campaign_generation import generate_candidates
from tools.profile_evolution.campaign_confirmation import (
    ARTIFACT_TYPE, build_confirmation_manifests, confirm_nine_player,
    validate_nine_player_confirmation,
)
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.fitness import _roster_provenance, _simulation_manifest_checksum


def _frozen_campaign():
    prepared = _prepared_campaign()
    return freeze_candidates(prepared, generate_candidates(prepared))


def _report_for_manifest(manifest, candidate_alias, candidate_wins=True, benchmark_fallback=0):
    profiles = manifest["matchups"][0]["profile_ids"]
    plan = manifest["evaluation_plans"][0]
    regime = manifest["regimes"][0]
    tournaments = []
    for index in range(plan["tournament_count"]):
        seat_ids = [profiles[(seat + index) % 9] for seat in range(9)]
        winner = candidate_alias if candidate_wins else next(p for p in profiles if p != candidate_alias)
        finishers = [winner] + [p for p in seat_ids if p != winner]
        results = []
        for seat, profile_id in enumerate(seat_ids):
            result = _result(profile_id, seat, finishers.index(profile_id) + 1, 9,
                             benchmark_fallback if profile_id == profiles[1] else 0)
            result["starting_stack"] = 1000
            result["final_stack"] = 9000 if profile_id == winner else 0
            result["chip_differential"] = result["final_stack"] - 1000
            results.append(result)
        tournaments.append({"tournament_index": index, "plan_id": plan["plan_id"],
                            "plan_tournament_index": index, "regime_id": regime["regime_id"],
                            "matchup_id": manifest["matchups"][0]["matchup_id"], "matchup_occurrence": index,
                            "rotation": index % 9, "effective_seed": manifest["seed_start"] + index,
                            "seat_map": [{"seat": seat, "profile_id": p} for seat, p in enumerate(seat_ids)],
                            "selected_profile_ids": seat_ids, "termination_reason": "winner", "winner_profile_id": winner,
                            "tournament_hand_count": 1, "profile_results": results, "diagnostics": []})
    provenance = _provenance()
    provenance["algorithm_versions"]["rng_streams"] = "named_stream_sha256_v2"
    return {"report_schema_version": 4, "manifest": manifest,
            "manifest_checksum": _simulation_manifest_checksum(manifest), "roster": _roster_provenance(manifest),
            "code_revision": provenance["code_revision"], "command_version": "simulation_cli_v6",
            "execution_provenance": provenance, "shard": {"index": 0, "count": 1},
            "started_at": "2026-11-01T12:00:00", "finished_at": "2026-11-01T12:01:00",
            "tournaments": tournaments, "aggregates": {}, "traces": []}


def _confirmation_fixture(directory: Path, candidate_index=0, candidate_wins=True, benchmark_fallback=0):
    """Return campaign, candidate ID, reports and a genuine strict confirmation."""
    campaign = _frozen_campaign()
    row = campaign["payload"]["contenders"][candidate_index]
    manifests = build_confirmation_manifests(campaign, row["candidate_id"])
    paths = {}
    for mode, manifest in manifests.items():
        path = directory / f"confirmation_{candidate_index}_{mode}.json"
        path.write_text(json.dumps(_report_for_manifest(manifest, row["profile"]["profile_id"], candidate_wins, benchmark_fallback)), encoding="utf-8")
        paths[mode] = path
    artifact = confirm_nine_player(campaign, row["candidate_id"], [paths["a"]], [paths["b"]])
    return campaign, row["candidate_id"], paths, artifact


class NinePlayerConfirmationTests(unittest.TestCase):
    def test_manifest_nine_player_strategic_tables_and_disjoint_reserved_ranges(self):
        campaign = _frozen_campaign()
        ranges = []
        for row in campaign["payload"]["contenders"]:
            manifests = build_confirmation_manifests(campaign, row["candidate_id"])
            for mode, manifest in manifests.items():
                self.assertEqual(9, len(manifest["profiles"]))
                self.assertEqual(9, len(set(manifest["matchups"][0]["profile_ids"])))
                self.assertTrue(all(p["model_id"] == "strategy_parameterized" for p in manifest["profiles"]))
                count = manifest["evaluation_plans"][0]["tournament_count"]
                self.assertEqual(297, count)
                ranges.append((manifest["seed_start"], manifest["seed_start"] + count - 1))
        ranges.sort()
        self.assertTrue(all(a[1] < b[0] for a, b in zip(ranges, ranges[1:])))

    def test_success_replays_embedded_reports_after_originals_are_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            campaign, candidate_id, _, artifact = _confirmation_fixture(Path(directory))
        context = validate_nine_player_confirmation(artifact)
        self.assertTrue(context["promotion_eligible"])
        self.assertTrue(context["review_required"])
        self.assertEqual("nine_player_promotion_v1", context["evidence_policy"]["policy_version"])
        self.assertEqual(candidate_id, context["candidate"]["candidate_id"])
        self.assertEqual(campaign["payload"]["contenders"][0]["parent_ids"], context["candidate"]["parent_ids"])
        self.assertEqual(campaign["payload"]["contenders"][0]["creation_checksum"], context["original_creation_checksum"])
        self.assertEqual([], context["legacy_ids"])
        for batch in context["batches"].values():
            self.assertEqual([33] * 9, batch["seat_samples"])
            self.assertTrue(all(c["lower_95_bound"] > 0 for c in batch["comparisons"]))

    def test_losing_candidate_and_benchmark_fallback_make_evidence_ineligible(self):
        for wins, fallback, reason in ((False, 0, "performance_not_demonstrated"), (True, 1, "invalid_action_fallbacks")):
            with self.subTest(wins=wins, fallback=fallback), tempfile.TemporaryDirectory() as directory:
                _, _, _, artifact = _confirmation_fixture(Path(directory), candidate_wins=wins, benchmark_fallback=fallback)
                context = validate_nine_player_confirmation(artifact)
                self.assertFalse(context["promotion_eligible"])
                self.assertTrue(any(reason in item for item in context["ineligibility_reasons"]))

    def test_resealed_summary_snapshot_and_cutoff_changes_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            _, _, _, original = _confirmation_fixture(Path(directory))
        changes = (
            lambda p: p["confirmation"]["candidate"]["parameters"].__setitem__("bluff_rate", 1),
            lambda p: p["confirmation"]["evidence_policy"].__setitem__("minimum_samples_per_seat", 1),
            lambda p: p["confirmation"]["evidence_policy"].__setitem__("policy_version", "promotion_evidence_v1"),
            lambda p: p["confirmation"]["batches"]["a"]["comparisons"][0].__setitem__("lower_95_bound", 100),
        )
        for index, change in enumerate(changes):
            payload = copy.deepcopy(original["payload"])
            change(payload)
            with self.subTest(index=index), self.assertRaises(ToolError):
                validate_nine_player_confirmation(create_artifact(ARTIFACT_TYPE, payload))

    def test_reused_seed_batch_incomplete_seats_and_changed_provenance_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            campaign, cid, paths, _ = _confirmation_fixture(Path(directory))
            with self.assertRaises(ToolError):
                confirm_nine_player(campaign, cid, [paths["a"]], [paths["a"]])
            original = json.loads(paths["b"].read_text())
            for change in (
                lambda r: r["tournaments"].pop(),
                lambda r: r["tournaments"][0]["seat_map"][0].__setitem__("profile_id", "wrong"),
                lambda r: r["execution_provenance"].__setitem__("engine_version", "4.8"),
                lambda r: r["execution_provenance"]["algorithm_versions"].__setitem__("rng_streams", "named_stream_v1"),
            ):
                report = copy.deepcopy(original)
                change(report)
                paths["b"].write_text(json.dumps(report))
                with self.assertRaises(ToolError):
                    confirm_nine_player(campaign, cid, [paths["a"]], [paths["b"]])

    def test_wrong_table_legacy_and_insufficient_budget_fail(self):
        campaign = _frozen_campaign()
        cid = campaign["payload"]["contenders"][0]["candidate_id"]
        with tempfile.TemporaryDirectory() as directory:
            _, _, paths, _ = _confirmation_fixture(Path(directory))
            report = json.loads(paths["a"].read_text())
            report["manifest"]["profiles"][1].update(model_id="random", parameters={"fold_weight": 1, "passive_weight": 4, "aggressive_weight": 2})
            paths["a"].write_text(json.dumps(report))
            with self.assertRaises(ToolError):
                confirm_nine_player(campaign, cid, [paths["a"]], [paths["b"]])
        for identifier in ("unknown", "balanced"):
            with self.assertRaises(ToolError):
                build_confirmation_manifests(campaign, identifier)
        with self.assertRaises(ToolError):
            build_confirmation_manifests(_prepared_campaign(), cid)


if __name__ == "__main__":
    unittest.main()
