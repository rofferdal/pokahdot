from __future__ import annotations

import contextlib
import copy
import io
import json
import math
import tempfile
import unittest
from pathlib import Path

from tools.profile_evolution.artifacts import (
    canonical_json_bytes,
    create_artifact,
    load_artifact,
    write_artifact_atomic,
)
from tools.profile_evolution.cli import main
from tools.profile_evolution.confirmation import confirm_candidate
from tools.profile_evolution.contracts import GENES
from tools.profile_evolution.export import export_candidates
from tools.profile_evolution.fitness import _roster_provenance, _simulation_manifest_checksum
from tools.profile_evolution.promotion_review import (
    create_promotion_review,
    validate_promotion_review,
)
from tools.profile_evolution.profile_publisher import publish_approved_profile


def _candidate(candidate_id: str, value: int) -> dict[str, object]:
    return {
        "candidate_id": candidate_id,
        "model_id": "strategy_parameterized",
        "parameters": {gene: value for gene in GENES},
        "parent_ids": [],
    }


def _entry(candidate: dict[str, object], champion: bool = False) -> dict[str, object]:
    candidate_id = candidate["candidate_id"]
    candidate_result = {
        "candidate": copy.deepcopy(candidate),
        "component_means": {
            name: 0.5
            for name in (
                "win_score",
                "finish_score",
                "top_third_score",
                "chip_score",
                "survival_score",
                "blind_chip_score",
            )
        },
        "eligible": True,
        "fitness": 0.4,
        "ineligibility_reasons": [],
        "plan_sample_counts": {"original_plan": 2},
        "sample_count": 2,
        "style_checks": {
            "bounded_behavioral_rates": {"passed": True, "violations": []},
            "zero_invalid_action_fallbacks": {"passed": True, "value": 0},
        },
        "uncertainty_95_half_width": {
            name: 0.1
            for name in (
                "win_score",
                "finish_score",
                "top_third_score",
                "chip_score",
                "survival_score",
                "blind_chip_score",
            )
        },
        "uncertainty_penalty": 0.1,
    }
    report_evidence = [
        {
            "batch_id": "original_batch",
            "code_revision": "original-revision",
            "command_version": "simulation_cli_v2",
            "manifest_checksum": "b" * 64,
            "report_checksum": "c" * 64,
            "seed_range": {"minimum": 1, "maximum": 10},
            "shard": {"index": 0, "count": 1},
        }
    ]
    return {
        "bounds": {
            "genes": {gene: {"minimum": 0, "maximum": 100} for gene in GENES}
        },
        "candidate": candidate,
        "creation": {
            "candidate_id": candidate_id,
            "operation": "initialization",
            "parent_ids": [],
            "seed": 1,
        },
        "creation_context": {
            "artifact_checksum": "a" * 64,
            "artifact_type": "generation_manifest",
            "tool_version": "0.1.0",
        },
        "evaluations": [
            {
                "code_revisions": ["original-revision"],
                "component_means": copy.deepcopy(candidate_result["component_means"]),
                "eligible": True,
                "evaluation_configuration": {
                    "plans": [{"plan_id": "original_plan"}],
                    "regimes": [{"regime_id": "original_regime"}],
                },
                "fitness": 0.4,
                "fitness_artifact_checksum": "d" * 64,
                "ineligibility_reasons": [],
                "plan_ids": ["original_plan"],
                "plan_sample_counts": {"original_plan": 2},
                "regime_ids": ["original_regime"],
                "report_evidence": report_evidence,
                "sample_count": 2,
                "style_checks": copy.deepcopy(candidate_result["style_checks"]),
                "uncertainty_95_half_width": copy.deepcopy(
                    candidate_result["uncertainty_95_half_width"]
                ),
                "uncertainty_penalty": 0.1,
            }
        ],
        "generation": 0,
        "generation_id": "generation_g0",
        "selection_history": (
            [
                {
                    "benchmark": candidate_result,
                    "elite_fraction": 0.2,
                    "next_generation_manifest": {
                        "generation": 1,
                        "generation_id": "generation_g1",
                    },
                    "retained_index": 0,
                    "selection_artifact_checksum": "e" * 64,
                    "source_fitness_checksum": "d" * 64,
                }
            ]
            if champion
            else []
        ),
    }


