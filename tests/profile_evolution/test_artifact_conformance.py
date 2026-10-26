"""The same report corpus is consumed by Godot inspect and Python workflows."""

from __future__ import annotations

import copy
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.profile_evolution.artifacts import create_artifact
from tools.profile_evolution.confirmation import _mode_evidence, confirm_candidate, validate_confirmation
from tools.profile_evolution.contracts import validate_selection
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.evolution import initialize_generation
from tools.profile_evolution.fitness import _roster_provenance, _simulation_manifest_checksum, evaluate_fitness
from tools.profile_evolution.selection import select_elites, validate_fitness_payload
from tests.profile_evolution.test_confirmation import _candidate, _entry

FIXTURE = Path(__file__).resolve().parents[1] / "fixtures" / "artifact_conformance_v1.json"


def _patched_report(fixture: dict, case: dict) -> dict:
    report = copy.deepcopy(fixture["base_report"])
    for patch in case["patches"]:
        node = report
        for key in patch["path"][:-1]:
            node = node[key]
        node[patch["path"][-1]] = copy.deepcopy(patch["value"])
    return report


def _repair_identity(report: dict) -> None:
    report["manifest_checksum"] = _simulation_manifest_checksum(report["manifest"])
    report["roster"] = _roster_provenance(report["manifest"])


class ArtifactConformanceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
        self.assertEqual(self.fixture["fixture_version"], 1)

    def test_shared_cases_through_fitness_and_selection_validation(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            path = Path(name) / "report.json"
            for case in self.fixture["cases"]:
                with self.subTest(case=case["id"]):
                    report = _patched_report(self.fixture, case)
                    self.assertEqual(report["manifest_checksum"],
                                     _simulation_manifest_checksum(report["manifest"]),
                                     "Semantic cases must not merely fail a stale checksum")
                    path.write_text(json.dumps(report))
                    if not case["valid"]:
                        with self.assertRaises(ToolError):
                            evaluate_fitness(self.fixture["generation"], [path])
                        continue
                    fitness = evaluate_fitness(self.fixture["generation"], [path])
                    self.assertEqual(fitness["payload"]["report_evidence"][0]["report_checksum"],
                                     hashlib.sha256(path.read_bytes()).hexdigest())
                    payload = validate_fitness_payload(fitness["payload"])
                    self.assertEqual(len(payload["candidate_results"]), 2)
                    if case["id"] == "valid_sparse_threshold":
                        self.assertTrue(all(not row["eligible"] for row in payload["candidate_results"]))
                    # A two-candidate corpus cannot supply the minimum two
                    # crossover parents at a legal 10–20% elite fraction.
                    with self.assertRaisesRegex(ToolError, "fewer than two crossover parents"):
                        select_elites(fitness, 0.20)

    def test_shared_cases_through_confirmation_report_ingestion(self) -> None:
        generation = self.fixture["generation"]
        candidates = generation["payload"]["candidates"]
        with tempfile.TemporaryDirectory() as name:
            path = Path(name) / "report.json"
            for case in self.fixture["cases"]:
                with self.subTest(case=case["id"]):
                    path.write_text(json.dumps(_patched_report(self.fixture, case)))
                    arguments = ("mirrored", [path], generation, candidates[0]["candidate_id"],
                                 {candidates[1]["candidate_id"]}, set())
                    if case["valid"]:
                        evidence = _mode_evidence(*arguments)
                        self.assertTrue(evidence[0]["batches"])
                        self.assertTrue(evidence[1], "Tiny samples must remain exploratory")
                    else:
                        with self.assertRaises(ToolError):
                            _mode_evidence(*arguments)

    def test_actual_selection_from_a_completed_report_rejects_tampered_counts(self) -> None:
        # Expand the candidate catalog while keeping the two-seat report small.
        # Four unplayed candidates remain ineligible, so exactly two genuine
        # evaluated candidates can fill the legal rounded elite count.
        bounds = self.fixture["generation"]["payload"]["bounds"]["genes"]
        generation = initialize_generation(bounds, 6, 14)
        report = copy.deepcopy(self.fixture["base_report"])
        candidates = generation["payload"]["candidates"]
        old_ids = [row["profile_id"] for row in report["manifest"]["profiles"]]
        replacements = dict(zip(old_ids, [row["candidate_id"] for row in candidates]))
        report["manifest"]["profiles"] = [
            {"profile_id": row["candidate_id"], "model_id": row["model_id"],
             "parameters": row["parameters"]} for row in candidates
        ]
        report["manifest"]["matchups"][0]["profile_ids"] = [replacements[item] for item in old_ids]
        for tournament in report["tournaments"]:
            tournament["winner_profile_id"] = replacements[tournament["winner_profile_id"]]
            tournament["selected_profile_ids"] = [replacements[item] for item in tournament["selected_profile_ids"]]
            for row in tournament["seat_map"] + tournament["profile_results"]:
                row["profile_id"] = replacements[row["profile_id"]]
        _repair_identity(report)
        with tempfile.TemporaryDirectory() as name:
            path = Path(name) / "report.json"
            path.write_text(json.dumps(report))
            fitness = evaluate_fitness(generation, [path])
        selection = select_elites(fitness, 0.20)
        self.assertEqual(len(validate_selection(selection["payload"])["selected_candidates"]), 2)
        payload = copy.deepcopy(fitness["payload"])
        payload["candidate_results"][0]["sample_count"] += 1
        with self.assertRaisesRegex(ToolError, "Plan sample counts"):
            select_elites(create_artifact("fitness", payload), 0.20)

    def test_public_confirmation_preserves_exploratory_status_for_sparse_fixture(self) -> None:
        first, second = copy.deepcopy(self.fixture["generation"]["payload"]["candidates"])
        legacy = _candidate("conformance_legacy", 20)
        registry = create_artifact("lineage_registry", {
            "artifacts": [], "entries": [_entry(first), _entry(second, champion=True), _entry(legacy)]
        })
        report = copy.deepcopy(self.fixture["base_report"])
        report["manifest"]["profiles"].append({
            "profile_id": legacy["candidate_id"], "model_id": legacy["model_id"],
            "parameters": legacy["parameters"],
        })
        _repair_identity(report)
        with tempfile.TemporaryDirectory() as name:
            path = Path(name) / "report.json"
            path.write_text(json.dumps(report))
            confirmation = confirm_candidate(registry, first["candidate_id"],
                [legacy["candidate_id"]], [second["candidate_id"]], [path], [path])
        self.assertFalse(confirmation["payload"]["promotion_eligible"])
        self.assertEqual(validate_confirmation(confirmation)["evidence_policy"]["evidence_class"],
                         "exploratory_only")
