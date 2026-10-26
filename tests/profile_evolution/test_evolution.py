from __future__ import annotations

import copy
import tempfile
import unittest
from pathlib import Path

from tools.profile_evolution.artifacts import (
    canonical_json_bytes,
    create_artifact,
    load_json_object,
    write_artifact_atomic,
)
from tools.profile_evolution.contracts import (
    GENES,
    validate_bounds,
    validate_candidate,
    validate_candidate_collection,
    validate_mutation_policy,
    validate_selection,
)
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.evolution import (
    crossover_candidates,
    initialize_generation,
    mutate_candidates,
)
from tools.profile_evolution.prng import SplitMix64


def full_bounds() -> dict[str, dict[str, int]]:
    return {gene: {"minimum": 0, "maximum": 100} for gene in GENES}


def candidate(candidate_id: str, value: int) -> dict[str, object]:
    return {
        "candidate_id": candidate_id,
        "model_id": "strategy_parameterized",
        "parameters": {gene: value for gene in GENES},
        "parent_ids": [],
    }


def selection_payload(candidates: list[dict[str, object]]) -> dict[str, object]:
    benchmarks = []
    for item in candidates:
        benchmarks.append(
            {
                "candidate": copy.deepcopy(item),
                "component_means": {name: 0.5 for name in ("win_score", "finish_score", "top_third_score", "chip_score", "survival_score", "blind_chip_score")},
                "eligible": True,
                "fitness": 0.5,
                "ineligibility_reasons": [],
                "plan_sample_counts": {"plan": 10},
                "sample_count": 10,
                "style_checks": {},
                "uncertainty_95_half_width": {name: 0.1 for name in ("win_score", "finish_score", "top_third_score", "chip_score", "survival_score", "blind_chip_score")},
                "uncertainty_penalty": 0.1,
            }
        )
    return {
        "bounds": {"genes": full_bounds()},
        "elite_fraction": 0.20,
        "generation_id": "generation_g0",
        "generation": 0,
        "historical_benchmarks": benchmarks,
        "next_generation_manifest": {"generation": 1, "generation_id": "generation_g1"},
        "population_size": max(10, len(candidates)),
        "report_evidence": [
            {
                "batch_id": "batch",
                "code_revision": "abc123",
                "command_version": "simulation_cli_v4",
                "manifest_checksum": "a" * 64,
                "report_checksum": "b" * 64,
                "seed_range": {"minimum": 100, "maximum": 109},
                "shard": {"index": 0, "count": 1},
            }
        ],
        "retained_count": len(candidates),
        "selected_candidates": candidates,
        "source_fitness_checksum": "0" * 64,
    }


class PrngTests(unittest.TestCase):
    def test_splitmix64_has_fixed_reference_sequence(self) -> None:
        random = SplitMix64(0)
        self.assertEqual(random.next_u64(), 0xE220A8397B1DCDAF)
        self.assertEqual(random.next_u64(), 0x6E789E6AA1B965F4)


class ContractTests(unittest.TestCase):
    def test_bounds_require_exact_four_genes_and_integer_range(self) -> None:
        payload = {"genes": full_bounds()}
        self.assertEqual(validate_bounds(payload), full_bounds())
        for invalid in (
            {"genes": {**full_bounds(), "extra": {"minimum": 0, "maximum": 1}}},
            {"genes": {**full_bounds(), "bluff_rate": {"minimum": 0.5, "maximum": 100}}},
            {"genes": {**full_bounds(), "bluff_rate": {"minimum": 101, "maximum": 100}}},
        ):
            with self.subTest(invalid=invalid), self.assertRaises(ToolError):
                validate_bounds(invalid)

    def test_candidate_rejects_unknown_missing_fractional_and_out_of_range_genes(self) -> None:
        valid = candidate("candidate_a", 50)
        invalid_candidates = []
        unknown = copy.deepcopy(valid)
        unknown["parameters"]["unknown"] = 1  # type: ignore[index]
        invalid_candidates.append(unknown)
        missing = copy.deepcopy(valid)
        del missing["parameters"]["bluff_rate"]  # type: ignore[index]
        invalid_candidates.append(missing)
        fractional = copy.deepcopy(valid)
        fractional["parameters"]["bluff_rate"] = 1.5  # type: ignore[index]
        invalid_candidates.append(fractional)
        out_of_range = copy.deepcopy(valid)
        out_of_range["parameters"]["bluff_rate"] = 101  # type: ignore[index]
        invalid_candidates.append(out_of_range)
        for invalid in invalid_candidates:
            with self.subTest(invalid=invalid), self.assertRaises(ToolError):
                validate_candidate(invalid)

    def test_policy_is_strict_and_bounded(self) -> None:
        valid = {"mutation_probability_percent": 25, "maximum_delta": 10}
        self.assertEqual(validate_mutation_policy(valid), valid)
        for invalid in (
            {**valid, "extra": 1},
            {**valid, "mutation_probability_percent": -1},
            {**valid, "maximum_delta": 101},
        ):
            with self.subTest(invalid=invalid), self.assertRaises(ToolError):
                validate_mutation_policy(invalid)

    def test_candidate_collection_rejects_unknown_provenance_fields(self) -> None:
        payload = initialize_generation(full_bounds(), 1, 1)["payload"]
        payload["creation_records"][0]["unknown"] = True
        with self.assertRaises(ToolError):
            validate_candidate_collection(payload)

    def test_candidate_collection_rejects_forged_mutation_result(self) -> None:
        source = initialize_generation(full_bounds(), 1, 8)["payload"]
        mutated = mutate_candidates(
            source, {"mutation_probability_percent": 100, "maximum_delta": 5}, 9
        )["payload"]
        mutated["creation_records"][0]["mutations"][0]["after"] = 100
        with self.assertRaises(ToolError):
            validate_candidate_collection(mutated)


