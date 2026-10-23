"""Deterministic reconstruction and inspection of candidate lineage."""

from __future__ import annotations

import copy
from typing import Any, Iterable

from .artifacts import create_artifact, validate_artifact_envelope
from .contracts import (
    require_exact_fields,
    require_integer,
    validate_bounds,
    validate_candidate,
    validate_candidate_collection,
    validate_selection,
)
from .errors import ExitCode, ToolError
from .selection import validate_fitness_payload

REGISTRY_FIELDS = ("artifacts", "entries")
ENTRY_FIELDS = (
    "bounds",
    "candidate",
    "creation",
    "creation_context",
    "evaluations",
    "generation",
    "generation_id",
    "selection_history",
)

EVALUATION_FIELDS = (
    "code_revisions",
    "component_means",
    "eligible",
    "evaluation_configuration",
    "fitness",
    "fitness_artifact_checksum",
    "ineligibility_reasons",
    "plan_ids",
    "plan_sample_counts",
    "regime_ids",
    "report_evidence",
    "sample_count",
    "style_checks",
    "uncertainty_95_half_width",
    "uncertainty_penalty",
)
SELECTION_HISTORY_FIELDS = (
    "benchmark",
    "elite_fraction",
    "next_generation_manifest",
    "retained_index",
    "selection_artifact_checksum",
    "source_fitness_checksum",
)


def _fail(code: str, message: str, details: dict[str, Any] | None = None) -> None:
    raise ToolError(code, message, ExitCode.INVALID_INPUT, details)


def _is_digest(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 64
        and all(character in "0123456789abcdef" for character in value)
    )


