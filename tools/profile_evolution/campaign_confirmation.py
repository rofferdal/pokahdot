"""Independent nine-player promotion evidence with replayable strict validation."""
from __future__ import annotations

import copy
import math
import tempfile
from pathlib import Path
from typing import Any, Iterable

from .artifacts import create_artifact, load_json_object, validate_artifact_envelope
from .campaign import schema_boundary, seed_start, validate_campaign
from .confirmation import (
    _empty_measured_behavior_counts, _genetic_diversity, _measured_behavior,
    _normal_95_half_width, _observe_measured_behavior, _raw_composite,
)
from .contracts import GENES, require_exact_fields
from .errors import ExitCode, ToolError
from .fitness import _normalize_report_integers, _validate_manifest, evaluate_fitness

ARTIFACT_TYPE = "nine_player_confirmation_v1"
POLICY_VERSION = "nine_player_promotion_v1"
MINIMUM_TOURNAMENTS = 297
MINIMUM_SEAT_SAMPLES = 33


def _fail(message: str) -> None:
    raise ToolError("invalid_nine_player_confirmation", message, ExitCode.INVALID_INPUT)


def _candidate(context: dict[str, Any], candidate_id: str) -> tuple[int, dict[str, Any]]:
    for index, row in enumerate(context["contenders"]):
        if row["candidate_id"] == candidate_id:
            return index, row
    _fail("Confirmation candidate is absent from the frozen campaign.")


@schema_boundary
def build_confirmation_manifests(campaign: dict[str, Any], candidate_id: str) -> dict[str, dict[str, Any]]:
    context = validate_campaign(campaign)
    if context["stage"] == "prepared":
        _fail("Confirmation requires frozen candidates.")
    index, row = _candidate(context, candidate_id)
    count = context["config"]["confirmation_repetitions"]
    if count < MINIMUM_TOURNAMENTS or count % 9:
        _fail("Nine-player confirmation requires at least 297 tournaments and complete rotations.")
    profiles = [row["profile"]] + context["inventory"]["confirmation_benchmarks"]
    ids = [p["profile_id"] for p in profiles]
    if len(profiles) != 9 or len(set(ids)) != 9 or any(p["model_id"] != "strategy_parameterized" for p in profiles):
        _fail("Confirmation requires one candidate and eight distinct strategic benchmarks.")
    result = {}
    for mode in ("a", "b"):
        block = f"confirmation_{mode}"
        manifest = {
            "schema_version": 2, "batch_id": f"{context['config']['campaign_id']}_{block}_{index:04d}",
            "seed_start": seed_start(context["config"], block, count, index * count),
            "profiles": copy.deepcopy(profiles),
            "regimes": [{"regime_id": "nine_player_100bb", "player_count": 9,
                         "starting_stack": 1000, "starting_small_blind": 5, "starting_big_blind": 10,
                         "blind_progression": "normative_hand_based_v1"}],
            "matchups": [{"matchup_id": "confirmation_table", "profile_ids": ids}],
            "evaluation_plans": [{"plan_id": f"{block}_plan", "regime_id": "nine_player_100bb",
                                  "matchup_ids": ["confirmation_table"], "tournament_count": count,
                                  "seat_rotation": "cyclic", "minimum_profile_samples": MINIMUM_TOURNAMENTS,
                                  "uncertainty_estimator": "normal_95"}],
        }
        _validate_manifest(manifest)
        result[mode] = manifest
    return result


def _evaluation_view(row: dict[str, Any]) -> dict[str, Any]:
    """Adapt the profile alias to fitness input; this is never ancestry evidence.

    evaluate_fitness consumes a candidate collection, so this ephemeral view
    uses an initialization-shaped record solely to select the manifest alias.
    No generation artifact is issued and no creation/parent claims are stored
    from this view. Confirmation binds the original row's creation checksum.
    """
    alias = row["profile"]["profile_id"]
    return {"purpose": "transient_alias_evaluation_view_not_lineage", "checksum": row["creation_checksum"], "payload": {
        "generation_id": "transient_confirmation_evaluation_view", "generation": 0, "seed": 0,
        "bounds": {"genes": {g: {"minimum": 0, "maximum": 100} for g in GENES}},
        "candidates": [{"candidate_id": alias, "model_id": row["profile"]["model_id"],
                        "parameters": copy.deepcopy(row["profile"]["parameters"]), "parent_ids": []}],
        "creation_records": [{"candidate_id": alias, "operation": "initialization", "parent_ids": [], "seed": 0}],
    }}


