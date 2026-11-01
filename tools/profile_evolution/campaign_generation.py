"""Deterministic candidate creation with honest archival-parent mutation records."""
from __future__ import annotations

import copy
import hashlib
from typing import Any

from .artifacts import canonical_json_bytes, create_artifact, validate_artifact_envelope
from .campaign import validate_campaign
from .contracts import GENES
from .errors import ExitCode, ToolError
from .evolution import initialize_generation
from .prng import SplitMix64

POLICY = "campaign_candidate_generation_v1"
MUTATION_POLICY = "campaign_mutation_v1"
MAXIMUM_ATTEMPTS = 128
MAXIMUM_DELTA = 20
ROOT_NAMES = (
    "Azure Current", "Silver Compass", "Amber Horizon", "Midnight Pulse",
    "Ivory Tempest", "Jade Undertow", "Indigo Spark", "Golden Veil",
    "Obsidian Tide", "Saffron Echo",
)
CHILD_SUFFIXES = (
    "Orbit", "Ripple", "Beacon", "Ember", "Cadence",
    "Torrent", "Venture", "Glimmer", "Crest", "Reverie",
)


def _fail(message: str) -> None:
    raise ToolError("invalid_campaign_generation", message, ExitCode.INVALID_INPUT)


def _vector(parameters: dict[str, int]) -> tuple[int, ...]:
    return tuple(parameters[gene] for gene in GENES)


def _seed(base: int, index: int) -> int:
    return (base + index) & ((1 << 64) - 1)


def _coverage(candidates: list[dict[str, Any]]) -> bool:
    return all(
        min(c["parameters"][g] for c in candidates) <= 25
        and max(c["parameters"][g] for c in candidates) >= 75
        for g in GENES
    )


def _row(candidate: dict[str, Any], name: str, origin: str, checksum: str) -> dict[str, Any]:
    return {
        "candidate_id": candidate["candidate_id"],
        "profile": {"profile_id": candidate["candidate_id"], "model_id": candidate["model_id"], "parameters": copy.deepcopy(candidate["parameters"])},
        "display_name": name, "origin": origin,
        "parent_ids": copy.deepcopy(candidate["parent_ids"]),
        "status": "active", "creation_checksum": checksum,
    }


def _label(row: dict[str, Any], explanation: str) -> dict[str, Any]:
    return {
        "candidate_id": row["candidate_id"], "display_name": row["display_name"],
        "parent_ids": copy.deepcopy(row["parent_ids"]),
        "parameters": copy.deepcopy(row["profile"]["parameters"]),
        "name_explanation": explanation,
        "gene_explanation": "; ".join(f"{gene}={row['profile']['parameters'][gene]}" for gene in GENES),
    }


