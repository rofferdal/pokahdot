from __future__ import annotations

import contextlib
import copy
import io
import tempfile
import unittest
from pathlib import Path

from tools.profile_evolution.artifacts import (
    canonical_json_bytes,
    create_artifact,
    load_json_object,
    write_artifact_atomic,
)
from tools.profile_evolution.cli import main
from tools.profile_evolution.contracts import GENES, validate_selection
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.fitness import COMPONENTS
from tools.profile_evolution.selection import select_elites


def fitness_artifact(
    population_size: int,
    scores: dict[str, float] | None = None,
    ineligible_ids: set[str] | None = None,
) -> dict[str, object]:
    score_values = scores or {}
    ineligible = ineligible_ids or set()
    results = []
    for index in range(population_size):
        candidate_id = f"candidate_{index:03d}"
        eligible = candidate_id not in ineligible
        results.append(
            {
                "candidate": {
                    "candidate_id": candidate_id,
                    "model_id": "strategy_parameterized",
                    "parameters": {gene: index % 101 for gene in GENES},
                    "parent_ids": [],
                },
                "component_means": {name: 0.5 for name in COMPONENTS},
                "eligible": eligible,
                "fitness": score_values.get(candidate_id, 0.5) if eligible else None,
                "ineligibility_reasons": [] if eligible else ["insufficient_samples:plan"],
                "plan_sample_counts": {"plan": 10},
                "sample_count": 10,
                "style_checks": {
                    "bounded_behavioral_rates": {"passed": True, "violations": []},
                    "zero_invalid_action_fallbacks": {"passed": True, "value": 0},
                },
                "uncertainty_95_half_width": {name: 0.1 for name in COMPONENTS},
                "uncertainty_penalty": 0.1,
            }
        )
    return create_artifact(
        "fitness",
        {
            "bounds": {
                "genes": {
                    gene: {"minimum": 0, "maximum": 100} for gene in GENES
                }
            },
            "candidate_results": results,
            "code_revisions": ["abc123"],
            "evaluation_configuration": {"plans": [], "regimes": []},
            "generation": 0,
            "generation_id": "generation_g0",
            "plan_ids": ["plan"],
            "regime_ids": ["regime"],
            "report_evidence": [
                {
                    "batch_id": "batch",
                    "code_revision": "abc123",
                    "command_version": "simulation_cli_v2",
                    "manifest_checksum": "a" * 64,
                    "report_checksum": "b" * 64,
                    "seed_range": {"minimum": 100, "maximum": 109},
                    "shard": {"index": 0, "count": 1},
                }
            ],
            "source_generation_checksum": "c" * 64,
        },
    )


class SelectionTests(unittest.TestCase):
    def test_retained_count_uses_ceiling_and_boundary_fractions(self) -> None:
        artifact = fitness_artifact(11)
        lower = select_elites(artifact, 0.10)
        upper = select_elites(artifact, 0.20)
        self.assertEqual(lower["payload"]["retained_count"], 2)
        self.assertEqual(upper["payload"]["retained_count"], 3)
        self.assertEqual(validate_selection(lower["payload"])["generation"], 1)

    def test_selection_orders_by_fitness_then_stable_candidate_id(self) -> None:
        scores = {
            "candidate_009": 0.9,
            "candidate_003": 0.8,
            "candidate_001": 0.8,
            "candidate_000": 0.1,
        }
        selected = select_elites(fitness_artifact(11, scores), 0.20)
        ids = [
            item["candidate_id"] for item in selected["payload"]["selected_candidates"]
        ]
        self.assertEqual(ids, ["candidate_009", "candidate_001", "candidate_003"])

    def test_ineligible_candidates_are_never_selected(self) -> None:
        scores = {"candidate_000": 1.0, "candidate_001": 0.9, "candidate_002": 0.8}
        artifact = fitness_artifact(11, scores, {"candidate_000"})
        selected = select_elites(artifact, 0.10)
        ids = [item["candidate_id"] for item in selected["payload"]["selected_candidates"]]
        self.assertNotIn("candidate_000", ids)

    def test_too_few_parents_or_eligible_candidates_are_rejected(self) -> None:
        with self.assertRaisesRegex(ToolError, "fewer than two"):
            select_elites(fitness_artifact(10), 0.10)
        with self.assertRaisesRegex(ToolError, "too few eligible"):
            select_elites(
                fitness_artifact(11, ineligible_ids={f"candidate_{index:03d}" for index in range(10)}),
                0.20,
            )

    def test_fraction_and_source_artifact_checksum_are_strict(self) -> None:
        artifact = fitness_artifact(20)
        for fraction in (0.099, 0.201, float("nan")):
            with self.subTest(fraction=fraction), self.assertRaises(ToolError):
                select_elites(artifact, fraction)
        tampered = copy.deepcopy(artifact)
        tampered["payload"]["generation"] = 2
        with self.assertRaisesRegex(ToolError, "checksum"):
            select_elites(tampered, 0.10)

    def test_selection_is_deterministic_and_snapshots_full_benchmark_evidence(self) -> None:
        artifact = fitness_artifact(11)
        original = copy.deepcopy(artifact)
        first = select_elites(artifact, 0.20)
        second = select_elites(artifact, 0.20)
        self.assertEqual(canonical_json_bytes(first), canonical_json_bytes(second))
        self.assertEqual(artifact, original)
        self.assertEqual(
            first["payload"]["historical_benchmarks"][0],
            original["payload"]["candidate_results"][0],
        )
        self.assertEqual(first["payload"]["report_evidence"], original["payload"]["report_evidence"])

    def test_select_command_writes_crossover_compatible_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            source = directory / "fitness.json"
            output = directory / "selection.json"
            write_artifact_atomic(source, fitness_artifact(11))
            with contextlib.redirect_stdout(io.StringIO()):
                result = main(
                    [
                        "select",
                        "--fitness",
                        str(source),
                        "--elite-fraction",
                        "0.20",
                        "--output",
                        str(output),
                    ]
                )
            self.assertEqual(result, 0)
            selection = load_json_object(output)
            self.assertEqual(selection["type"], "selection")
            self.assertEqual(len(validate_selection(selection["payload"])["selected_candidates"]), 3)
