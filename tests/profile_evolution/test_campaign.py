"""Campaign configuration and ledger safeguards using tracked archival inputs."""
from __future__ import annotations

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

from tools.profile_evolution.artifacts import create_artifact
from tools.profile_evolution.campaign import (
    create_campaign, default_config, freeze_candidates, seed_start, validate_campaign, validate_config,
)
from tools.profile_evolution.campaign_generation import generate_candidates
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.historical_lineage import import_historical_lineage

ROOT = Path(__file__).resolve().parents[2]


def _archive(directory: Path) -> dict[str, Any]:
    """Resolve exactly the registry's original envelope catalog, never reports."""
    registry_path = directory / "lineage_registry.json"
    registry = json.loads(registry_path.read_text())
    wanted = {row["checksum"] for row in registry["payload"]["artifacts"]}
    original_paths: dict[str, Path] = {}
    for path in directory.glob("*.json"):
        # Immutable creation/fitness/selection envelopes are small. Simulation
        # reports/manifests are not source artifacts for the historical importer.
        if "report" in path.name or "manifest" in path.name or path.stat().st_size > 1_000_000:
            continue
        document = json.loads(path.read_text())
        checksum = document.get("checksum")
        if checksum in wanted:
            if checksum in original_paths:
                raise AssertionError(f"Duplicate historical source checksum: {path}")
            original_paths[checksum] = path
    if set(original_paths) != wanted:
        raise AssertionError("Tracked fixture is missing original lineage artifacts.")
    return import_historical_lineage(registry_path, original_paths.values())


def _prepared_campaign() -> dict[str, Any]:
    inventory = json.loads((ROOT / "tests/fixtures/campaign_inventory.json").read_text())
    archives = [
        _archive(ROOT / "tests/fixtures/campaign_history"),
        _archive(ROOT / "examples/profile_evolution/milestone5"),
    ]
    return create_campaign(default_config("test_campaign"), inventory, archives)


class CampaignTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.prepared = _prepared_campaign()

    def _tampered(self, mutate: Any) -> dict[str, Any]:
        payload = copy.deepcopy(self.prepared["payload"])
        mutate(payload)
        return create_artifact("roster_campaign", payload)

    def test_preparation_is_deterministic_and_preserves_original_identities(self) -> None:
        self.assertEqual(self.prepared, _prepared_campaign())
        context = validate_campaign(self.prepared)
        self.assertEqual(context["stage"], "prepared")
        self.assertEqual(len(context["contenders"]), 10)
        self.assertEqual(len(context["inventory"]["fixed_controls"]), 5)
        self.assertEqual(len(context["inventory"]["confirmation_benchmarks"]), 8)
        strategic_profiles = context["inventory"]["fixed_controls"] + context["inventory"]["confirmation_benchmarks"]
        self.assertTrue(all(p["model_id"] == "strategy_parameterized" for p in strategic_profiles))
        legacy_ids = {p["profile_id"] for p in context["inventory"]["legacy_profiles"]}
        self.assertEqual(len(legacy_ids), 3)
        self.assertFalse(legacy_ids & {p["profile_id"] for p in strategic_profiles})
        for row in context["contenders"]:
            self.assertTrue(row["profile"]["profile_id"].startswith(row["candidate_id"] + "__"))
            self.assertEqual(row["status"], "active")

    def test_configuration_rejects_non_nine_player_starts_and_invalid_counts(self) -> None:
        for field, value in (("player_count", 2), ("player_count", 6), ("player_count", 8),
                             ("player_count", True), ("player_count", 9.0),
                             ("expected_contenders", 31), ("survivor_counts", [25, 19]),
                             ("survivor_counts", [25.0, 20]), ("starting_stack", 999)):
            with self.subTest(field=field, value=value):
                config = default_config("test")
                config[field] = value
                with self.assertRaises(ToolError):
                    validate_config(config)

    def test_configuration_rejects_incomplete_rotations_and_invalid_budgets(self) -> None:
        for field, value in (("round_repetitions", [901, 1800]),
                             ("round_repetitions", [900, 1791]),
                             ("round_repetitions", [True, 1800]),
                             ("confirmation_repetitions", 288),
                             ("confirmation_repetitions", 901),
                             ("maximum_schedule_cycles", 0),
                             ("maximum_parallel_processes", 0),
                             ("maximum_extensions", 2), ("generation_seed", -1),
                             ("schedule_seeds", [1]), ("mutation_seed", 2**64)):
            with self.subTest(field=field, value=value):
                config = default_config("test")
                config[field] = value
                with self.assertRaises(ToolError):
                    validate_config(config)

    def test_seed_reservations_are_disjoint_and_lossless(self) -> None:
        config = default_config("test")
        config["seed_blocks"]["round2"] = copy.deepcopy(config["seed_blocks"]["round1"])
        with self.assertRaises(ToolError):
            validate_config(config)
        for value in (0, -1, True, 1.5, 2**53):
            config = default_config("test")
            config["seed_blocks"]["pilot"]["minimum"] = value
            with self.subTest(value=value), self.assertRaises(ToolError):
                validate_config(config)

    def test_seed_allocation_accepts_exact_block_boundary_and_rejects_overflow(self) -> None:
        config = default_config("test")
        block = config["seed_blocks"]["pilot"]
        size = block["maximum"] - block["minimum"] + 1
        self.assertEqual(seed_start(config, "pilot", size), block["minimum"])
        self.assertEqual(seed_start(config, "pilot", 1, size - 1), block["maximum"])
        for name, count, offset in (("pilot", size + 1, 0), ("pilot", 2, size - 1),
                                    ("pilot", 0, 0), ("pilot", 1, -1),
                                    ("pilot", True, 0), ("missing", 1, 0)):
            with self.subTest(name=name, count=count, offset=offset), self.assertRaises(ToolError):
                seed_start(config, name, count, offset)

    def test_changed_incumbent_snapshot_name_identity_and_alias_are_rejected(self) -> None:
        mutations = (
            lambda p: p["contenders"][0]["profile"]["parameters"].__setitem__("bluff_rate", 0),
            lambda p: p["contenders"][0].__setitem__("display_name", "Forged Name"),
            lambda p: p["contenders"][0].__setitem__("candidate_id", "unrecorded_candidate"),
            lambda p: p["contenders"][0]["profile"].__setitem__("profile_id", "unrecorded_alias"),
            lambda p: p["contenders"][0].__setitem__("origin", "initialized"),
        )
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index), self.assertRaises(ToolError):
                validate_campaign(self._tampered(mutate))

    def test_duplicate_names_ids_aliases_and_parameter_vectors_are_rejected(self) -> None:
        def duplicate(p: dict[str, Any], field: str) -> None:
            if field == "parameters":
                p["contenders"][1]["profile"][field] = copy.deepcopy(p["contenders"][0]["profile"][field])
            elif field == "profile_id":
                p["contenders"][1]["profile"][field] = p["contenders"][0]["profile"][field]
            else:
                p["contenders"][1][field] = p["contenders"][0][field]
        for field in ("display_name", "candidate_id", "profile_id", "parameters"):
            with self.subTest(field=field), self.assertRaises(ToolError):
                validate_campaign(self._tampered(lambda p: duplicate(p, field)))

    def test_missing_archive_or_changed_historical_champion_is_rejected(self) -> None:
        mutations = (
            lambda p: p.__setitem__("archives", []),
            lambda p: p["archives"].pop(),
            lambda p: p["inventory"]["confirmation_benchmarks"].pop(),
            lambda p: p["inventory"]["confirmation_benchmarks"][-1].__setitem__("profile_id", "fake_champion"),
            lambda p: p["inventory"]["confirmation_benchmarks"][-1]["parameters"].__setitem__("bluff_rate", 99),
        )
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index), self.assertRaises(ToolError):
                validate_campaign(self._tampered(mutate))

    def test_shared_control_and_benchmark_identity_cannot_have_different_snapshot(self) -> None:
        def change_benchmark(p: dict[str, Any]) -> None:
            profile = next(x for x in p["inventory"]["confirmation_benchmarks"]
                           if x["profile_id"] == "balanced")
            profile["parameters"]["bluff_rate"] = 99
        with self.assertRaises(ToolError):
            validate_campaign(self._tampered(change_benchmark))

    def test_prepared_ledger_cannot_claim_elimination_or_confirmation(self) -> None:
        for status in ("rejected_round1", "rejected_round2", "finalist", "confirmed"):
            with self.subTest(status=status), self.assertRaises(ToolError):
                validate_campaign(self._tampered(lambda p: p["contenders"][0].__setitem__("status", status)))
        for field in ("rounds", "confirmations"):
            with self.subTest(field=field), self.assertRaises(ToolError):
                validate_campaign(self._tampered(lambda p: p[field].append({"unverified": True})))

    def test_frozen_stage_cannot_omit_twenty_new_candidates(self) -> None:
        with self.assertRaises(ToolError):
            validate_campaign(self._tampered(lambda p: p.__setitem__("stage", "candidates_frozen")))
        with self.assertRaises(ToolError):
            validate_campaign(self._tampered(lambda p: p["contenders"].pop()))

    def test_historical_champion_model_must_match_archived_identity(self) -> None:
        with self.assertRaises(ToolError):
            validate_campaign(self._tampered(
                lambda p: p["inventory"]["confirmation_benchmarks"][-1].__setitem__("model_id", "random")))

    def test_malformed_config_and_ledger_shapes_have_structured_validation_errors(self) -> None:
        config = default_config("test")
        config["seed_blocks"] = None
        with self.assertRaises(ToolError):
            validate_config(config)
        mutations = (
            lambda p: p["config"].__setitem__("seed_blocks", None),
            lambda p: p.__setitem__("archives", None),
            lambda p: p.__setitem__("contenders", None),
            lambda p: p["inventory"].pop("incumbents"),
        )
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index), self.assertRaises(ToolError):
                validate_campaign(self._tampered(mutate))

    def test_cli_reports_malformed_campaign_as_json_without_traceback(self) -> None:
        artifact = self._tampered(lambda p: p.__setitem__("contenders", None))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "malformed.json"
            path.write_text(json.dumps(artifact))
            result = subprocess.run(
                [sys.executable, "-B", str(ROOT / "tools/roster-campaign"),
                 "validate", "--campaign", str(path)],
                cwd=ROOT, text=True, capture_output=True, check=False,
            )
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        error = json.loads(result.stderr)["error"]
        self.assertEqual(error["code"], "invalid_campaign")
        self.assertNotIn("Traceback", result.stderr)

    def test_frozen_candidates_bind_row_genes_name_and_creation_checksum(self) -> None:
        generation = generate_candidates(self.prepared)
        frozen = freeze_candidates(self.prepared, generation)
        self.assertEqual(validate_campaign(frozen)["stage"], "candidates_frozen")
        mutations = (
            lambda row: row.__setitem__("creation_checksum", "0" * 64),
            lambda row: row["profile"]["parameters"].__setitem__("bluff_rate", 99),
            lambda row: row.__setitem__("display_name", "Altered Frozen Name"),
            lambda row: row.__setitem__("parent_ids", ["unrecorded_parent"]),
        )
        for index, mutate in enumerate(mutations):
            payload = copy.deepcopy(frozen["payload"])
            mutate(payload["contenders"][10])
            with self.subTest(index=index), self.assertRaises(ToolError):
                validate_campaign(create_artifact("roster_campaign", payload))

    def test_rechecksummed_generation_and_rows_cannot_replace_creation_evidence(self) -> None:
        generation = generate_candidates(self.prepared)
        frozen = freeze_candidates(self.prepared, generation)
        payload = copy.deepcopy(frozen["payload"])
        generated = payload["candidate_generation"]["payload"]
        generated["new_contenders"][0]["display_name"] = "Forged Generated Name"
        payload["candidate_generation"] = create_artifact(payload["candidate_generation"]["type"], generated)
        payload["contenders"][10]["display_name"] = "Forged Generated Name"
        with self.assertRaises(ToolError):
            validate_campaign(create_artifact("roster_campaign", payload))

    def test_legacy_profiles_cannot_enter_competition_or_confirmation(self) -> None:
        def replace_control(p: dict[str, Any]) -> None:
            p["inventory"]["fixed_controls"][0] = copy.deepcopy(p["inventory"]["legacy_profiles"][0])
        def replace_benchmark(p: dict[str, Any]) -> None:
            p["inventory"]["confirmation_benchmarks"][-1] = copy.deepcopy(p["inventory"]["legacy_profiles"][0])
        def replace_contender(p: dict[str, Any]) -> None:
            p["contenders"][0]["profile"] = copy.deepcopy(p["inventory"]["legacy_profiles"][0])
        for index, mutate in enumerate((replace_control, replace_benchmark, replace_contender)):
            with self.subTest(index=index), self.assertRaises(ToolError):
                validate_campaign(self._tampered(mutate))

    def test_protected_controls_cannot_be_counted_as_contenders_or_rejected(self) -> None:
        def append_protected_contender(p: dict[str, Any]) -> None:
            profile = copy.deepcopy(p["inventory"]["fixed_controls"][0])
            p["contenders"].append({
                "candidate_id": profile["profile_id"], "profile": profile,
                "display_name": "Protected control", "origin": "initialized",
                "parent_ids": [], "status": "rejected_round1", "creation_checksum": "0" * 64,
            })
        def mark_control_rejected(p: dict[str, Any]) -> None:
            p["inventory"]["fixed_controls"][0]["status"] = "rejected_round1"
        for index, mutate in enumerate((append_protected_contender, mark_control_rejected)):
            with self.subTest(index=index), self.assertRaises(ToolError):
                validate_campaign(self._tampered(mutate))

    def test_artifact_checksum_tampering_is_rejected(self) -> None:
        artifact = copy.deepcopy(self.prepared)
        artifact["payload"]["config"]["campaign_id"] = "altered_without_rehashing"
        with self.assertRaises(ToolError):
            validate_campaign(artifact)


if __name__ == "__main__":
    unittest.main()