def _compute(campaign: dict[str, Any], candidate_id: str, documents: dict[str, list[str]]) -> dict[str, Any]:
    context = validate_campaign(campaign)
    _, row = _candidate(context, candidate_id)
    expected = build_confirmation_manifests(campaign, candidate_id)
    require_exact_fields(documents, ("a", "b"), "nine-player report batches")
    alias = row["profile"]["profile_id"]
    benchmarks = {p["profile_id"]: p for p in context["inventory"]["confirmation_benchmarks"]}
    candidate = {"candidate_id": candidate_id, "model_id": row["profile"]["model_id"],
                 "parameters": copy.deepcopy(row["profile"]["parameters"]), "parent_ids": copy.deepcopy(row["parent_ids"])}
    counts = _empty_measured_behavior_counts()
    reasons = []
    batches = {}
    all_provenance = []
    all_report_checksums = []
    runtime_directory = Path(__file__).resolve().parents[2] / "localtmp"
    runtime_directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="confirmation-validation-", dir=runtime_directory) as folder:
        for mode in ("a", "b"):
            if not isinstance(documents[mode], list) or not documents[mode] or any(not isinstance(text, str) for text in documents[mode]):
                _fail("Both confirmation batches require original UTF-8 report documents.")
            paths, reports = [], []
            for index, text in enumerate(documents[mode]):
                path = Path(folder) / f"{mode}_{index:04d}.json"
                path.write_bytes(text.encode("utf-8"))
                report = _normalize_report_integers(load_json_object(path))
                if report.get("manifest") != expected[mode]:
                    _fail("Confirmation report differs from its frozen nine-player manifest.")
                paths.append(path)
                reports.append(report)
            shards = [report["shard"]["index"] for report in reports]
            if shards != sorted(shards):
                _fail("Embedded confirmation reports must be ordered by shard index.")
            fitness = evaluate_fitness(_evaluation_view(row), paths)["payload"]
            candidate_result = fitness["candidate_results"][0]
            if not candidate_result["eligible"]:
                reasons.extend(f"{mode}:{reason}" for reason in candidate_result["ineligibility_reasons"])
            differences = {identifier: [] for identifier in benchmarks}
            seats = [0] * 9
            tournament_count = 0
            fallback_count = 0
            for report in reports:
                provenance = report["execution_provenance"]
                if provenance["algorithm_versions"]["rng_streams"] != "named_stream_sha256_v2":
                    _fail("Nine-player confirmation requires current named-stream RNG provenance.")
                all_provenance.append(provenance)
                for tournament in report["tournaments"]:
                    tournament_count += 1
                    results = {result["profile_id"]: result for result in tournament["profile_results"]}
                    result = results[alias]
                    _observe_measured_behavior(counts, result)
                    seats[result["seat"]] += 1
                    fallback_count += sum(item["invalid_action_fallbacks"] for item in results.values())
                    composite = _raw_composite(result, 9)
                    for identifier in benchmarks:
                        differences[identifier].append(composite - _raw_composite(results[identifier], 9))
            comparisons = []
            if tournament_count < MINIMUM_TOURNAMENTS:
                reasons.append(f"{mode}:insufficient_tournament_samples")
            if any(value < MINIMUM_SEAT_SAMPLES for value in seats):
                reasons.append(f"{mode}:insufficient_seat_samples")
            if fallback_count:
                reasons.append(f"{mode}:invalid_action_fallbacks")
            for identifier, values in sorted(differences.items()):
                mean = math.fsum(values) / len(values)
                width = _normal_95_half_width(values)
                lower = mean - width if width is not None else None
                passed = lower is not None and lower > 0
                comparisons.append({"opponent_id": identifier, "sample_count": len(values),
                                    "mean_difference": mean, "uncertainty_95_half_width": width,
                                    "lower_95_bound": lower, "passed": passed})
                if not passed:
                    reasons.append(f"{mode}:performance_not_demonstrated:{identifier}")
            all_report_checksums.extend(e["report_checksum"] for e in fitness["report_evidence"])
            batches[mode] = {"candidate_result": candidate_result, "report_evidence": fitness["report_evidence"],
                             "tournament_count": tournament_count, "seat_samples": seats,
                             "comparisons": comparisons, "invalid_action_fallbacks": fallback_count,
                             "seed_range": {"minimum": expected[mode]["seed_start"], "maximum": expected[mode]["seed_start"] + tournament_count - 1}}
    if any(provenance != all_provenance[0] for provenance in all_provenance):
        _fail("Independent confirmation batches must share identical executable provenance.")
    if len(set(all_report_checksums)) != len(all_report_checksums):
        _fail("Confirmation batches reuse report evidence.")
    # Expected manifests use distinct per-candidate subranges of disjoint frozen
    # config blocks; validate_campaign also excludes all pilot/selection blocks.
    diversity = _genetic_diversity(candidate, benchmarks)
    if not diversity["passed"]:
        reasons.append("genetic_diversity:insufficient_parameter_distance")
    reasons = sorted(set(reasons))
    controls = {p["profile_id"] for p in context["inventory"]["fixed_controls"]}
    return {"candidate": candidate, "candidate_profile_alias": alias,
            "campaign_checksum": campaign["checksum"], "registry_checksum": campaign["checksum"],
            "original_creation_checksum": row["creation_checksum"],
            "evidence_policy": {"policy_version": POLICY_VERSION, "minimum_tournaments_per_matchup": MINIMUM_TOURNAMENTS,
                                "minimum_samples_per_seat": MINIMUM_SEAT_SAMPLES, "player_count": 9,
                                "independent_batches": 2, "comparison_rule": "paired_composite_lower_95_gt_zero",
                                "evidence_class": "promotion_eligible" if not reasons else "exploratory_only"},
            "opponent_profiles": [copy.deepcopy(benchmarks[k]) for k in sorted(benchmarks)],
            "historical_champion_ids": sorted(set(benchmarks) - controls), "legacy_ids": [],
            "batches": batches, "genetic_diversity": diversity, "measured_behavior": _measured_behavior(counts),
            "ineligibility_reasons": reasons, "promotion_eligible": not reasons, "review_required": True}


