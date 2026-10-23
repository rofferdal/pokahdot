"""Deterministic candidate initialization, crossover, and mutation."""

from __future__ import annotations

import copy
import hashlib
from typing import Any

from .artifacts import canonical_json_bytes, create_artifact
from .contracts import GENES, MODEL_ID, validate_candidate_collection
from .prng import SplitMix64


def _identifier(prefix: str, identity: dict[str, Any]) -> str:
    digest = hashlib.sha256(canonical_json_bytes(identity)).hexdigest()[:16]
    return f"{prefix}_{digest}"


def initialize_generation(
    bounds: dict[str, dict[str, int]], population_size: int, seed: int
) -> dict[str, Any]:
    random = SplitMix64(seed)
    generation_id = _identifier(
        "generation_g0",
        {"seed": seed, "bounds": bounds, "population_size": population_size},
    )
    candidates: list[dict[str, Any]] = []
    records: list[dict[str, Any]] = []
    for index in range(population_size):
        parameters = {
            gene: random.integer(bounds[gene]["minimum"], bounds[gene]["maximum"])
            for gene in GENES
        }
        candidate_id = _identifier(
            f"candidate_g0_{index:04d}",
            {"generation_id": generation_id, "index": index, "parameters": parameters},
        )
        candidate = {
            "candidate_id": candidate_id,
            "model_id": MODEL_ID,
            "parameters": parameters,
            "parent_ids": [],
        }
        candidates.append(candidate)
        records.append(
            {
                "candidate_id": candidate_id,
                "operation": "initialization",
                "parent_ids": [],
                "seed": seed,
            }
        )
    return create_artifact(
        "generation_manifest",
        {
            "generation_id": generation_id,
            "generation": 0,
            "seed": seed,
            "bounds": {"genes": copy.deepcopy(bounds)},
            "candidates": candidates,
            "creation_records": records,
        },
    )


def crossover_candidates(
    selection: dict[str, Any], target_count: int, seed: int
) -> dict[str, Any]:
    parents = selection["selected_candidates"]
    if len(parents) < 2:
        from .errors import ExitCode, ToolError

        raise ToolError(
            "insufficient_crossover_parents",
            "Crossover requires at least two selected candidates.",
            ExitCode.INVALID_INPUT,
        )
    random = SplitMix64(seed)
    generation = selection["generation"]
    generation_id = selection["generation_id"]
    children: list[dict[str, Any]] = []
    records: list[dict[str, Any]] = []
    for index in range(target_count):
        first_index = random.integer(0, len(parents) - 1)
        second_index = random.integer(0, len(parents) - 2)
        if second_index >= first_index:
            second_index += 1
        selected_parents = [parents[first_index], parents[second_index]]
        sources: dict[str, str] = {}
        parameters: dict[str, int] = {}
        for gene in GENES:
            parent = selected_parents[random.integer(0, 1)]
            sources[gene] = parent["candidate_id"]
            parameters[gene] = parent["parameters"][gene]
        parent_ids = [parent["candidate_id"] for parent in selected_parents]
        candidate_id = _identifier(
            f"candidate_g{generation}_{index:04d}",
            {
                "generation_id": generation_id,
                "index": index,
                "parent_ids": parent_ids,
                "parameters": parameters,
                "seed": seed,
            },
        )
        children.append(
            {
                "candidate_id": candidate_id,
                "model_id": MODEL_ID,
                "parameters": parameters,
                "parent_ids": parent_ids,
            }
        )
        records.append(
            {
                "candidate_id": candidate_id,
                "gene_sources": sources,
                "operation": "crossover",
                "parent_ids": parent_ids,
                "seed": seed,
            }
        )
    return create_artifact(
        "candidate_batch",
        {
            "generation_id": generation_id,
            "generation": generation,
            "seed": seed,
            "bounds": copy.deepcopy(selection["bounds"]),
            "candidates": children,
            "creation_records": records,
        },
    )


def mutate_candidates(
    source: dict[str, Any], policy: dict[str, int], seed: int
) -> dict[str, Any]:
    source = validate_candidate_collection(source)
    random = SplitMix64(seed)
    generation = source["generation"]
    generation_id = source["generation_id"]
    candidates: list[dict[str, Any]] = []
    records: list[dict[str, Any]] = []
    for index, source_candidate in enumerate(source["candidates"]):
        parameters: dict[str, int] = {}
        mutations: list[dict[str, Any]] = []
        for gene in GENES:
            before = source_candidate["parameters"][gene]
            delta = 0
            if random.integer(1, 100) <= policy["mutation_probability_percent"]:
                delta = random.integer(-policy["maximum_delta"], policy["maximum_delta"])
            minimum = source["bounds"]["genes"][gene]["minimum"]
            maximum = source["bounds"]["genes"][gene]["maximum"]
            unbounded = before + delta
            after = min(maximum, max(minimum, unbounded))
            parameters[gene] = after
            mutations.append(
                {
                    "after": after,
                    "before": before,
                    "clamped": after != unbounded,
                    "delta": delta,
                    "gene": gene,
                    "seed": seed,
                }
            )
        parent_id = source_candidate["candidate_id"]
        candidate_id = _identifier(
            f"candidate_g{generation}_mut_{index:04d}",
            {
                "generation_id": generation_id,
                "index": index,
                "parent_id": parent_id,
                "parameters": parameters,
                "seed": seed,
            },
        )
        candidates.append(
            {
                "candidate_id": candidate_id,
                "model_id": MODEL_ID,
                "parameters": parameters,
                "parent_ids": [parent_id],
            }
        )
        records.append(
            {
                "candidate_id": candidate_id,
                "mutations": mutations,
                "operation": "mutation",
                "parent_ids": [parent_id],
                "seed": seed,
            }
        )
    return create_artifact(
        "generation_manifest",
        {
            "generation_id": generation_id,
            "generation": generation,
            "seed": seed,
            "bounds": copy.deepcopy(source["bounds"]),
            "candidates": candidates,
            "creation_records": records,
        },
    )
