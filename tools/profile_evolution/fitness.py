"""Strict evaluation of candidate fitness from completed simulation reports."""

from __future__ import annotations

import hashlib
import json
import math
import copy
from pathlib import Path
from typing import Any, Iterable

from .artifacts import create_artifact, load_json_object
from .contracts import require_exact_fields, validate_candidate_collection, validate_parameters
from .errors import ExitCode, ToolError

REPORT_FIELDS = (
    "report_schema_version",
    "manifest",
    "manifest_checksum",
    "roster",
    "code_revision",
    "command_version",
    "execution_provenance",
    "shard",
    "started_at",
    "finished_at",
    "tournaments",
    "aggregates",
    "traces",
)
EXECUTION_PROVENANCE_FIELDS = (
    "algorithm_versions",
    "code_revision",
    "dirty_source_fingerprint",
    "engine_version",
    "source_state",
)
SUPPORTED_ALGORITHM_VERSIONS = {
    "aggregate_statistics": "normal_95_v1",
    "rng_streams": "named_stream_sha256_v2",
    "simulation_runner": "tournament_match_v1",
    "tournament_metrics": "elimination_history_v1",
}
SUPPORTED_RNG_STREAM_VERSIONS = ("named_stream_v1", "named_stream_sha256_v2")
MANIFEST_FIELDS = (
    "schema_version",
    "batch_id",
    "seed_start",
    "profiles",
    "regimes",
    "matchups",
    "evaluation_plans",
)
PROFILE_FIELDS = ("profile_id", "model_id", "parameters")
REGIME_FIELDS = (
    "regime_id",
    "player_count",
    "starting_stack",
    "starting_small_blind",
    "starting_big_blind",
    "blind_progression",
)
MATCHUP_FIELDS = ("matchup_id", "profile_ids")
PLAN_FIELDS = (
    "plan_id",
    "regime_id",
    "matchup_ids",
    "tournament_count",
    "seat_rotation",
    "minimum_profile_samples",
    "uncertainty_estimator",
)
TOURNAMENT_FIELDS = (
    "tournament_index",
    "plan_id",
    "plan_tournament_index",
    "regime_id",
    "matchup_id",
    "matchup_occurrence",
    "rotation",
    "effective_seed",
    "seat_map",
    "selected_profile_ids",
    "termination_reason",
    "winner_profile_id",
    "tournament_hand_count",
    "profile_results",
    "diagnostics",
)
PROFILE_RESULT_FIELDS = (
    "seat",
    "profile_id",
    "finishing_position",
    "won_tournament",
    "top_third",
    "starting_stack",
    "final_stack",
    "chip_differential",
    "hands_survived",
    "tournament_hand_count",
    "survival_ratio",
    "blind_normalized_chip_sum",
    "hands_observed",
    "bnc_per_100",
    "vpip_hands",
    "vpip_rate",
    "pfr_hands",
    "pfr_rate",
    "bet_actions",
    "raise_actions",
    "aggressive_actions",
    "call_actions",
    "aggression_factor",
    "bet_raise_opportunities",
    "bet_raise_frequency",
    "check_bet_opportunities",
    "bets_at_check_bet_opportunity",
    "bet_frequency",
    "call_raise_opportunities",
    "calls_at_call_raise_opportunity",
    "raises_at_call_raise_opportunity",
    "raise_share",
    "eligible_bluff_opportunities",
    "bluff_actions",
    "eligible_bluff_frequency",
    "invalid_action_fallbacks",
)
COUNT_FIELDS = (
    "seat",
    "finishing_position",
    "starting_stack",
    "final_stack",
    "hands_survived",
    "tournament_hand_count",
    "hands_observed",
    "vpip_hands",
    "pfr_hands",
    "bet_actions",
    "raise_actions",
    "aggressive_actions",
    "call_actions",
    "bet_raise_opportunities",
    "check_bet_opportunities",
    "bets_at_check_bet_opportunity",
    "call_raise_opportunities",
    "calls_at_call_raise_opportunity",
    "raises_at_call_raise_opportunity",
    "eligible_bluff_opportunities",
    "bluff_actions",
    "invalid_action_fallbacks",
)
FINITE_FIELDS = (
    "chip_differential",
    "survival_ratio",
    "blind_normalized_chip_sum",
    "bnc_per_100",
    "vpip_rate",
    "pfr_rate",
    "aggression_factor",
    "bet_raise_frequency",
    "bet_frequency",
    "raise_share",
    "eligible_bluff_frequency",
)
RATE_FIELDS = (
    "survival_ratio",
    "vpip_rate",
    "pfr_rate",
    "bet_raise_frequency",
    "bet_frequency",
    "raise_share",
    "eligible_bluff_frequency",
)
COMPONENTS = (
    "win_score",
    "finish_score",
    "top_third_score",
    "chip_score",
    "survival_score",
    "blind_chip_score",
)
WEIGHTS = (0.30, 0.20, 0.15, 0.15, 0.10, 0.10)