@schema_boundary
def confirm_nine_player(campaign: dict[str, Any], candidate_id: str, report_paths_a: Iterable[Path], report_paths_b: Iterable[Path]) -> dict[str, Any]:
    documents = {}
    for mode, paths in (("a", report_paths_a), ("b", report_paths_b)):
        ordered = sorted((Path(path) for path in paths), key=lambda path: load_json_object(path)["shard"]["index"])
        try:
            documents[mode] = [path.read_bytes().decode("utf-8") for path in ordered]
        except (OSError, UnicodeDecodeError) as error:
            raise ToolError("confirmation_report_read_failed", str(error), ExitCode.IO_FAILURE) from error
    confirmation = _compute(campaign, candidate_id, documents)
    return create_artifact(ARTIFACT_TYPE, {"campaign": copy.deepcopy(campaign), "candidate_id": candidate_id,
                                          "report_documents": documents, "confirmation": confirmation})


@schema_boundary
def validate_nine_player_confirmation(artifact: dict[str, Any]) -> dict[str, Any]:
    """Replay embedded strict reports and recompute every gate without source files."""
    validate_artifact_envelope(artifact, ARTIFACT_TYPE)
    payload = artifact["payload"]
    require_exact_fields(payload, ("campaign", "candidate_id", "report_documents", "confirmation"), ARTIFACT_TYPE)
    expected = _compute(payload["campaign"], payload["candidate_id"], payload["report_documents"])
    if payload["confirmation"] != expected:
        _fail("Confirmation summary differs from independently recomputed report evidence.")
    return copy.deepcopy(expected)
