from __future__ import annotations

import copy
import contextlib
import io
import json
import math
import tempfile
import unittest
from pathlib import Path

from tools.profile_evolution.artifacts import canonical_json_bytes, write_artifact_atomic
from tools.profile_evolution.contracts import GENES
from tools.profile_evolution.cli import main
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.evolution import initialize_generation
from tools.profile_evolution.fitness import (
    _roster_provenance,
    _simulation_manifest_checksum,
    evaluate_fitness,
)


def _bounds() -> dict[str, dict[str, int]]:
    return {gene: {"minimum": 0, "maximum": 100} for gene in GENES}


def _profile_result(
    profile_id: str,
    seat: int,
    won: bool,
    player_count: int,
    starting_stack: int,
    invalid_fallbacks: int = 0,
) -> dict[str, object]:
    finishing_position = 1 if won else 2
    final_stack = player_count * starting_stack if won else 0
    differential = final_stack - starting_stack
    return {
        "seat": seat,
        "profile_id": profile_id,
        "finishing_position": finishing_position,
        "won_tournament": won,
        "top_third": won,
        "starting_stack": starting_stack,
        "final_stack": final_stack,
        "chip_differential": differential,
        "hands_survived": 1,
        "tournament_hand_count": 1,
        "survival_ratio": 1.0,
        "blind_normalized_chip_sum": 2.0 if won else -2.0,
        "hands_observed": 1,
        "bnc_per_100": 200.0 if won else -200.0,
        "vpip_hands": 1,
        "vpip_rate": 1.0,
        "pfr_hands": 0,
        "pfr_rate": 0.0,
        "bet_actions": 0,
        "raise_actions": 0,
        "aggressive_actions": 0,
        "call_actions": 1,
        "aggression_factor": 0.0,
        "bet_raise_opportunities": 1,
        "bet_raise_frequency": 0.0,
        "check_bet_opportunities": 1,
        "bets_at_check_bet_opportunity": 0,
        "bet_frequency": 0.0,
        "call_raise_opportunities": 1,
        "calls_at_call_raise_opportunity": 1,
        "raises_at_call_raise_opportunity": 0,
        "raise_share": 0.0,
        "eligible_bluff_opportunities": 1,
        "bluff_actions": 0,
        "eligible_bluff_frequency": 0.0,
        "invalid_action_fallbacks": invalid_fallbacks,
    }


def _case(
    directory: Path,
    minimum_samples: int = 2,
    regime_stacks: tuple[int, ...] = (20,),
    shard_count: int = 1,
) -> tuple[dict[str, object], list[Path]]:
    generation = initialize_generation(_bounds(), 2, 14)
    candidates = generation["payload"]["candidates"]
    profiles = [
        {
            "profile_id": item["candidate_id"],
            "model_id": item["model_id"],
            "parameters": copy.deepcopy(item["parameters"]),
        }
        for item in candidates
    ]
    regimes = []
    matchups = []
    plans = []
    for index, stack in enumerate(regime_stacks):
        regimes.append(
            {
                "regime_id": f"regime_{index}",
                "player_count": 2,
                "starting_stack": stack,
                "starting_small_blind": 5,
                "starting_big_blind": 10,
                "blind_progression": "normative_hand_based_v1",
            }
        )
        matchups.append(
            {
                "matchup_id": f"matchup_{index}",
                "profile_ids": [item["candidate_id"] for item in candidates],
            }
        )
        plans.append(
            {
                "plan_id": f"plan_{index}",
                "regime_id": f"regime_{index}",
                "matchup_ids": [f"matchup_{index}"],
                "tournament_count": 2,
                "seat_rotation": "cyclic",
                "minimum_profile_samples": minimum_samples,
                "uncertainty_estimator": "normal_95",
            }
        )
    manifest = {
        "schema_version": 2,
        "batch_id": "fitness_test",
        "seed_start": 1000,
        "profiles": profiles,
        "regimes": regimes,
        "matchups": matchups,
        "evaluation_plans": plans,
    }
    tournaments = []
    global_index = 0
    for plan_index, plan in enumerate(plans):
        stack = regimes[plan_index]["starting_stack"]
        for local_index in range(2):
            rotation = local_index % 2
            seat_ids = [
                candidates[(seat + rotation) % 2]["candidate_id"] for seat in range(2)
            ]
            winner_id = candidates[local_index % 2]["candidate_id"]
            tournaments.append(
                {
                    "tournament_index": global_index,
                    "plan_id": plan["plan_id"],
                    "plan_tournament_index": local_index,
                    "regime_id": plan["regime_id"],
                    "matchup_id": f"matchup_{plan_index}",
                    "matchup_occurrence": local_index,
                    "rotation": rotation,
                    "effective_seed": 1000 + global_index,
                    "seat_map": [
                        {"seat": seat, "profile_id": profile_id}
                        for seat, profile_id in enumerate(seat_ids)
                    ],
                    "selected_profile_ids": seat_ids,
                    "termination_reason": "winner",
                    "winner_profile_id": winner_id,
                    "tournament_hand_count": 1,
                    "profile_results": [
                        _profile_result(
                            profile_id,
                            seat,
                            profile_id == winner_id,
                            2,
                            stack,
                        )
                        for seat, profile_id in enumerate(seat_ids)
                    ],
                    "diagnostics": [],
                }
            )
            global_index += 1
    reports: list[Path] = []
    for shard_index in range(shard_count):
        report = {
            "report_schema_version": 3,
            "manifest": copy.deepcopy(manifest),
            "manifest_checksum": _simulation_manifest_checksum(manifest),
            "roster": _roster_provenance(manifest),
            "code_revision": "abc123",
            "command_version": "simulation_cli_v4",
            "shard": {"index": shard_index, "count": shard_count},
            "started_at": "2026-01-01T00:00:00",
            "finished_at": "2026-01-01T00:01:00",
            "tournaments": [
                item for item in tournaments if item["tournament_index"] % shard_count == shard_index
            ],
            "aggregates": {},
            "traces": [{"ignored": "recipient-safe trace"}],
        }
        path = directory / f"report_{shard_index}.json"
        path.write_text(json.dumps(report, separators=(",", ":")), encoding="utf-8")
        reports.append(path)
    return generation, reports


