"""Strict schemas for deterministic candidate operations."""

from __future__ import annotations

import math
from typing import Any, Iterable

from .errors import ExitCode, ToolError

GENES = (
    "tight_vs_loose",
    "passive_vs_aggressive",
    "call_vs_raise",
    "bluff_rate",
)
MODEL_ID = "strategy_parameterized"
MAX_SEED = (1 << 64) - 1


def _fail(code: str, message: str, details: dict[str, Any] | None = None) -> None:
    raise ToolError(code, message, ExitCode.INVALID_INPUT, details)


def require_exact_fields(
    value: dict[str, Any], fields: Iterable[str], context: str
) -> None:
    expected = set(fields)
    actual = set(value)
    missing = sorted(expected - actual)
    unknown = sorted(actual - expected)
    if missing or unknown:
        _fail(
            "invalid_schema_fields",
            f"{context} fields do not match the schema.",
            {"context": context, "missing_fields": missing, "unknown_fields": unknown},
        )


def require_integer(value: Any, context: str, minimum: int, maximum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        _fail("invalid_integer", f"{context} must be an integer.")
    if value < minimum or value > maximum:
        _fail(
            "integer_out_of_range",
            f"{context} must be in the inclusive range {minimum}..{maximum}.",
        )
    return value


def require_identifier(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value or value.strip() != value:
        _fail("invalid_identifier", f"{context} must be a non-empty trimmed string.")
    return value


def validate_seed(seed: Any, context: str = "seed") -> int:
    return require_integer(seed, context, 0, MAX_SEED)


def validate_bounds(payload: dict[str, Any]) -> dict[str, dict[str, int]]:
    require_exact_fields(payload, ("genes",), "gene bounds payload")
    genes = payload["genes"]
    if not isinstance(genes, dict):
        _fail("invalid_gene_bounds", "gene bounds payload genes must be an object.")
    require_exact_fields(genes, GENES, "gene bounds")
    result: dict[str, dict[str, int]] = {}
    for gene in GENES:
        bounds = genes[gene]
        if not isinstance(bounds, dict):
            _fail("invalid_gene_bounds", f"Bounds for '{gene}' must be an object.")
        require_exact_fields(bounds, ("minimum", "maximum"), f"bounds for {gene}")
        minimum = require_integer(bounds["minimum"], f"{gene}.minimum", 0, 100)
        maximum = require_integer(bounds["maximum"], f"{gene}.maximum", 0, 100)
        if minimum > maximum:
            _fail(
                "invalid_gene_bounds",
                f"Minimum exceeds maximum for gene '{gene}'.",
            )
        result[gene] = {"minimum": minimum, "maximum": maximum}
    return result


def validate_parameters(parameters: Any) -> dict[str, int]:
    if not isinstance(parameters, dict):
        _fail("invalid_candidate", "Candidate parameters must be an object.")
    require_exact_fields(parameters, GENES, "candidate parameters")
    return {
        gene: require_integer(parameters[gene], f"parameters.{gene}", 0, 100)
        for gene in GENES
    }


def validate_candidate(candidate: Any) -> dict[str, Any]:
    if not isinstance(candidate, dict):
        _fail("invalid_candidate", "Each candidate must be an object.")
    require_exact_fields(
        candidate,
        ("candidate_id", "model_id", "parameters", "parent_ids"),
        "candidate",
    )
    candidate_id = require_identifier(candidate["candidate_id"], "candidate_id")
    if candidate["model_id"] != MODEL_ID:
        _fail("invalid_model_id", f"Candidate '{candidate_id}' has an unsupported model_id.")
    parent_ids = candidate["parent_ids"]
    if not isinstance(parent_ids, list) or len(parent_ids) > 2:
        _fail("invalid_parent_ids", "Candidate parent_ids must be an array of at most two IDs.")
    validated_parents = [require_identifier(parent, "parent_id") for parent in parent_ids]
    if len(set(validated_parents)) != len(validated_parents):
        _fail("invalid_parent_ids", "Candidate parent_ids must be unique.")
    return {
        "candidate_id": candidate_id,
        "model_id": MODEL_ID,
        "parameters": validate_parameters(candidate["parameters"]),
        "parent_ids": validated_parents,
    }


def validate_candidates(candidates: Any) -> list[dict[str, Any]]:
    if not isinstance(candidates, list) or not candidates:
        _fail("invalid_candidates", "Candidates must be a non-empty array.")
    result = [validate_candidate(candidate) for candidate in candidates]
    identifiers = [candidate["candidate_id"] for candidate in result]
    if len(set(identifiers)) != len(identifiers):
        _fail("duplicate_candidate_id", "Candidate IDs must be unique.")
    return result


def validate_selection(payload: dict[str, Any]) -> dict[str, Any]:
    require_exact_fields(
        payload,
        (
            "bounds",
            "elite_fraction",
            "generation",
            "generation_id",
            "historical_benchmarks",
            "next_generation_manifest",
            "population_size",
            "report_evidence",
            "retained_count",
            "selected_candidates",
            "source_fitness_checksum",
        ),
        "selection payload",
    )
    bounds = validate_bounds(payload["bounds"])
    candidates = validate_candidates(payload["selected_candidates"])
    for candidate in candidates:
        for gene in GENES:
            value = candidate["parameters"][gene]
            if not bounds[gene]["minimum"] <= value <= bounds[gene]["maximum"]:
                _fail(
                    "candidate_outside_bounds",
                    f"Candidate '{candidate['candidate_id']}' gene '{gene}' is outside selection bounds.",
                )
    fraction = payload["elite_fraction"]
    if (
        isinstance(fraction, bool)
        or not isinstance(fraction, (int, float))
        or not math.isfinite(float(fraction))
        or not 0.10 <= float(fraction) <= 0.20
    ):
        _fail("invalid_selection", "Selection elite_fraction must be in [0.10, 0.20].")
    population_size = require_integer(payload["population_size"], "population_size", 1, 2**31 - 1)
    retained_count = require_integer(payload["retained_count"], "retained_count", 2, 2**31 - 1)
    if retained_count != len(candidates) or population_size < retained_count:
        _fail("invalid_selection", "Selection retained counts are inconsistent.")
    checksum = payload["source_fitness_checksum"]
    if (
        not isinstance(checksum, str)
        or len(checksum) != 64
        or any(character not in "0123456789abcdef" for character in checksum)
    ):
        _fail("invalid_selection", "Selection source fitness checksum is invalid.")
    next_generation = payload["next_generation_manifest"]
    if not isinstance(next_generation, dict):
        _fail("invalid_selection", "next_generation_manifest must be an object.")
    require_exact_fields(next_generation, ("generation", "generation_id"), "next generation")
    generation = require_integer(payload["generation"], "generation", 0, 2**31 - 1)
    if require_integer(next_generation["generation"], "next generation", 1, 2**31 - 1) != generation + 1:
        _fail("invalid_selection", "Next generation number is inconsistent.")
    require_identifier(next_generation["generation_id"], "next generation_id")
    benchmarks = payload["historical_benchmarks"]
    if not isinstance(benchmarks, list) or len(benchmarks) != retained_count:
        _fail("invalid_selection", "Historical benchmarks must match retained candidates.")
    benchmark_fields = (
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
    )
    for candidate, benchmark in zip(candidates, benchmarks):
        if not isinstance(benchmark, dict):
            _fail("invalid_selection", "Each historical benchmark must be an object.")
        require_exact_fields(benchmark, benchmark_fields, "historical benchmark")
        if validate_candidate(benchmark["candidate"]) != candidate or benchmark["eligible"] is not True:
            _fail("invalid_selection", "Historical benchmark identity or eligibility is invalid.")
        for fitness_field in ("fitness", "point_fitness"):
            value = benchmark[fitness_field]
            if (
                isinstance(value, bool)
                or not isinstance(value, (int, float))
                or not math.isfinite(float(value))
                or not 0.0 <= float(value) <= 1.0
            ):
                _fail("invalid_selection", f"Historical benchmark {fitness_field} is invalid.")
        for field in ("component_means", "uncertainty_95_half_width"):
            values = benchmark[field]
            if not isinstance(values, dict):
                _fail("invalid_selection", f"Historical benchmark {field} must be an object.")
            component_names = (
                "win_score",
                "finish_score",
                "top_third_score",
                "chip_score",
                "survival_score",
                "blind_chip_score",
            )
            require_exact_fields(values, component_names, f"historical benchmark {field}")
            if any(
                item is not None
                and (
                    isinstance(item, bool)
                    or not isinstance(item, (int, float))
                    or not math.isfinite(float(item))
                    or not 0.0 <= float(item) <= 1.0
                )
                for item in values.values()
            ) or (field == "component_means" and any(item is None for item in values.values())):
                _fail("invalid_selection", f"Historical benchmark {field} is invalid.")
        if benchmark["ineligibility_reasons"] != []:
            _fail("invalid_selection", "Historical benchmarks cannot have ineligibility reasons.")
        require_integer(benchmark["sample_count"], "benchmark sample_count", 0, 2**31 - 1)
        penalty = benchmark["uncertainty_penalty"]
        if (
            isinstance(penalty, bool)
            or not isinstance(penalty, (int, float))
            or not math.isfinite(float(penalty))
            or not 0.0 <= float(penalty) <= 0.10
        ):
            _fail("invalid_selection", "Historical benchmark uncertainty penalty is invalid.")
        if not isinstance(benchmark["plan_sample_counts"], dict) or not isinstance(
            benchmark["style_checks"], dict
        ):
            _fail("invalid_selection", "Historical benchmark evidence objects are invalid.")
    evidence = payload["report_evidence"]
    if not isinstance(evidence, list) or not evidence:
        _fail("invalid_selection", "Selection report_evidence must be non-empty.")
    evidence_fields = (
        "batch_id",
        "code_revision",
        "command_version",
        "execution_provenance",
        "manifest_checksum",
        "report_checksum",
        "seed_range",
        "shard",
    )
    for item in evidence:
        if not isinstance(item, dict):
            _fail("invalid_selection", "Each report evidence entry must be an object.")
        require_exact_fields(item, evidence_fields, "selection report evidence")
        if any(
            not isinstance(item[field], str)
            for field in (
                "batch_id",
                "code_revision",
                "command_version",
                "manifest_checksum",
                "report_checksum",
            )
        ):
            _fail("invalid_selection", "Selection report evidence strings are invalid.")
        for field in ("manifest_checksum", "report_checksum"):
            checksum_value = item[field]
            if len(checksum_value) != 64 or any(
                character not in "0123456789abcdef" for character in checksum_value
            ):
                _fail("invalid_selection", "Selection report checksum is invalid.")
        provenance = item["execution_provenance"]
        if not isinstance(provenance, dict) or provenance.get("code_revision") != item["code_revision"]:
            _fail("invalid_selection", "Selection report provenance is invalid.")
        seed_range = item["seed_range"]
        if not isinstance(seed_range, dict):
            _fail("invalid_selection", "Selection seed range must be an object.")
        require_exact_fields(seed_range, ("minimum", "maximum"), "selection seed range")
        minimum_seed = require_integer(seed_range["minimum"], "minimum seed", 0, 2**63 - 1)
        maximum_seed = require_integer(seed_range["maximum"], "maximum seed", 0, 2**63 - 1)
        if minimum_seed > maximum_seed:
            _fail("invalid_selection", "Selection seed range is inverted.")
        shard = item["shard"]
        if not isinstance(shard, dict):
            _fail("invalid_selection", "Selection report shard must be an object.")
        require_exact_fields(shard, ("index", "count"), "selection report shard")
        shard_index = require_integer(shard["index"], "selection shard index", 0, 2**31 - 1)
        shard_count = require_integer(shard["count"], "selection shard count", 1, 2**31 - 1)
        if shard_index >= shard_count:
            _fail("invalid_selection", "Selection report shard is invalid.")
    return {
        "generation_id": require_identifier(
            next_generation["generation_id"], "next generation_id"
        ),
        "generation": next_generation["generation"],
        "bounds": {"genes": bounds},
        "selected_candidates": candidates,
    }


def validate_mutation_policy(payload: dict[str, Any]) -> dict[str, int]:
    require_exact_fields(
        payload,
        ("mutation_probability_percent", "maximum_delta"),
        "mutation policy payload",
    )
    return {
        "mutation_probability_percent": require_integer(
            payload["mutation_probability_percent"],
            "mutation_probability_percent",
            0,
            100,
        ),
        "maximum_delta": require_integer(payload["maximum_delta"], "maximum_delta", 0, 100),
    }


def validate_candidate_collection(payload: dict[str, Any]) -> dict[str, Any]:
    require_exact_fields(
        payload,
        ("generation_id", "generation", "seed", "bounds", "candidates", "creation_records"),
        "candidate collection payload",
    )
    collection_seed = validate_seed(payload["seed"])
    candidates = validate_candidates(payload["candidates"])
    bounds = validate_bounds(payload["bounds"])
    for candidate in candidates:
        for gene in GENES:
            if not bounds[gene]["minimum"] <= candidate["parameters"][gene] <= bounds[gene]["maximum"]:
                _fail(
                    "candidate_outside_bounds",
                    f"Candidate '{candidate['candidate_id']}' gene '{gene}' is outside collection bounds.",
                )
    raw_records = payload["creation_records"]
    if not isinstance(raw_records, list) or len(raw_records) != len(candidates):
        _fail("invalid_creation_records", "creation_records must be an array.")
    records: list[dict[str, Any]] = []
    for candidate, record in zip(candidates, raw_records):
        if not isinstance(record, dict):
            _fail("invalid_creation_records", "Each creation record must be an object.")
        operation = record.get("operation")
        common_fields = ("candidate_id", "operation", "parent_ids", "seed")
        if operation == "initialization":
            require_exact_fields(record, common_fields, "initialization record")
        elif operation == "crossover":
            require_exact_fields(record, (*common_fields, "gene_sources"), "crossover record")
            sources = record["gene_sources"]
            if not isinstance(sources, dict):
                _fail("invalid_creation_records", "gene_sources must be an object.")
            require_exact_fields(sources, GENES, "crossover gene_sources")
            validated_sources = [
                require_identifier(sources[gene], f"gene source for {gene}") for gene in GENES
            ]
            if any(source not in candidate["parent_ids"] for source in validated_sources):
                _fail("invalid_creation_records", "Every gene source must identify one parent.")
        elif operation == "mutation":
            require_exact_fields(record, (*common_fields, "mutations"), "mutation record")
            mutations = record["mutations"]
            if not isinstance(mutations, list) or len(mutations) != len(GENES):
                _fail("invalid_creation_records", "Mutation records must contain every gene.")
            for gene, mutation in zip(GENES, mutations):
                if not isinstance(mutation, dict):
                    _fail("invalid_creation_records", "Each mutation must be an object.")
                require_exact_fields(
                    mutation,
                    ("seed", "gene", "before", "delta", "after", "clamped"),
                    "gene mutation record",
                )
                if mutation["gene"] != gene or not isinstance(mutation["clamped"], bool):
                    _fail("invalid_creation_records", "Mutation gene order or clamped flag is invalid.")
                validate_seed(mutation["seed"], "mutation seed")
                require_integer(mutation["before"], "mutation before", 0, 100)
                require_integer(mutation["delta"], "mutation delta", -100, 100)
                require_integer(mutation["after"], "mutation after", 0, 100)
                unbounded = mutation["before"] + mutation["delta"]
                expected_after = min(
                    bounds[gene]["maximum"],
                    max(bounds[gene]["minimum"], unbounded),
                )
                if (
                    mutation["seed"] != collection_seed
                    or mutation["after"] != expected_after
                    or mutation["after"] != candidate["parameters"][gene]
                    or mutation["clamped"] != (expected_after != unbounded)
                ):
                    _fail("invalid_creation_records", "Mutation record values are inconsistent.")
        else:
            _fail("invalid_creation_records", "Creation record operation is unsupported.")
        if (
            record["candidate_id"] != candidate["candidate_id"]
            or record["parent_ids"] != candidate["parent_ids"]
        ):
            _fail("invalid_creation_records", "Creation record identity does not match its candidate.")
        validate_seed(record["seed"], "creation record seed")
        if record["seed"] != collection_seed:
            _fail("invalid_creation_records", "Creation record seed does not match the collection.")
        records.append(record)
    return {
        "generation_id": require_identifier(payload["generation_id"], "generation_id"),
        "generation": require_integer(payload["generation"], "generation", 0, 2**31 - 1),
        "seed": collection_seed,
        "bounds": {"genes": bounds},
        "candidates": candidates,
        "creation_records": records,
    }
