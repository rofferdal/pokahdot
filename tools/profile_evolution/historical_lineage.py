"""Import immutable pre-provenance lineage as archival identity evidence only.

Historical scores never become current evaluations or RNG attestations. Every
entry and retained-champion claim is reconstructed from embedded originals.
"""

from __future__ import annotations

import copy
import hashlib
import math
from pathlib import Path
from typing import Any, Iterable

from .artifacts import canonical_json_bytes, create_artifact, load_artifact, validate_artifact_envelope
from .contracts import GENES, require_exact_fields, require_integer, validate_candidate, validate_candidate_collection, validate_report_seed_range
from .errors import ExitCode, ToolError
from .fitness import COMPONENTS
from .lineage import EVALUATION_FIELDS, _entry_from_collection
from .selection import CANDIDATE_RESULT_FIELDS, FITNESS_PAYLOAD_FIELDS, REPORT_EVIDENCE_FIELDS

POLICY = "historical_lineage_v1"
DISCLAIMER = "archival_only_execution_provenance_unavailable"


def _fail(message: str) -> None:
    raise ToolError("invalid_historical_lineage", message, ExitCode.INVALID_INPUT)


def _object(value: Any, context: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(f"{context} must be an object.")
    return value


def _finite(value: Any, context: str, maximum: float = 1.0) -> None:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not 0 <= value <= maximum:
        _fail(f"{context} must be finite and in 0..{maximum}.")


def _digest(value: Any) -> None:
    if not isinstance(value, str) or len(value) != 64 or any(c not in "0123456789abcdef" for c in value):
        _fail("Invalid original evidence checksum.")


def _historical_fitness(payload: dict[str, Any], entries: dict[str, Any], originals: dict[str, Any]) -> None:
    require_exact_fields(payload, FITNESS_PAYLOAD_FIELDS, "historical fitness")
    source = originals.get(payload["source_generation_checksum"])
    if source is None or source["type"] != "generation_manifest":
        _fail("Historical fitness requires its original generation.")
    generation = source["payload"]
    for field in ("bounds", "generation", "generation_id"):
        if payload[field] != generation[field]:
            _fail(f"Historical fitness contradicts source {field}.")
    if not isinstance(payload["report_evidence"], list) or not payload["report_evidence"]:
        _fail("Historical fitness must contain report evidence.")
    for evidence in payload["report_evidence"]:
        evidence = _object(evidence, "historical report evidence")
        require_exact_fields(evidence, set(REPORT_EVIDENCE_FIELDS) - {"execution_provenance"}, "historical report evidence")
        for field in ("batch_id", "code_revision", "command_version"):
            if not isinstance(evidence[field], str):
                _fail("Historical report metadata must contain strings.")
        for field in ("manifest_checksum", "report_checksum"):
            _digest(evidence[field])
        validate_report_seed_range(evidence["seed_range"], "historical seed range")
        shard = _object(evidence["shard"], "historical shard")
        require_exact_fields(shard, ("index", "count"), "historical shard")
        count = require_integer(shard["count"], "shard count", 1, 2**31 - 1)
        require_integer(shard["index"], "shard index", 0, count - 1)
    if not isinstance(payload["candidate_results"], list) or not payload["candidate_results"]:
        _fail("Historical fitness must contain candidate results.")
    result_ids = []
    for result in payload["candidate_results"]:
        result = _object(result, "historical candidate result")
        require_exact_fields(result, set(CANDIDATE_RESULT_FIELDS) - {"point_fitness"}, "historical result")
        candidate = validate_candidate(result["candidate"])
        cid = candidate["candidate_id"]
        result_ids.append(cid)
        if cid not in entries or candidate != entries[cid]["candidate"] or entries[cid]["creation_context"]["artifact_checksum"] != source["checksum"]:
            _fail("Historical result contradicts original candidate creation.")
        for field in ("component_means", "uncertainty_95_half_width"):
            values = _object(result[field], field)
            require_exact_fields(values, COMPONENTS, field)
            for value in values.values():
                if value is not None or field == "component_means":
                    _finite(value, field)
        _finite(result["uncertainty_penalty"], "uncertainty penalty", 0.1)
        if not isinstance(result["eligible"], bool):
            _fail("Historical eligibility must be boolean.")
        if result["eligible"]:
            _finite(result["fitness"], "historical fitness")
            if result["ineligibility_reasons"] != []:
                _fail("Eligible historical result has failure reasons.")
        elif result["fitness"] is not None or not result["ineligibility_reasons"]:
            _fail("Ineligible historical result must have null fitness and reasons.")
        count = require_integer(result["sample_count"], "sample count", 0, 2**31 - 1)
        counts = _object(result["plan_sample_counts"], "plan samples")
        require_exact_fields(counts, payload["plan_ids"], "historical plan samples")
        if sum(require_integer(v, "plan count", 0, 2**31 - 1) for v in counts.values()) != count:
            _fail("Historical sample counts do not reconcile.")
    if len(set(result_ids)) != len(result_ids) or set(result_ids) != {c["candidate_id"] for c in generation["candidates"]}:
        _fail("Historical results must cover each source candidate exactly once.")


def _reconstruct(registry: dict[str, Any], sources: list[dict[str, Any]]) -> dict[str, Any]:
    validate_artifact_envelope(registry, "lineage_registry")
    require_exact_fields(registry["payload"], ("artifacts", "entries"), "historical registry")
    originals: dict[str, Any] = {}
    for source in sources:
        validate_artifact_envelope(source)
        checksum = source["checksum"]
        if checksum in originals:
            _fail("Duplicate original artifact.")
        if source["type"] not in ("generation_manifest", "candidate_batch", "fitness", "selection"):
            _fail("Unsupported original artifact type.")
        originals[checksum] = source
    catalog = [{"checksum": checksum, "type": originals[checksum]["type"]} for checksum in sorted(originals)]
    if catalog != registry["payload"]["artifacts"]:
        _fail("Original artifacts must exactly match the registry catalog.")
    entries: dict[str, Any] = {}
    for checksum in sorted(originals):
        source = originals[checksum]
        if source["type"] not in ("generation_manifest", "candidate_batch"):
            continue
        collection = validate_candidate_collection(source["payload"])
        for candidate, creation in zip(collection["candidates"], collection["creation_records"]):
            cid = candidate["candidate_id"]
            entry = _entry_from_collection(source, collection, candidate, creation)
            if cid in entries and entries[cid] != entry:
                _fail("Conflicting candidate creation history.")
            entries[cid] = entry
    for entry in entries.values():
        operation = entry["creation"]["operation"]
        parents = entry["candidate"]["parent_ids"]
        expected_count = {"initialization": 0, "crossover": 2, "mutation": 1}[operation]
        if len(parents) != expected_count:
            _fail("Historical creation has the wrong parent count.")
        for parent in parents:
            if parent not in entries:
                _fail("Dangling historical parent.")
            parent_generation = entries[parent]["generation"]
            invalid = parent_generation >= entry["generation"] if entry["creation"]["operation"] == "crossover" else parent_generation != entry["generation"]
            if invalid:
                _fail("Historical parent generation contradicts creation operation.")
        if operation == "crossover":
            for gene in GENES:
                parent = entry["creation"]["gene_sources"][gene]
                if entry["candidate"]["parameters"][gene] != entries[parent]["candidate"]["parameters"][gene]:
                    _fail("Historical crossover gene contradicts its recorded source parent.")
        elif operation == "mutation":
            original = entries[parents[0]]["candidate"]["parameters"]
            if any(mutation["before"] != original[mutation["gene"]] for mutation in entry["creation"]["mutations"]):
                _fail("Historical mutation before-values contradict its source parent.")
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(cid: str) -> None:
        if cid in visiting:
            _fail("Historical ancestry contains a cycle.")
        if cid in visited:
            return
        visiting.add(cid)
        for parent in entries[cid]["candidate"]["parent_ids"]:
            visit(parent)
        visiting.remove(cid)
        visited.add(cid)

    for cid in entries:
        visit(cid)
    for checksum in sorted(originals):
        source = originals[checksum]
        if source["type"] != "fitness":
            continue
        fitness = source["payload"]
        _historical_fitness(fitness, entries, originals)
        for result in fitness["candidate_results"]:
            evaluation = {field: copy.deepcopy(result[field] if field in result else fitness[field]) for field in EVALUATION_FIELDS if field not in ("fitness_artifact_checksum", "point_fitness")}
            evaluation["fitness_artifact_checksum"] = checksum
            entries[result["candidate"]["candidate_id"]]["evaluations"].append(evaluation)
    for checksum in sorted(originals):
        source = originals[checksum]
        if source["type"] != "selection":
            continue
        selection = source["payload"]
        require_exact_fields(selection, ("bounds", "elite_fraction", "generation", "generation_id", "historical_benchmarks", "next_generation_manifest", "population_size", "report_evidence", "retained_count", "selected_candidates", "source_fitness_checksum"), "historical selection")
        fitness_source = originals.get(selection["source_fitness_checksum"])
        if fitness_source is None or fitness_source["type"] != "fitness":
            _fail("Historical selection lacks original fitness.")
        fitness = fitness_source["payload"]
        fraction = selection["elite_fraction"]
        _finite(fraction, "elite fraction", 0.2)
        if fraction < 0.1:
            _fail("Historical elite fraction is below 0.1.")
        population = len(fitness["candidate_results"])
        count = math.ceil(population * fraction)
        ranked = sorted((r for r in fitness["candidate_results"] if r["eligible"]), key=lambda r: (-r["fitness"], r["candidate"]["candidate_id"]))
        if count < 2 or len(ranked) < count:
            _fail("Historical selection lacks enough eligible parents.")
        selected = ranked[:count]
        identity = {"elite_fraction": fraction, "selected_candidate_ids": [r["candidate"]["candidate_id"] for r in selected], "source_fitness_checksum": fitness_source["checksum"]}
        digest = hashlib.sha256(canonical_json_bytes(identity)).hexdigest()[:16]
        expected = {"bounds": fitness["bounds"], "elite_fraction": fraction, "generation": fitness["generation"], "generation_id": fitness["generation_id"], "historical_benchmarks": selected, "next_generation_manifest": {"generation": fitness["generation"] + 1, "generation_id": f"generation_g{fitness['generation'] + 1}_selection_{digest}"}, "population_size": population, "report_evidence": fitness["report_evidence"], "retained_count": count, "selected_candidates": [r["candidate"] for r in selected], "source_fitness_checksum": fitness_source["checksum"]}
        if selection != expected:
            _fail("Historical champion selection contradicts original fitness ranking.")
        for index, benchmark in enumerate(selected):
            entries[benchmark["candidate"]["candidate_id"]]["selection_history"].append({"benchmark": copy.deepcopy(benchmark), "elite_fraction": fraction, "next_generation_manifest": copy.deepcopy(selection["next_generation_manifest"]), "retained_index": index, "selection_artifact_checksum": checksum, "source_fitness_checksum": fitness_source["checksum"]})
    ordered = []
    for cid in sorted(entries):
        entry = entries[cid]
        entry["evaluations"].sort(key=lambda e: e["fitness_artifact_checksum"])
        entry["selection_history"].sort(key=lambda h: (h["selection_artifact_checksum"], h["retained_index"]))
        ordered.append(entry)
    if registry["payload"]["entries"] != ordered:
        _fail("Historical registry claims differ from reconstructed original history.")
    return entries


def _validated_reconstruction(registry: dict[str, Any], originals: list[dict[str, Any]]) -> dict[str, Any]:
    try:
        return _reconstruct(registry, originals)
    except (KeyError, TypeError, ValueError, RecursionError) as error:
        _fail(f"Malformed historical source data: {type(error).__name__}.")


def import_historical_lineage(registry_path: Path, artifact_paths: Iterable[Path]) -> dict[str, Any]:
    """Embed and verify original history without upgrading historical scores."""
    registry = load_artifact(registry_path, "lineage_registry")
    sources = [load_artifact(path) for path in artifact_paths]
    _validated_reconstruction(registry, sources)
    return create_artifact(POLICY, {"evidence_status": DISCLAIMER, "source_registry": registry, "original_artifacts": sorted(sources, key=lambda a: a["checksum"])})


def validate_historical_lineage(artifact: dict[str, Any]) -> dict[str, Any]:
    """Return archival identity/selection context; current evaluations stay empty."""
    validate_artifact_envelope(artifact, POLICY)
    payload = artifact["payload"]
    require_exact_fields(payload, ("evidence_status", "source_registry", "original_artifacts"), POLICY)
    if payload["evidence_status"] != DISCLAIMER or not isinstance(payload["original_artifacts"], list):
        _fail("Historical evidence status or originals are invalid.")
    originals = payload["original_artifacts"]
    for original in originals:
        validate_artifact_envelope(original)
    if originals != sorted(originals, key=lambda a: a["checksum"]):
        _fail("Historical originals must be in canonical checksum order.")
    reconstructed = _validated_reconstruction(payload["source_registry"], originals)
    return {"entries": {cid: {"candidate": copy.deepcopy(entry["candidate"]), "original_creation": {"bounds": copy.deepcopy(entry["bounds"]), "creation": copy.deepcopy(entry["creation"]), "creation_context": copy.deepcopy(entry["creation_context"]), "generation": entry["generation"], "generation_id": entry["generation_id"]}, "historical_selection": copy.deepcopy(entry["selection_history"]), "historical_evaluations": copy.deepcopy(entry["evaluations"]), "evaluations": [], "evidence_status": DISCLAIMER} for cid, entry in reconstructed.items()}, "original_artifacts": copy.deepcopy(originals), "source_registry_checksum": payload["source_registry"]["checksum"], "execution_provenance": None}