class FitnessTests(unittest.TestCase):
    def test_roster_provenance_matches_the_cross_language_fixture(self) -> None:
        fixture = json.loads(
            Path("tests/fixtures/roster_provenance_v1.json").read_text(encoding="utf-8")
        )
        self.assertEqual(
            _roster_provenance({"profiles": fixture["profiles"]}),
            {"version": fixture["version"], "profile_ids": fixture["profile_ids"]},
        )

    def test_manifest_checksum_matches_godot_fixture(self) -> None:
        fixture = json.loads(
            Path("tests/fixtures/simulation_report_v2.json").read_text(encoding="utf-8")
        )
        self.assertEqual(
            _simulation_manifest_checksum(fixture["manifest"]),
            fixture["manifest_checksum"],
        )

    def test_evaluate_fitness_command_writes_fitness_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            generation, reports = _case(directory)
            generation_path = directory / "generation.json"
            output_path = directory / "fitness.json"
            write_artifact_atomic(generation_path, generation)
            with contextlib.redirect_stdout(io.StringIO()):
                result = main(
                    [
                        "evaluate-fitness",
                        "--generation",
                        str(generation_path),
                        "--report",
                        str(reports[0]),
                        "--output",
                        str(output_path),
                    ]
                )
            self.assertEqual(result, 0)
            self.assertEqual(json.loads(output_path.read_text(encoding="utf-8"))["type"], "fitness")

    def test_formula_means_normal_uncertainty_and_penalty(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            generation, reports = _case(Path(name))
            artifact = evaluate_fitness(generation, reports)
        result = artifact["payload"]["candidate_results"][0]
        self.assertTrue(result["eligible"])
        self.assertEqual(result["sample_count"], 2)
        self.assertEqual(result["component_means"]["win_score"], 0.5)
        self.assertEqual(result["component_means"]["survival_score"], 1.0)
        self.assertAlmostEqual(result["uncertainty_95_half_width"]["win_score"], 0.98)
        self.assertEqual(result["uncertainty_penalty"], 0.10)
        self.assertAlmostEqual(result["fitness"], 0.45)

    def test_mixed_regimes_are_normalized_per_observation(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            generation, reports = _case(Path(name), regime_stacks=(20, 1000))
            artifact = evaluate_fitness(generation, reports)
        self.assertEqual(artifact["payload"]["regime_ids"], ["regime_0", "regime_1"])
        for result in artifact["payload"]["candidate_results"]:
            self.assertEqual(result["sample_count"], 4)
            self.assertEqual(result["component_means"]["chip_score"], 0.5)

    def test_insufficient_samples_are_ineligible_and_not_ranked(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            generation, reports = _case(Path(name), minimum_samples=3)
            artifact = evaluate_fitness(generation, reports)
        result = artifact["payload"]["candidate_results"][0]
        self.assertFalse(result["eligible"])
        self.assertIsNone(result["fitness"])
        self.assertEqual(result["ineligibility_reasons"], ["insufficient_samples:plan_0"])
        self.assertNotIn("rank", result)

    def test_candidate_snapshot_mismatch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            generation, reports = _case(directory)
            report = json.loads(reports[0].read_text(encoding="utf-8"))
            report["manifest"]["profiles"][0]["parameters"][GENES[0]] += 1
            report["manifest_checksum"] = _simulation_manifest_checksum(report["manifest"])
            report["roster"] = _roster_provenance(report["manifest"])
            reports[0].write_text(json.dumps(report), encoding="utf-8")
            with self.assertRaisesRegex(ToolError, "Manifest snapshot"):
                evaluate_fitness(generation, reports)

    def test_manifest_checksum_and_command_version_are_rejected(self) -> None:
        for field, value in (
            ("manifest_checksum", "0" * 64),
            ("command_version", "simulation_cli_v3"),
        ):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as name:
                directory = Path(name)
                generation, reports = _case(directory)
                report = json.loads(reports[0].read_text(encoding="utf-8"))
                report[field] = value
                reports[0].write_text(json.dumps(report), encoding="utf-8")
                with self.assertRaises(ToolError):
                    evaluate_fitness(generation, reports)

    def test_duplicate_and_incomplete_shards_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            generation, reports = _case(Path(name), shard_count=2)
            with self.assertRaisesRegex(ToolError, "every shard"):
                evaluate_fitness(generation, [reports[0], reports[0]])
            with self.assertRaisesRegex(ToolError, "every shard"):
                evaluate_fitness(generation, [reports[0]])

    def test_incomplete_plan_and_failed_tournament_are_rejected(self) -> None:
        for mutation in ("remove", "fail"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as name:
                generation, reports = _case(Path(name))
                report = json.loads(reports[0].read_text(encoding="utf-8"))
                if mutation == "remove":
                    report["tournaments"].pop()
                else:
                    report["tournaments"][0]["termination_reason"] = "error"
                reports[0].write_text(json.dumps(report), encoding="utf-8")
                with self.assertRaises(ToolError):
                    evaluate_fitness(generation, reports)

    def test_invalid_action_fallback_is_an_explicit_style_failure(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            generation, reports = _case(Path(name))
            report = json.loads(reports[0].read_text(encoding="utf-8"))
            report["tournaments"][0]["profile_results"][0]["invalid_action_fallbacks"] = 1
            reports[0].write_text(json.dumps(report), encoding="utf-8")
            artifact = evaluate_fitness(generation, reports)
        failed = next(
            item
            for item in artifact["payload"]["candidate_results"]
            if "invalid_action_fallbacks" in item["ineligibility_reasons"]
        )
        self.assertFalse(failed["style_checks"]["zero_invalid_action_fallbacks"]["passed"])
        self.assertIsNone(failed["fitness"])

    def test_non_finite_or_out_of_bounds_rates_are_rejected(self) -> None:
        for value in (1.01, math.inf):
            with self.subTest(value=value), tempfile.TemporaryDirectory() as name:
                generation, reports = _case(Path(name))
                report = json.loads(reports[0].read_text(encoding="utf-8"))
                report["tournaments"][0]["profile_results"][0]["vpip_rate"] = value
                reports[0].write_text(json.dumps(report), encoding="utf-8")
                with self.assertRaises(ToolError):
                    evaluate_fitness(generation, reports)

    def test_repeated_profile_ids_are_counted_once_per_seat(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            generation, reports = _case(Path(name), minimum_samples=4)
            report = json.loads(reports[0].read_text(encoding="utf-8"))
            candidate_id = generation["payload"]["candidates"][0]["candidate_id"]
            report["manifest"]["matchups"][0]["profile_ids"] = [candidate_id, candidate_id]
            report["manifest_checksum"] = _simulation_manifest_checksum(report["manifest"])
            report["roster"] = _roster_provenance(report["manifest"])
            for tournament in report["tournaments"]:
                stack = report["manifest"]["regimes"][0]["starting_stack"]
                tournament["seat_map"] = [
                    {"seat": 0, "profile_id": candidate_id},
                    {"seat": 1, "profile_id": candidate_id},
                ]
                tournament["selected_profile_ids"] = [candidate_id, candidate_id]
                tournament["winner_profile_id"] = candidate_id
                tournament["profile_results"] = [
                    _profile_result(candidate_id, 0, True, 2, stack),
                    _profile_result(candidate_id, 1, False, 2, stack),
                ]
            reports[0].write_text(json.dumps(report), encoding="utf-8")
            artifact = evaluate_fitness(generation, reports)
        first, second = artifact["payload"]["candidate_results"]
        self.assertEqual(first["sample_count"], 4)
        self.assertTrue(first["eligible"])
        self.assertEqual(second["sample_count"], 0)

    def test_result_seat_must_match_planned_seat(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            generation, reports = _case(Path(name))
            report = json.loads(reports[0].read_text(encoding="utf-8"))
            report["tournaments"][0]["profile_results"][0]["seat"] = 1
            reports[0].write_text(json.dumps(report), encoding="utf-8")
            with self.assertRaisesRegex(ToolError, "planned seat"):
                evaluate_fitness(generation, reports)

    def test_derived_metrics_must_match_their_counts(self) -> None:
        mutations = (
            ("bnc_per_100", 0.0),
            ("vpip_rate", 0.0),
            ("pfr_rate", 1.0),
            ("aggressive_actions", 1),
            ("aggression_factor", 1.0),
            ("bet_raise_frequency", 1.0),
            ("bet_frequency", 1.0),
            ("raise_share", 1.0),
            ("eligible_bluff_frequency", 1.0),
        )
        for field, value in mutations:
            with self.subTest(field=field), tempfile.TemporaryDirectory() as name:
                generation, reports = _case(Path(name))
                report = json.loads(reports[0].read_text(encoding="utf-8"))
                report["tournaments"][0]["profile_results"][0][field] = value
                reports[0].write_text(json.dumps(report), encoding="utf-8")
                with self.assertRaises(ToolError):
                    evaluate_fitness(generation, reports)

    def test_behavior_counts_cannot_exceed_denominators(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            generation, reports = _case(Path(name))
            report = json.loads(reports[0].read_text(encoding="utf-8"))
            result = report["tournaments"][0]["profile_results"][0]
            result["pfr_hands"] = 2
            result["pfr_rate"] = 2.0
            reports[0].write_text(json.dumps(report), encoding="utf-8")
            with self.assertRaises(ToolError):
                evaluate_fitness(generation, reports)

    def test_tournament_chips_must_be_conserved(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            generation, reports = _case(Path(name))
            report = json.loads(reports[0].read_text(encoding="utf-8"))
            result = report["tournaments"][0]["profile_results"][0]
            result["final_stack"] += 1
            result["chip_differential"] += 1
            reports[0].write_text(json.dumps(report), encoding="utf-8")
            with self.assertRaises(ToolError):
                evaluate_fitness(generation, reports)

    def test_product_player_limit_and_bootstrap_estimator_are_rejected(self) -> None:
        for field, value in (("player_count", 10), ("uncertainty_estimator", "bootstrap_95")):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as name:
                generation, reports = _case(Path(name))
                report = json.loads(reports[0].read_text(encoding="utf-8"))
                if field == "player_count":
                    report["manifest"]["regimes"][0][field] = value
                else:
                    report["manifest"]["evaluation_plans"][0][field] = value
                report["manifest_checksum"] = _simulation_manifest_checksum(report["manifest"])
                reports[0].write_text(json.dumps(report), encoding="utf-8")
                with self.assertRaises(ToolError):
                    evaluate_fitness(generation, reports)

    def test_evaluation_is_deterministic_and_preserves_report_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            generation, reports = _case(Path(name), shard_count=2)
            before = [path.read_bytes() for path in reports]
            first = evaluate_fitness(generation, reversed(reports))
            second = evaluate_fitness(generation, reports)
            self.assertEqual(canonical_json_bytes(first), canonical_json_bytes(second))
            self.assertEqual([path.read_bytes() for path in reports], before)