def _registry(
    candidate_value: int = 50,
) -> tuple[dict[str, object], dict[str, dict[str, object]]]:
    candidates = {
        "candidate": _candidate("candidate", candidate_value),
        "legacy": _candidate("legacy", 20),
        "champion": _candidate("champion", 80),
        "outsider": _candidate("outsider", 30),
    }
    registry = create_artifact(
        "lineage_registry",
        {
            "artifacts": [],
            "entries": [
                _entry(candidates["candidate"]),
                _entry(candidates["legacy"]),
                _entry(candidates["champion"], champion=True),
                _entry(candidates["outsider"]),
            ],
        },
    )
    return registry, candidates


def _result(
    profile_id: str,
    seat: int,
    finishing_position: int,
    player_count: int,
    fallback: int = 0,
) -> dict[str, object]:
    won = finishing_position == 1
    stack = 100
    final_stack = stack * player_count if won else 0
    return {
        "seat": seat,
        "profile_id": profile_id,
        "finishing_position": finishing_position,
        "won_tournament": won,
        "top_third": finishing_position <= math.ceil(player_count / 3),
        "starting_stack": stack,
        "final_stack": final_stack,
        "chip_differential": final_stack - stack,
        "hands_survived": 1,
        "tournament_hand_count": 1,
        "survival_ratio": 1.0,
        "blind_normalized_chip_sum": 1.0 if won else -1.0,
        "hands_observed": 1,
        "bnc_per_100": 100.0 if won else -100.0,
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
        "invalid_action_fallbacks": fallback,
    }


def _report(
    path: Path,
    profiles: list[dict[str, object]],
    seed_start: int,
    batch_id: str,
    candidate_fallback: int = 0,
) -> Path:
    player_count = len(profiles)
    profile_ids = [item["candidate_id"] for item in profiles]
    manifest = {
        "schema_version": 2,
        "batch_id": batch_id,
        "seed_start": seed_start,
        "profiles": [
            {
                "profile_id": item["candidate_id"],
                "model_id": item["model_id"],
                "parameters": item["parameters"],
            }
            for item in profiles
        ],
        "regimes": [
            {
                "regime_id": "regime",
                "player_count": player_count,
                "starting_stack": 100,
                "starting_small_blind": 5,
                "starting_big_blind": 10,
                "blind_progression": "normative_hand_based_v1",
            }
        ],
        "matchups": [{"matchup_id": "matchup", "profile_ids": profile_ids}],
        "evaluation_plans": [
            {
                "plan_id": "plan",
                "regime_id": "regime",
                "matchup_ids": ["matchup"],
                "tournament_count": player_count,
                "seat_rotation": "cyclic",
                "minimum_profile_samples": player_count,
                "uncertainty_estimator": "normal_95",
            }
        ],
    }
    tournaments = []
    for index in range(player_count):
        seat_ids = [profile_ids[(seat + index) % player_count] for seat in range(player_count)]
        winner = "candidate" if index % 2 == 0 else seat_ids[0]
        ordered_finishers = [winner] + [item for item in seat_ids if item != winner]
        tournaments.append(
            {
                "tournament_index": index,
                "plan_id": "plan",
                "plan_tournament_index": index,
                "regime_id": "regime",
                "matchup_id": "matchup",
                "matchup_occurrence": index,
                "rotation": index,
                "effective_seed": seed_start + index,
                "seat_map": [
                    {"seat": seat, "profile_id": profile_id}
                    for seat, profile_id in enumerate(seat_ids)
                ],
                "selected_profile_ids": seat_ids,
                "termination_reason": "winner",
                "winner_profile_id": winner,
                "tournament_hand_count": 1,
                "profile_results": [
                    _result(
                        profile_id,
                        seat,
                        ordered_finishers.index(profile_id) + 1,
                        player_count,
                        candidate_fallback if profile_id == "candidate" else 0,
                    )
                    for seat, profile_id in enumerate(seat_ids)
                ],
                "diagnostics": [],
            }
        )
    report = {
        "report_schema_version": 3,
        "manifest": manifest,
        "manifest_checksum": _simulation_manifest_checksum(manifest),
        "roster": _roster_provenance(manifest),
        "code_revision": "confirm-revision",
        "command_version": "simulation_cli_v3",
        "shard": {"index": 0, "count": 1},
        "started_at": "2026-01-01T00:00:00",
        "finished_at": "2026-01-01T00:01:00",
        "tournaments": tournaments,
        "aggregates": {},
        "traces": [],
    }
    path.write_text(json.dumps(report, separators=(",", ":")), encoding="utf-8")
    return path


