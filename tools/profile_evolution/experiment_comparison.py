"""Cross-generation ranking from one validated common simulation cohort."""

from __future__ import annotations

import copy
from pathlib import Path
from typing import Any, Iterable

from .artifacts import create_artifact, load_json_object
from .confirmation import _candidate_generation
from .errors import ExitCode, ToolError
from .experiment import RNG_ALGORITHM, experiment_manifests, load_experiment
from .experiment_output import publish_documents
from .fitness import _normalize_report_integers, evaluate_fitness
from .lineage import evaluation_record, validate_lineage_registry
from .selection import validate_fitness_payload


def compare_experiment(
    config_path: Path, report_paths: Iterable[Path], output_dir: Path
) -> dict[str, Any]:
    context = load_experiment(config_path)
    manifests, issues = experiment_manifests(context)
    if issues:
        raise ToolError(
            "incompatible_experiment", "Experiment inputs are incompatible.",
            ExitCode.INVALID_INPUT, {"incompatibilities": issues},
        )
    reports = list(report_paths)
    if not reports:
        raise ToolError(
            "missing_reports", "A complete common evaluation cohort is required.",
            ExitCode.INVALID_INPUT,
        )
    expected_manifest = manifests["evaluation_manifest.json"]
    for path in reports:
        report = _normalize_report_integers(load_json_object(path))
        if report.get("manifest") != expected_manifest:
            raise ToolError(
                "incompatible_experiment_cohort",
                "Every report must use the exact generated common evaluation manifest.",
                ExitCode.INVALID_INPUT, {"path": str(path)},
            )
        provenance = report.get("execution_provenance")
        algorithms = provenance.get("algorithm_versions") if isinstance(provenance, dict) else None
        algorithm = algorithms.get("rng_streams") if isinstance(algorithms, dict) else None
        if algorithm != RNG_ALGORITHM:
            raise ToolError(
                "incompatible_experiment_rng",
                f"Experiment reports require {RNG_ALGORITHM}.", ExitCode.INVALID_INPUT,
            )
    documents = {}
    rows = []
    registry_payload = copy.deepcopy(context["registry_artifact"]["payload"])
    updated_entries = {
        entry["candidate"]["candidate_id"]: entry
        for entry in registry_payload["entries"]
    }
    for index, candidate_id in enumerate(context["config"]["candidate_ids"]):
        entry = context["entries"][candidate_id]
        # The temporary single-candidate collection reuses the existing evaluator.
        # Persist evidence against the original immutable creation artifact rather
        # than incorrectly binding it to this in-memory subset's checksum.
        evaluated = evaluate_fitness(_candidate_generation(entry), reports)
        payload = copy.deepcopy(evaluated["payload"])
        payload["source_generation_checksum"] = entry["creation_context"]["artifact_checksum"]
        fitness = create_artifact("fitness", payload)
        validate_fitness_payload(fitness["payload"])
        result = fitness["payload"]["candidate_results"][0]
        filename = f"candidate_{index:04d}_fitness.json"
        documents[filename] = fitness
        updated_entries[candidate_id]["evaluations"].append(evaluation_record(fitness, result))
        registry_payload["artifacts"].append({"checksum": fitness["checksum"], "type": "fitness"})
        rows.append({
            "candidate_id": candidate_id,
            "generation_id": entry["generation_id"],
            "generation": entry["generation"],
            "source_creation": copy.deepcopy(entry["creation_context"]),
            "fitness_path": filename,
            "fitness_checksum": fitness["checksum"],
            "result": copy.deepcopy(result),
            "rank": None,
        })
    rows.sort(key=lambda row: (
        not row["result"]["eligible"],
        -(row["result"]["fitness"] or 0),
        row["candidate_id"],
    ))
    for rank, row in enumerate((row for row in rows if row["result"]["eligible"]), 1):
        row["rank"] = rank
    registry_payload["artifacts"] = sorted(
        {item["checksum"]: item for item in registry_payload["artifacts"]}.values(),
        key=lambda item: item["checksum"],
    )
    registry = create_artifact("lineage_registry", registry_payload)
    validate_lineage_registry(registry)
    documents["evaluated_registry.json"] = registry
    comparison = create_artifact("experiment_comparison", {
        "experiment_id": context["config"]["experiment_id"],
        "source_registry_checksum": context["registry_artifact"]["checksum"],
        "evaluated_registry_checksum": registry["checksum"],
        "candidates": rows,
        "report_evidence": documents["candidate_0000_fitness.json"]["payload"]["report_evidence"],
        "review_required": True,
        "ranking_rule": (
            "eligible fitness descending, candidate ID ascending; "
            "ineligible candidates remain unranked"
        ),
    })
    publish_documents(output_dir.absolute(), documents, "comparison.json", comparison)
    return comparison
