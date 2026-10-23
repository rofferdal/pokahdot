from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from tools.profile_evolution.artifacts import (
    create_artifact,
    load_json_object,
    write_artifact_atomic,
)
from tools.profile_evolution.cli import build_parser, main
from tools.profile_evolution.contracts import GENES


class CliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.parser = build_parser()

    def test_all_command_contracts_parse(self) -> None:
        cases = (
            ["init-generation", "--bounds", "b.json", "--population-size", "8", "--seed", "0", "--output", "g.json"],
            ["evaluate-fitness", "--generation", "g.json", "--report", "r1.json", "--report", "r2.json", "--output", "f.json"],
            ["select", "--fitness", "f.json", "--elite-fraction", "0.15", "--output", "s.json"],
            ["crossover", "--selection", "s.json", "--seed", "2", "--target-count", "10", "--output", "c.json"],
            ["mutate", "--input", "c.json", "--seed", "3", "--policy", "p.json", "--output", "m.json"],
            ["build-lineage", "--artifact", "g.json", "--artifact", "f.json", "--output", "l.json"],
            ["inspect-lineage", "--registry", "l.json", "--candidate-id", "c1"],
            ["confirm-candidate", "--registry", "l.json", "--candidate-id", "c1", "--legacy-id", "legacy", "--historical-champion-id", "champion", "--mirrored-report", "heads.json", "--mixed-report", "mixed.json", "--output", "confirmation.json"],
            ["export-candidates", "--registry", "l.json", "--confirmation", "confirmation.json", "--candidate-id", "c1", "--output", "e.json"],
        )
        for arguments in cases:
            with self.subTest(command=arguments[0]):
                self.assertEqual(self.parser.parse_args(arguments).command, arguments[0])

    def test_missing_required_and_unknown_arguments_are_exit_two(self) -> None:
        for arguments in (["select"], ["select", "--unknown"]):
            with self.subTest(arguments=arguments):
                with contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(main(arguments), 2)

    def test_elite_fraction_range_is_enforced(self) -> None:
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(
                main(["select", "--fitness", "x", "--elite-fraction", "0.21", "--output", "y"]),
                2,
            )

    def test_seed_must_fit_unsigned_64_bit_range(self) -> None:
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(
                main(
                    [
                        "init-generation",
                        "--bounds",
                        "bounds.json",
                        "--population-size",
                        "1",
                        "--seed",
                        str(1 << 64),
                        "--output",
                        "generation.json",
                    ]
                ),
                2,
            )

    def test_output_must_be_json_and_must_not_target_roster(self) -> None:
        for output in ("candidate.tres", "playable_roster.json"):
            with self.subTest(output=output), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(
                    main(
                        [
                            "init-generation",
                            "--bounds",
                            "bounds.json",
                            "--population-size",
                            "4",
                            "--seed",
                            "1",
                            "--output",
                            output,
                        ]
                    ),
                    2,
                )

    def test_missing_input_is_io_exit_three(self) -> None:
        error_output = io.TextIOWrapper(io.BytesIO(), encoding="utf-8")
        with contextlib.redirect_stderr(error_output):
            result = main(
                ["inspect-lineage", "--registry", "missing.json", "--candidate-id", "c1"]
            )
        self.assertEqual(result, 3)

    def test_generation_crossover_and_mutation_commands_write_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as directory_name:
            directory = Path(directory_name)
            bounds_path = directory / "bounds.json"
            bounds_payload = {
                "genes": {
                    gene: {"minimum": 0, "maximum": 100} for gene in GENES
                }
            }
            bounds_path.write_text(json.dumps(bounds_payload), encoding="utf-8")
            generation_path = directory / "generation.json"
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(
                    main(
                        [
                            "init-generation",
                            "--bounds",
                            str(bounds_path),
                            "--population-size",
                            "3",
                            "--seed",
                            "44",
                            "--output",
                            str(generation_path),
                        ]
                    ),
                    0,
                )
            generation = load_json_object(generation_path)
            self.assertEqual(generation["type"], "generation_manifest")

            selection_path = directory / "selection.json"
            generation_payload = generation["payload"]
            selected = generation_payload["candidates"][:2]
            components = (
                "win_score",
                "finish_score",
                "top_third_score",
                "chip_score",
                "survival_score",
                "blind_chip_score",
            )
            selection_payload = {
                "generation_id": generation_payload["generation_id"],
                "generation": generation_payload["generation"],
                "bounds": generation_payload["bounds"],
                "elite_fraction": 0.20,
                "historical_benchmarks": [
                    {
                        "candidate": candidate,
                        "component_means": {name: 0.5 for name in components},
                        "eligible": True,
                        "fitness": 0.5,
                        "ineligibility_reasons": [],
                        "plan_sample_counts": {"plan": 10},
                        "sample_count": 10,
                        "style_checks": {},
                        "uncertainty_95_half_width": {name: 0.1 for name in components},
                        "uncertainty_penalty": 0.1,
                    }
                    for candidate in selected
                ],
                "next_generation_manifest": {
                    "generation": 1,
                    "generation_id": "generation_g1",
                },
                "population_size": 10,
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
                "retained_count": 2,
                "selected_candidates": selected,
                "source_fitness_checksum": "0" * 64,
            }
            write_artifact_atomic(
                selection_path, create_artifact("selection", selection_payload)
            )
            crossover_path = directory / "crossover.json"
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(
                    main(
                        [
                            "crossover",
                            "--selection",
                            str(selection_path),
                            "--seed",
                            "45",
                            "--target-count",
                            "4",
                            "--output",
                            str(crossover_path),
                        ]
                    ),
                    0,
                )
            self.assertEqual(load_json_object(crossover_path)["type"], "candidate_batch")

            policy_path = directory / "policy.json"
            policy_path.write_text(
                json.dumps(
                    {"mutation_probability_percent": 50, "maximum_delta": 10}
                ),
                encoding="utf-8",
            )
            mutation_path = directory / "mutation.json"
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(
                    main(
                        [
                            "mutate",
                            "--input",
                            str(crossover_path),
                            "--seed",
                            "46",
                            "--policy",
                            str(policy_path),
                            "--output",
                            str(mutation_path),
                        ]
                    ),
                    0,
                )
            mutation = load_json_object(mutation_path)
            self.assertEqual(mutation["type"], "generation_manifest")
            self.assertEqual(len(mutation["payload"]["candidates"]), 4)
