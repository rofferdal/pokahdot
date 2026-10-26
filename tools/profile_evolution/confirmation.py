"""Independent mirrored and mixed-table confirmation evidence."""

from __future__ import annotations

import copy
import math
from pathlib import Path
from typing import Any, Iterable

from .artifacts import create_artifact, load_json_object, validate_artifact_envelope
from .contracts import (
    GENES,
    require_exact_fields,
    require_identifier,
    require_integer,
    validate_candidate,
    validate_report_seed_range,
)
from .errors import ExitCode, ToolError
from .fitness import COMPONENTS, WEIGHTS, _normalize_report_integers, _validate_execution_provenance, evaluate_fitness
from .lineage import validate_lineage_registry

MINIMUM_STRATEGY_PARAMETER_DISTANCE = 10
PROMOTION_EVIDENCE_POLICY_VERSION = "promotion_evidence_v1"
MINIMUM_PROMOTION_TOURNAMENTS_PER_MATCHUP = 300
MINIMUM_PROMOTION_SAMPLES_PER_SEAT = 100
PROMOTION_COMPARISON_RULE = "paired_composite_lower_95_gt_zero"
LEGACY_RNG_STREAM_VERSION = "named_stream_v1"
LEGACY_SEED_MODULUS = 2_147_483_647

CONFIRMATION_FIELDS = (
    "candidate",
    "evidence_policy",
    "genetic_diversity",
    "historical_champion_ids",
    "ineligibility_reasons",
    "legacy_ids",
    "measured_behavior",
    "mirrored",
    "mixed",
    "opponent_profiles",
    "promotion_eligible",
    "registry_checksum",
    "review_required",
)

SIMULATION_PROFILE_FIELDS = ("profile_id", "model_id", "parameters")
MEASURED_BEHAVIOR_FIELDS = (
    "bet_frequency",
    "bet_raise_frequency",
    "pfr_rate",
    "raise_share",
    "vpip_rate",
)


def _fail(code: str, message: str) -> None:
    raise ToolError(code, message, ExitCode.INVALID_INPUT)


def _ranges_overlap(first: dict[str, int], second: dict[str, int]) -> bool:
    return first["minimum"] <= second["maximum"] and second["minimum"] <= first["maximum"]


def _range_contains_residue(seed_range: dict[str, int], residue: int) -> bool:
    minimum = seed_range["minimum"]
    first = minimum + ((residue - minimum) % LEGACY_SEED_MODULUS)
    return first <= seed_range["maximum"]


