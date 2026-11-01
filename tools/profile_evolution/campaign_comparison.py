"""Reproducible fair-round selection from successful campaign producer receipts."""
from __future__ import annotations

import copy
import math
from collections import Counter
from itertools import combinations
from pathlib import Path
from typing import Any

from .artifacts import create_artifact, load_artifact, load_json_object, validate_artifact_envelope
from .campaign import schema_boundary, validate_campaign
from .campaign_runner import COMPLETE_TYPE, READY_TYPE, RUN_TYPE, START_TYPE, _digest, _safe
from .campaign_schedule import audit_manifest, build_round_manifest
from .confirmation import _empty_measured_behavior_counts, _measured_behavior, _normal_95_half_width, _observe_measured_behavior, _raw_composite
from .contracts import GENES, require_exact_fields, require_integer
from .errors import ExitCode, ToolError
from .fitness import _normalize_report_integers, _simulation_manifest_checksum, evaluate_fitness

RESULT_TYPE = "campaign_round_result_v1"


def _fail(message: str) -> None:
    raise ToolError("invalid_campaign_comparison", message, ExitCode.INVALID_INPUT)


def _evaluation_view(campaign_checksum: str, rows: list[dict[str, Any]]) -> dict[str, Any]:
    """Select aliases for one evaluator call; never issue ancestry from this view."""
    aliases = [{"candidate_id": row["profile"]["profile_id"], "model_id": row["profile"]["model_id"],
                "parameters": copy.deepcopy(row["profile"]["parameters"]), "parent_ids": []} for row in rows]
    return {"purpose": "transient_cohort_alias_evaluation_view_not_lineage", "checksum": campaign_checksum,
            "payload": {"generation_id": "transient_round_cohort_evaluation", "generation": 0, "seed": 0,
                        "bounds": {"genes": {gene: {"minimum": 0, "maximum": 100} for gene in GENES}},
                        "candidates": aliases, "creation_records": [{"candidate_id": c["candidate_id"],
                            "operation": "initialization", "parent_ids": [], "seed": 0} for c in aliases]}}