def _invalid(code: str, message: str, details: dict[str, Any] | None = None) -> None:
    raise ToolError(code, message, ExitCode.INVALID_INPUT, details)


def _validate_execution_provenance(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        _invalid("invalid_simulation_report", "Execution provenance must be an object.")
    require_exact_fields(value, EXECUTION_PROVENANCE_FIELDS, "execution provenance")
    algorithms = value["algorithm_versions"]
    expected_algorithms = dict(SUPPORTED_ALGORITHM_VERSIONS)
    rng_algorithm = algorithms.get("rng_streams") if isinstance(algorithms, dict) else None
    expected_algorithms["rng_streams"] = rng_algorithm
    if (
        algorithms != expected_algorithms
        or rng_algorithm not in SUPPORTED_RNG_STREAM_VERSIONS
    ):
        _invalid("unsupported_simulation_report", "Simulation algorithm versions are unsupported.")
    for field in ("code_revision", "dirty_source_fingerprint", "engine_version", "source_state"):
        if not isinstance(value[field], str):
            _invalid("invalid_simulation_report", f"Execution provenance {field} must be a string.")
    revision = value["code_revision"]
    if len(revision) not in (40, 64) or any(character not in "0123456789abcdef" for character in revision):
        _invalid("invalid_simulation_report", "Execution provenance requires a Git revision.")
    if not value["engine_version"]:
        _invalid("invalid_simulation_report", "Execution provenance requires an engine version.")
    state = value["source_state"]
    fingerprint = value["dirty_source_fingerprint"]
    if state not in ("clean", "dirty"):
        _invalid("invalid_simulation_report", "Execution provenance source state is invalid.")
    if state == "dirty":
        if len(fingerprint) != 64 or any(character not in "0123456789abcdef" for character in fingerprint):
            _invalid("invalid_simulation_report", "Dirty source fingerprint must be SHA-256.")
    elif fingerprint:
        _invalid("invalid_simulation_report", "Clean source must not have a dirty fingerprint.")
    return value


def _integer(value: Any, context: str, minimum: int | None = None) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        _invalid("invalid_simulation_report", f"{context} must be an integer.")
    if minimum is not None and value < minimum:
        _invalid("invalid_simulation_report", f"{context} must be at least {minimum}.")
    return value


def _number(value: Any, context: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        _invalid("invalid_simulation_report", f"{context} must be a number.")
    result = float(value)
    if not math.isfinite(result):
        _invalid("invalid_simulation_report", f"{context} must be finite.")
    return result


def _string(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value:
        _invalid("invalid_simulation_report", f"{context} must be a non-empty string.")
    return value


def _object_array(value: Any, context: str) -> list[dict[str, Any]]:
    if not isinstance(value, list) or any(not isinstance(item, dict) for item in value):
        _invalid("invalid_simulation_report", f"{context} must be an array of objects.")
    return value


def _simulation_manifest_checksum(manifest: dict[str, Any]) -> str:
    encoded = json.dumps(
        manifest, ensure_ascii=False, separators=(",", ":"), sort_keys=True, allow_nan=False
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _roster_provenance(manifest: dict[str, Any]) -> dict[str, Any]:
    profiles = manifest["profiles"]
    encoded = json.dumps(
        profiles, ensure_ascii=False, separators=(",", ":"), sort_keys=True, allow_nan=False
    ).encode("utf-8")
    return {
        "version": f"manifest_profiles_v1:{hashlib.sha256(encoded).hexdigest()}",
        "profile_ids": [profile["profile_id"] for profile in profiles],
    }


def _validate_manifest(manifest: dict[str, Any]) -> dict[str, Any]:
    require_exact_fields(manifest, MANIFEST_FIELDS, "simulation manifest")
    if manifest["schema_version"] != 2:
        _invalid("unsupported_simulation_manifest", "Simulation manifest schema must be 2.")
    _string(manifest["batch_id"], "manifest.batch_id")
    _integer(manifest["seed_start"], "manifest.seed_start")
    profiles = _object_array(manifest["profiles"], "manifest.profiles")
    regimes = _object_array(manifest["regimes"], "manifest.regimes")
    matchups = _object_array(manifest["matchups"], "manifest.matchups")
    plans = _object_array(manifest["evaluation_plans"], "manifest.evaluation_plans")
    if not profiles or not regimes or not matchups or not plans:
        _invalid("invalid_simulation_manifest", "Manifest collections must be non-empty.")
    profile_ids: set[str] = set()
    for profile in profiles:
        require_exact_fields(profile, PROFILE_FIELDS, "simulation profile")
        profile_id = _string(profile["profile_id"], "profile_id")
        if profile_id in profile_ids or not isinstance(profile["parameters"], dict):
            _invalid("invalid_simulation_manifest", "Simulation profiles are invalid or duplicated.")
        profile_ids.add(profile_id)
        _string(profile["model_id"], "model_id")
    regime_by_id: dict[str, dict[str, Any]] = {}
    for regime in regimes:
        require_exact_fields(regime, REGIME_FIELDS, "simulation regime")
        regime_id = _string(regime["regime_id"], "regime_id")
        if regime_id in regime_by_id:
            _invalid("invalid_simulation_manifest", "Simulation regime IDs must be unique.")
        player_count = _integer(regime["player_count"], "player_count", 2)
        _integer(regime["starting_stack"], "starting_stack", 1)
        _integer(regime["starting_small_blind"], "starting_small_blind", 1)
        _integer(regime["starting_big_blind"], "starting_big_blind", 1)
        if regime["blind_progression"] != "normative_hand_based_v1" or player_count > 9:
            _invalid("invalid_simulation_manifest", "Simulation regime is unsupported.")
        regime_by_id[regime_id] = regime
    matchup_by_id: dict[str, dict[str, Any]] = {}
    for matchup in matchups:
        require_exact_fields(matchup, MATCHUP_FIELDS, "simulation matchup")
        matchup_id = _string(matchup["matchup_id"], "matchup_id")
        ids = matchup["profile_ids"]
        if (
            matchup_id in matchup_by_id
            or not isinstance(ids, list)
            or not ids
            or any(not isinstance(profile_id, str) or profile_id not in profile_ids for profile_id in ids)
        ):
            _invalid("invalid_simulation_manifest", "Simulation matchup is invalid.")
        matchup_by_id[matchup_id] = matchup
    plan_ids: set[str] = set()
    for plan in plans:
        require_exact_fields(plan, PLAN_FIELDS, "simulation evaluation plan")
        plan_id = _string(plan["plan_id"], "plan_id")
        regime_id = _string(plan["regime_id"], "plan.regime_id")
        matchup_ids = plan["matchup_ids"]
        if (
            plan_id in plan_ids
            or regime_id not in regime_by_id
            or not isinstance(matchup_ids, list)
            or not matchup_ids
            or any(matchup_id not in matchup_by_id for matchup_id in matchup_ids)
            or plan["seat_rotation"] != "cyclic"
            or plan["uncertainty_estimator"] != "normal_95"
        ):
            _invalid("invalid_simulation_manifest", "Simulation evaluation plan is invalid.")
        _integer(plan["tournament_count"], "tournament_count", 1)
        _integer(plan["minimum_profile_samples"], "minimum_profile_samples", 1)
        player_count = regime_by_id[regime_id]["player_count"]
        if any(len(matchup_by_id[item]["profile_ids"]) != player_count for item in matchup_ids):
            _invalid("invalid_simulation_manifest", "Plan matchup size does not fit its regime.")
        plan_ids.add(plan_id)
    return {
        "profiles": {profile["profile_id"]: profile for profile in profiles},
        "regimes": regime_by_id,
        "matchups": matchup_by_id,
        "plans": {plan["plan_id"]: plan for plan in plans},
    }


def _planned_tournaments(manifest: dict[str, Any], indexes: dict[str, Any]) -> dict[int, dict[str, Any]]:
    planned: dict[int, dict[str, Any]] = {}
    global_index = 0
    for plan in manifest["evaluation_plans"]:
        regime = indexes["regimes"][plan["regime_id"]]
        for local_index in range(plan["tournament_count"]):
            matchup_id = plan["matchup_ids"][local_index % len(plan["matchup_ids"])]
            occurrence = local_index // len(plan["matchup_ids"])
            rotation = occurrence % regime["player_count"]
            matchup = indexes["matchups"][matchup_id]
            seat_map = [
                {
                    "seat": seat,
                    "profile_id": matchup["profile_ids"][(seat + rotation) % regime["player_count"]],
                }
                for seat in range(regime["player_count"])
            ]
            planned[global_index] = {
                "tournament_index": global_index,
                "plan_id": plan["plan_id"],
                "plan_tournament_index": local_index,
                "regime_id": plan["regime_id"],
                "matchup_id": matchup_id,
                "matchup_occurrence": occurrence,
                "rotation": rotation,
                "effective_seed": manifest["seed_start"] + global_index,
                "seat_map": seat_map,
                "selected_profile_ids": [seat["profile_id"] for seat in seat_map],
            }
            global_index += 1
    return planned


def _validate_profile_result(
    result: dict[str, Any], regime: dict[str, Any], tournament_hand_count: int
) -> tuple[dict[str, float], dict[str, Any]]:
    require_exact_fields(result, PROFILE_RESULT_FIELDS, "simulation profile result")
    for field in COUNT_FIELDS:
        _integer(result[field], f"profile_result.{field}", 0)
    numeric = {field: _number(result[field], f"profile_result.{field}") for field in FINITE_FIELDS}
    for field in RATE_FIELDS:
        if numeric[field] < 0.0 or numeric[field] > 1.0:
            _invalid("invalid_metric", f"Behavioral rate '{field}' must be in [0, 1].")
    if numeric["aggression_factor"] < 0.0:
        _invalid("invalid_metric", "aggression_factor must not be negative.")
    if not isinstance(result["won_tournament"], bool) or not isinstance(result["top_third"], bool):
        _invalid("invalid_metric", "Tournament indicator metrics must be booleans.")
    player_count = regime["player_count"]
    position = result["finishing_position"]
    if position < 1 or position > player_count:
        _invalid("invalid_metric", "finishing_position is outside the regime.")
    starting_stack = result["starting_stack"]
    if starting_stack != regime["starting_stack"] or result["tournament_hand_count"] != tournament_hand_count:
        _invalid("invalid_metric", "Profile result settings do not match the tournament regime.")
    if tournament_hand_count <= 0 or result["hands_survived"] > tournament_hand_count:
        _invalid("invalid_metric", "Hand survival inputs are invalid.")
    expected_survival = result["hands_survived"] / tournament_hand_count
    if not math.isclose(numeric["survival_ratio"], expected_survival, abs_tol=1e-12):
        _invalid("invalid_metric", "survival_ratio does not match its counts.")
    if result["final_stack"] - starting_stack != result["chip_differential"]:
        _invalid("invalid_metric", "chip_differential does not match stack values.")
    if result["hands_observed"] != result["hands_survived"]:
        _invalid("invalid_metric", "hands_observed does not match hands_survived.")
    expected_bnc = (
        numeric["blind_normalized_chip_sum"] * 100.0 / result["hands_observed"]
        if result["hands_observed"] > 0
        else 0.0
    )
    if not math.isclose(numeric["bnc_per_100"], expected_bnc, rel_tol=1e-12, abs_tol=1e-12):
        _invalid("invalid_metric", "bnc_per_100 does not match its sum and denominator.")
    expected_rates = {
        "vpip_rate": (
            result["vpip_hands"] / result["hands_observed"]
            if result["hands_observed"] > 0
            else 0.0
        ),
        "pfr_rate": (
            result["pfr_hands"] / result["hands_observed"]
            if result["hands_observed"] > 0
            else 0.0
        ),
        "bet_raise_frequency": (
            result["aggressive_actions"] / result["bet_raise_opportunities"]
            if result["bet_raise_opportunities"] > 0
            else 0.0
        ),
        "bet_frequency": (
            result["bets_at_check_bet_opportunity"] / result["check_bet_opportunities"]
            if result["check_bet_opportunities"] > 0
            else 0.0
        ),
        "raise_share": (
            result["raises_at_call_raise_opportunity"]
            / (
                result["calls_at_call_raise_opportunity"]
                + result["raises_at_call_raise_opportunity"]
            )
            if (
                result["calls_at_call_raise_opportunity"]
                + result["raises_at_call_raise_opportunity"]
            )
            > 0
            else 0.0
        ),
        "eligible_bluff_frequency": (
            result["bluff_actions"] / result["eligible_bluff_opportunities"]
            if result["eligible_bluff_opportunities"] > 0
            else 0.0
        ),
    }
    for field, expected_rate in expected_rates.items():
        if not math.isclose(numeric[field], expected_rate, rel_tol=1e-12, abs_tol=1e-12):
            _invalid("invalid_metric", f"{field} does not match its counts.")
    if result["aggressive_actions"] != result["bet_actions"] + result["raise_actions"]:
        _invalid("invalid_metric", "aggressive_actions does not match bet and raise counts.")
    expected_aggression = (
        result["aggressive_actions"] / result["call_actions"]
        if result["call_actions"] > 0
        else 0.0
    )
    if not math.isclose(
        numeric["aggression_factor"], expected_aggression, rel_tol=1e-12, abs_tol=1e-12
    ):
        _invalid("invalid_metric", "aggression_factor does not match its counts.")
    count_bounds = (
        ("vpip_hands", "hands_observed"),
        ("pfr_hands", "hands_observed"),
        ("pfr_hands", "vpip_hands"),
        ("aggressive_actions", "bet_raise_opportunities"),
        ("bets_at_check_bet_opportunity", "check_bet_opportunities"),
        ("calls_at_call_raise_opportunity", "call_raise_opportunities"),
        ("raises_at_call_raise_opportunity", "call_raise_opportunities"),
        ("bluff_actions", "eligible_bluff_opportunities"),
    )
    if any(result[numerator] > result[denominator] for numerator, denominator in count_bounds):
        _invalid("invalid_metric", "A behavioral count exceeds its opportunity count.")
    if (
        result["calls_at_call_raise_opportunity"]
        + result["raises_at_call_raise_opportunity"]
        > result["call_raise_opportunities"]
    ):
        _invalid("invalid_metric", "Call and raise counts exceed their shared opportunities.")
    expected_top = position <= math.ceil(player_count / 3)
    if result["top_third"] != expected_top or result["won_tournament"] != (position == 1):
        _invalid("invalid_metric", "Outcome indicator does not match finishing position.")
    components = {
        "win_score": 1.0 if result["won_tournament"] else 0.0,
        "finish_score": (player_count - position) / (player_count - 1),
        "top_third_score": 1.0 if result["top_third"] else 0.0,
        "chip_score": (result["chip_differential"] + starting_stack)
        / (player_count * starting_stack),
        "survival_score": expected_survival,
        "blind_chip_score": (min(100.0, max(-100.0, numeric["bnc_per_100"])) + 100.0)
        / 200.0,
    }
    if any(value < 0.0 or value > 1.0 for value in components.values()):
        _invalid("invalid_metric", "A normalized fitness component is outside [0, 1].")
    style = {
        "invalid_action_fallbacks": result["invalid_action_fallbacks"],
        "rates": {field: numeric[field] for field in RATE_FIELDS if field != "survival_ratio"},
    }
    return components, style


def _mean(values: list[float]) -> float:
    return math.fsum(values) / len(values) if values else 0.0


def _half_width(values: list[float]) -> float | None:
    if len(values) < 2:
        return None
    mean = _mean(values)
    squared = math.fsum((value - mean) ** 2 for value in values)
    standard_error = math.sqrt(squared / (len(values) - 1)) / math.sqrt(len(values))
    normal_half_width = 1.96 * standard_error
    z = 1.96
    count = len(values)
    wilson_half_width = (
        z
        * math.sqrt(mean * (1.0 - mean) / count + z**2 / (4.0 * count**2))
        / (1.0 + z**2 / count)
    )
    return max(normal_half_width, wilson_half_width)


def _competition_positions_are_valid(results: list[dict[str, Any]]) -> bool:
    counts: dict[int, int] = {}
    for result in results:
        position = result["finishing_position"]
        counts[position] = counts.get(position, 0) + 1
    expected_position = 1
    while expected_position <= len(results):
        tied_count = counts.get(expected_position, 0)
        if tied_count == 0:
            return False
        expected_position += tied_count
    return expected_position == len(results) + 1


def _report_evidence(path: Path, report: dict[str, Any], source: bytes) -> dict[str, Any]:
    seeds = [item["effective_seed"] for item in report["tournaments"]]
    return {
        "batch_id": report["manifest"]["batch_id"],
        "code_revision": report["code_revision"],
        "command_version": report["command_version"],
        "execution_provenance": copy.deepcopy(report["execution_provenance"]),
        "manifest_checksum": report["manifest_checksum"],
        "report_checksum": hashlib.sha256(source).hexdigest(),
        "seed_range": {"maximum": max(seeds), "minimum": min(seeds)},
        "shard": dict(report["shard"]),
    }


def evaluate_fitness(
    generation_artifact: dict[str, Any], report_paths: Iterable[Path]
) -> dict[str, Any]:
    generation = validate_candidate_collection(generation_artifact["payload"])
    paths = list(report_paths)
    if not paths:
        _invalid("missing_reports", "At least one completed simulation report is required.")
    reports: list[tuple[Path, dict[str, Any], bytes]] = []
    for path in paths:
        try:
            source = path.read_bytes()
        except OSError as error:
            raise ToolError(
                "input_read_failed",
                f"Cannot read simulation report '{path}': {error}",
                ExitCode.IO_FAILURE,
                {"path": str(path)},
            ) from error
        report = load_json_object(path)
        require_exact_fields(report, REPORT_FIELDS, "simulation report")
        if (
            isinstance(report["report_schema_version"], bool)
            or not isinstance(report["report_schema_version"], int)
            or report["report_schema_version"] != 4
            or report["command_version"] != "simulation_cli_v6"
        ):
            _invalid("unsupported_simulation_report", "Simulation report or command version is unsupported.")
        if (
            not isinstance(report["code_revision"], str)
            or not isinstance(report["manifest_checksum"], str)
            or not isinstance(report["started_at"], str)
            or not isinstance(report["finished_at"], str)
        ):
            _invalid("invalid_simulation_report", "Report identity fields have invalid types.")
        _validate_execution_provenance(report["execution_provenance"])
        if report["code_revision"] != report["execution_provenance"]["code_revision"]:
            _invalid("invalid_simulation_report", "Report code revision contradicts provenance.")
        if (
            not isinstance(report["aggregates"], dict)
            or not isinstance(report["traces"], list)
            or not isinstance(report["shard"], dict)
        ):
            _invalid("invalid_simulation_report", "Report aggregates and traces have invalid types.")
        if not isinstance(report["manifest"], dict):
            _invalid("invalid_simulation_report", "Report manifest must be an object.")
        _validate_manifest(report["manifest"])
        if report["roster"] != _roster_provenance(report["manifest"]):
            _invalid("roster_provenance_mismatch", "Report roster provenance does not match its manifest.")
        expected_checksum = _simulation_manifest_checksum(report["manifest"])
        if report["manifest_checksum"] != expected_checksum:
            _invalid("manifest_checksum_mismatch", "Simulation manifest checksum does not match.")
        reports.append((path, report, source))
    manifest = reports[0][1]["manifest"]
    manifest_checksum = reports[0][1]["manifest_checksum"]
    if any(
        report["manifest"] != manifest or report["manifest_checksum"] != manifest_checksum
        for _, report, _ in reports[1:]
    ):
        _invalid("incompatible_reports", "Simulation reports do not share an identical manifest.")
    reference_provenance = reports[0][1]["execution_provenance"]
    differing_provenance_fields = sorted(
        {
            field
            for _, report, _ in reports[1:]
            for field in EXECUTION_PROVENANCE_FIELDS
            if report["execution_provenance"].get(field) != reference_provenance.get(field)
        }
    )
    if differing_provenance_fields:
        _invalid(
            "incompatible_report_provenance",
            "Simulation report shards do not share identical execution provenance: "
            + ", ".join(differing_provenance_fields),
            {"fields": differing_provenance_fields},
        )
    indexes = _validate_manifest(manifest)
    manifest_profiles = indexes["profiles"]
    candidate_ids = [candidate["candidate_id"] for candidate in generation["candidates"]]
    for candidate in generation["candidates"]:
        reported_profile = manifest_profiles.get(candidate["candidate_id"])
        reported_parameters = (
            validate_parameters(reported_profile["parameters"])
            if reported_profile is not None
            else None
        )
        expected_snapshot = {
            "profile_id": candidate["candidate_id"],
            "model_id": candidate["model_id"],
            "parameters": candidate["parameters"],
        }
        normalized_snapshot = (
            {
                "profile_id": reported_profile["profile_id"],
                "model_id": reported_profile["model_id"],
                "parameters": reported_parameters,
            }
            if reported_profile is not None
            else None
        )
        if normalized_snapshot != expected_snapshot:
            _invalid(
                "candidate_snapshot_mismatch",
                f"Manifest snapshot does not match candidate '{candidate['candidate_id']}'.",
            )
    shard_counts = {report["shard"].get("count") for _, report, _ in reports if isinstance(report["shard"], dict)}
    if len(shard_counts) != 1:
        _invalid("incomplete_shards", "All reports must use one shard count.")
    shard_count = next(iter(shard_counts))
    _integer(shard_count, "shard.count", 1)
    shard_indexes: list[int] = []
    for _, report, _ in reports:
        require_exact_fields(report["shard"], ("index", "count"), "simulation shard")
        index = _integer(report["shard"]["index"], "shard.index", 0)
        if index >= shard_count:
            _invalid("incomplete_shards", "Shard index is outside its shard count.")
        shard_indexes.append(index)
    if sorted(shard_indexes) != list(range(shard_count)):
        _invalid("incomplete_shards", "Reports must contain every shard exactly once.")
    planned = _planned_tournaments(manifest, indexes)
    seen: set[int] = set()
    observations: dict[str, list[tuple[str, dict[str, float], dict[str, Any]]]] = {
        candidate_id: [] for candidate_id in candidate_ids
    }
    for _, report, _ in reports:
        tournaments = _object_array(report["tournaments"], "report.tournaments")
        shard_index = report["shard"]["index"]
        expected_shard = {index for index in planned if index % shard_count == shard_index}
        actual_shard: set[int] = set()
        for tournament in tournaments:
            require_exact_fields(tournament, TOURNAMENT_FIELDS, "simulation tournament")
            tournament_index = _integer(tournament["tournament_index"], "tournament_index", 0)
            if tournament_index in seen or tournament_index not in planned:
                _invalid("duplicate_tournament", "Tournament identity is duplicated or unexpected.")
            expected = planned[tournament_index]
            for field in (
                "tournament_index",
                "plan_id",
                "plan_tournament_index",
                "regime_id",
                "matchup_id",
                "matchup_occurrence",
                "rotation",
                "effective_seed",
                "seat_map",
                "selected_profile_ids",
            ):
                if tournament[field] != expected[field]:
                    _invalid("tournament_identity_mismatch", f"Tournament field '{field}' does not match its plan.")
            if (
                tournament["termination_reason"] != "winner"
                or not isinstance(tournament["diagnostics"], list)
                or tournament["diagnostics"]
            ):
                _invalid("unsuccessful_tournament", "Every evaluated tournament must complete without diagnostics.")
            hand_count = _integer(tournament["tournament_hand_count"], "tournament_hand_count", 1)
            results = _object_array(tournament["profile_results"], "profile_results")
            regime = indexes["regimes"][tournament["regime_id"]]
            if len(results) != regime["player_count"]:
                _invalid("invalid_simulation_report", "Profile result count does not match the regime.")
            result_seats: set[int] = set()
            winner_ids: list[str] = []
            tournament_samples: dict[str, list[tuple[dict[str, float], dict[str, Any]]]] = {}
            for result in results:
                profile_id = _string(result.get("profile_id"), "profile_result.profile_id")
                seat = result.get("seat")
                if profile_id not in manifest_profiles or seat in result_seats:
                    _invalid("invalid_simulation_report", "Profile result identity is invalid.")
                if (
                    not isinstance(seat, int)
                    or isinstance(seat, bool)
                    or seat < 0
                    or seat >= regime["player_count"]
                    or expected["seat_map"][seat]
                    != {"seat": seat, "profile_id": profile_id}
                ):
                    _invalid(
                        "invalid_simulation_report",
                        "Profile result does not match its planned seat.",
                    )
                result_seats.add(seat)
                components, style = _validate_profile_result(result, regime, hand_count)
                if result["won_tournament"]:
                    winner_ids.append(profile_id)
                if profile_id in observations:
                    tournament_samples.setdefault(profile_id, []).append((components, style))
            if result_seats != set(range(regime["player_count"])):
                _invalid("invalid_simulation_report", "Profile results do not match the planned seat map.")
            if winner_ids != [tournament["winner_profile_id"]]:
                _invalid("invalid_simulation_report", "Tournament winner fields are inconsistent.")
            if not _competition_positions_are_valid(results):
                _invalid(
                    "invalid_simulation_report",
                    "Tournament finishing positions must use competition ranking.",
                )
            expected_total = regime["player_count"] * regime["starting_stack"]
            if (
                sum(result["starting_stack"] for result in results) != expected_total
                or sum(result["final_stack"] for result in results) != expected_total
                or sum(result["chip_differential"] for result in results) != 0
            ):
                _invalid("invalid_metric", "Tournament stacks do not conserve chips.")
            for profile_id, seat_samples in tournament_samples.items():
                clustered_components = {
                    component: _mean([sample[0][component] for sample in seat_samples])
                    for component in COMPONENTS
                }
                clustered_style = {
                    "invalid_action_fallbacks": sum(
                        sample[1]["invalid_action_fallbacks"] for sample in seat_samples
                    )
                }
                observations[profile_id].append(
                    (tournament["plan_id"], clustered_components, clustered_style)
                )
            seen.add(tournament_index)
            actual_shard.add(tournament_index)
        if actual_shard != expected_shard:
            _invalid("incomplete_shard", "A report does not contain its complete planned shard.")
    if seen != set(planned):
        _invalid("incomplete_plan", "Reports do not cover the complete evaluation plan.")
    candidate_results: list[dict[str, Any]] = []
    for candidate in generation["candidates"]:
        candidate_id = candidate["candidate_id"]
        samples = observations[candidate_id]
        values = {component: [sample[1][component] for sample in samples] for component in COMPONENTS}
        means = {component: _mean(values[component]) for component in COMPONENTS}
        uncertainty = {component: _half_width(values[component]) for component in COMPONENTS}
        penalty = min(0.10, 0.10 / math.sqrt(len(samples))) if samples else 0.10
        plan_counts = {
            plan["plan_id"]: sum(1 for sample in samples if sample[0] == plan["plan_id"])
            for plan in manifest["evaluation_plans"]
        }
        reasons = [
            f"insufficient_samples:{plan['plan_id']}"
            for plan in manifest["evaluation_plans"]
            if plan_counts[plan["plan_id"]] < plan["minimum_profile_samples"]
        ]
        fallback_count = sum(sample[2]["invalid_action_fallbacks"] for sample in samples)
        if fallback_count:
            reasons.append("invalid_action_fallbacks")
        style_checks = {
            "bounded_behavioral_rates": {"passed": True, "violations": []},
            "zero_invalid_action_fallbacks": {
                "passed": fallback_count == 0,
                "value": fallback_count,
            },
        }
        eligible = not reasons
        raw_fitness = math.fsum(weight * means[name] for weight, name in zip(WEIGHTS, COMPONENTS))
        point_fitness = max(0.0, min(1.0, raw_fitness))
        candidate_results.append(
            {
                "candidate": candidate,
                "component_means": means,
                "eligible": eligible,
                "fitness": max(0.0, point_fitness - penalty) if eligible else None,
                "ineligibility_reasons": reasons,
                "plan_sample_counts": plan_counts,
                "point_fitness": point_fitness,
                "sample_count": len(samples),
                "style_checks": style_checks,
                "uncertainty_95_half_width": uncertainty,
                "uncertainty_penalty": penalty,
            }
        )
    report_evidence = [
        _report_evidence(path, report, source)
        for path, report, source in sorted(
            reports, key=lambda item: item[1]["shard"]["index"]
        )
    ]
    return create_artifact(
        "fitness",
        {
            "bounds": generation["bounds"],
            "candidate_results": candidate_results,
            "code_revisions": sorted({report["code_revision"] for _, report, _ in reports}),
            "evaluation_configuration": {
                "plans": copy.deepcopy(manifest["evaluation_plans"]),
                "regimes": copy.deepcopy(manifest["regimes"]),
            },
            "generation": generation["generation"],
            "generation_id": generation["generation_id"],
            "plan_ids": [plan["plan_id"] for plan in manifest["evaluation_plans"]],
            "regime_ids": [regime["regime_id"] for regime in manifest["regimes"]],
            "report_evidence": report_evidence,
            "source_generation_checksum": generation_artifact["checksum"],
        },
    )
