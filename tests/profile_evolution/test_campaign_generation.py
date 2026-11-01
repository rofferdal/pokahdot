"""Fresh-checkout campaign generation and archival-parent mutation safeguards."""
from __future__ import annotations

import copy
import unittest
from unittest.mock import patch

from tools.profile_evolution.artifacts import create_artifact, validate_artifact_envelope
from tools.profile_evolution.campaign_generation import generate_candidates, validate_candidate_generation
from tools.profile_evolution.contracts import GENES, validate_candidate_collection
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.evolution import initialize_generation
from tests.profile_evolution.test_campaign import _prepared_campaign


class CampaignGenerationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.campaign = _prepared_campaign()
        cls.generation = generate_candidates(cls.campaign)

    def test_reproducible_twenty_new_candidates_and_broad_coverage(self) -> None:
        self.assertEqual(self.generation, generate_candidates(copy.deepcopy(self.campaign)))
        context = validate_candidate_generation(self.generation, self.campaign)
        rows = context["new_contenders"]
        self.assertEqual(20, len(rows))
        self.assertEqual(["initialized"] * 10 + ["mutated"] * 10, [r["origin"] for r in rows])
        source = validate_candidate_collection(context["initialized_generation"]["payload"])
        for gene in GENES:
            values = [c["parameters"][gene] for c in source["candidates"]]
            self.assertLessEqual(min(values), 25)
            self.assertGreaterEqual(max(values), 75)
        for row in rows:
            self.assertEqual(row["candidate_id"], row["profile"]["profile_id"])
            self.assertEqual("active", row["status"])

    def test_names_vectors_and_benchmark_diversity(self) -> None:
        rows = self.generation["payload"]["new_contenders"]
        incumbents = self.campaign["payload"]["contenders"]
        all_rows = incumbents + rows
        self.assertEqual(30, len({r["display_name"].casefold() for r in all_rows}))
        vectors = [tuple(r["profile"]["parameters"][g] for g in GENES) for r in all_rows]
        self.assertEqual(30, len(set(vectors)))
        for row in rows:
            for benchmark in self.campaign["payload"]["inventory"]["confirmation_benchmarks"]:
                if benchmark["model_id"] == "strategy_parameterized":
                    self.assertGreaterEqual(sum(abs(row["profile"]["parameters"][g] - benchmark["parameters"][g]) for g in GENES), 10)
        self.assertEqual(20, len(self.generation["payload"]["labels"]))

    def test_descendants_bind_actual_incumbents_without_fabricated_selection(self) -> None:
        context = self.generation["payload"]
        incumbents = self.campaign["payload"]["contenders"]
        for parent, row, mutation in zip(incumbents, context["new_contenders"][10:], context["mutation_records"]):
            validate_artifact_envelope(mutation, "campaign_mutation_v1")
            payload = mutation["payload"]
            self.assertEqual(self.campaign["checksum"], payload["prepared_campaign_checksum"])
            self.assertEqual(parent["candidate_id"], payload["parent_id"])
            self.assertEqual(parent["profile"], payload["parent_snapshot"])
            self.assertEqual([parent["candidate_id"]], row["parent_ids"])
            self.assertEqual(mutation["checksum"], row["creation_checksum"])
            self.assertNotIn("selection", payload)
            for record in payload["gene_records"]:
                self.assertEqual(parent["profile"]["parameters"][record["gene"]], record["before"])
                self.assertEqual(min(100, max(0, record["before"] + record["requested_delta"])), record["after"])
                self.assertEqual(row["profile"]["parameters"][record["gene"]], record["after"])
        for row in context["new_contenders"][:10]:
            self.assertEqual(context["initialized_generation"]["checksum"], row["creation_checksum"])

    def test_resealed_gene_name_parent_attempt_and_binding_tampering_fail(self) -> None:
        mutations = (
            lambda p: p["new_contenders"][0]["profile"]["parameters"].__setitem__("bluff_rate", 101),
            lambda p: p["new_contenders"][0].__setitem__("display_name", "Tampered Name"),
            lambda p: p["new_contenders"][10].__setitem__("parent_ids", []),
            lambda p: p["new_contenders"][10].__setitem__("creation_checksum", "0" * 64),
            lambda p: p["mutation_attempts"][0].__setitem__("seed", 1),
            lambda p: p["labels"][0].__setitem__("name_explanation", "Fabricated lineage"),
            lambda p: p.__setitem__("prepared_campaign_checksum", "0" * 64),
        )
        for index, mutate in enumerate(mutations):
            payload = copy.deepcopy(self.generation["payload"])
            mutate(payload)
            with self.subTest(index=index), self.assertRaises(ToolError):
                validate_candidate_generation(create_artifact(self.generation["type"], payload), self.campaign)

    def test_initialization_retry_records_rejected_attempts(self) -> None:
        def insufficient_then_real(bounds, count, seed):
            generation = initialize_generation(bounds, count, seed)
            if seed == self.campaign["payload"]["config"]["generation_seed"]:
                for candidate in generation["payload"]["candidates"]:
                    candidate["parameters"] = {g: 50 for g in GENES}
                generation = create_artifact(generation["type"], generation["payload"])
            return generation
        with patch("tools.profile_evolution.campaign_generation.initialize_generation", side_effect=insufficient_then_real):
            generated = generate_candidates(self.campaign)
            attempts = generated["payload"]["initialization_attempts"]
            self.assertGreaterEqual(len(attempts), 2)
            self.assertIn("insufficient_broad_gene_coverage", attempts[0]["rejection_reasons"])
            self.assertEqual([], attempts[-1]["rejection_reasons"])
            validate_candidate_generation(generated, self.campaign)

    def test_bounded_mutation_retry_exhaustion_fails_without_candidates(self) -> None:
        class ZeroDeltas:
            def __init__(self, seed):
                pass

            def integer(self, minimum, maximum):
                return 0
        with patch("tools.profile_evolution.campaign_generation.SplitMix64", ZeroDeltas):
            with self.assertRaisesRegex(ToolError, "mutation attempts exhausted"):
                generate_candidates(self.campaign)

    def test_changed_prepared_campaign_binding_is_rejected(self) -> None:
        payload = copy.deepcopy(self.campaign["payload"])
        payload["config"]["campaign_id"] = "different_campaign"
        different = create_artifact(self.campaign["type"], payload)
        with self.assertRaises(ToolError):
            validate_candidate_generation(self.generation, different)


if __name__ == "__main__":
    unittest.main()