def _reports(
    directory: Path,
    fallback: int = 0,
    mixed_seed: int = 300,
    candidate_value: int = 50,
):
    registry, candidates = _registry(candidate_value)
    mirrored = [
        _report(
            directory / "mirror_legacy.json",
            [candidates["candidate"], candidates["legacy"]],
            100,
            "mirror_legacy",
        ),
        _report(
            directory / "mirror_champion.json",
            [candidates["candidate"], candidates["champion"]],
            200,
            "mirror_champion",
        ),
    ]
    mixed = [
        _report(
            directory / "mixed.json",
            [candidates["candidate"], candidates["legacy"], candidates["champion"]],
            mixed_seed,
            "mixed",
            fallback,
        )
    ]
    return registry, candidates, mirrored, mixed


class ConfirmationTests(unittest.TestCase):
    def test_deterministic_eligible_confirmation_and_review_export(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(Path(name))
            first = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            second = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], reversed(mirrored), mixed
            )
            self.assertTrue(first["payload"]["promotion_eligible"])
            self.assertTrue(first["payload"]["review_required"])
            self.assertEqual(canonical_json_bytes(first), canonical_json_bytes(second))
            bundle = export_candidates(registry, [first], ["candidate"])
            self.assertEqual(bundle["payload"]["purpose"], "review_only")
            self.assertEqual(bundle["payload"]["candidates"][0]["candidate"]["candidate_id"], "candidate")

    def test_diversity_and_reviewer_approval_are_independent_promotion_gates(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(Path(name), candidate_value=20)
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            self.assertFalse(confirmation["payload"]["promotion_eligible"])
            self.assertIn(
                "behavioral_diversity:insufficient_parameter_distance",
                confirmation["payload"]["ineligibility_reasons"],
            )
            self.assertFalse(confirmation["payload"]["behavioral_diversity"]["passed"])
            with self.assertRaisesRegex(Exception, "cannot receive approval"):
                create_promotion_review(confirmation, "reviewer", True, "Approve it")

            eligible_registry, _, eligible_mirrored, eligible_mixed = _reports(
                Path(name), candidate_value=50
            )
            approved_confirmation = confirm_candidate(
                eligible_registry,
                "candidate",
                ["legacy"],
                ["champion"],
                eligible_mirrored,
                eligible_mixed,
            )
            review = create_promotion_review(
                approved_confirmation, "reviewer", True, "Evidence reviewed."
            )
            self.assertTrue(validate_promotion_review(review)["approved"])

    def test_publish_requires_exact_approved_review_and_never_overwrites_profile(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            registry, _, mirrored, mixed = _reports(directory)
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            rejected_review = create_promotion_review(
                confirmation, "reviewer", False, "Not ready."
            )
            with self.assertRaisesRegex(Exception, "must approve"):
                publish_approved_profile(
                    confirmation, rejected_review, directory, "v1", "Published Candidate"
                )

            approved_review = create_promotion_review(
                confirmation, "reviewer", True, "Approved for publication."
            )
            published = publish_approved_profile(
                confirmation, approved_review, directory, "v1", "Published Candidate"
            )
            resource_path = Path(published["resource_path"])
            contents = resource_path.read_text(encoding="utf-8")
            self.assertEqual(published["profile_id"], "candidate__v1")
            self.assertIn('profile_id = &"candidate__v1"', contents)
            self.assertIn('model_id = &"strategy_parameterized"', contents)
            self.assertIn("tight_vs_loose = 50", contents)
            with self.assertRaisesRegex(Exception, "cannot be overwritten"):
                publish_approved_profile(
                    confirmation, approved_review, directory, "v1", "Changed Name"
                )
            self.assertEqual(contents, resource_path.read_text(encoding="utf-8"))

    def test_legacy_profile_does_not_require_evolution_lineage(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(Path(name))
            registry["payload"]["entries"] = [
                entry
                for entry in registry["payload"]["entries"]
                if entry["candidate"]["candidate_id"] != "legacy"
            ]
            registry = create_artifact("lineage_registry", registry["payload"])
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            self.assertTrue(confirmation["payload"]["promotion_eligible"])
            snapshots = {
                profile["profile_id"]: profile
                for profile in confirmation["payload"]["opponent_profiles"]
            }
            self.assertIn("legacy", snapshots)

    def test_narrow_matchup_and_missing_opponent_classes_are_ineligible(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            registry, candidates, mirrored, _ = _reports(directory)
            mixed = [
                _report(
                    directory / "mixed_narrow.json",
                    [candidates["candidate"], candidates["legacy"], candidates["outsider"]],
                    400,
                    "mixed_narrow",
                )
            ]
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored[:1], mixed
            )
            reasons = confirmation["payload"]["ineligibility_reasons"]
            self.assertIn("mirrored:missing_champion:champion", reasons)
            self.assertIn("mixed:missing_champion", reasons)

    def test_overlapping_seed_ranges_and_fallbacks_are_ineligible(self) -> None:
        for fallback, mixed_seed, expected in (
            (0, 100, "independence:seed_range_overlap"),
            (1, 300, "mixed:invalid_action_fallbacks"),
        ):
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as name:
                registry, _, mirrored, mixed = _reports(
                    Path(name), fallback=fallback, mixed_seed=mixed_seed
                )
                confirmation = confirm_candidate(
                    registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
                )
                self.assertFalse(confirmation["payload"]["promotion_eligible"])
                self.assertIn(expected, confirmation["payload"]["ineligibility_reasons"])

    def test_reused_report_is_not_independent(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, _ = _reports(Path(name))
            confirmation = confirm_candidate(
                registry,
                "candidate",
                ["legacy"],
                ["champion"],
                mirrored,
                [mirrored[0]],
            )
            reasons = confirmation["payload"]["ineligibility_reasons"]
            self.assertIn("independence:report_checksum_overlap", reasons)
            self.assertIn("independence:manifest_checksum_overlap", reasons)

    def test_cli_confirmation_and_export_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            registry, _, mirrored, mixed = _reports(directory)
            registry_path = directory / "registry.json"
            confirmation_path = directory / "confirmation.json"
            review_path = directory / "review.json"
            bundle_path = directory / "bundle.json"
            write_artifact_atomic(registry_path, registry)
            with contextlib.redirect_stdout(io.StringIO()):
                result = main(
                    [
                        "confirm-candidate",
                        "--registry",
                        str(registry_path),
                        "--candidate-id",
                        "candidate",
                        "--legacy-id",
                        "legacy",
                        "--historical-champion-id",
                        "champion",
                        "--mirrored-report",
                        str(mirrored[0]),
                        "--mirrored-report",
                        str(mirrored[1]),
                        "--mixed-report",
                        str(mixed[0]),
                        "--output",
                        str(confirmation_path),
                    ]
                )
            self.assertEqual(result, 0)
            with contextlib.redirect_stdout(io.StringIO()):
                result = main(
                    [
                        "review-promotion",
                        "--confirmation",
                        str(confirmation_path),
                        "--reviewer-id",
                        "reviewer",
                        "--approve",
                        "--note",
                        "Evidence reviewed.",
                        "--output",
                        str(review_path),
                    ]
                )
            self.assertEqual(result, 0)
            self.assertTrue(
                load_artifact(review_path, "promotion_review")["payload"]["approved"]
            )
            with contextlib.redirect_stdout(io.StringIO()):
                result = main(
                    [
                        "export-candidates",
                        "--registry",
                        str(registry_path),
                        "--confirmation",
                        str(confirmation_path),
                        "--candidate-id",
                        "candidate",
                        "--output",
                        str(bundle_path),
                    ]
                )
            self.assertEqual(result, 0)
            bundle = load_artifact(bundle_path, "candidate_bundle")
            self.assertEqual(bundle["payload"]["purpose"], "review_only")

    def test_export_refuses_ineligible_confirmation(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(Path(name), fallback=1)
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            with self.assertRaisesRegex(Exception, "did not pass"):
                export_candidates(registry, [confirmation], ["candidate"])

    def test_export_rejects_forged_confirmation_metrics(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(Path(name))
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            confirmation["payload"]["mirrored"]["batches"][0]["candidate_result"][
                "fitness"
            ] = 1.0
            forged = create_artifact("confirmation", confirmation["payload"])
            with self.assertRaises(Exception):
                export_candidates(registry, [forged], ["candidate"])
