from __future__ import annotations

import contextlib
import copy
import hashlib
import io
import json
import math
import tempfile
import unittest
from unittest import mock
from pathlib import Path

from tools.profile_evolution.artifacts import (
    canonical_json_bytes,
    create_artifact,
    load_artifact,
    write_artifact_atomic,
)
from tools.profile_evolution.cli import main
from tools.profile_evolution.confirmation import (
    LEGACY_SEED_MODULUS,
    _effective_seed_ranges_overlap,
    _genetic_diversity,
    confirm_candidate,
    validate_confirmation,
)
from tools.profile_evolution.contracts import GENES
from tools.profile_evolution.export import export_candidates
from tools.profile_evolution.fitness import _roster_provenance, _simulation_manifest_checksum
from tools.profile_evolution.promotion_review import (
    create_promotion_review,
    create_promotion_review_plan,
    write_promotion_review_plan_atomic,
    finalize_promotion_review,
    validate_promotion_review_batch,
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


def _provenance(revision: str = "a" * 40) -> dict[str, object]:
    return {
        "algorithm_versions": {
            "aggregate_statistics": "normal_95_v1",
            "rng_streams": "named_stream_v1",
            "simulation_runner": "tournament_match_v1",
            "tournament_metrics": "elimination_history_v1",
        },
        "code_revision": revision,
        "dirty_source_fingerprint": "",
        "engine_version": "4.7.2",
        "source_state": "clean",
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
        "point_fitness": 0.5,
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
            "code_revision": "b" * 40,
            "command_version": "simulation_cli_v6",
            "execution_provenance": _provenance("b" * 40),
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
                "code_revisions": ["b" * 40],
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
                "point_fitness": 0.5,
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
    tournament_count: int = 300,
    candidate_win_percent: int = 100,
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
                "tournament_count": tournament_count,
                "seat_rotation": "cyclic",
                "minimum_profile_samples": 1,
                "uncertainty_estimator": "normal_95",
            }
        ],
    }
    tournaments = []
    for index in range(tournament_count):
        seat_ids = [profile_ids[(seat + index) % player_count] for seat in range(player_count)]
        winner = (
            "candidate"
            if index % 100 < candidate_win_percent
            else next(profile_id for profile_id in seat_ids if profile_id != "candidate")
        )
        ordered_finishers = [winner] + [item for item in seat_ids if item != winner]
        tournaments.append(
            {
                "tournament_index": index,
                "plan_id": "plan",
                "plan_tournament_index": index,
                "regime_id": "regime",
                "matchup_id": "matchup",
                "matchup_occurrence": index,
                "rotation": index % player_count,
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
        "report_schema_version": 4,
        "manifest": manifest,
        "manifest_checksum": _simulation_manifest_checksum(manifest),
        "roster": _roster_provenance(manifest),
        "code_revision": "a" * 40,
        "command_version": "simulation_cli_v6",
        "execution_provenance": _provenance(),
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
    mixed_seed: int = 3000,
    candidate_value: int = 50,
    tournament_count: int = 300,
    candidate_win_percent: int = 100,
):
    registry, candidates = _registry(candidate_value)
    mirrored = [
        _report(
            directory / "mirror_legacy.json",
            [candidates["candidate"], candidates["legacy"]],
            1000,
            "mirror_legacy",
            tournament_count=tournament_count,
            candidate_win_percent=candidate_win_percent,
        ),
        _report(
            directory / "mirror_champion.json",
            [candidates["candidate"], candidates["champion"]],
            2000,
            "mirror_champion",
            tournament_count=tournament_count,
            candidate_win_percent=candidate_win_percent,
        ),
    ]
    mixed = [
        _report(
            directory / "mixed.json",
            [candidates["candidate"], candidates["legacy"], candidates["champion"]],
            mixed_seed,
            "mixed",
            fallback,
            tournament_count,
            candidate_win_percent,
        )
    ]
    return registry, candidates, mirrored, mixed


def _confirmation_variant(
    confirmation: dict[str, object], candidate_id: str, gene_value: int
) -> dict[str, object]:
    payload = copy.deepcopy(confirmation["payload"])
    candidate = _candidate(candidate_id, gene_value)
    payload["candidate"] = candidate
    for mode in ("mirrored", "mixed"):
        for batch in payload[mode]["batches"]:
            batch["candidate_result"]["candidate"] = copy.deepcopy(candidate)
    opponents = {
        profile["profile_id"]: profile for profile in payload["opponent_profiles"]
    }
    payload["genetic_diversity"] = _genetic_diversity(candidate, opponents)
    vpip = payload["measured_behavior"]["metrics"]["vpip_rate"]
    vpip["numerator"] = 0
    vpip["rate"] = 0.0
    return create_artifact("confirmation", payload)


class ConfirmationTests(unittest.TestCase):
    def test_effective_seed_overlap_uses_the_recorded_rng_algorithm(self) -> None:
        legacy_first = {
            "rng_algorithm": "named_stream_v1",
            "seed_range": {"minimum": 1, "maximum": 10},
        }
        legacy_alias = {
            "rng_algorithm": "named_stream_v1",
            "seed_range": {
                "minimum": LEGACY_SEED_MODULUS + 1,
                "maximum": LEGACY_SEED_MODULUS + 10,
            },
        }
        stronger_alias = copy.deepcopy(legacy_alias)
        stronger_alias["rng_algorithm"] = "named_stream_sha256_v2"

        self.assertTrue(_effective_seed_ranges_overlap(legacy_first, legacy_alias))
        self.assertFalse(_effective_seed_ranges_overlap(legacy_first, stronger_alias))

    def test_promotion_policy_rejects_caller_approved_tiny_samples(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(
                Path(name), tournament_count=3
            )
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )

            self.assertFalse(confirmation["payload"]["promotion_eligible"])
            self.assertEqual(
                confirmation["payload"]["evidence_policy"]["evidence_class"],
                "exploratory_only",
            )
            self.assertIn(
                "mirrored:insufficient_matchup_samples:plan:matchup",
                confirmation["payload"]["ineligibility_reasons"],
            )

    def test_promotion_policy_requires_demonstrated_paired_advantage(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(
                Path(name), candidate_win_percent=50
            )
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )

            self.assertFalse(confirmation["payload"]["promotion_eligible"])
            self.assertTrue(
                any(
                    reason.startswith("mirrored:performance_not_demonstrated:")
                    for reason in confirmation["payload"]["ineligibility_reasons"]
                )
            )

    def test_exact_promotion_sample_boundary_is_recorded_and_validated(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(Path(name))
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )

            self.assertTrue(confirmation["payload"]["promotion_eligible"])
            mixed_coverage = confirmation["payload"]["mixed"]["batches"][0][
                "promotion_checks"
            ]["coverage"][0]
            self.assertEqual(mixed_coverage["tournament_samples"], 300)
            self.assertEqual(
                [item["samples"] for item in mixed_coverage["seat_samples"]],
                [100, 100, 100],
            )
            self.assertEqual(
                validate_confirmation(confirmation)["evidence_policy"]["policy_version"],
                "promotion_evidence_v1",
            )

    def test_pre_river_fix_confirmation_evidence_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(Path(name))
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            payload = copy.deepcopy(confirmation["payload"])
            payload["mirrored"]["batches"][0]["report_evidence"][0][
                "command_version"
            ] = "simulation_cli_v3"
            stale_confirmation = create_artifact("confirmation", payload)

            with self.assertRaisesRegex(
                Exception, "unsupported simulation command version"
            ):
                create_promotion_review(stale_confirmation, "reviewer", True)

    def test_consolidated_review_plan_requires_one_decision_per_candidate(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            registry, _, mirrored, mixed = _reports(directory)
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            plan = create_promotion_review_plan([confirmation], "reviewer")
            self.assertEqual(plan["candidates"][0]["decision"], "pending")
            with self.assertRaisesRegex(Exception, "must be approve or reject"):
                finalize_promotion_review(plan, [confirmation])

            rejected_plan = copy.deepcopy(plan)
            rejected_plan["candidates"][0]["decision"] = "reject"
            rejected_review = finalize_promotion_review(
                rejected_plan, [confirmation]
            )
            with self.assertRaisesRegex(Exception, "must approve"):
                publish_approved_profile(
                    confirmation, rejected_review, directory, "rejected"
                )

            plan["candidates"][0]["decision"] = "approve"
            plan["candidates"][0]["display_name"] = "Reviewed Candidate"
            review = finalize_promotion_review(plan, [confirmation])
            validated = validate_promotion_review_batch(review)
            self.assertEqual(validated["reviewer_id"], "reviewer")
            self.assertTrue(validated["decisions"][0]["approved"])

            published = publish_approved_profile(
                confirmation, review, directory, "v1"
            )
            contents = Path(published["resource_path"]).read_text(encoding="utf-8")
            self.assertIn('display_name = "Reviewed Candidate"', contents)

    def test_consolidated_review_rejects_confirmation_snapshot_changes(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(Path(name))
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            plan = create_promotion_review_plan([confirmation], "reviewer")
            plan["candidates"][0]["decision"] = "reject"
            plan["candidates"][0]["candidate"]["parameters"][GENES[0]] += 1
            with self.assertRaisesRegex(Exception, "snapshot differs"):
                finalize_promotion_review(plan, [confirmation])

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

    def test_genetic_diversity_and_reviewer_approval_are_independent_gates(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(Path(name), candidate_value=20)
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            self.assertFalse(confirmation["payload"]["promotion_eligible"])
            self.assertIn(
                "genetic_diversity:insufficient_parameter_distance",
                confirmation["payload"]["ineligibility_reasons"],
            )
            self.assertFalse(confirmation["payload"]["genetic_diversity"]["passed"])
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
            review = create_promotion_review(approved_confirmation, "reviewer", True)
            validated_review = validate_promotion_review(review)
            self.assertTrue(validated_review["approved"])
            self.assertEqual(validated_review["review_note"], "")

    def test_consolidated_review_compares_every_candidate_pair_before_approval(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(Path(name))
            first = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            second = _confirmation_variant(first, "candidate_two", 65)
            third = _confirmation_variant(first, "candidate_three", 35)

            plan = create_promotion_review_plan([second, first, third], "reviewer")
            diversity = plan["roster_diversity"]
            self.assertEqual(
                diversity["candidate_ids"],
                ["candidate", "candidate_three", "candidate_two"],
            )
            self.assertEqual(len(diversity["pairwise_comparisons"]), 3)
            comparison = next(
                item
                for item in diversity["pairwise_comparisons"]
                if item["second_candidate_id"] == "candidate_two"
            )
            self.assertEqual(comparison["genetic_parameter_distance"], 60)
            self.assertEqual(
                comparison["measured_behavior_absolute_differences"]["vpip_rate"],
                1.0,
            )
            self.assertEqual(comparison["measured_behavior_l1_distance"], 1.0)
            self.assertEqual(
                [entry["decision"] for entry in plan["candidates"]],
                ["pending", "pending", "pending"],
            )

            for entry in plan["candidates"]:
                entry["decision"] = "approve"
            review = finalize_promotion_review(plan, [first, second, third])
            validated = validate_promotion_review_batch(review)
            self.assertEqual(validated["roster_diversity"], diversity)
            self.assertTrue(all(item["approved"] for item in validated["decisions"]))

            forged = copy.deepcopy(plan)
            forged["roster_diversity"]["pairwise_comparisons"][0][
                "genetic_parameter_distance"
            ] += 1
            with self.assertRaisesRegex(Exception, "differs from the supplied"):
                finalize_promotion_review(forged, [first, second, third])

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
            provenance_path = Path(published["provenance_path"])
            contents = resource_path.read_text(encoding="utf-8")
            provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
            self.assertEqual(published["profile_id"], "candidate__v1")
            self.assertEqual(
                provenance,
                {
                    "confirmation_checksum": confirmation["checksum"],
                    "profile_id": "candidate__v1",
                    "resource_sha256": hashlib.sha256(resource_path.read_bytes()).hexdigest(),
                    "review_checksum": approved_review["checksum"],
                },
            )
            self.assertEqual(published["resource_sha256"], provenance["resource_sha256"])
            self.assertIn('profile_id = &"candidate__v1"', contents)
            self.assertIn('model_id = &"strategy_parameterized"', contents)
            self.assertIn("tight_vs_loose = 50", contents)
            with self.assertRaisesRegex(Exception, "cannot be overwritten"):
                publish_approved_profile(
                    confirmation, approved_review, directory, "v1", "Changed Name"
                )
            self.assertEqual(contents, resource_path.read_text(encoding="utf-8"))

    def test_publish_refuses_an_existing_provenance_sidecar_without_partial_output(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            registry, _, mirrored, mixed = _reports(directory)
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            review = create_promotion_review(confirmation, "reviewer", True)
            published_directory = directory / "resources" / "bot_profiles" / "published"
            published_directory.mkdir(parents=True)
            sidecar = published_directory / "candidate__v1.provenance.json"
            sidecar.write_text("reserved", encoding="utf-8")

            with self.assertRaisesRegex(Exception, "cannot be overwritten"):
                publish_approved_profile(confirmation, review, directory, "v1")

            self.assertFalse((published_directory / "candidate__v1.tres").exists())
            self.assertEqual(sidecar.read_text(encoding="utf-8"), "reserved")

    def test_review_writer_preserves_pretty_json_and_no_clobber_errors(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            registry, _, mirrored, mixed = _reports(directory)
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            plan = create_promotion_review_plan([confirmation], "reviewer")
            plan["candidates"][0]["review_note"] = "Pågående review"
            destination = directory / "review.json"
            write_promotion_review_plan_atomic(destination, plan)
            expected = (json.dumps(plan, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
            self.assertEqual(destination.read_bytes(), expected)
            with self.assertRaises(Exception) as caught:
                write_promotion_review_plan_atomic(destination, plan)
            self.assertEqual(caught.exception.code, "output_exists")
            self.assertEqual(destination.read_bytes(), expected)
            self.assertEqual(list(directory.glob(".*.tmp")), [])

    def test_profile_sidecar_publish_failure_rolls_back_only_its_resource(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            registry, _, mirrored, mixed = _reports(directory)
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )
            review = create_promotion_review(confirmation, "reviewer", True)
            original_link = __import__("os").link

            def race_sidecar(source: Path, destination: Path) -> None:
                if destination.suffix == ".json":
                    destination.write_bytes(b"other publisher's provenance")
                original_link(source, destination)

            with mock.patch("tools.profile_evolution.atomic_write.os.link", side_effect=race_sidecar):
                with self.assertRaises(Exception) as caught:
                    publish_approved_profile(confirmation, review, directory, "v1")
            self.assertEqual(caught.exception.code, "published_profile_exists")
            published = directory / "resources" / "bot_profiles" / "published"
            self.assertFalse((published / "candidate__v1.tres").exists())
            self.assertEqual(
                (published / "candidate__v1.provenance.json").read_bytes(),
                b"other publisher's provenance",
            )
            self.assertEqual(list(published.glob(".*.tmp")), [])

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
            (0, 1000, "independence:effective_seed_overlap"),
            (1, 4000, "mixed:invalid_action_fallbacks"),
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

    def test_disjoint_legacy_seed_ranges_with_aliases_are_ineligible(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            registry, _, mirrored, mixed = _reports(
                Path(name), mixed_seed=LEGACY_SEED_MODULUS + 1
            )
            confirmation = confirm_candidate(
                registry, "candidate", ["legacy"], ["champion"], mirrored, mixed
            )

            self.assertFalse(confirmation["payload"]["promotion_eligible"])
            self.assertIn(
                "independence:effective_seed_overlap",
                confirmation["payload"]["ineligibility_reasons"],
            )

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
            review_plan_path = directory / "review_plan.json"
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
                        "prepare-promotion-review",
                        "--confirmation",
                        str(confirmation_path),
                        "--reviewer-id",
                        "reviewer",
                        "--output",
                        str(review_plan_path),
                    ]
                )
            self.assertEqual(result, 0)
            review_plan = json.loads(review_plan_path.read_text(encoding="utf-8"))
            review_plan["candidates"][0]["decision"] = "approve"
            review_plan_path.write_text(json.dumps(review_plan), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                result = main(
                    [
                        "finalize-promotion-review",
                        "--plan",
                        str(review_plan_path),
                        "--confirmation",
                        str(confirmation_path),
                        "--output",
                        str(review_path),
                    ]
                )
            self.assertEqual(result, 0)
            self.assertTrue(
                load_artifact(review_path, "promotion_review_batch")["payload"][
                    "decisions"
                ][0]["approved"]
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
            ] = 0.0
            forged = create_artifact("confirmation", confirmation["payload"])
            with self.assertRaises(Exception):
                export_candidates(registry, [forged], ["candidate"])
