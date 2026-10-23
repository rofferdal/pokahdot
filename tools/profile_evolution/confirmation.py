"""Independent mirrored and mixed-table confirmation evidence."""

from __future__ import annotations

import copy
import math
from pathlib import Path
from typing import Any, Iterable

from .artifacts import create_artifact, load_json_object, validate_artifact_envelope
from .contracts import (
    require_exact_fields,
    require_identifier,
    require_integer,
    validate_candidate,
)
from .errors import ExitCode, ToolError
from .fitness import COMPONENTS, WEIGHTS, evaluate_fitness
from .lineage import validate_lineage_registry

CONFIRMATION_FIELDS = (
    "candidate",
    "historical_champion_ids",
    "ineligibility_reasons",
    "legacy_ids",
    "mirrored",
    "mixed",
    "opponent_profiles",
    "promotion_eligible",
    "registry_checksum",
)

SIMULATION_PROFILE_FIELDS = ("profile_id", "model_id", "parameters")


def _fail(code: str, message: str) -> None:
    raise ToolError(code, message, ExitCode.INVALID_INPUT)


def _ranges_overlap(first: dict[str, int], second: dict[str, int]) -> bool:
    return first["minimum"] <= second["maximum"] and second["minimum"] <= first["maximum"]


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


def _group_reports(paths: Iterable[Path]) -> list[tuple[str, list[Path], dict[str, Any]]]:
    grouped: dict[str, tuple[list[Path], dict[str, Any]]] = {}
    for path in paths:
        report = load_json_object(path)
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
    list[dict[str, int]],
    set[str],
    set[str],
    set[str],
    set[str],
    dict[str, dict[str, Any]],
]:
    batches: list[dict[str, Any]] = []
    reasons: list[str] = []
    mode_ranges: list[dict[str, int]] = []
    report_checksums: set[str] = set()
    manifest_checksums: set[str] = set()
    covered_legacy: set[str] = set()
    covered_champions: set[str] = set()
    opponent_profiles: dict[str, dict[str, Any]] = {}
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
        reports = [load_json_object(path) for path in group_paths]
        seats: dict[tuple[str, str], set[int]] = {}
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
                for seat_data in tournament["seat_map"]:
                    if seat_data["profile_id"] == candidate_id:
                        seats.setdefault(key, set()).add(seat_data["seat"])
        for plan in manifest["evaluation_plans"]:
            regime = regimes[plan["regime_id"]]
            player_count = regime["player_count"]
            if mode == "mirrored" and player_count != 2:
                reasons.append("mirrored:not_heads_up")
            if mode == "mixed" and player_count < 3:
                reasons.append("mixed:table_too_small")
            for matchup_id in plan["matchup_ids"]:
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
        seed_range = {"minimum": min(seeds), "maximum": max(seeds)}
        mode_ranges.append(seed_range)
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

    original_reports: set[str] = set()
    original_manifests: set[str] = set()
    original_ranges: list[dict[str, int]] = []
    for evaluation in entry["evaluations"]:
        for evidence in evaluation["report_evidence"]:
            original_reports.add(evidence["report_checksum"])
            original_manifests.add(evidence["manifest_checksum"])
            original_ranges.append(evidence["seed_range"])
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
            if not (
                first_mode == "original" and second_mode == "original"
            ) and _ranges_overlap(first_range, second_range):
                reasons.append("independence:seed_range_overlap")
    reasons = sorted(set(reasons))
    return create_artifact(
        "confirmation",
        {
            "candidate": copy.deepcopy(entry["candidate"]),
            "historical_champion_ids": champions,
            "ineligibility_reasons": reasons,
            "legacy_ids": legacy,
            "mirrored": mirrored,
            "mixed": mixed,
            "opponent_profiles": [
                opponent_profiles[identifier] for identifier in sorted(opponent_profiles)
            ],
            "promotion_eligible": not reasons,
            "registry_checksum": registry_artifact["checksum"],
        },
    )


def validate_confirmation(artifact: dict[str, Any]) -> dict[str, Any]:
    validate_artifact_envelope(artifact, "confirmation")
    payload = artifact["payload"]
    require_exact_fields(payload, CONFIRMATION_FIELDS, "confirmation payload")
    candidate = validate_candidate(payload["candidate"])
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
        for batch in evidence["batches"]:
            if not isinstance(batch, dict):
                _fail("invalid_confirmation", f"Confirmation {mode} batch must be an object.")
            require_exact_fields(
                batch,
                (
                    "candidate_result",
                    "evaluation_configuration",
                    "manifest_checksum",
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
            for values, maximum in ((means, 1.0), (uncertainty, 2.0)):
                if any(
                    isinstance(value, bool)
                    or not isinstance(value, (int, float))
                    or not math.isfinite(float(value))
                    or not 0.0 <= float(value) <= maximum
                    for value in values.values()
                ):
                    _fail("invalid_confirmation", f"Confirmation {mode} components are invalid.")
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
            expected_penalty = min(
                0.10, math.fsum(float(value) for value in uncertainty.values()) / len(COMPONENTS)
            )
            if not math.isclose(float(penalty), expected_penalty, rel_tol=1e-12, abs_tol=1e-12):
                _fail("invalid_confirmation", f"Confirmation {mode} penalty is inconsistent.")
            if result["eligible"]:
                expected_fitness = max(
                    0.0,
                    min(
                        1.0,
                        math.fsum(
                            weight * float(means[name])
                            for weight, name in zip(WEIGHTS, COMPONENTS)
                        )
                        - expected_penalty,
                    ),
                )
                if not math.isclose(
                    float(result["fitness"]), expected_fitness, rel_tol=1e-12, abs_tol=1e-12
                ):
                    _fail("invalid_confirmation", f"Confirmation {mode} fitness is inconsistent.")
                if fallbacks["passed"] is not True:
                    _fail("invalid_confirmation", f"Confirmation {mode} eligible style is invalid.")
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
            minimum = require_integer(seed_range["minimum"], "seed range minimum", 0, (1 << 64) - 1)
            maximum = require_integer(seed_range["maximum"], "seed range maximum", 0, (1 << 64) - 1)
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
                        "manifest_checksum",
                        "report_checksum",
                        "seed_range",
                        "shard",
                    ),
                    f"confirmation {mode} report evidence",
                )
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
                item_minimum = require_integer(item_range["minimum"], "report seed minimum", 0, (1 << 64) - 1)
                item_maximum = require_integer(item_range["maximum"], "report seed maximum", 0, (1 << 64) - 1)
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
    return payload