def _legacy_ranges_overlap(first: dict[str, int], second: dict[str, int]) -> bool:
    minimum_delta = first["minimum"] - second["maximum"]
    maximum_delta = first["maximum"] - second["minimum"]
    first_multiple = -(-minimum_delta // LEGACY_SEED_MODULUS)
    last_multiple = maximum_delta // LEGACY_SEED_MODULUS
    if first_multiple <= last_multiple:
        return True
    # Legacy normalization maps both residues zero and one to identity one.
    return (
        _range_contains_residue(first, 0) and _range_contains_residue(second, 1)
    ) or (
        _range_contains_residue(first, 1) and _range_contains_residue(second, 0)
    )


def _effective_seed_ranges_overlap(first: dict[str, Any], second: dict[str, Any]) -> bool:
    if first["rng_algorithm"] != second["rng_algorithm"]:
        return False
    if first["rng_algorithm"] == LEGACY_RNG_STREAM_VERSION:
        return _legacy_ranges_overlap(first["seed_range"], second["seed_range"])
    return _ranges_overlap(first["seed_range"], second["seed_range"])


def _normal_95_half_width(values: list[float]) -> float | None:
    if len(values) < 2:
        return None
    mean = math.fsum(values) / len(values)
    squared = math.fsum((value - mean) ** 2 for value in values)
    return 1.96 * math.sqrt(squared / (len(values) - 1)) / math.sqrt(len(values))


def _raw_composite(result: dict[str, Any], player_count: int) -> float:
    components = (
        1.0 if result["won_tournament"] else 0.0,
        (player_count - result["finishing_position"]) / (player_count - 1),
        1.0 if result["top_third"] else 0.0,
        (result["chip_differential"] + result["starting_stack"])
        / (player_count * result["starting_stack"]),
        result["survival_ratio"],
        (min(100.0, max(-100.0, result["bnc_per_100"])) + 100.0) / 200.0,
    )
    return math.fsum(weight * value for weight, value in zip(WEIGHTS, components))


def _candidate_generation(entry: dict[str, Any]) -> dict[str, Any]:
    return create_artifact(
        "generation_manifest",
        {
            "bounds": copy.deepcopy(entry["bounds"]),
            "candidates": [copy.deepcopy(entry["candidate"])],
            "creation_records": [copy.deepcopy(entry["creation"])],
            "generation": entry["generation"],
            "generation_id": entry["generation_id"],
            "seed": entry["creation"]["seed"],
        },
    )


def _genetic_diversity(
    candidate: dict[str, Any], opponent_profiles: dict[str, dict[str, Any]]
) -> dict[str, Any]:
    """Measure a stable strategy-genome distance from confirmed opponents.

    The external workflow has no access to a live playable roster. Its declared
    legacy and champion opponents are therefore the review set whose snapshots
    are independently confirmed alongside the candidate. A minimum L1 distance
    of ten percentage points prevents a near-identical strategy profile from
    passing as a distinct playable personality.
    """
    distances: list[tuple[int, str]] = []
    for profile_id, profile in opponent_profiles.items():
        if profile.get("model_id") != candidate["model_id"]:
            continue
        parameters = profile.get("parameters")
        if not isinstance(parameters, dict) or set(parameters) != set(GENES):
            continue
        if any(
            isinstance(parameters[gene], bool) or not isinstance(parameters[gene], int)
            for gene in GENES
        ):
            continue
        distance = sum(
            abs(candidate["parameters"][gene] - parameters[gene]) for gene in GENES
        )
        distances.append((distance, profile_id))
    distances.sort(key=lambda item: (item[0], item[1]))
    nearest_distance, nearest_profile_id = distances[0] if distances else (None, None)
    return {
        "compared_profile_ids": [profile_id for _, profile_id in distances],
        "minimum_parameter_distance": MINIMUM_STRATEGY_PARAMETER_DISTANCE,
        "nearest_parameter_distance": nearest_distance,
        "nearest_profile_id": nearest_profile_id,
        "passed": (
            nearest_distance is not None
            and nearest_distance >= MINIMUM_STRATEGY_PARAMETER_DISTANCE
        ),
    }


def _empty_measured_behavior_counts() -> dict[str, dict[str, int]]:
    return {
        field: {"denominator": 0, "numerator": 0}
        for field in MEASURED_BEHAVIOR_FIELDS
    }


def _observe_measured_behavior(
    counts: dict[str, dict[str, int]], result: dict[str, Any]
) -> None:
    observations = {
        "bet_frequency": (
            result["bets_at_check_bet_opportunity"],
            result["check_bet_opportunities"],
        ),
        "bet_raise_frequency": (
            result["aggressive_actions"], result["bet_raise_opportunities"]
        ),
        "pfr_rate": (result["pfr_hands"], result["hands_observed"]),
        "raise_share": (
            result["raises_at_call_raise_opportunity"],
            result["calls_at_call_raise_opportunity"]
            + result["raises_at_call_raise_opportunity"],
        ),
        "vpip_rate": (result["vpip_hands"], result["hands_observed"]),
    }
    for field, (numerator, denominator) in observations.items():
        counts[field]["numerator"] += numerator
        counts[field]["denominator"] += denominator


def _merge_measured_behavior_counts(
    *sources: dict[str, dict[str, int]],
) -> dict[str, dict[str, int]]:
    merged = _empty_measured_behavior_counts()
    for source in sources:
        for field in MEASURED_BEHAVIOR_FIELDS:
            merged[field]["numerator"] += source[field]["numerator"]
            merged[field]["denominator"] += source[field]["denominator"]
    return merged


def _measured_behavior(counts: dict[str, dict[str, int]]) -> dict[str, Any]:
    metrics = {}
    for field in MEASURED_BEHAVIOR_FIELDS:
        numerator = counts[field]["numerator"]
        denominator = counts[field]["denominator"]
        metrics[field] = {
            "denominator": denominator,
            "numerator": numerator,
            "rate": numerator / denominator if denominator > 0 else 0.0,
        }
    return {"metrics": metrics}


def _validate_measured_behavior(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail("invalid_confirmation", "Confirmation measured behavior is invalid.")
    require_exact_fields(value, ("metrics",), "confirmation measured behavior")
    metrics = value["metrics"]
    if not isinstance(metrics, dict):
        _fail("invalid_confirmation", "Confirmation measured behavior is invalid.")
    require_exact_fields(
        metrics, MEASURED_BEHAVIOR_FIELDS, "confirmation measured behavior metrics"
    )
    counts = _empty_measured_behavior_counts()
    for field in MEASURED_BEHAVIOR_FIELDS:
        metric = metrics[field]
        if not isinstance(metric, dict):
            _fail("invalid_confirmation", "Confirmation measured behavior is invalid.")
        require_exact_fields(
            metric,
            ("denominator", "numerator", "rate"),
            f"confirmation measured behavior {field}",
        )
        denominator = require_integer(
            metric["denominator"], f"measured behavior {field} denominator", 0, 2**63 - 1
        )
        numerator = require_integer(
            metric["numerator"], f"measured behavior {field} numerator", 0, denominator
        )
        rate = metric["rate"]
        expected_rate = numerator / denominator if denominator > 0 else 0.0
        if (
            isinstance(rate, bool)
            or not isinstance(rate, (int, float))
            or not math.isfinite(float(rate))
            or not math.isclose(
                float(rate), expected_rate, rel_tol=1e-12, abs_tol=1e-12
            )
        ):
            _fail("invalid_confirmation", "Confirmation measured behavior is inconsistent.")
        counts[field] = {"denominator": denominator, "numerator": numerator}
    return _measured_behavior(counts)


def _group_reports(paths: Iterable[Path]) -> list[tuple[str, list[Path], dict[str, Any]]]:
    grouped: dict[str, tuple[list[Path], dict[str, Any]]] = {}
    for path in paths:
        report = _normalize_report_integers(load_json_object(path))
        checksum = report.get("manifest_checksum")
        if not isinstance(checksum, str):
            _fail("invalid_confirmation_report", "Confirmation report lacks manifest checksum.")
        manifest = report.get("manifest")
        if not isinstance(manifest, dict):
            _fail("invalid_confirmation_report", "Confirmation report lacks a manifest object.")
        if checksum not in grouped:
            grouped[checksum] = ([], manifest)
        elif grouped[checksum][1] != manifest:
            _fail("confirmation_manifest_conflict", "One manifest checksum identifies different manifests.")
        grouped[checksum][0].append(path)
    if not grouped:
        _fail("missing_confirmation_reports", "Each confirmation mode requires reports.")
    return [(checksum, *grouped[checksum]) for checksum in sorted(grouped)]


def _mode_evidence(
    mode: str,
    paths: Iterable[Path],
    generation: dict[str, Any],
    candidate_id: str,
    legacy_ids: set[str],
    champion_ids: set[str],
) -> tuple[
    dict[str, Any],
    list[str],
    list[dict[str, Any]],
    set[str],
    set[str],
    set[str],
    set[str],
    dict[str, dict[str, Any]],
    dict[str, dict[str, int]],
]:
    batches: list[dict[str, Any]] = []
    reasons: list[str] = []
    mode_ranges: list[dict[str, Any]] = []
    report_checksums: set[str] = set()
    manifest_checksums: set[str] = set()
    covered_legacy: set[str] = set()
    covered_champions: set[str] = set()
    opponent_profiles: dict[str, dict[str, Any]] = {}
    measured_behavior_counts = _empty_measured_behavior_counts()
    for manifest_checksum, group_paths, manifest in _group_reports(paths):
        fitness_artifact = evaluate_fitness(generation, group_paths)
        fitness_payload = fitness_artifact["payload"]
        result = fitness_payload["candidate_results"][0]
        if not result["eligible"]:
            reasons.extend(f"{mode}:{reason}" for reason in result["ineligibility_reasons"])
        regimes = {item["regime_id"]: item for item in manifest["regimes"]}
        plan_by_id = {item["plan_id"]: item for item in manifest["evaluation_plans"]}
        matchups = {item["matchup_id"]: item for item in manifest["matchups"]}
        for profile in manifest["profiles"]:
            profile_id = profile.get("profile_id")
            if profile_id not in legacy_ids | champion_ids:
                continue
            snapshot = copy.deepcopy(profile)
            previous = opponent_profiles.get(profile_id)
            if previous is not None and previous != snapshot:
                _fail(
                    "confirmation_opponent_snapshot_mismatch",
                    f"Opponent profile '{profile_id}' changes between confirmation manifests.",
                )
            opponent_profiles[profile_id] = snapshot
        reports = [_normalize_report_integers(load_json_object(path)) for path in group_paths]
        seats: dict[tuple[str, str], set[int]] = {}
        matchup_sample_counts: dict[tuple[str, str], int] = {}
        seat_sample_counts: dict[tuple[str, str, int], int] = {}
        paired_differences: dict[tuple[str, str, str], list[float]] = {}
        seeds: list[int] = []
        for report in reports:
            for tournament in report["tournaments"]:
                seeds.append(tournament["effective_seed"])
                if any(
                    result["invalid_action_fallbacks"] != 0
                    for result in tournament["profile_results"]
                ):
                    reasons.append(f"{mode}:invalid_action_fallbacks")
                key = (tournament["plan_id"], tournament["matchup_id"])
                plan = plan_by_id[key[0]]
                player_count = regimes[plan["regime_id"]]["player_count"]
                candidate_results = [
                    item
                    for item in tournament["profile_results"]
                    if item["profile_id"] == candidate_id
                ]
                if len(candidate_results) != 1:
                    reasons.append(f"{mode}:candidate_occurrence_invalid:{key[0]}:{key[1]}")
                else:
                    _observe_measured_behavior(
                        measured_behavior_counts, candidate_results[0]
                    )
                    candidate_composite = _raw_composite(candidate_results[0], player_count)
                    for opponent_result in tournament["profile_results"]:
                        opponent_id = opponent_result["profile_id"]
                        if opponent_id not in legacy_ids | champion_ids:
                            continue
                        comparison_key = (key[0], key[1], opponent_id)
                        paired_differences.setdefault(comparison_key, []).append(
                            candidate_composite
                            - _raw_composite(opponent_result, player_count)
                        )
                for seat_data in tournament["seat_map"]:
                    if seat_data["profile_id"] == candidate_id:
                        seat = seat_data["seat"]
                        seats.setdefault(key, set()).add(seat)
                        matchup_sample_counts[key] = matchup_sample_counts.get(key, 0) + 1
                        seat_key = (key[0], key[1], seat)
                        seat_sample_counts[seat_key] = seat_sample_counts.get(seat_key, 0) + 1
        coverage: list[dict[str, Any]] = []
        comparisons: list[dict[str, Any]] = []
        for plan in manifest["evaluation_plans"]:
            regime = regimes[plan["regime_id"]]
            player_count = regime["player_count"]
            if mode == "mirrored" and player_count != 2:
                reasons.append("mirrored:not_heads_up")
            if mode == "mixed" and player_count < 3:
                reasons.append("mixed:table_too_small")
            for matchup_id in plan["matchup_ids"]:
                key = (plan["plan_id"], matchup_id)
                profile_ids = set(matchups[matchup_id]["profile_ids"])
                if candidate_id not in profile_ids:
                    reasons.append(f"{mode}:candidate_missing:{matchup_id}")
                    continue
                opponents = profile_ids - {candidate_id}
                covered_legacy.update(opponents & legacy_ids)
                covered_champions.update(opponents & champion_ids)
                if mode == "mirrored" and len(opponents) != 1:
                    reasons.append(f"mirrored:not_one_opponent:{matchup_id}")
                if mode == "mixed" and (
                    not opponents.intersection(legacy_ids)
                    or not opponents.intersection(champion_ids)
                ):
                    reasons.append(f"mixed:missing_opponent_class:{matchup_id}")
                if seats.get((plan["plan_id"], matchup_id), set()) != set(range(player_count)):
                    reasons.append(f"{mode}:incomplete_seat_rotation:{plan['plan_id']}:{matchup_id}")
                tournament_samples = matchup_sample_counts.get(key, 0)
                per_seat = [
                    {
                        "samples": seat_sample_counts.get((key[0], key[1], seat), 0),
                        "seat": seat,
                    }
                    for seat in range(player_count)
                ]
                coverage.append(
                    {
                        "matchup_id": matchup_id,
                        "plan_id": plan["plan_id"],
                        "seat_samples": per_seat,
                        "tournament_samples": tournament_samples,
                    }
                )
                if tournament_samples < MINIMUM_PROMOTION_TOURNAMENTS_PER_MATCHUP:
                    reasons.append(
                        f"{mode}:insufficient_matchup_samples:{plan['plan_id']}:{matchup_id}"
                    )
                for seat_data in per_seat:
                    if seat_data["samples"] < MINIMUM_PROMOTION_SAMPLES_PER_SEAT:
                        reasons.append(
                            f"{mode}:insufficient_seat_samples:{plan['plan_id']}:{matchup_id}:{seat_data['seat']}"
                        )
                for opponent_id in sorted(opponents & (legacy_ids | champion_ids)):
                    differences = paired_differences.get(
                        (plan["plan_id"], matchup_id, opponent_id), []
                    )
                    mean_difference = (
                        math.fsum(differences) / len(differences) if differences else 0.0
                    )
                    half_width = _normal_95_half_width(differences)
                    lower_bound = (
                        mean_difference - half_width if half_width is not None else None
                    )
                    passed = lower_bound is not None and lower_bound > 0.0
                    comparisons.append(
                        {
                            "lower_95_bound": lower_bound,
                            "matchup_id": matchup_id,
                            "mean_difference": mean_difference,
                            "opponent_id": opponent_id,
                            "passed": passed,
                            "plan_id": plan["plan_id"],
                            "sample_count": len(differences),
                            "uncertainty_95_half_width": half_width,
                        }
                    )
                    if not passed:
                        reasons.append(
                            f"{mode}:performance_not_demonstrated:{plan['plan_id']}:{matchup_id}:{opponent_id}"
                        )
        seed_range = {"minimum": min(seeds), "maximum": max(seeds)}
        rng_algorithm = reports[0]["execution_provenance"]["algorithm_versions"][
            "rng_streams"
        ]
        mode_ranges.append(
            {"rng_algorithm": rng_algorithm, "seed_range": seed_range}
        )
        evidence = fitness_payload["report_evidence"]
        report_checksums.update(item["report_checksum"] for item in evidence)
        manifest_checksums.add(manifest_checksum)
        batches.append(
            {
                "candidate_result": copy.deepcopy(result),
                "evaluation_configuration": copy.deepcopy(
                    fitness_payload["evaluation_configuration"]
                ),
                "manifest_checksum": manifest_checksum,
                "promotion_checks": {
                    "comparisons": comparisons,
                    "coverage": coverage,
                },
                "report_evidence": copy.deepcopy(evidence),
                "seed_range": seed_range,
            }
        )
    eligible_fitness = [
        batch["candidate_result"]["fitness"]
        for batch in batches
        if batch["candidate_result"]["fitness"] is not None
    ]
    return (
        {
            "batches": batches,
            "maximum_uncertainty_penalty": max(
                batch["candidate_result"]["uncertainty_penalty"] for batch in batches
            ),
            "mean_fitness": math.fsum(eligible_fitness) / len(eligible_fitness)
            if eligible_fitness
            else None,
        },
        reasons,
        mode_ranges,
        report_checksums,
        manifest_checksums,
        covered_legacy,
        covered_champions,
        opponent_profiles,
        measured_behavior_counts,
    )


def confirm_candidate(
    registry_artifact: dict[str, Any],
    candidate_id: str,
    legacy_ids: Iterable[str],
    champion_ids: Iterable[str],
    mirrored_reports: Iterable[Path],
    mixed_reports: Iterable[Path],
) -> dict[str, Any]:
    registry = validate_lineage_registry(registry_artifact)
    entries = registry["entries"]
    if candidate_id not in entries:
        _fail("unknown_confirmation_candidate", f"Candidate '{candidate_id}' is not in the registry.")
    legacy = list(dict.fromkeys(legacy_ids))
    champions = list(dict.fromkeys(champion_ids))
    if not legacy or not champions or set(legacy) & set(champions) or candidate_id in set(legacy + champions):
        _fail("invalid_confirmation_opponents", "Legacy and champion IDs must be non-empty and disjoint.")
    if any(identifier not in entries for identifier in champions):
        _fail("unknown_confirmation_opponent", "Every historical champion must exist in the registry.")
    if any(not entries[identifier]["selection_history"] for identifier in champions):
        _fail("invalid_historical_champion", "Historical champion IDs require selection history.")
    entry = entries[candidate_id]
    generation = _candidate_generation(entry)
    (
        mirrored,
        mirrored_reasons,
        mirrored_ranges,
        mirrored_reports_seen,
        mirrored_manifests,
        mirrored_legacy,
        mirrored_champions,
        mirrored_profiles,
        mirrored_behavior_counts,
    ) = _mode_evidence(
        "mirrored", mirrored_reports, generation, candidate_id, set(legacy), set(champions)
    )
    (
        mixed,
        mixed_reasons,
        mixed_ranges,
        mixed_reports_seen,
        mixed_manifests,
        mixed_legacy,
        mixed_champions,
        mixed_profiles,
        mixed_behavior_counts,
    ) = _mode_evidence(
        "mixed", mixed_reports, generation, candidate_id, set(legacy), set(champions)
    )
    reasons = mirrored_reasons + mixed_reasons
    for identifier in legacy:
        if identifier not in mirrored_legacy:
            reasons.append(f"mirrored:missing_legacy:{identifier}")
    for identifier in champions:
        if identifier not in mirrored_champions:
            reasons.append(f"mirrored:missing_champion:{identifier}")
    if not mixed_legacy:
        reasons.append("mixed:missing_legacy")
    if not mixed_champions:
        reasons.append("mixed:missing_champion")
    opponent_profiles = dict(mirrored_profiles)
    for profile_id, snapshot in mixed_profiles.items():
        if profile_id in opponent_profiles and opponent_profiles[profile_id] != snapshot:
            _fail(
                "confirmation_opponent_snapshot_mismatch",
                f"Opponent profile '{profile_id}' changes between confirmation modes.",
            )
        opponent_profiles[profile_id] = snapshot
    for identifier in legacy + champions:
        if identifier not in opponent_profiles:
            reasons.append(f"confirmation:missing_opponent_snapshot:{identifier}")
    for identifier in champions:
        expected = entries[identifier]["candidate"]
        expected_snapshot = {
            "profile_id": expected["candidate_id"],
            "model_id": expected["model_id"],
            "parameters": expected["parameters"],
        }
        if opponent_profiles.get(identifier) != expected_snapshot:
            reasons.append(f"confirmation:champion_snapshot_mismatch:{identifier}")
    genetic_diversity = _genetic_diversity(entry["candidate"], opponent_profiles)
    if not genetic_diversity["passed"]:
        reasons.append("genetic_diversity:insufficient_parameter_distance")
    measured_behavior = _measured_behavior(
        _merge_measured_behavior_counts(
            mirrored_behavior_counts, mixed_behavior_counts
        )
    )

    original_reports: set[str] = set()
    original_manifests: set[str] = set()
    original_ranges: list[dict[str, Any]] = []
    for evaluation in entry["evaluations"]:
        for evidence in evaluation["report_evidence"]:
            original_reports.add(evidence["report_checksum"])
            original_manifests.add(evidence["manifest_checksum"])
            original_ranges.append(
                {
                    "rng_algorithm": evidence["execution_provenance"][
                        "algorithm_versions"
                    ]["rng_streams"],
                    "seed_range": evidence["seed_range"],
                }
            )
    if not entry["evaluations"] or not any(evaluation["eligible"] for evaluation in entry["evaluations"]):
        reasons.append("original:evaluation_ineligible")
    if mirrored_reports_seen & (original_reports | mixed_reports_seen):
        reasons.append("independence:report_checksum_overlap")
    if mixed_reports_seen & original_reports:
        reasons.append("independence:report_checksum_overlap")
    if mirrored_manifests & (original_manifests | mixed_manifests):
        reasons.append("independence:manifest_checksum_overlap")
    if mixed_manifests & original_manifests:
        reasons.append("independence:manifest_checksum_overlap")
    all_ranges = [("original", item) for item in original_ranges]
    all_ranges.extend(("mirrored", item) for item in mirrored_ranges)
    all_ranges.extend(("mixed", item) for item in mixed_ranges)
    for index, (first_mode, first_range) in enumerate(all_ranges):
        for second_mode, second_range in all_ranges[index + 1 :]:
            if first_mode == "original" and second_mode == "original":
                continue
            if first_range["rng_algorithm"] != second_range["rng_algorithm"]:
                reasons.append("independence:rng_algorithm_mismatch")
            elif _effective_seed_ranges_overlap(first_range, second_range):
                reasons.append("independence:effective_seed_overlap")
    reasons = sorted(set(reasons))
    evidence_policy = {
        "comparison_rule": PROMOTION_COMPARISON_RULE,
        "evidence_class": "promotion_eligible" if not reasons else "exploratory_only",
        "minimum_samples_per_seat": MINIMUM_PROMOTION_SAMPLES_PER_SEAT,
        "minimum_tournaments_per_matchup": MINIMUM_PROMOTION_TOURNAMENTS_PER_MATCHUP,
        "policy_version": PROMOTION_EVIDENCE_POLICY_VERSION,
    }
    return create_artifact(
        "confirmation",
        {
            "candidate": copy.deepcopy(entry["candidate"]),
            "evidence_policy": evidence_policy,
            "genetic_diversity": genetic_diversity,
            "historical_champion_ids": champions,
            "ineligibility_reasons": reasons,
            "legacy_ids": legacy,
            "measured_behavior": measured_behavior,
            "mirrored": mirrored,
            "mixed": mixed,
            "opponent_profiles": [
                opponent_profiles[identifier] for identifier in sorted(opponent_profiles)
            ],
            "promotion_eligible": not reasons,
            "registry_checksum": registry_artifact["checksum"],
            "review_required": True,
        },
    )


def validate_confirmation(artifact: dict[str, Any]) -> dict[str, Any]:
    validate_artifact_envelope(artifact, "confirmation")
    payload = artifact["payload"]
    require_exact_fields(payload, CONFIRMATION_FIELDS, "confirmation payload")
    candidate = validate_candidate(payload["candidate"])
    evidence_policy = payload["evidence_policy"]
    expected_policy = {
        "comparison_rule": PROMOTION_COMPARISON_RULE,
        "evidence_class": (
            "promotion_eligible" if payload.get("promotion_eligible") is True else "exploratory_only"
        ),
        "minimum_samples_per_seat": MINIMUM_PROMOTION_SAMPLES_PER_SEAT,
        "minimum_tournaments_per_matchup": MINIMUM_PROMOTION_TOURNAMENTS_PER_MATCHUP,
        "policy_version": PROMOTION_EVIDENCE_POLICY_VERSION,
    }
    if evidence_policy != expected_policy:
        _fail("invalid_confirmation", "Confirmation evidence policy is invalid or inconsistent.")
    registry_checksum = payload["registry_checksum"]
    if (
        not isinstance(registry_checksum, str)
        or len(registry_checksum) != 64
        or any(character not in "0123456789abcdef" for character in registry_checksum)
    ):
        _fail("invalid_confirmation", "Confirmation registry checksum is invalid.")
    legacy_ids = payload["legacy_ids"]
    champion_ids = payload["historical_champion_ids"]
    if not isinstance(legacy_ids, list) or not isinstance(champion_ids, list):
        _fail("invalid_confirmation", "Confirmation opponent IDs must be arrays.")
    legacy = [require_identifier(item, "legacy_id") for item in legacy_ids]
    champions = [require_identifier(item, "historical_champion_id") for item in champion_ids]
    if (
        not legacy
        or not champions
        or len(set(legacy)) != len(legacy)
        or len(set(champions)) != len(champions)
        or set(legacy) & set(champions)
        or candidate["candidate_id"] in set(legacy + champions)
    ):
        _fail("invalid_confirmation", "Confirmation opponent IDs are invalid.")
    raw_profiles = payload["opponent_profiles"]
    if not isinstance(raw_profiles, list):
        _fail("invalid_confirmation", "Confirmation opponent_profiles must be an array.")
    profiles: dict[str, dict[str, Any]] = {}
    for profile in raw_profiles:
        if not isinstance(profile, dict):
            _fail("invalid_confirmation", "Every opponent profile must be an object.")
        require_exact_fields(profile, SIMULATION_PROFILE_FIELDS, "confirmation opponent profile")
        profile_id = require_identifier(profile["profile_id"], "opponent profile_id")
        require_identifier(profile["model_id"], "opponent model_id")
        if not isinstance(profile["parameters"], dict) or profile_id in profiles:
            _fail("invalid_confirmation", "Confirmation opponent profile is invalid or duplicated.")
        profiles[profile_id] = copy.deepcopy(profile)
    if set(profiles) != set(legacy + champions):
        _fail("invalid_confirmation", "Confirmation opponent snapshots do not match opponent IDs.")
    genetic_diversity = payload["genetic_diversity"]
    if not isinstance(genetic_diversity, dict):
        _fail("invalid_confirmation", "Confirmation genetic diversity is invalid.")
    require_exact_fields(
        genetic_diversity,
        (
            "compared_profile_ids",
            "minimum_parameter_distance",
            "nearest_parameter_distance",
            "nearest_profile_id",
            "passed",
        ),
        "confirmation genetic diversity",
    )
    expected_diversity = _genetic_diversity(candidate, profiles)
    if genetic_diversity != expected_diversity:
        _fail("invalid_confirmation", "Confirmation genetic diversity is inconsistent.")
    measured_behavior = _validate_measured_behavior(payload["measured_behavior"])
    if payload.get("review_required") is not True:
        _fail("invalid_confirmation", "Confirmation must require an external reviewer.")
    reasons = payload["ineligibility_reasons"]
    if (
        not isinstance(payload["promotion_eligible"], bool)
        or not isinstance(reasons, list)
        or any(not isinstance(reason, str) or not reason for reason in reasons)
        or reasons != sorted(set(reasons))
    ):
        _fail("invalid_confirmation", "Confirmation eligibility fields are invalid.")
    if payload["promotion_eligible"] != (not reasons):
        _fail("invalid_confirmation", "Confirmation eligibility contradicts its reasons.")
    if payload["promotion_eligible"] and genetic_diversity["passed"] is not True:
        _fail("invalid_confirmation", "Eligible confirmation lacks genetic diversity.")
    for mode in ("mirrored", "mixed"):
        evidence = payload[mode]
        if not isinstance(evidence, dict):
            _fail("invalid_confirmation", f"Confirmation {mode} evidence must be an object.")
        require_exact_fields(
            evidence,
            ("batches", "maximum_uncertainty_penalty", "mean_fitness"),
            f"confirmation {mode} evidence",
        )
        if not isinstance(evidence["batches"], list) or not evidence["batches"]:
            _fail("invalid_confirmation", f"Confirmation {mode} requires evidence batches.")
        for field, maximum in (
            ("maximum_uncertainty_penalty", 0.10),
            ("mean_fitness", 1.0),
        ):
            value = evidence[field]
            if value is None and field == "mean_fitness":
                continue
            if (
                isinstance(value, bool)
                or not isinstance(value, (int, float))
                or not math.isfinite(float(value))
                or not 0.0 <= float(value) <= maximum
            ):
                _fail("invalid_confirmation", f"Confirmation {mode} {field} is invalid.")
        mode_fitness: list[float] = []
        mode_penalties: list[float] = []
        mode_compared_opponents: set[str] = set()
        for batch in evidence["batches"]:
            if not isinstance(batch, dict):
                _fail("invalid_confirmation", f"Confirmation {mode} batch must be an object.")
            require_exact_fields(
                batch,
                (
                    "candidate_result",
                    "evaluation_configuration",
                    "manifest_checksum",
                    "promotion_checks",
                    "report_evidence",
                    "seed_range",
                ),
                f"confirmation {mode} batch",
            )
            result = batch["candidate_result"]
            if not isinstance(result, dict) or validate_candidate(result.get("candidate")) != candidate:
                _fail("invalid_confirmation", f"Confirmation {mode} candidate result is invalid.")
            require_exact_fields(
                result,
                (
                    "candidate",
                    "component_means",
                    "eligible",
                    "fitness",
                    "ineligibility_reasons",
                    "plan_sample_counts",
                    "point_fitness",
                    "sample_count",
                    "style_checks",
                    "uncertainty_95_half_width",
                    "uncertainty_penalty",
                ),
                f"confirmation {mode} candidate result",
            )
            if not isinstance(result["eligible"], bool) or not isinstance(
                result["ineligibility_reasons"], list
            ):
                _fail("invalid_confirmation", f"Confirmation {mode} result eligibility is invalid.")
            if any(
                not isinstance(reason, str) or not reason
                for reason in result["ineligibility_reasons"]
            ):
                _fail("invalid_confirmation", f"Confirmation {mode} result reasons are invalid.")
            means = result["component_means"]
            uncertainty = result["uncertainty_95_half_width"]
            if not isinstance(means, dict) or not isinstance(uncertainty, dict):
                _fail("invalid_confirmation", f"Confirmation {mode} component evidence is invalid.")
            require_exact_fields(means, COMPONENTS, f"confirmation {mode} component means")
            require_exact_fields(
                uncertainty, COMPONENTS, f"confirmation {mode} component uncertainty"
            )
            for values, maximum, nullable in (
                (means, 1.0, False),
                (uncertainty, 2.0, True),
            ):
                if any(
                    value is not None
                    and (
                        isinstance(value, bool)
                        or not isinstance(value, (int, float))
                        or not math.isfinite(float(value))
                        or not 0.0 <= float(value) <= maximum
                    )
                    for value in values.values()
                ) or (not nullable and any(value is None for value in values.values())):
                    _fail("invalid_confirmation", f"Confirmation {mode} components are invalid.")
            point_fitness = result["point_fitness"]
            if (
                isinstance(point_fitness, bool)
                or not isinstance(point_fitness, (int, float))
                or not math.isfinite(float(point_fitness))
                or not 0.0 <= float(point_fitness) <= 1.0
            ):
                _fail("invalid_confirmation", f"Confirmation {mode} point fitness is invalid.")
            sample_count = require_integer(
                result["sample_count"], "confirmation sample_count", 0, 2**31 - 1
            )
            plan_counts = result["plan_sample_counts"]
            if (
                not isinstance(plan_counts, dict)
                or any(
                    not isinstance(value, int) or isinstance(value, bool) or value < 0
                    for value in plan_counts.values()
                )
                or sum(plan_counts.values()) != sample_count
            ):
                _fail("invalid_confirmation", f"Confirmation {mode} samples are invalid.")
            style = result["style_checks"]
            if not isinstance(style, dict):
                _fail("invalid_confirmation", f"Confirmation {mode} style evidence is invalid.")
            require_exact_fields(
                style,
                ("bounded_behavioral_rates", "zero_invalid_action_fallbacks"),
                f"confirmation {mode} style checks",
            )
            bounded = style["bounded_behavioral_rates"]
            fallbacks = style["zero_invalid_action_fallbacks"]
            if (
                not isinstance(bounded, dict)
                or not isinstance(fallbacks, dict)
                or bounded.get("passed") is not True
                or bounded.get("violations") != []
                or not isinstance(fallbacks.get("passed"), bool)
                or not isinstance(fallbacks.get("value"), int)
                or isinstance(fallbacks.get("value"), bool)
                or fallbacks["value"] < 0
                or fallbacks["passed"] != (fallbacks["value"] == 0)
            ):
                _fail("invalid_confirmation", f"Confirmation {mode} style evidence is invalid.")
            fitness = result["fitness"]
            if result["eligible"]:
                if (
                    result["ineligibility_reasons"]
                    or isinstance(fitness, bool)
                    or not isinstance(fitness, (int, float))
                    or not math.isfinite(float(fitness))
                    or not 0.0 <= float(fitness) <= 1.0
                ):
                    _fail("invalid_confirmation", f"Confirmation {mode} eligible result is invalid.")
                mode_fitness.append(float(fitness))
            elif fitness is not None or not result["ineligibility_reasons"]:
                _fail("invalid_confirmation", f"Confirmation {mode} ineligible result is invalid.")
            penalty = result["uncertainty_penalty"]
            if (
                isinstance(penalty, bool)
                or not isinstance(penalty, (int, float))
                or not math.isfinite(float(penalty))
                or not 0.0 <= float(penalty) <= 0.10
            ):
                _fail("invalid_confirmation", f"Confirmation {mode} uncertainty is invalid.")
            mode_penalties.append(float(penalty))
            expected_penalty = (
                min(0.10, 0.10 / math.sqrt(sample_count)) if sample_count else 0.10
            )
            if not math.isclose(float(penalty), expected_penalty, rel_tol=1e-12, abs_tol=1e-12):
                _fail("invalid_confirmation", f"Confirmation {mode} penalty is inconsistent.")
            if result["eligible"]:
                expected_point_fitness = max(
                    0.0,
                    min(
                        1.0,
                        math.fsum(
                            weight * float(means[name])
                            for weight, name in zip(WEIGHTS, COMPONENTS)
                        ),
                    ),
                )
                if not math.isclose(
                    float(result["point_fitness"]),
                    expected_point_fitness,
                    rel_tol=1e-12,
                    abs_tol=1e-12,
                ):
                    _fail("invalid_confirmation", f"Confirmation {mode} point fitness is inconsistent.")
                expected_fitness = max(0.0, expected_point_fitness - expected_penalty)
                if not math.isclose(
                    float(result["fitness"]), expected_fitness, rel_tol=1e-12, abs_tol=1e-12
                ):
                    _fail("invalid_confirmation", f"Confirmation {mode} fitness is inconsistent.")
                if fallbacks["passed"] is not True:
                    _fail("invalid_confirmation", f"Confirmation {mode} eligible style is invalid.")
            promotion_checks = batch["promotion_checks"]
            if not isinstance(promotion_checks, dict):
                _fail("invalid_confirmation", f"Confirmation {mode} promotion checks are invalid.")
            require_exact_fields(
                promotion_checks,
                ("comparisons", "coverage"),
                f"confirmation {mode} promotion checks",
            )
            coverage = promotion_checks["coverage"]
            if not isinstance(coverage, list) or not coverage:
                _fail("invalid_confirmation", f"Confirmation {mode} coverage is invalid.")
            coverage_counts: dict[tuple[str, str], int] = {}
            for coverage_item in coverage:
                if not isinstance(coverage_item, dict):
                    _fail("invalid_confirmation", f"Confirmation {mode} coverage is invalid.")
                require_exact_fields(
                    coverage_item,
                    ("matchup_id", "plan_id", "seat_samples", "tournament_samples"),
                    f"confirmation {mode} coverage",
                )
                require_identifier(coverage_item["matchup_id"], "confirmation matchup_id")
                require_identifier(coverage_item["plan_id"], "confirmation plan_id")
                coverage_key = (coverage_item["plan_id"], coverage_item["matchup_id"])
                if coverage_key in coverage_counts:
                    _fail("invalid_confirmation", f"Confirmation {mode} coverage is duplicated.")
                tournament_samples = require_integer(
                    coverage_item["tournament_samples"],
                    "confirmation tournament samples",
                    0,
                    2**31 - 1,
                )
                seat_samples = coverage_item["seat_samples"]
                if not isinstance(seat_samples, list) or not seat_samples:
                    _fail("invalid_confirmation", f"Confirmation {mode} seat coverage is invalid.")
                sample_total = 0
                seen_seats: set[int] = set()
                for seat_item in seat_samples:
                    if not isinstance(seat_item, dict):
                        _fail("invalid_confirmation", f"Confirmation {mode} seat coverage is invalid.")
                    require_exact_fields(
                        seat_item, ("samples", "seat"), f"confirmation {mode} seat coverage"
                    )
                    seat = require_integer(seat_item["seat"], "confirmation seat", 0, 8)
                    samples = require_integer(
                        seat_item["samples"], "confirmation seat samples", 0, 2**31 - 1
                    )
                    if seat in seen_seats:
                        _fail("invalid_confirmation", f"Confirmation {mode} seat coverage is duplicated.")
                    seen_seats.add(seat)
                    sample_total += samples
                if sample_total != tournament_samples:
                    _fail("invalid_confirmation", f"Confirmation {mode} coverage totals are inconsistent.")
                coverage_counts[coverage_key] = tournament_samples
                if payload["promotion_eligible"] and (
                    tournament_samples < MINIMUM_PROMOTION_TOURNAMENTS_PER_MATCHUP
                    or any(
                        item["samples"] < MINIMUM_PROMOTION_SAMPLES_PER_SEAT
                        for item in seat_samples
                    )
                ):
                    _fail("invalid_confirmation", f"Eligible confirmation has insufficient {mode} coverage.")
            comparisons = promotion_checks["comparisons"]
            if not isinstance(comparisons, list) or not comparisons:
                _fail("invalid_confirmation", f"Confirmation {mode} comparisons are invalid.")
            comparison_keys: set[tuple[str, str, str]] = set()
            for comparison in comparisons:
                if not isinstance(comparison, dict):
                    _fail("invalid_confirmation", f"Confirmation {mode} comparison is invalid.")
                require_exact_fields(
                    comparison,
                    (
                        "lower_95_bound",
                        "matchup_id",
                        "mean_difference",
                        "opponent_id",
                        "passed",
                        "plan_id",
                        "sample_count",
                        "uncertainty_95_half_width",
                    ),
                    f"confirmation {mode} comparison",
                )
                plan_id = require_identifier(comparison["plan_id"], "confirmation plan_id")
                matchup_id = require_identifier(
                    comparison["matchup_id"], "confirmation matchup_id"
                )
                opponent_id = require_identifier(
                    comparison["opponent_id"], "confirmation opponent_id"
                )
                comparison_key = (plan_id, matchup_id, opponent_id)
                if comparison_key in comparison_keys or opponent_id not in set(legacy + champions):
                    _fail("invalid_confirmation", f"Confirmation {mode} comparison is invalid.")
                comparison_keys.add(comparison_key)
                mode_compared_opponents.add(opponent_id)
                comparison_samples = require_integer(
                    comparison["sample_count"], "confirmation comparison samples", 0, 2**31 - 1
                )
                if comparison_samples != coverage_counts.get((plan_id, matchup_id)):
                    _fail("invalid_confirmation", f"Confirmation {mode} comparison samples are inconsistent.")
                mean_value = comparison["mean_difference"]
                if (
                    isinstance(mean_value, bool)
                    or not isinstance(mean_value, (int, float))
                    or not math.isfinite(float(mean_value))
                ):
                    _fail("invalid_confirmation", f"Confirmation {mode} comparison is invalid.")
                mean_difference = float(mean_value)
                half_value = comparison["uncertainty_95_half_width"]
                lower_value = comparison["lower_95_bound"]
                if comparison_samples < 2:
                    if half_value is not None or lower_value is not None:
                        _fail("invalid_confirmation", f"Confirmation {mode} sparse comparison is invalid.")
                    lower_bound = None
                else:
                    if any(
                        isinstance(value, bool)
                        or not isinstance(value, (int, float))
                        or not math.isfinite(float(value))
                        for value in (half_value, lower_value)
                    ):
                        _fail("invalid_confirmation", f"Confirmation {mode} comparison is invalid.")
                    half_width = float(half_value)
                    lower_bound = float(lower_value)
                    if half_width < 0.0 or not math.isclose(
                        lower_bound,
                        mean_difference - half_width,
                        rel_tol=1e-12,
                        abs_tol=1e-12,
                    ):
                        _fail("invalid_confirmation", f"Confirmation {mode} comparison is inconsistent.")
                if (
                    not isinstance(comparison["passed"], bool)
                    or comparison["passed"] != (lower_bound is not None and lower_bound > 0.0)
                ):
                    _fail("invalid_confirmation", f"Confirmation {mode} comparison result is inconsistent.")
                if payload["promotion_eligible"] and not comparison["passed"]:
                    _fail("invalid_confirmation", f"Eligible confirmation fails {mode} comparison.")
            checksum = batch["manifest_checksum"]
            if (
                not isinstance(checksum, str)
                or len(checksum) != 64
                or any(character not in "0123456789abcdef" for character in checksum)
            ):
                _fail("invalid_confirmation", f"Confirmation {mode} manifest checksum is invalid.")
            report_evidence = batch["report_evidence"]
            configuration = batch["evaluation_configuration"]
            if not isinstance(configuration, dict) or not isinstance(report_evidence, list) or not report_evidence:
                _fail("invalid_confirmation", f"Confirmation {mode} batch evidence is invalid.")
            require_exact_fields(configuration, ("plans", "regimes"), "confirmation configuration")
            if not isinstance(configuration["plans"], list) or not isinstance(
                configuration["regimes"], list
            ):
                _fail("invalid_confirmation", f"Confirmation {mode} configuration is invalid.")
            seed_range = batch["seed_range"]
            if not isinstance(seed_range, dict):
                _fail("invalid_confirmation", f"Confirmation {mode} seed range is invalid.")
            require_exact_fields(seed_range, ("minimum", "maximum"), "confirmation seed range")
            minimum, maximum = validate_report_seed_range(seed_range, "confirmation seed range")
            if minimum > maximum:
                _fail("invalid_confirmation", f"Confirmation {mode} seed range is invalid.")
            evidence_ranges: list[dict[str, int]] = []
            for item in report_evidence:
                if not isinstance(item, dict):
                    _fail("invalid_confirmation", f"Confirmation {mode} report evidence is invalid.")
                require_exact_fields(
                    item,
                    (
                        "batch_id",
                        "code_revision",
                        "command_version",
                        "execution_provenance",
                        "manifest_checksum",
                        "report_checksum",
                        "seed_range",
                        "shard",
                    ),
                    f"confirmation {mode} report evidence",
                )
                if item["command_version"] != "simulation_cli_v6":
                    _fail(
                        "invalid_confirmation",
                        f"Confirmation {mode} uses an unsupported simulation command version.",
                    )
                provenance = _validate_execution_provenance(item["execution_provenance"])
                if provenance["code_revision"] != item["code_revision"]:
                    _fail("invalid_confirmation", f"Confirmation {mode} provenance is inconsistent.")
                if item["manifest_checksum"] != checksum:
                    _fail("invalid_confirmation", f"Confirmation {mode} report manifest is inconsistent.")
                report_checksum = item["report_checksum"]
                if (
                    not isinstance(report_checksum, str)
                    or len(report_checksum) != 64
                    or any(character not in "0123456789abcdef" for character in report_checksum)
                ):
                    _fail("invalid_confirmation", f"Confirmation {mode} report checksum is invalid.")
                item_range = item["seed_range"]
                if not isinstance(item_range, dict):
                    _fail("invalid_confirmation", f"Confirmation {mode} report seed range is invalid.")
                require_exact_fields(item_range, ("minimum", "maximum"), "report seed range")
                item_minimum, item_maximum = validate_report_seed_range(item_range, "report seed range")
                if item_minimum > item_maximum:
                    _fail("invalid_confirmation", f"Confirmation {mode} report seed range is invalid.")
                evidence_ranges.append({"minimum": item_minimum, "maximum": item_maximum})
            if minimum != min(item["minimum"] for item in evidence_ranges) or maximum != max(
                item["maximum"] for item in evidence_ranges
            ):
                _fail("invalid_confirmation", f"Confirmation {mode} aggregate seed range is invalid.")
        expected_mean = math.fsum(mode_fitness) / len(mode_fitness) if mode_fitness else None
        if evidence["mean_fitness"] != expected_mean or evidence[
            "maximum_uncertainty_penalty"
        ] != max(mode_penalties):
            _fail("invalid_confirmation", f"Confirmation {mode} summary is inconsistent.")
        if payload["promotion_eligible"] and len(mode_fitness) != len(evidence["batches"]):
            _fail("invalid_confirmation", f"Eligible confirmation has an ineligible {mode} batch.")
        if payload["promotion_eligible"]:
            if mode == "mirrored" and mode_compared_opponents != set(legacy + champions):
                _fail("invalid_confirmation", "Eligible mirrored confirmation omits a benchmark.")
            if mode == "mixed" and (
                not mode_compared_opponents.intersection(legacy)
                or not mode_compared_opponents.intersection(champions)
            ):
                _fail("invalid_confirmation", "Eligible mixed confirmation omits an opponent class.")
    validated = copy.deepcopy(payload)
    validated["measured_behavior"] = measured_behavior
    return validated