def _producer(readiness: dict[str, Any], manifest: dict[str, Any]) -> tuple[list[Path], dict[str, Any]]:
    validate_artifact_envelope(readiness, READY_TYPE)
    ready = readiness["payload"]
    require_exact_fields(ready, ("run_checksum", "manifest_checksum", "manifest", "workers", "reports",
                                 "execution_provenance", "tournament_count", "schedule_audit"), "campaign readiness")
    audit = audit_manifest(manifest)
    checksum = _simulation_manifest_checksum(manifest)
    workers = require_integer(ready["workers"], "worker count", 1, 4)
    if ready["manifest"] != manifest or ready["manifest_checksum"] != checksum or ready["schedule_audit"] != audit or ready["tournament_count"] != audit["tournament_count"]:
        _fail("Readiness differs from the exact expected round manifest or fairness certificate.")
    if not isinstance(ready["reports"], list) or len(ready["reports"]) != workers:
        _fail("Readiness must contain every successful shard receipt.")
    paths = []
    directory = None
    for index, evidence in enumerate(ready["reports"]):
        require_exact_fields(evidence, ("path", "sha256", "shard", "tournament_count"), "report receipt")
        require_exact_fields(evidence["shard"], ("index", "count"), "report receipt shard")
        require_integer(evidence["shard"]["index"], "shard index", index, index)
        require_integer(evidence["shard"]["count"], "shard count", workers, workers)
        path = Path(evidence["path"])
        if not path.is_absolute() or path.name != f"shard_{index:04d}.json":
            _fail("Readiness report paths must be absolute owned shard outputs.")
        _safe(path)
        _safe(path.parent)
        if directory is None:
            directory = path.parent
        if path.parent != directory:
            _fail("All report receipts must belong to one producer directory.")
        if not path.is_file() or _digest(path) != evidence["sha256"]:
            _fail("A successful producer report is missing or changed.")
        expected_count = len(range(index, ready["tournament_count"], workers))
        require_integer(evidence["tournament_count"], "receipt tournament count", expected_count, expected_count)
        start = directory / f"shard_{index:04d}.started.json"
        complete = directory / f"shard_{index:04d}.completed.json"
        for marker in (start, complete):
            _safe(marker)
        expected_start = create_artifact(START_TYPE, {"run_checksum": ready["run_checksum"], "shard": {"index": index, "count": workers}})
        expected_complete = create_artifact(COMPLETE_TYPE, {"run_checksum": ready["run_checksum"], "exit_code": 0, "report": evidence})
        if load_artifact(start, START_TYPE) != expected_start or load_artifact(complete, COMPLETE_TYPE) != expected_complete:
            _fail("Report lacks an exact successful-producer ownership receipt.")
        paths.append(path)
    for marker in (directory / "run.json", directory / "readiness.json", directory / "manifest.json"):
        _safe(marker)
    if load_artifact(directory / "readiness.json", READY_TYPE) != readiness:
        _fail("Readiness is absent or differs from the producer's final readiness marker.")
    run = load_artifact(directory / "run.json", RUN_TYPE)
    require_exact_fields(run["payload"], ("manifest", "manifest_checksum", "workers", "godot", "expected_provenance", "approval"), "campaign run")
    request = run["payload"]
    approval = request["approval"]
    if run["checksum"] != ready["run_checksum"] or request["manifest"] != manifest or request["manifest_checksum"] != checksum or request["workers"] != workers or load_json_object(directory / "manifest.json") != manifest:
        _fail("Readiness does not bind the exact approved producer manifest.")
    if not isinstance(approval, dict) or approval.get("approved") is not True or approval.get("manifest_checksum") != checksum or approval.get("source", "user") != "user" or set(approval) - {"approved", "manifest_checksum", "source", "reviewer_id", "note"}:
        _fail("Producer request has no explicit approval for this exact manifest.")
    if request["expected_provenance"] is not None and request["expected_provenance"] != ready["execution_provenance"]:
        _fail("Readiness executable provenance contradicts the approved reference.")
    return paths, ready


def _completed_audit(paths: list[Path], ready: dict[str, Any], expected: dict[str, Any], controls: set[str]) -> tuple[dict[str, Any], dict[str, list[float]]]:
    profiles = expected["appearances_by_profile"]
    appearances = Counter({identifier: 0 for identifier in profiles})
    seats = {identifier: [0] * 9 for identifier in profiles}
    fallbacks = Counter({identifier: 0 for identifier in profiles})
    pairs: Counter[tuple[str, str]] = Counter()
    matchups = Counter()
    composites = {identifier: [] for identifier in profiles}
    behavior = {identifier: _empty_measured_behavior_counts() for identifier in profiles}
    indexes = set()
    for path in paths:
        report = _normalize_report_integers(load_json_object(path))
        if report["execution_provenance"] != ready["execution_provenance"] or report["execution_provenance"]["algorithm_versions"]["rng_streams"] != "named_stream_sha256_v2":
            _fail("Reports do not share the producer's current executable provenance.")
        for tournament in report["tournaments"]:
            index = tournament["tournament_index"]
            if index in indexes:
                _fail("Completed tournament identity is duplicated.")
            indexes.add(index)
            participants = [seat["profile_id"] for seat in tournament["seat_map"]]
            if len(participants) != 9 or len(set(participants)) != 9 or not set(participants).issubset(profiles):
                _fail("Completed starting table contains missing, repeated or unknown profiles.")
            matchups[tournament["matchup_id"]] += 1
            for entry in tournament["seat_map"]:
                appearances[entry["profile_id"]] += 1
                seats[entry["profile_id"]][entry["seat"]] += 1
            for pair in combinations(sorted(participants), 2):
                pairs[pair] += 1
            for result in tournament["profile_results"]:
                identifier = result["profile_id"]
                fallbacks[identifier] += result["invalid_action_fallbacks"]
                _observe_measured_behavior(behavior[identifier], result)
                composites[identifier].append(_raw_composite(result, 9))
    if indexes != set(range(ready["tournament_count"])) or dict(appearances) != expected["appearances_by_profile"] or seats != expected["seat_counts_by_profile"]:
        _fail("Completed tournament, participant or seat coverage differs from the fair schedule.")
    if len(matchups) != expected["matchup_count"] or set(matchups.values()) != {expected["repetitions_per_table"]}:
        _fail("Completed matchup coverage differs from the fair schedule.")
    expected_pairs = {tuple(row["profile_ids"]): row["tournament_count"] for row in expected["pair_counts"]}
    if dict(pairs) != expected_pairs:
        _fail("Completed opponent-pair coverage differs from the fair schedule.")
    if any(fallbacks[identifier] for identifier in controls):
        _fail("A protected handcrafted control used an invalid-action fallback; the round cannot be selected.")
    return {"tournament_count": len(indexes), "appearances_by_profile": dict(sorted(appearances.items())),
            "seat_counts_by_profile": dict(sorted(seats.items())), "matchup_tournament_counts": dict(sorted(matchups.items())),
            "invalid_action_fallbacks_by_profile": dict(sorted(fallbacks.items())),
            "measured_behavior_by_profile": {identifier: _measured_behavior(behavior[identifier]) for identifier in sorted(profiles)},
            "pair_tournament_counts": [{"profile_ids": list(pair), "tournament_count": pairs[pair]} for pair in sorted(pairs)]}, composites


