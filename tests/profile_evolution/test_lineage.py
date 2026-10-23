from __future__ import annotations

import contextlib
import copy
import io
import json
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
from tools.profile_evolution.evolution import (
    crossover_candidates,
    initialize_generation,
    mutate_candidates,
)
from tools.profile_evolution.fitness import COMPONENTS
from tools.profile_evolution.lineage import build_lineage_registry, inspect_lineage
from tools.profile_evolution.selection import select_elites


def _bounds() -> dict[str, dict[str, int]]:
    return {gene: {"minimum": 0, "maximum": 100} for gene in GENES}


def _fitness_for_generation(generation: dict[str, object]) -> dict[str, object]:
    payload = generation["payload"]
    results = []
    for index, candidate in enumerate(payload["candidates"]):
        results.append(
            {
                "candidate": copy.deepcopy(candidate),
                "component_means": {name: 0.5 for name in COMPONENTS},
                "eligible": True,
                "fitness": 1.0 - index / 20.0,
                "ineligibility_reasons": [],
                "plan_sample_counts": {"plan": 20},
                "sample_count": 20,
                "style_checks": {
                    "bounded_behavioral_rates": {"passed": True, "violations": []},
                    "zero_invalid_action_fallbacks": {"passed": True, "value": 0},
                },
                "uncertainty_95_half_width": {name: 0.05 for name in COMPONENTS},
                "uncertainty_penalty": 0.05,
            }
        )
    return create_artifact(
        "fitness",
        {
            "bounds": copy.deepcopy(payload["bounds"]),
            "candidate_results": results,
            "code_revisions": ["revision-a"],
            "evaluation_configuration": {
                "plans": [{"plan_id": "plan"}],
                "regimes": [{"regime_id": "regime"}],
            },
            "generation": payload["generation"],
            "generation_id": payload["generation_id"],
            "plan_ids": ["plan"],
            "regime_ids": ["regime"],
            "report_evidence": [
                {
                    "batch_id": "batch",
                    "code_revision": "revision-a",
                    "command_version": "simulation_cli_v2",
                    "manifest_checksum": "a" * 64,
                    "report_checksum": "b" * 64,
                    "seed_range": {"minimum": 100, "maximum": 119},
                    "shard": {"index": 0, "count": 1},
                }
            ],
            "source_generation_checksum": generation["checksum"],
        },
    )


def _history() -> list[dict[str, object]]:
    initial = initialize_generation(_bounds(), 11, 100)
    fitness = _fitness_for_generation(initial)
    selection = select_elites(fitness, 0.20)
    children = crossover_candidates(validate_selection(selection["payload"]), 4, 101)
    final_generation = mutate_candidates(
        children["payload"],
        {"mutation_probability_percent": 100, "maximum_delta": 5},
        102,
    )
    return [initial, fitness, selection, children, final_generation]


class LineageTests(unittest.TestCase):
    def test_registry_entries_are_complete_for_champions_and_descendants(self) -> None:
        history = _history()
        registry = build_lineage_registry(history)
        entries = registry["payload"]["entries"]
        self.assertEqual(len(entries), 11 + 4 + 4)
        champion = next(entry for entry in entries if entry["selection_history"])
        self.assertTrue(champion["evaluations"])
        evaluation = champion["evaluations"][0]
        for field in (
            "plan_ids",
            "regime_ids",
            "code_revisions",
            "evaluation_configuration",
            "report_evidence",
            "component_means",
            "style_checks",
            "sample_count",
            "uncertainty_95_half_width",
            "uncertainty_penalty",
        ):
            self.assertIn(field, evaluation)
        final_entry = next(
            entry
            for entry in entries
            if entry["creation"]["operation"] == "mutation"
        )
        self.assertEqual(final_entry["generation"], 1)
        self.assertIn("mutations", final_entry["creation"])
        self.assertEqual(final_entry["creation_context"]["tool_version"], "0.1.0")

    def test_missing_parent_and_conflicting_candidate_are_rejected(self) -> None:
        history = _history()
        with self.assertRaisesRegex(ToolError, "missing parent"):
            build_lineage_registry([history[0], history[4]])

        conflicting_payload = copy.deepcopy(history[0]["payload"])
        original_value = conflicting_payload["candidates"][0]["parameters"][GENES[0]]
        conflicting_payload["candidates"][0]["parameters"][GENES[0]] = (
            original_value + 1
        ) % 101
        conflicting = create_artifact("generation_manifest", conflicting_payload)
        with self.assertRaisesRegex(ToolError, "conflicting immutable history"):
            build_lineage_registry([history[0], conflicting])

    def test_registry_rejects_forged_nested_evidence(self) -> None:
        registry = build_lineage_registry(_history())
        champion = next(
            entry for entry in registry["payload"]["entries"] if entry["selection_history"]
        )
        champion["evaluations"][0]["component_means"]["win_score"] = 2.0
        forged = create_artifact("lineage_registry", registry["payload"])
        with self.assertRaises(ToolError):
            inspect_lineage(forged, champion["candidate"]["candidate_id"])

    def test_inspection_returns_ordered_ancestry_and_evidence(self) -> None:
        history = _history()
        registry = build_lineage_registry(history)
        final_candidate = history[4]["payload"]["candidates"][0]
        inspected = inspect_lineage(registry, final_candidate["candidate_id"])
        ancestor_ids = [item["candidate"]["candidate_id"] for item in inspected["ancestors"]]
        self.assertEqual(inspected["candidate"], final_candidate)
        self.assertEqual(len(ancestor_ids), 3)
        self.assertEqual(ancestor_ids[-1], final_candidate["parent_ids"][0])

    def test_registry_and_next_generation_are_repeatable_and_order_independent(self) -> None:
        first_history = _history()
        second_history = _history()
        self.assertEqual(
            canonical_json_bytes(build_lineage_registry(first_history)),
            canonical_json_bytes(build_lineage_registry(reversed(second_history))),
        )
        selection = first_history[2]["payload"]["next_generation_manifest"]
        children = first_history[3]["payload"]
        final_generation = first_history[4]
        self.assertEqual(children["generation_id"], selection["generation_id"])
        self.assertEqual(children["generation"], selection["generation"])
        self.assertEqual(final_generation["type"], "generation_manifest")
        self.assertEqual(final_generation["payload"]["generation_id"], selection["generation_id"])

    def test_build_and_inspect_commands_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            history = _history()
            paths = []
            for index, artifact in enumerate(history):
                path = directory / f"artifact_{index}.json"
                write_artifact_atomic(path, artifact)
                paths.append(path)
            registry_path = directory / "lineage.json"
            arguments = ["build-lineage"]
            for path in reversed(paths):
                arguments.extend(("--artifact", str(path)))
            arguments.extend(("--output", str(registry_path)))
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main(arguments), 0)
            registry = load_json_object(registry_path)
            self.assertEqual(registry["type"], "lineage_registry")

            candidate_id = history[4]["payload"]["candidates"][0]["candidate_id"]
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(
                    main(
                        [
                            "inspect-lineage",
                            "--registry",
                            str(registry_path),
                            "--candidate-id",
                            candidate_id,
                        ]
                    ),
                    0,
                )
            self.assertEqual(json.loads(output.getvalue())["candidate"]["candidate_id"], candidate_id)
