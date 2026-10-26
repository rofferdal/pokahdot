"""Deterministic elitist selection from validated fitness artifacts."""

from __future__ import annotations

import copy
import hashlib
import math
from typing import Any

from .artifacts import canonical_json_bytes, create_artifact, validate_artifact_envelope
from .contracts import (
    GENES,
    require_exact_fields,
    require_identifier,
    require_integer,
    validate_bounds,
    validate_candidate,
)
from .errors import ExitCode, ToolError
from .fitness import COMPONENTS

FITNESS_PAYLOAD_FIELDS = (
    "bounds",
    "candidate_results",
    "code_revisions",
    "evaluation_configuration",
    "generation",
    "generation_id",
    "plan_ids",
    "regime_ids",
    "report_evidence",
    "source_generation_checksum",
)
CANDIDATE_RESULT_FIELDS = (
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
)
REPORT_EVIDENCE_FIELDS = (
    "batch_id",
    "code_revision",
    "command_version",
    "manifest_checksum",
    "report_checksum",
    "seed_range",
    "shard",
)


def _fail(code: str, message: str) -> None:
    raise ToolError(code, message, ExitCode.INVALID_INPUT)


def _finite(value: Any, context: str, minimum: float, maximum: float) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        _fail("invalid_fitness_artifact", f"{context} must be numeric.")
    result = float(value)
    if not math.isfinite(result) or result < minimum or result > maximum:
        _fail(
            "invalid_fitness_artifact",
            f"{context} must be finite and in [{minimum}, {maximum}].",
        )
    return result