class EvolutionTests(unittest.TestCase):
    def test_generation_accepts_more_than_product_strategic_roster_capacity(self) -> None:
        generation = initialize_generation(full_bounds(), 26, 42)

        validated = validate_candidate_collection(generation["payload"])
        self.assertEqual(len(validated["candidates"]), 26)

    def test_identity_includes_population_and_operation_seeds(self) -> None:
        bounds = full_bounds()
        small = initialize_generation(bounds, 2, 9)
        large = initialize_generation(bounds, 3, 9)
        self.assertNotEqual(
            small["payload"]["generation_id"], large["payload"]["generation_id"]
        )

        first_selection = validate_selection(
            selection_payload([candidate("parent_a", 10), candidate("parent_b", 90)])
        )
        first = crossover_candidates(first_selection, 2, 11)
        second = crossover_candidates(first_selection, 2, 12)
        self.assertNotEqual(
            [item["candidate_id"] for item in first["payload"]["candidates"]],
            [item["candidate_id"] for item in second["payload"]["candidates"]],
        )
        policy = {"mutation_probability_percent": 0, "maximum_delta": 0}
        first_mutation = mutate_candidates(first["payload"], policy, 20)
        second_mutation = mutate_candidates(first["payload"], policy, 21)
        self.assertNotEqual(
            [item["candidate_id"] for item in first_mutation["payload"]["candidates"]],
            [item["candidate_id"] for item in second_mutation["payload"]["candidates"]],
        )

    def test_initialization_is_deterministic_ordered_and_within_bounds(self) -> None:
        bounds = {
            gene: {"minimum": index * 10, "maximum": index * 10 + 3}
            for index, gene in enumerate(GENES)
        }
        first = initialize_generation(bounds, 8, 42)
        second = initialize_generation(bounds, 8, 42)
        self.assertEqual(canonical_json_bytes(first), canonical_json_bytes(second))
        validate_candidate_collection(first["payload"])
        candidates = first["payload"]["candidates"]
        self.assertEqual(len(candidates), 8)
        self.assertEqual(len({item["candidate_id"] for item in candidates}), 8)
        for item in candidates:
            self.assertEqual(item["parent_ids"], [])
            for gene in GENES:
                self.assertGreaterEqual(item["parameters"][gene], bounds[gene]["minimum"])
                self.assertLessEqual(item["parameters"][gene], bounds[gene]["maximum"])

    def test_identical_initialization_writes_byte_equivalent_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            first_path = Path(directory) / "first.json"
            second_path = Path(directory) / "second.json"
            write_artifact_atomic(first_path, initialize_generation(full_bounds(), 3, 9))
            write_artifact_atomic(second_path, initialize_generation(full_bounds(), 3, 9))
            self.assertEqual(first_path.read_bytes(), second_path.read_bytes())

    def test_crossover_is_deterministic_records_sources_and_does_not_mutate_selection(self) -> None:
        selection = validate_selection(
            selection_payload([candidate("parent_a", 10), candidate("parent_b", 90)])
        )
        original = copy.deepcopy(selection)
        first = crossover_candidates(selection, 5, 123)
        second = crossover_candidates(selection, 5, 123)
        self.assertEqual(first, second)
        self.assertEqual(selection, original)
        validate_candidate_collection(first["payload"])
        for child, record in zip(
            first["payload"]["candidates"], first["payload"]["creation_records"]
        ):
            self.assertEqual(len(child["parent_ids"]), 2)
            self.assertEqual(record["parent_ids"], child["parent_ids"])
            for gene in GENES:
                source = record["gene_sources"][gene]
                self.assertIn(source, child["parent_ids"])
                expected = 10 if source == "parent_a" else 90
                self.assertEqual(child["parameters"][gene], expected)

    def test_crossover_requires_two_parents(self) -> None:
        with self.assertRaises(ToolError):
            validate_selection(selection_payload([candidate("only_parent", 10)]))

    def test_mutation_records_every_gene_clamps_and_preserves_source(self) -> None:
        source_artifact = initialize_generation(full_bounds(), 2, 7)
        source = source_artifact["payload"]
        source["candidates"][0]["parameters"] = {gene: 0 for gene in GENES}
        source["candidates"][1]["parameters"] = {gene: 100 for gene in GENES}
        original = copy.deepcopy(source)
        policy = {"mutation_probability_percent": 100, "maximum_delta": 100}
        first = mutate_candidates(source, policy, 2)
        second = mutate_candidates(source, policy, 2)
        self.assertEqual(first, second)
        self.assertEqual(source, original)
        validate_candidate_collection(first["payload"])
        mutation_records = first["payload"]["creation_records"]
        self.assertTrue(
            any(change["clamped"] for record in mutation_records for change in record["mutations"])
        )
        for record in mutation_records:
            self.assertEqual([change["gene"] for change in record["mutations"]], list(GENES))
            for change in record["mutations"]:
                self.assertEqual(change["seed"], 2)
                self.assertEqual(
                    change["after"], min(100, max(0, change["before"] + change["delta"]))
                )

    def test_artifact_contracts_can_be_persisted_as_strict_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bounds.json"
            artifact = create_artifact("gene_bounds", {"genes": full_bounds()})
            write_artifact_atomic(path, artifact)
            self.assertEqual(load_json_object(path), artifact)