def _generate(campaign: dict[str, Any]) -> dict[str, Any]:
    context = validate_campaign(campaign)
    if context["stage"] != "prepared":
        _fail("Candidate generation requires a prepared campaign.")
    config = context["config"]
    incumbents = context["contenders"]
    reserved_profiles = [r["profile"] for r in incumbents] + context["inventory"]["confirmation_benchmarks"]
    benchmark_vectors = [_vector(p["parameters"]) for p in context["inventory"]["confirmation_benchmarks"] if p["model_id"] == "strategy_parameterized"]
    reserved = {_vector(p["parameters"]) for p in reserved_profiles if p["model_id"] == "strategy_parameterized"}
    used_names = {r["display_name"].casefold() for r in incumbents}
    bounds = {g: {"minimum": 0, "maximum": 100} for g in GENES}
    initialization_attempts = []
    selected_generation = None
    for attempt in range(MAXIMUM_ATTEMPTS):
        generation = initialize_generation(bounds, 10, _seed(config["generation_seed"], attempt))
        candidates = generation["payload"]["candidates"]
        vectors = [_vector(c["parameters"]) for c in candidates]
        reasons = []
        if not _coverage(candidates):
            reasons.append("insufficient_broad_gene_coverage")
        if len(set(vectors)) != 10 or set(vectors) & reserved:
            reasons.append("duplicate_parameter_vector")
        if any(sum(abs(a - b) for a, b in zip(vector, benchmark)) < 10 for vector in vectors for benchmark in benchmark_vectors):
            reasons.append("insufficient_benchmark_genetic_distance")
        initialization_attempts.append({"attempt": attempt, "seed": generation["payload"]["seed"], "generation": generation, "rejection_reasons": reasons})
        if not reasons:
            selected_generation = generation
            break
    if selected_generation is None:
        _fail("Bounded initialization attempts exhausted before simulations.")
    rows = []
    labels = []
    for candidate, name in zip(selected_generation["payload"]["candidates"], ROOT_NAMES):
        if name.casefold() in used_names:
            _fail("Proposed root name conflicts with an existing name.")
        used_names.add(name.casefold())
        reserved.add(_vector(candidate["parameters"]))
        row = _row(candidate, name, "initialized", selected_generation["checksum"])
        rows.append(row)
        labels.append(_label(row, "New evocative root name; no ancestral identity implied."))
    mutation_attempts = []
    accepted_mutations = []
    for index, parent in enumerate(incumbents):
        name = parent["display_name"].split()[0] + " " + CHILD_SUFFIXES[index]
        if name.casefold() in used_names:
            _fail("Proposed descendant name conflicts with an existing name.")
        used_names.add(name.casefold())
        accepted = None
        for attempt in range(MAXIMUM_ATTEMPTS):
            seed = _seed(config["mutation_seed"], index * MAXIMUM_ATTEMPTS + attempt)
            random = SplitMix64(seed)
            parameters = {}
            gene_records = []
            for gene in GENES:
                before = parent["profile"]["parameters"][gene]
                delta = random.integer(-MAXIMUM_DELTA, MAXIMUM_DELTA)
                after = min(100, max(0, before + delta))
                parameters[gene] = after
                gene_records.append({"gene": gene, "seed": seed, "before": before, "requested_delta": delta, "after": after, "clamped": after != before + delta})
            identity = {"prepared_campaign_checksum": campaign["checksum"], "parent_id": parent["candidate_id"], "parent_snapshot": copy.deepcopy(parent["profile"]), "seed": seed, "attempt": attempt, "parameters": parameters}
            digest = hashlib.sha256(canonical_json_bytes(identity)).hexdigest()[:16]
            candidate = {"candidate_id": f"candidate_campaign_mut_{index:04d}_{digest}", "model_id": "strategy_parameterized", "parameters": parameters, "parent_ids": [parent["candidate_id"]]}
            mutation = create_artifact(MUTATION_POLICY, {**identity, "candidate": candidate, "maximum_delta": MAXIMUM_DELTA, "bounds": {"genes": bounds}, "gene_records": gene_records})
            reasons = ["duplicate_parameter_vector"] if _vector(parameters) in reserved else []
            if any(sum(abs(a - b) for a, b in zip(_vector(parameters), benchmark)) < 10 for benchmark in benchmark_vectors):
                reasons.append("insufficient_benchmark_genetic_distance")
            mutation_attempts.append({"parent_id": parent["candidate_id"], "attempt": attempt, "seed": seed, "mutation": mutation, "rejection_reasons": reasons})
            if not reasons:
                accepted = mutation
                break
        if accepted is None:
            _fail("Bounded mutation attempts exhausted before simulations.")
        accepted_mutations.append(accepted)
        reserved.add(_vector(accepted["payload"]["candidate"]["parameters"]))
        row = _row(accepted["payload"]["candidate"], name, "mutated", accepted["checksum"])
        rows.append(row)
        labels.append(_label(row, f"Retains the leading name of parent {parent['display_name']}; {CHILD_SUFFIXES[index]} distinguishes this descendant."))
    return create_artifact(POLICY, {
        "prepared_campaign_checksum": campaign["checksum"],
        "policy": {"bounds": {"genes": bounds}, "initialized_count": 10, "descendant_count": 10, "maximum_attempts": MAXIMUM_ATTEMPTS, "maximum_mutation_delta": MAXIMUM_DELTA, "minimum_benchmark_l1_distance": 10, "broad_coverage": {"minimum_at_most": 25, "maximum_at_least": 75}},
        "initialization_attempts": initialization_attempts,
        "initialized_generation": selected_generation,
        "mutation_attempts": mutation_attempts,
        "mutation_records": accepted_mutations,
        "new_contenders": rows, "labels": labels,
    })


def generate_candidates(campaign_artifact: dict[str, Any]) -> dict[str, Any]:
    """Create ten initialized roots and one honestly recorded child per incumbent."""
    return _generate(campaign_artifact)


def validate_candidate_generation(artifact: dict[str, Any], campaign_artifact: dict[str, Any]) -> dict[str, Any]:
    """Replay all bounded seeded attempts, verifying genes, ancestry, names and bindings."""
    validate_artifact_envelope(artifact, POLICY)
    expected = _generate(campaign_artifact)
    if artifact != expected:
        _fail("Candidate generation differs from deterministic campaign creation evidence.")
    return copy.deepcopy(artifact["payload"])
