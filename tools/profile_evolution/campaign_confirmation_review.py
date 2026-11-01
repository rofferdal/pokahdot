"""Postprocess a complete confirmation cohort into one pending human review."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
from typing import Any

from .artifacts import create_artifact, load_artifact, load_json_object, validate_artifact_envelope
from .campaign import PROTECTED_CONTROL_IDS, schema_boundary
from .campaign_confirmation import POLICY_VERSION, confirm_nine_player
from .campaign_confirmation_cohort import (
    JOB_READY_TYPE, JOB_RUN_TYPE, READY_TYPE, RUN_TYPE, PLAN_TYPE,
    _authorization, _job_audit, _validate_job_ready, _validate_plan,
)
from .campaign_runner import COMPLETE_TYPE, START_TYPE, _digest, _safe, _io_boundary
from .contracts import require_exact_fields, require_identifier, require_integer
from .errors import ExitCode, ToolError
from .experiment_output import publish_documents
from .promotion_review import create_promotion_review_plan, validate_promotion_review_plan

SUMMARY_TYPE = "confirmation_review_readiness_v1"
RECEIPT_FIELDS = ("job_id", "candidate_id", "mode", "manifest_checksum", "readiness_path",
                  "readiness_checksum", "readiness_sha256", "reports", "tournament_count")
COHORT_FIELDS = ("plan_checksum", "campaign_checksum", "run_checksum", "policy_version",
                 "execution_provenance", "finalist_ids", "jobs", "job_count", "tournament_count")


def _fail(message: str) -> None:
    raise ToolError("invalid_confirmation_review", message, ExitCode.INVALID_INPUT)


def _file(path: Path) -> None:
    _safe(path)
    if not path.is_file():
        _fail(f"Required completed-producer file is missing: {path}")


def _job_receipts(root: Path, job: dict[str, Any], receipt: dict[str, Any], authorization: dict[str, Any], provenance: dict[str, Any]) -> dict[str, Any]:
    """Check successful ownership receipts before any raw report is consumed."""
    require_exact_fields(receipt, RECEIPT_FIELDS, "completed confirmation job")
    for field in ("job_id", "candidate_id", "mode", "manifest_checksum", "tournament_count"):
        if receipt[field] != job[field]:
            _fail("Cohort job receipt differs from its frozen plan.")
    directory = root / "jobs" / job["job_id"]
    _safe(root / "jobs")
    _safe(directory)
    ready_path = directory / "readiness.json"
    if receipt["readiness_path"] != str(ready_path):
        _fail("A job readiness path escapes its owned cohort directory.")
    for name in ("run.json", "manifest.json", "readiness.json", "shard_0000.started.json", "shard_0000.completed.json"):
        _file(directory / name)
    if _digest(ready_path) != receipt["readiness_sha256"]:
        _fail("Job readiness bytes changed after cohort completion.")
    ready = load_artifact(ready_path, JOB_READY_TYPE)
    require_exact_fields(ready["payload"], ("run_checksum", "manifest_checksum", "manifest", "workers", "reports",
                                           "execution_provenance", "tournament_count", "schedule_audit"), "job readiness")
    require_integer(ready["payload"]["workers"], "job workers", 1, 1)
    require_integer(ready["payload"]["tournament_count"], "job tournament count", 297, 297)
    if ready["payload"]["manifest"] != job["manifest"] or ready["payload"]["manifest_checksum"] != job["manifest_checksum"] or ready["payload"]["execution_provenance"] != provenance or ready["payload"]["schedule_audit"] != _job_audit(job):
        _fail("Job readiness metadata contradicts its frozen cohort plan.")
    if ready["checksum"] != receipt["readiness_checksum"]:
        _fail("Job readiness checksum differs from the cohort receipt.")
    run = load_artifact(directory / "run.json", JOB_RUN_TYPE)
    require_exact_fields(run["payload"], ("manifest", "manifest_checksum", "workers", "godot", "expected_provenance", "policy_authorization"), "job producer run")
    require_integer(run["payload"]["workers"], "job run workers", 1, 1)
    if run["checksum"] != ready["payload"]["run_checksum"] or run["payload"]["manifest"] != job["manifest"] or run["payload"]["manifest_checksum"] != job["manifest_checksum"] or run["payload"]["policy_authorization"] != authorization or run["payload"]["expected_provenance"] != provenance or not isinstance(run["payload"]["godot"], str) or not run["payload"]["godot"].strip():
        _fail("A job lacks the exact policy-authorized producer run.")
    reports = receipt["reports"]
    if not isinstance(reports, list) or len(reports) != 1:
        _fail("Each completed confirmation job requires exactly one report receipt.")
    if ready["payload"]["reports"] != reports:
        _fail("Job readiness reports differ from the completed cohort receipt.")
    evidence = reports[0]
    require_exact_fields(evidence, ("path", "sha256", "shard", "tournament_count"), "confirmation report receipt")
    report_path = directory / "shard_0000.json"
    if evidence["path"] != str(report_path) or evidence["shard"] != {"index": 0, "count": 1} or evidence["tournament_count"] != 297:
        _fail("Confirmation report path, shard or sample count differs from its producer.")
    start = create_artifact(START_TYPE, {"run_checksum": run["checksum"], "shard": evidence["shard"]})
    complete = create_artifact(COMPLETE_TYPE, {"run_checksum": run["checksum"], "exit_code": 0, "report": evidence})
    if load_artifact(directory / "shard_0000.started.json", START_TYPE) != start or load_artifact(directory / "shard_0000.completed.json", COMPLETE_TYPE) != complete:
        _fail("A confirmation report has no exact successful-producer receipt.")
    _file(report_path)
    if _digest(report_path) != evidence["sha256"]:
        _fail("Confirmation report bytes differ from the successful producer receipt.")
    return ready


def _cohort(plan: dict[str, Any], cohort_readiness: dict[str, Any]) -> tuple[dict[str, Any], Path, dict[str, Any]]:
    validate_artifact_envelope(cohort_readiness, READY_TYPE)
    p = cohort_readiness["payload"]
    require_exact_fields(p, COHORT_FIELDS, "complete confirmation cohort")
    # A readiness artifact is mandatory before plan validation or report access.
    require_integer(p["job_count"], "cohort job count", 40, 40)
    require_integer(p["tournament_count"], "cohort tournament count", 11880, 11880)
    if p["job_count"] != 40 or p["tournament_count"] != 11880 or not isinstance(p["jobs"], list) or len(p["jobs"]) != 40:
        _fail("A complete forty-job confirmation cohort readiness marker is required.")
    context = _validate_plan(plan)
    for field, expected in (("plan_checksum", plan["checksum"]), ("campaign_checksum", context["campaign_checksum"]),
                            ("policy_version", POLICY_VERSION), ("execution_provenance", context["expected_provenance"]),
                            ("finalist_ids", context["finalist_ids"])):
        if p[field] != expected:
            _fail("Confirmation readiness differs from its frozen final selection.")
    finalists = context["finalist_ids"]
    protected = {profile["profile_id"] for profile in context["campaign"]["payload"]["inventory"]["fixed_controls"]}
    if len(finalists) != 20 or len(set(finalists)) != 20 or protected != PROTECTED_CONTROL_IDS or set(finalists) & protected:
        _fail("Twenty unique finalists must remain separate from all five protected controls.")
    planned_jobs = context["jobs"]
    if len(planned_jobs) != 40 or len({job["job_id"] for job in planned_jobs}) != 40 or {(job["candidate_id"], job["mode"]) for job in planned_jobs} != {(identifier, mode) for identifier in finalists for mode in ("a", "b")}:
        _fail("The frozen plan must contain exactly one independent a/b job per finalist.")
    first_path = Path(p["jobs"][0]["readiness_path"])
    if not first_path.is_absolute():
        _fail("Cohort readiness paths must be absolute owned-producer paths.")
    root = first_path.parents[2]
    _safe(root)
    for name in ("run.json", "plan.json", "readiness.json"):
        _file(root / name)
    if load_artifact(root / "plan.json", PLAN_TYPE) != plan or load_artifact(root / "readiness.json", READY_TYPE) != cohort_readiness:
        _fail("The frozen cohort plan or complete readiness marker changed on disk.")
    run = load_artifact(root / "run.json", RUN_TYPE)
    require_exact_fields(run["payload"], ("plan_checksum", "campaign_checksum", "policy_version", "policy_authorization",
                                          "godot", "expected_provenance", "maximum_parallel_jobs"), "confirmation cohort run")
    expected_run = {"plan_checksum": plan["checksum"], "campaign_checksum": context["campaign_checksum"],
                    "policy_version": POLICY_VERSION, "policy_authorization": _authorization(plan, run["payload"]["policy_authorization"]),
                    "godot": run["payload"]["godot"], "expected_provenance": context["expected_provenance"], "maximum_parallel_jobs": 4}
    if run["payload"] != expected_run or run["checksum"] != p["run_checksum"] or not isinstance(expected_run["godot"], str) or not expected_run["godot"].strip():
        _fail("Cohort readiness has no exact authorized producer run.")
    by_id = {}
    for receipt in p["jobs"]:
        require_exact_fields(receipt, RECEIPT_FIELDS, "completed confirmation job")
        if receipt["job_id"] in by_id:
            _fail("A confirmation job receipt occurs more than once.")
        by_id[receipt["job_id"]] = receipt
    if set(by_id) != {job["job_id"] for job in context["jobs"]}:
        _fail("Cohort readiness does not contain exactly the frozen forty jobs.")
    ready_by_id = {}
    for job in context["jobs"]:
        ready_by_id[job["job_id"]] = _job_receipts(root, job, by_id[job["job_id"]], run["payload"]["policy_authorization"], context["expected_provenance"])
    # All success receipts now exist and match. Strict raw-report validation may
    # proceed, with the shared cohort validator recomputing ownership/evidence.
    for job in context["jobs"]:
        actual = _validate_job_ready(root / "jobs" / job["job_id"], job, ready_by_id[job["job_id"]],
                                     run["payload"]["policy_authorization"], context["expected_provenance"])
        if actual != by_id[job["job_id"]]:
            _fail("A job receipt differs from independently validated producer evidence.")
    return context, root, by_id


@schema_boundary
@_io_boundary
def prepare_confirmation_review(plan: dict[str, Any], cohort_readiness: dict[str, Any], output_dir: Path, reviewer_id: str) -> dict[str, Any]:
    """Write twenty confirmations and one pending consolidated review atomically."""
    reviewer = require_identifier(reviewer_id, "reviewer_id")
    context, root, receipts = _cohort(plan, cohort_readiness)
    campaign = context["campaign"]
    rows = {row["candidate_id"]: row for row in campaign["payload"]["contenders"]}
    jobs = {(job["candidate_id"], job["mode"]): job for job in context["jobs"]}
    if len(jobs) != 40 or set(jobs) != {(identifier, mode) for identifier in context["finalist_ids"] for mode in ("a", "b")}:
        _fail("The frozen cohort must contain exactly one a/b job for every finalist.")
    documents, confirmations, summaries, proposed = {}, [], [], []
    for index, identifier in enumerate(context["finalist_ids"]):
        evidence = {mode: receipts[jobs[(identifier, mode)]["job_id"]]["reports"][0] for mode in ("a", "b")}
        confirmation = confirm_nine_player(campaign, identifier, [Path(evidence["a"]["path"])], [Path(evidence["b"]["path"])])
        for mode in ("a", "b"):
            texts = confirmation["payload"]["report_documents"][mode]
            if len(texts) != 1 or hashlib.sha256(texts[0].encode("utf-8")).hexdigest() != evidence[mode]["sha256"] or _digest(Path(evidence[mode]["path"])) != evidence[mode]["sha256"]:
                _fail("Embedded confirmation report bytes do not bind the completed producer receipt.")
        filename = f"confirmation_{index:04d}.json"
        documents[filename] = confirmation
        confirmations.append(confirmation)
        result = confirmation["payload"]["confirmation"]
        summaries.append({"candidate_id": identifier, "confirmation_path": filename, "confirmation_checksum": confirmation["checksum"],
                          "promotion_eligible": result["promotion_eligible"], "ineligibility_reasons": copy.deepcopy(result["ineligibility_reasons"])})
        row = rows[identifier]
        proposed.append({"candidate_id": identifier, "evaluated_profile_id": row["profile"]["profile_id"],
                         "display_name": row["display_name"], "profile_snapshot": copy.deepcopy(row["profile"]),
                         "original_creation_checksum": row["creation_checksum"]})
    review = create_promotion_review_plan(confirmations, reviewer)
    for entry in review["candidates"]:
        entry["display_name"] = rows[entry["candidate"]["candidate_id"]]["display_name"]
        if entry["decision"] != "pending":
            _fail("Automatic postprocessing must never make a human promotion decision.")
    validate_promotion_review_plan(review, require_complete=False)
    documents["promotion_review_plan.json"] = review
    pretty_review = (json.dumps(review, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8")
    # Recheck byte-bound producers immediately before publishing the review set.
    if load_artifact(root / "readiness.json", READY_TYPE) != cohort_readiness:
        _fail("Cohort readiness changed during postprocessing.")
    if load_artifact(root / "plan.json", PLAN_TYPE) != plan:
        _fail("The frozen cohort plan changed during postprocessing.")
    run = load_artifact(root / "run.json", RUN_TYPE)
    if run["checksum"] != cohort_readiness["payload"]["run_checksum"]:
        _fail("The cohort producer ownership changed during postprocessing.")
    for job in context["jobs"]:
        _job_receipts(root, job, receipts[job["job_id"]], run["payload"]["policy_authorization"], context["expected_provenance"])
    eligible = sum(item["promotion_eligible"] for item in summaries)
    summary = create_artifact(SUMMARY_TYPE, {"plan_checksum": plan["checksum"], "cohort_readiness_checksum": cohort_readiness["checksum"],
        "cohort_readiness_path": str(root / "readiness.json"), "campaign_checksum": campaign["checksum"], "policy_version": POLICY_VERSION,
        "reviewer_id": reviewer, "confirmation_count": 20, "job_count": 40, "tournament_count": 11880,
        "eligible_count": eligible, "ineligible_count": 20 - eligible, "confirmations": summaries,
        "promotion_review_plan": {"path": "promotion_review_plan.json", "sha256": hashlib.sha256(pretty_review).hexdigest(), "decision_status": "all_pending"},
        "proposed_profiles": proposed, "protected_strategic_controls": copy.deepcopy(campaign["payload"]["inventory"]["fixed_controls"]),
        "publication_authorized": False})
    publish_documents(Path(output_dir).absolute(), documents, "summary.json", summary, pretty_names={"promotion_review_plan.json"})
    return summary