def _validate_entry_evidence(entry: dict[str, Any]) -> None:
    candidate = entry["candidate"]
    creation_context = entry["creation_context"]
    # Reuse the candidate-collection validator for the full creation record,
    # including crossover gene sources and mutation arithmetic.
    validate_candidate_collection(
        {
            "generation_id": entry["generation_id"],
            "generation": entry["generation"],
            "seed": entry["creation"].get("seed"),
            "bounds": entry["bounds"],
            "candidates": [candidate],
            "creation_records": [entry["creation"]],
        }
    )
    normalized_evaluations: list[dict[str, Any]] = []
    for evaluation in entry["evaluations"]:
        if not isinstance(evaluation, dict):
            _fail("invalid_lineage_registry", "Every lineage evaluation must be an object.")
        require_exact_fields(evaluation, EVALUATION_FIELDS, "lineage evaluation")
        if not _is_digest(evaluation["fitness_artifact_checksum"]):
            _fail("invalid_lineage_registry", "Lineage fitness checksum is invalid.")
        candidate_result = {
            key: copy.deepcopy(evaluation[key])
            for key in (
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
        }
        candidate_result["candidate"] = copy.deepcopy(candidate)
        validate_fitness_payload(
            {
                "bounds": copy.deepcopy(entry["bounds"]),
                "candidate_results": [candidate_result],
                "code_revisions": copy.deepcopy(evaluation["code_revisions"]),
                "evaluation_configuration": copy.deepcopy(
                    evaluation["evaluation_configuration"]
                ),
                "generation": entry["generation"],
                "generation_id": entry["generation_id"],
                "plan_ids": copy.deepcopy(evaluation["plan_ids"]),
                "regime_ids": copy.deepcopy(evaluation["regime_ids"]),
                "report_evidence": copy.deepcopy(evaluation["report_evidence"]),
                "source_generation_checksum": creation_context["artifact_checksum"],
            }
        )
        normalized_evaluations.append(candidate_result)
    for history in entry["selection_history"]:
        if not isinstance(history, dict):
            _fail("invalid_lineage_registry", "Every selection history entry must be an object.")
        require_exact_fields(history, SELECTION_HISTORY_FIELDS, "lineage selection history")
        if not _is_digest(history["selection_artifact_checksum"]) or not _is_digest(
            history["source_fitness_checksum"]
        ):
            _fail("invalid_lineage_registry", "Lineage selection checksum is invalid.")
        benchmark = history["benchmark"]
        if not isinstance(benchmark, dict):
            _fail("invalid_lineage_registry", "Lineage benchmark must be an object.")
        if benchmark not in normalized_evaluations:
            _fail(
                "invalid_lineage_registry",
                "Lineage benchmark does not match stored evaluation evidence.",
            )
        fraction = history["elite_fraction"]
        if (
            isinstance(fraction, bool)
            or not isinstance(fraction, (int, float))
            or not 0.10 <= float(fraction) <= 0.20
        ):
            _fail("invalid_lineage_registry", "Lineage elite fraction is invalid.")
        require_integer(history["retained_index"], "retained_index", 0, 2**31 - 1)
        next_generation = history["next_generation_manifest"]
        if not isinstance(next_generation, dict):
            _fail("invalid_lineage_registry", "Next-generation identity must be an object.")
        require_exact_fields(
            next_generation, ("generation", "generation_id"), "next-generation identity"
        )
        if require_integer(
            next_generation["generation"], "next generation", 1, 2**31 - 1
        ) != entry["generation"] + 1:
            _fail("invalid_lineage_registry", "Next-generation number is inconsistent.")


def _entry_from_collection(
    artifact: dict[str, Any],
    collection: dict[str, Any],
    candidate: dict[str, Any],
    creation: dict[str, Any],
) -> dict[str, Any]:
    return {
        "bounds": copy.deepcopy(collection["bounds"]),
        "candidate": copy.deepcopy(candidate),
        "creation": copy.deepcopy(creation),
        "creation_context": {
            "artifact_checksum": artifact["checksum"],
            "artifact_type": artifact["type"],
            "tool_version": artifact["tool_version"],
        },
        "evaluations": [],
        "generation": collection["generation"],
        "generation_id": collection["generation_id"],
        "selection_history": [],
    }


def build_lineage_registry(artifacts: Iterable[dict[str, Any]]) -> dict[str, Any]:
    unique: dict[str, dict[str, Any]] = {}
    for artifact in artifacts:
        validate_artifact_envelope(artifact)
        artifact_type = artifact["type"]
        if artifact_type not in (
            "generation_manifest",
            "candidate_batch",
            "fitness",
            "selection",
        ):
            _fail("unsupported_lineage_artifact", f"Unsupported lineage artifact type '{artifact_type}'.")
        checksum = artifact["checksum"]
        if checksum in unique and unique[checksum] != artifact:
            _fail("lineage_artifact_conflict", "Artifacts sharing a checksum differ.")
        unique[checksum] = copy.deepcopy(artifact)
    if not unique:
        _fail("missing_lineage_artifacts", "At least one lineage artifact is required.")

    entries: dict[str, dict[str, Any]] = {}
    generation_checksums: set[str] = set()
    fitness_by_checksum: dict[str, dict[str, Any]] = {}
    selections: list[tuple[str, dict[str, Any]]] = []
    catalog: list[dict[str, str]] = []
    for checksum in sorted(unique):
        artifact = unique[checksum]
        artifact_type = artifact["type"]
        catalog.append({"checksum": checksum, "type": artifact_type})
        if artifact_type in ("generation_manifest", "candidate_batch"):
            collection = validate_candidate_collection(artifact["payload"])
            if artifact_type == "generation_manifest":
                generation_checksums.add(checksum)
            for candidate, creation in zip(
                collection["candidates"], collection["creation_records"]
            ):
                candidate_id = candidate["candidate_id"]
                proposed = _entry_from_collection(artifact, collection, candidate, creation)
                existing = entries.get(candidate_id)
                if existing is not None and existing != proposed:
                    _fail(
                        "lineage_candidate_conflict",
                        f"Candidate '{candidate_id}' has conflicting immutable history.",
                    )
                entries[candidate_id] = proposed
        elif artifact_type == "fitness":
            fitness_by_checksum[checksum] = validate_fitness_payload(artifact["payload"])
        else:
            validate_selection(artifact["payload"])
            selections.append((checksum, artifact["payload"]))

    for candidate_id, entry in entries.items():
        for parent_id in entry["candidate"]["parent_ids"]:
            if parent_id not in entries:
                _fail(
                    "orphan_lineage_parent",
                    f"Candidate '{candidate_id}' references missing parent '{parent_id}'.",
                )
            parent_generation = entries[parent_id]["generation"]
            operation = entry["creation"]["operation"]
            invalid_generation = (
                parent_generation >= entry["generation"]
                if operation == "crossover"
                else parent_generation != entry["generation"]
            )
            if invalid_generation:
                _fail(
                    "invalid_lineage_generation",
                    f"Parent '{parent_id}' must precede candidate '{candidate_id}'.",
                )

    for fitness_checksum in sorted(fitness_by_checksum):
        fitness = fitness_by_checksum[fitness_checksum]
        if fitness["source_generation_checksum"] not in generation_checksums:
            _fail(
                "missing_source_generation",
                "Fitness artifact source generation is absent from lineage history.",
            )
        for result in fitness["candidate_results"]:
            candidate = result["candidate"]
            candidate_id = candidate["candidate_id"]
            if candidate_id not in entries or entries[candidate_id]["candidate"] != candidate:
                _fail(
                    "lineage_candidate_conflict",
                    f"Fitness evidence does not match candidate '{candidate_id}'.",
                )
            if (
                entries[candidate_id]["generation"] != fitness["generation"]
                or entries[candidate_id]["generation_id"] != fitness["generation_id"]
            ):
                _fail(
                    "lineage_generation_conflict",
                    f"Fitness generation does not match candidate '{candidate_id}'.",
                )
            entries[candidate_id]["evaluations"].append(
                {
                    "code_revisions": copy.deepcopy(fitness["code_revisions"]),
                    "component_means": copy.deepcopy(result["component_means"]),
                    "eligible": result["eligible"],
                    "evaluation_configuration": copy.deepcopy(
                        fitness["evaluation_configuration"]
                    ),
                    "fitness": result["fitness"],
                    "fitness_artifact_checksum": fitness_checksum,
                    "ineligibility_reasons": copy.deepcopy(result["ineligibility_reasons"]),
                    "plan_ids": copy.deepcopy(fitness["plan_ids"]),
                    "plan_sample_counts": copy.deepcopy(result["plan_sample_counts"]),
                    "regime_ids": copy.deepcopy(fitness["regime_ids"]),
                    "report_evidence": copy.deepcopy(fitness["report_evidence"]),
                    "sample_count": result["sample_count"],
                    "style_checks": copy.deepcopy(result["style_checks"]),
                    "uncertainty_95_half_width": copy.deepcopy(
                        result["uncertainty_95_half_width"]
                    ),
                    "uncertainty_penalty": result["uncertainty_penalty"],
                }
            )

    for selection_checksum, selection in sorted(selections):
        source_checksum = selection["source_fitness_checksum"]
        if source_checksum not in fitness_by_checksum:
            _fail(
                "missing_source_fitness",
                "Selection source fitness artifact is absent from lineage history.",
            )
        source_fitness = fitness_by_checksum[source_checksum]
        if (
            source_fitness["generation"] != selection["generation"]
            or source_fitness["generation_id"] != selection["generation_id"]
        ):
            _fail(
                "lineage_generation_conflict",
                "Selection generation does not match its source fitness artifact.",
            )
        for retained_index, benchmark in enumerate(selection["historical_benchmarks"]):
            candidate = benchmark["candidate"]
            candidate_id = candidate["candidate_id"]
            if candidate_id not in entries or entries[candidate_id]["candidate"] != candidate:
                _fail(
                    "lineage_candidate_conflict",
                    f"Selection evidence does not match candidate '{candidate_id}'.",
                )
            entries[candidate_id]["selection_history"].append(
                {
                    "benchmark": copy.deepcopy(benchmark),
                    "elite_fraction": selection["elite_fraction"],
                    "next_generation_manifest": copy.deepcopy(
                        selection["next_generation_manifest"]
                    ),
                    "retained_index": retained_index,
                    "selection_artifact_checksum": selection_checksum,
                    "source_fitness_checksum": source_checksum,
                }
            )

    ordered_entries = []
    for candidate_id in sorted(entries):
        entry = entries[candidate_id]
        entry["evaluations"].sort(key=lambda item: item["fitness_artifact_checksum"])
        entry["selection_history"].sort(
            key=lambda item: (item["selection_artifact_checksum"], item["retained_index"])
        )
        ordered_entries.append(entry)
    return create_artifact(
        "lineage_registry", {"artifacts": catalog, "entries": ordered_entries}
    )


def validate_lineage_registry(artifact: dict[str, Any]) -> dict[str, Any]:
    validate_artifact_envelope(artifact, "lineage_registry")
    payload = artifact["payload"]
    require_exact_fields(payload, REGISTRY_FIELDS, "lineage registry")
    if not isinstance(payload["artifacts"], list) or not isinstance(payload["entries"], list):
        _fail("invalid_lineage_registry", "Registry artifacts and entries must be arrays.")
    for item in payload["artifacts"]:
        if not isinstance(item, dict):
            _fail("invalid_lineage_registry", "Registry artifact evidence must be an object.")
        require_exact_fields(item, ("checksum", "type"), "registry artifact evidence")
        if not _is_digest(item["checksum"]) or not isinstance(item["type"], str):
            _fail("invalid_lineage_registry", "Registry artifact evidence is invalid.")
    entries: dict[str, dict[str, Any]] = {}
    for entry in payload["entries"]:
        if not isinstance(entry, dict):
            _fail("invalid_lineage_registry", "Every lineage entry must be an object.")
        require_exact_fields(entry, ENTRY_FIELDS, "lineage entry")
        candidate = validate_candidate(entry["candidate"])
        candidate_id = candidate["candidate_id"]
        if candidate_id in entries:
            _fail("invalid_lineage_registry", "Lineage candidate IDs must be unique.")
        if not isinstance(entry["evaluations"], list) or not isinstance(
            entry["selection_history"], list
        ):
            _fail("invalid_lineage_registry", "Lineage evidence must be stored in arrays.")
        if isinstance(entry["generation"], bool) or not isinstance(entry["generation"], int):
            _fail("invalid_lineage_registry", "Lineage generation must be an integer.")
        if not isinstance(entry["generation_id"], str) or not isinstance(entry["creation"], dict):
            _fail("invalid_lineage_registry", "Lineage generation or creation is invalid.")
        creation_context = entry["creation_context"]
        if not isinstance(creation_context, dict):
            _fail("invalid_lineage_registry", "Lineage creation context must be an object.")
        require_exact_fields(
            creation_context,
            ("artifact_checksum", "artifact_type", "tool_version"),
            "lineage creation context",
        )
        if any(not isinstance(value, str) or not value for value in creation_context.values()):
            _fail("invalid_lineage_registry", "Lineage creation context is invalid.")
        validate_bounds(entry["bounds"])
        if (
            entry["creation"].get("candidate_id") != candidate_id
            or entry["creation"].get("parent_ids") != candidate["parent_ids"]
        ):
            _fail("invalid_lineage_registry", "Lineage creation identity is inconsistent.")
        _validate_entry_evidence(entry)
        entries[candidate_id] = entry
    for candidate_id, entry in entries.items():
        for parent_id in entry["candidate"]["parent_ids"]:
            if parent_id not in entries:
                _fail(
                    "orphan_lineage_parent",
                    f"Candidate '{candidate_id}' references missing parent '{parent_id}'.",
                )
            if entries[parent_id]["generation"] > entry["generation"]:
                _fail("invalid_lineage_registry", "A lineage parent cannot be from a later generation.")
    visiting: set[str] = set()
    visited: set[str] = set()

    def validate_acyclic(candidate_id: str) -> None:
        if candidate_id in visiting:
            _fail("invalid_lineage_registry", "Lineage ancestry contains a cycle.")
        if candidate_id in visited:
            return
        visiting.add(candidate_id)
        for parent_id in entries[candidate_id]["candidate"]["parent_ids"]:
            validate_acyclic(parent_id)
        visiting.remove(candidate_id)
        visited.add(candidate_id)

    for candidate_id in entries:
        validate_acyclic(candidate_id)
    return {"artifacts": copy.deepcopy(payload["artifacts"]), "entries": entries}


def inspect_lineage(artifact: dict[str, Any], candidate_id: str) -> dict[str, Any]:
    registry = validate_lineage_registry(artifact)
    entries = registry["entries"]
    if candidate_id not in entries:
        _fail("unknown_lineage_candidate", f"Candidate '{candidate_id}' is not in the registry.")
    ancestors: list[dict[str, Any]] = []
    visited: set[str] = set()

    def visit(current_id: str) -> None:
        for parent_id in entries[current_id]["candidate"]["parent_ids"]:
            visit(parent_id)
            if parent_id not in visited:
                parent = entries[parent_id]
                ancestors.append(
                    {
                        "candidate": copy.deepcopy(parent["candidate"]),
                        "creation": copy.deepcopy(parent["creation"]),
                        "creation_context": copy.deepcopy(parent["creation_context"]),
                        "generation": parent["generation"],
                        "generation_id": parent["generation_id"],
                    }
                )
                visited.add(parent_id)

    visit(candidate_id)
    entry = entries[candidate_id]
    return {
        "ancestors": ancestors,
        "candidate": copy.deepcopy(entry["candidate"]),
        "creation": copy.deepcopy(entry["creation"]),
        "creation_context": copy.deepcopy(entry["creation_context"]),
        "evaluations": copy.deepcopy(entry["evaluations"]),
        "generation": entry["generation"],
        "generation_id": entry["generation_id"],
        "selection_history": copy.deepcopy(entry["selection_history"]),
    }