def _string_array(value: Any, context: str) -> list[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        _fail("invalid_fitness_artifact", f"{context} must be an array of strings.")
    return list(value)


def _sha256(value: Any, context: str) -> str:
    if (
        not isinstance(value, str)
        or len(value) != 64
        or any(character not in "0123456789abcdef" for character in value)
    ):
        _fail("invalid_fitness_artifact", f"{context} must be a lowercase SHA-256 digest.")
    return value


def validate_fitness_payload(payload: dict[str, Any]) -> dict[str, Any]:
    require_exact_fields(payload, FITNESS_PAYLOAD_FIELDS, "fitness payload")
    bounds = validate_bounds(payload["bounds"])
    generation_id = require_identifier(payload["generation_id"], "generation_id")
    generation = require_integer(payload["generation"], "generation", 0, 2**31 - 1)
    source_checksum = _sha256(payload["source_generation_checksum"], "source checksum")
    plan_ids = _string_array(payload["plan_ids"], "plan_ids")
    regime_ids = _string_array(payload["regime_ids"], "regime_ids")
    code_revisions = _string_array(payload["code_revisions"], "code_revisions")
    evaluation_configuration = payload["evaluation_configuration"]
    if not isinstance(evaluation_configuration, dict):
        _fail("invalid_fitness_artifact", "evaluation_configuration must be an object.")
    require_exact_fields(
        evaluation_configuration, ("plans", "regimes"), "evaluation configuration"
    )
    if not isinstance(evaluation_configuration["plans"], list) or not isinstance(
        evaluation_configuration["regimes"], list
    ):
        _fail("invalid_fitness_artifact", "Evaluation plans and regimes must be arrays.")
    if len(set(plan_ids)) != len(plan_ids) or len(set(regime_ids)) != len(regime_ids):
        _fail("invalid_fitness_artifact", "Plan and regime IDs must be unique.")
    report_evidence = payload["report_evidence"]
    if not isinstance(report_evidence, list) or not report_evidence:
        _fail("invalid_fitness_artifact", "report_evidence must be a non-empty array.")
    for evidence in report_evidence:
        if not isinstance(evidence, dict):
            _fail("invalid_fitness_artifact", "Each report evidence entry must be an object.")
        require_exact_fields(evidence, REPORT_EVIDENCE_FIELDS, "report evidence")
        for field in ("batch_id", "command_version"):
            require_identifier(evidence[field], f"report evidence {field}")
        if evidence["command_version"] != "simulation_cli_v4":
            _fail(
                "invalid_fitness_artifact",
                "Report evidence uses an unsupported simulation command version.",
            )
        if not isinstance(evidence["code_revision"], str):
            _fail("invalid_fitness_artifact", "Report code_revision must be a string.")
        _sha256(evidence["manifest_checksum"], "manifest checksum")
        _sha256(evidence["report_checksum"], "report checksum")
        seed_range = evidence["seed_range"]
        if not isinstance(seed_range, dict):
            _fail("invalid_fitness_artifact", "Report seed_range must be an object.")
        require_exact_fields(seed_range, ("minimum", "maximum"), "report seed range")
        minimum_seed = require_integer(seed_range["minimum"], "minimum seed", 0, 2**63 - 1)
        maximum_seed = require_integer(seed_range["maximum"], "maximum seed", 0, 2**63 - 1)
        if minimum_seed > maximum_seed:
            _fail("invalid_fitness_artifact", "Report seed range is inverted.")
        shard = evidence["shard"]
        if not isinstance(shard, dict):
            _fail("invalid_fitness_artifact", "Report shard must be an object.")
        require_exact_fields(shard, ("index", "count"), "report shard")
        index = require_integer(shard["index"], "shard.index", 0, 2**31 - 1)
        count = require_integer(shard["count"], "shard.count", 1, 2**31 - 1)
        if index >= count:
            _fail("invalid_fitness_artifact", "Report shard index is outside its count.")
    raw_results = payload["candidate_results"]
    if not isinstance(raw_results, list) or not raw_results:
        _fail("invalid_fitness_artifact", "candidate_results must be a non-empty array.")
    results: list[dict[str, Any]] = []
    candidate_ids: set[str] = set()
    for raw_result in raw_results:
        if not isinstance(raw_result, dict):
            _fail("invalid_fitness_artifact", "Each candidate result must be an object.")
        require_exact_fields(raw_result, CANDIDATE_RESULT_FIELDS, "candidate result")
        candidate = validate_candidate(raw_result["candidate"])
        candidate_id = candidate["candidate_id"]
        if candidate_id in candidate_ids:
            _fail("invalid_fitness_artifact", "Candidate result IDs must be unique.")
        candidate_ids.add(candidate_id)
        for gene in GENES:
            value = candidate["parameters"][gene]
            if not bounds[gene]["minimum"] <= value <= bounds[gene]["maximum"]:
                _fail("invalid_fitness_artifact", "Candidate is outside fitness bounds.")
        means = raw_result["component_means"]
        uncertainty = raw_result["uncertainty_95_half_width"]
        if not isinstance(means, dict) or not isinstance(uncertainty, dict):
            _fail("invalid_fitness_artifact", "Fitness components must be objects.")
        require_exact_fields(means, COMPONENTS, "component means")
        require_exact_fields(uncertainty, COMPONENTS, "component uncertainty")
        normalized_means = {name: _finite(means[name], name, 0.0, 1.0) for name in COMPONENTS}
        normalized_uncertainty = {
            name: _finite(uncertainty[name], f"{name} uncertainty", 0.0, 1.0)
            for name in COMPONENTS
        }
        penalty = _finite(raw_result["uncertainty_penalty"], "uncertainty_penalty", 0.0, 0.10)
        eligible = raw_result["eligible"]
        if not isinstance(eligible, bool):
            _fail("invalid_fitness_artifact", "eligible must be boolean.")
        fitness_value = raw_result["fitness"]
        if eligible:
            fitness = _finite(fitness_value, "fitness", 0.0, 1.0)
        elif fitness_value is not None:
            _fail("invalid_fitness_artifact", "Ineligible candidates must have null fitness.")
        else:
            fitness = None
        reasons = _string_array(raw_result["ineligibility_reasons"], "ineligibility_reasons")
        if eligible and reasons:
            _fail("invalid_fitness_artifact", "Eligible candidates cannot have ineligibility reasons.")
        if not eligible and not reasons:
            _fail("invalid_fitness_artifact", "Ineligible candidates require a reason.")
        sample_count = require_integer(raw_result["sample_count"], "sample_count", 0, 2**31 - 1)
        plan_counts = raw_result["plan_sample_counts"]
        if not isinstance(plan_counts, dict):
            _fail("invalid_fitness_artifact", "plan_sample_counts must be an object.")
        require_exact_fields(plan_counts, plan_ids, "plan sample counts")
        normalized_counts = {
            plan_id: require_integer(plan_counts[plan_id], f"samples for {plan_id}", 0, 2**31 - 1)
            for plan_id in plan_ids
        }
        if sum(normalized_counts.values()) != sample_count:
            _fail("invalid_fitness_artifact", "Plan sample counts do not match sample_count.")
        style_checks = raw_result["style_checks"]
        if not isinstance(style_checks, dict):
            _fail("invalid_fitness_artifact", "style_checks must be an object.")
        require_exact_fields(
            style_checks,
            ("bounded_behavioral_rates", "zero_invalid_action_fallbacks"),
            "style checks",
        )
        results.append(
            {
                **copy.deepcopy(raw_result),
                "candidate": candidate,
                "component_means": normalized_means,
                "fitness": fitness,
                "plan_sample_counts": normalized_counts,
                "uncertainty_95_half_width": normalized_uncertainty,
                "uncertainty_penalty": penalty,
            }
        )
    return {
        "bounds": {"genes": bounds},
        "candidate_results": results,
        "code_revisions": code_revisions,
        "evaluation_configuration": copy.deepcopy(evaluation_configuration),
        "generation": generation,
        "generation_id": generation_id,
        "plan_ids": plan_ids,
        "regime_ids": regime_ids,
        "report_evidence": copy.deepcopy(report_evidence),
        "source_generation_checksum": source_checksum,
    }


def select_elites(fitness_artifact: dict[str, Any], elite_fraction: float) -> dict[str, Any]:
    if not math.isfinite(elite_fraction) or elite_fraction < 0.10 or elite_fraction > 0.20:
        _fail("invalid_elite_fraction", "Elite fraction must be in [0.10, 0.20].")
    validate_artifact_envelope(fitness_artifact, "fitness")
    fitness = validate_fitness_payload(fitness_artifact["payload"])
    population_size = len(fitness["candidate_results"])
    retained_count = math.ceil(population_size * elite_fraction)
    if retained_count < 2:
        _fail(
            "too_few_crossover_parents",
            "Elite rounding retained fewer than two crossover parents.",
        )
    eligible = [result for result in fitness["candidate_results"] if result["eligible"]]
    if len(eligible) < retained_count:
        _fail(
            "insufficient_eligible_candidates",
            "There are too few eligible candidates for the retained elite count.",
        )
    eligible.sort(key=lambda result: (-result["fitness"], result["candidate"]["candidate_id"]))
    benchmarks = copy.deepcopy(eligible[:retained_count])
    selected_candidates = [copy.deepcopy(item["candidate"]) for item in benchmarks]
    next_generation = fitness["generation"] + 1
    identity = {
        "elite_fraction": elite_fraction,
        "selected_candidate_ids": [item["candidate_id"] for item in selected_candidates],
        "source_fitness_checksum": fitness_artifact["checksum"],
    }
    digest = hashlib.sha256(canonical_json_bytes(identity)).hexdigest()[:16]
    return create_artifact(
        "selection",
        {
            "bounds": copy.deepcopy(fitness["bounds"]),
            "elite_fraction": elite_fraction,
            "generation": fitness["generation"],
            "generation_id": fitness["generation_id"],
            "historical_benchmarks": benchmarks,
            "next_generation_manifest": {
                "generation": next_generation,
                "generation_id": f"generation_g{next_generation}_selection_{digest}",
            },
            "population_size": population_size,
            "report_evidence": copy.deepcopy(fitness["report_evidence"]),
            "retained_count": retained_count,
            "selected_candidates": selected_candidates,
            "source_fitness_checksum": fitness_artifact["checksum"],
        },
    )