@schema_boundary
def compare_round(campaign: dict[str, Any], readiness: dict[str, Any], round_number: int = 1, previous_result: dict[str, Any] | None = None) -> dict[str, Any]:
    """Rank contenders once; controls remain protected and exactly five are cut."""
    context = validate_campaign(campaign)
    require_integer(round_number, "round number", 1, 2)
    if round_number == 1:
        if previous_result is not None:
            _fail("Round one cannot bind a previous result.")
        selected_ids = None
    else:
        if previous_result is None:
            _fail("Round two requires the verified first-round result.")
        previous = validate_round_result(previous_result, campaign)
        if previous["round_number"] != 1:
            _fail("Round two requires a first-round predecessor.")
        selected_ids = previous["survivor_ids"]
    manifest = build_round_manifest(campaign, round_number, selected_ids)
    paths, ready = _producer(readiness, manifest)
    rows = [row for row in context["contenders"] if selected_ids is None or row["candidate_id"] in selected_ids]
    fitness = evaluate_fitness(_evaluation_view(campaign["checksum"], rows), paths)["payload"]
    if [e["report_checksum"] for e in fitness["report_evidence"]] != [e["sha256"] for e in ready["reports"]]:
        _fail("Strictly evaluated report bytes differ from their successful producer receipts.")
    schedule = audit_manifest(manifest)
    controls = {p["profile_id"] for p in context["inventory"]["fixed_controls"]}
    completed, composites = _completed_audit(paths, ready, schedule, controls)
    if any(not path.is_file() or _digest(path) != evidence["sha256"] for path, evidence in zip(paths, ready["reports"])):
        _fail("Producer report bytes changed while comparison was consuming them.")
    results = {result["candidate"]["candidate_id"]: result for result in fitness["candidate_results"]}
    ranking = []
    for row in rows:
        alias = row["profile"]["profile_id"]
        metrics = results[alias]
        value = metrics["fitness"]
        if metrics["eligible"] and (isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value)):
            _fail("Eligible contender fitness must be finite.")
        ranking.append({"candidate_id": row["candidate_id"], "profile_id": alias, "display_name": row["display_name"],
                        "origin": row["origin"], "parent_ids": copy.deepcopy(row["parent_ids"]),
                        "original_creation_checksum": row["creation_checksum"], "profile_snapshot": copy.deepcopy(row["profile"]),
                        "eligible": metrics["eligible"], "fitness": value, "point_fitness": metrics["point_fitness"],
                        "component_means": metrics["component_means"], "sample_count": metrics["sample_count"],
                        "plan_sample_counts": metrics["plan_sample_counts"],
                        "measured_behavior": completed["measured_behavior_by_profile"][alias],
                        "uncertainty_95_half_width": metrics["uncertainty_95_half_width"],
                        "uncertainty_penalty": metrics["uncertainty_penalty"],
                        "composite_half_width": _normal_95_half_width(composites[alias]),
                        "style_checks": metrics["style_checks"], "ineligibility_reasons": metrics["ineligibility_reasons"]})
    ranking.sort(key=lambda result: (not result["eligible"], -result["fitness"] if result["eligible"] else 0, result["candidate_id"]))
    survivor_count = context["config"]["survivor_counts"][round_number - 1]
    if sum(row["eligible"] for row in ranking) < survivor_count:
        _fail("Too few eligible contenders remain to retain the required survivors.")
    survivors, rejected = ranking[:survivor_count], ranking[survivor_count:]
    if len(rejected) != 5:
        _fail("A round must reject exactly five distinct contenders.")
    for index, row in enumerate(ranking):
        row["rank"] = index + 1
    last, first = survivors[-1], rejected[0]
    ambiguous = first["eligible"] and last["composite_half_width"] is not None and first["composite_half_width"] is not None and last["fitness"] - last["composite_half_width"] <= first["fitness"] + first["composite_half_width"]
    cuts = [{"candidate_id": row["candidate_id"], "rank": row["rank"],
             "reason": "ineligible" if not row["eligible"] else "below_five_candidate_cutoff",
             "ineligibility_reasons": row["ineligibility_reasons"], "fitness": row["fitness"],
             "lowest_retained_candidate_id": last["candidate_id"], "lowest_retained_fitness": last["fitness"]} for row in rejected]
    return create_artifact(RESULT_TYPE, {"campaign_checksum": campaign["checksum"], "round_number": round_number,
        "previous_result_checksum": previous_result["checksum"] if previous_result is not None else None,
        "readiness": copy.deepcopy(readiness), "readiness_checksum": readiness["checksum"],
        "manifest_checksum": ready["manifest_checksum"], "execution_provenance": ready["execution_provenance"],
        "report_evidence": fitness["report_evidence"], "schedule_audit": schedule, "completed_audit": completed,
        "ranking": ranking, "survivor_ids": [row["candidate_id"] for row in survivors],
        "rejected_ids": [row["candidate_id"] for row in rejected], "cuts": cuts,
        "selection_policy": {"eligible_first": True, "fitness_order": "descending", "tie_break": "original_candidate_id_ascending",
                             "survivor_count": survivor_count, "rejection_count": 5,
                             "uncertainty_rule": "marginal_normal_95_composite_interval_overlap",
                             "extensions_automatically_authorized": False},
        "extension_recommended": bool(ambiguous), "extension_requires_user_approval": True})


@schema_boundary
def validate_round_result(result: dict[str, Any], campaign: dict[str, Any], previous_result: dict[str, Any] | None = None) -> dict[str, Any]:
    """Recompute selection from immutable producer receipts and reports on disk."""
    validate_artifact_envelope(result, RESULT_TYPE)
    payload = result["payload"]
    if payload.get("campaign_checksum") != campaign.get("checksum") or payload.get("readiness_checksum") != payload.get("readiness", {}).get("checksum"):
        _fail("Round result does not bind this campaign and its producer readiness.")
    recomputed = compare_round(campaign, payload["readiness"], payload["round_number"], previous_result)
    if recomputed != result:
        _fail("Round selection differs from independently recomputed raw evidence.")
    return copy.deepcopy(payload)
