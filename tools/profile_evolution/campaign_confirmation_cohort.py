"""Owned, resumable execution of one explicitly authorized confirmation cohort."""
from __future__ import annotations

import copy
import fcntl
import os
import signal
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any

from .artifacts import canonical_json_bytes, create_artifact, load_artifact, load_json_object, validate_artifact_envelope, write_artifact_atomic
from .atomic_write import publish_bytes_no_replace
from .campaign import schema_boundary, validate_campaign
from .campaign_comparison import validate_round_result
from .campaign_confirmation import POLICY_VERSION, build_confirmation_manifests
from .campaign_runner import COMPLETE_TYPE, START_TYPE, _digest, _event, _report, _safe
from .contracts import require_exact_fields, require_integer
from .errors import ExitCode, ToolError
from .fitness import _planned_tournaments, _simulation_manifest_checksum, _validate_manifest

PLAN_TYPE = "confirmation_cohort_plan_v1"
RUN_TYPE = "confirmation_cohort_run_v1"
READY_TYPE = "confirmation_cohort_readiness_v1"
JOB_RUN_TYPE = "confirmation_job_run_v1"
JOB_READY_TYPE = "confirmation_job_readiness_v1"


def _fail(message: str) -> None:
    raise ToolError("invalid_confirmation_cohort", message, ExitCode.INVALID_INPUT)


@schema_boundary
def prepare_confirmation_cohort(campaign: dict[str, Any], round1_result: dict[str, Any], round2_result: dict[str, Any]) -> dict[str, Any]:
    """Verify final selection once and freeze all forty independent job inputs."""
    context = validate_campaign(campaign)
    final = validate_round_result(round2_result, campaign, round1_result)
    if final["round_number"] != 2 or len(final["survivor_ids"]) != 20 or len(set(final["survivor_ids"])) != 20:
        _fail("Confirmation requires the twenty verified second-round finalists.")
    finalists = list(final["survivor_ids"])
    jobs = []
    for index, identifier in enumerate(finalists):
        manifests = build_confirmation_manifests(campaign, identifier)
        for mode in ("a", "b"):
            manifest = manifests[mode]
            count = manifest["evaluation_plans"][0]["tournament_count"]
            if count != 297:
                _fail("This cohort requires exactly 297 tournaments in each independent batch.")
            jobs.append({"job_id": f"candidate_{index:04d}_{mode}", "candidate_id": identifier,
                         "mode": mode, "manifest": manifest,
                         "manifest_checksum": _simulation_manifest_checksum(manifest), "tournament_count": count})
    return create_artifact(PLAN_TYPE, {"policy_version": POLICY_VERSION, "campaign_checksum": campaign["checksum"],
        "campaign": copy.deepcopy(campaign), "round1_result": copy.deepcopy(round1_result),
        "round2_result": copy.deepcopy(round2_result), "round2_result_checksum": round2_result["checksum"],
        "finalist_ids": finalists, "jobs": jobs, "job_count": 40, "tournament_count": 11880,
        "expected_provenance": copy.deepcopy(final["execution_provenance"]),
        "maximum_parallel_jobs": 4, "workers_per_job": 1})


def _validate_plan(plan: dict[str, Any]) -> dict[str, Any]:
    validate_artifact_envelope(plan, PLAN_TYPE)
    payload = plan["payload"]
    require_exact_fields(payload, ("policy_version", "campaign_checksum", "campaign", "round1_result", "round2_result",
                                 "round2_result_checksum", "finalist_ids", "jobs", "job_count", "tournament_count",
                                 "expected_provenance", "maximum_parallel_jobs", "workers_per_job"), "confirmation cohort plan")
    expected = prepare_confirmation_cohort(payload["campaign"], payload["round1_result"], payload["round2_result"])
    if plan != expected:
        _fail("Confirmation cohort differs from the verified final selection and frozen manifests.")
    return payload


def _authorization(plan: dict[str, Any], authorization: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(authorization, dict):
        _fail("An explicit confirmation-cohort policy authorization is required.")
    require_exact_fields(authorization, ("scope", "source", "authorized", "plan_checksum", "campaign_checksum", "policy_version"), "confirmation policy authorization")
    if authorization["scope"] != "confirmation_cohort" or authorization["source"] != "user_authorized_backlog" or authorization["authorized"] is not True:
        _fail("Confirmation requires explicit user-authorized backlog scope, not a competitive manifest approval.")
    if authorization["plan_checksum"] != plan["checksum"] or authorization["campaign_checksum"] != plan["payload"]["campaign_checksum"] or authorization["policy_version"] != POLICY_VERSION:
        _fail("Policy authorization does not bind this exact cohort, campaign and confirmation policy.")
    return copy.deepcopy(authorization)


def _job_audit(job: dict[str, Any]) -> dict[str, Any]:
    manifest = job["manifest"]
    context = _validate_manifest(manifest)
    profiles = list(context["profiles"].values())
    plan = next(iter(context["plans"].values()))
    table = next(iter(context["matchups"].values()))["profile_ids"]
    if len(profiles) != 9 or len(table) != 9 or len(set(table)) != 9 or any(p["model_id"] != "strategy_parameterized" for p in profiles) or len(context["matchups"]) != 1 or len(context["plans"]) != 1 or len(context["regimes"]) != 1:
        _fail("Every confirmation job must use one full table of nine strategic profiles.")
    if next(iter(context["regimes"].values()))["player_count"] != 9 or plan["tournament_count"] != 297:
        _fail("Confirmation policy requires nine starting seats and 297 tournaments per job.")
    return {"policy_version": POLICY_VERSION, "candidate_id": job["candidate_id"], "mode": job["mode"],
            "manifest_checksum": job["manifest_checksum"], "profile_count": 9, "matchup_count": 1,
            "tournament_count": 297, "minimum_samples_per_seat": 33}


def _validate_job_ready(directory: Path, job: dict[str, Any], ready: dict[str, Any], authorization: dict[str, Any], provenance: dict[str, Any]) -> dict[str, Any]:
    validate_artifact_envelope(ready, JOB_READY_TYPE)
    payload = ready["payload"]
    require_exact_fields(payload, ("run_checksum", "manifest_checksum", "manifest", "workers", "reports",
                                  "execution_provenance", "tournament_count", "schedule_audit"), "confirmation job readiness")
    if payload["manifest"] != job["manifest"] or payload["manifest_checksum"] != job["manifest_checksum"] or payload["workers"] != 1 or payload["execution_provenance"] != provenance or payload["tournament_count"] != 297 or payload["schedule_audit"] != _job_audit(job):
        _fail("A confirmation producer returned changed manifests, provenance, budgets or shard identity.")
    for path in (directory, directory / "run.json", directory / "readiness.json", directory / "manifest.json",
                 directory / "shard_0000.json", directory / "shard_0000.started.json", directory / "shard_0000.completed.json"):
        _safe(path)
    if load_artifact(directory / "readiness.json", JOB_READY_TYPE) != ready or load_json_object(directory / "manifest.json") != job["manifest"]:
        _fail("Confirmation readiness or its frozen manifest is missing or changed.")
    run = load_artifact(directory / "run.json", JOB_RUN_TYPE)
    require_exact_fields(run["payload"], ("manifest", "manifest_checksum", "workers", "godot", "expected_provenance", "policy_authorization"), "policy-authorized job run")
    if run["checksum"] != payload["run_checksum"] or run["payload"].get("policy_authorization") != authorization or run["payload"].get("manifest") != job["manifest"] or run["payload"].get("manifest_checksum") != job["manifest_checksum"] or run["payload"].get("workers") != 1 or run["payload"].get("expected_provenance") != provenance or "approval" in run["payload"]:
        _fail("Confirmation readiness lacks exact policy-authorized producer ownership.")
    if not isinstance(payload["reports"], list) or len(payload["reports"]) != 1:
        _fail("A confirmation job requires one successful single-worker report.")
    report_path = directory / "shard_0000.json"
    planned = _planned_tournaments(job["manifest"], _validate_manifest(job["manifest"]))
    evidence, actual = _report(report_path, job["manifest"], planned, 0, 1, provenance)
    if evidence != payload["reports"][0] or actual != provenance:
        _fail("Confirmation report differs from its completed producer receipt.")
    start = create_artifact(START_TYPE, {"run_checksum": run["checksum"], "shard": {"index": 0, "count": 1}})
    complete = create_artifact(COMPLETE_TYPE, {"run_checksum": run["checksum"], "exit_code": 0, "report": evidence})
    if load_artifact(directory / "shard_0000.started.json", START_TYPE) != start or load_artifact(directory / "shard_0000.completed.json", COMPLETE_TYPE) != complete:
        _fail("Confirmation report has no valid successful-producer receipts.")
    return {"job_id": job["job_id"], "candidate_id": job["candidate_id"], "mode": job["mode"],
            "manifest_checksum": job["manifest_checksum"], "readiness_path": str(directory / "readiness.json"),
            "readiness_checksum": ready["checksum"], "readiness_sha256": _digest(directory / "readiness.json"),
            "reports": copy.deepcopy(payload["reports"]), "tournament_count": 297}


def _run_job(job, context, authorization, godot, root, cancellation):
    from .campaign_runner import _execute_validated_manifest
    if cancellation.is_set():
        _fail("Confirmation cohort was cancelled before job launch.")
    manifest_path = root / "manifests" / f"{job['job_id']}.json"
    _safe(manifest_path)
    if manifest_path.exists():
        if load_json_object(manifest_path) != job["manifest"]:
            _fail("An existing confirmation input differs from its frozen plan.")
    else:
        publish_bytes_no_replace(manifest_path, canonical_json_bytes(job["manifest"]))
    directory = root / "jobs" / job["job_id"]
    ready = _execute_validated_manifest(manifest_path, job["manifest"], godot, directory,
        {"policy_authorization": authorization}, 1, context["expected_provenance"], _job_audit(job),
        run_type=JOB_RUN_TYPE, ready_type=JOB_READY_TYPE, cancel_event=cancellation)
    if cancellation.is_set():
        _fail("Confirmation cohort was cancelled before accepting producer output.")
    return _validate_job_ready(directory, job, ready, authorization, context["expected_provenance"])


@schema_boundary
def run_confirmation_cohort(plan: dict[str, Any], authorization: dict[str, Any], godot: str, output_dir: Path, workers: int = 4) -> dict[str, Any]:
    """Execute at most four single-worker Godot jobs; resume only owned outputs."""
    validate_artifact_envelope(plan, PLAN_TYPE)
    authorization = _authorization(plan, authorization)
    require_integer(workers, "parallel confirmation jobs", 1, 4)
    if not isinstance(godot, str) or not godot.strip():
        _fail("A Godot executable is required.")
    context = _validate_plan(plan)  # Expensive source selection is verified once per start/resume.
    root = Path(output_dir).absolute()
    _safe(root)
    run = create_artifact(RUN_TYPE, {"plan_checksum": plan["checksum"], "campaign_checksum": context["campaign_checksum"],
        "policy_version": POLICY_VERSION, "policy_authorization": authorization, "godot": godot,
        "expected_provenance": context["expected_provenance"], "maximum_parallel_jobs": 4})
    try:
        root.mkdir()
    except FileExistsError:
        _safe(root / "run.json")
        _safe(root / "plan.json")
        if load_artifact(root / "run.json", RUN_TYPE) != run or load_artifact(root / "plan.json", PLAN_TYPE) != plan:
            _fail("Existing confirmation output is not owned by this exact authorized cohort.")
    else:
        write_artifact_atomic(root / "run.json", run)
        write_artifact_atomic(root / "plan.json", plan)
    for child in (root / "jobs", root / "manifests"):
        _safe(child)
        child.mkdir(exist_ok=True)
    lock_path = root / "cohort.lock"
    _safe(lock_path)
    lock_descriptor = os.open(lock_path, os.O_CREAT | os.O_RDWR | getattr(os, "O_NOFOLLOW", 0), 0o600)
    try:
        fcntl.flock(lock_descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(lock_descriptor)
        _fail("Another process already owns this confirmation cohort run.")
    cancellation = threading.Event()
    old_signals = {}
    if threading.current_thread() is threading.main_thread():
        def interrupted(signum, frame):
            cancellation.set()
            raise KeyboardInterrupt(f"Confirmation cohort interrupted by signal {signum}.")
        for signum in (signal.SIGINT, signal.SIGTERM):
            old_signals[signum] = signal.getsignal(signum)
            signal.signal(signum, interrupted)
    pool = None
    futures = []
    receipts = {}
    try:
        pool = ThreadPoolExecutor(max_workers=workers, thread_name_prefix="confirmation-job")
        _event("confirmation_cohort_started", plan_checksum=plan["checksum"], total_jobs=40,
               total_tournaments=11880, parallel_jobs=workers, workers_per_job=1)
        futures = [pool.submit(_run_job, job, context, authorization, godot, root, cancellation) for job in context["jobs"]]
        for future in as_completed(futures):
            receipt = future.result()
            receipts[receipt["job_id"]] = receipt
            _event("confirmation_job_completed", job_id=receipt["job_id"], candidate_id=receipt["candidate_id"], mode=receipt["mode"],
                   completed_jobs=len(receipts), total_jobs=40, completed_tournaments=len(receipts) * 297)
        if cancellation.is_set() or len(receipts) != 40:
            _fail("The full confirmation cohort did not complete successfully.")
        for receipt in receipts.values():
            readiness_path = Path(receipt["readiness_path"])
            _safe(readiness_path)
            if not readiness_path.is_file() or _digest(readiness_path) != receipt["readiness_sha256"]:
                _fail("A completed job readiness marker changed before cohort publication.")
            for evidence in receipt["reports"]:
                path = Path(evidence["path"])
                _safe(path)
                if not path.is_file() or _digest(path) != evidence["sha256"]:
                    _fail("A completed producer report is missing or changed before cohort publication.")
        ready = create_artifact(READY_TYPE, {"plan_checksum": plan["checksum"], "campaign_checksum": context["campaign_checksum"],
            "run_checksum": run["checksum"], "policy_version": POLICY_VERSION,
            "execution_provenance": context["expected_provenance"], "finalist_ids": context["finalist_ids"],
            "jobs": [receipts[job["job_id"]] for job in context["jobs"]], "job_count": 40, "tournament_count": 11880})
        destination = root / "readiness.json"
        _safe(destination)
        if destination.exists():
            if load_artifact(destination, READY_TYPE) != ready:
                _fail("Existing cohort readiness differs from verified producer outputs.")
        else:
            write_artifact_atomic(destination, ready)
        _event("confirmation_cohort_ready", completed_jobs=40, total_tournaments=11880, readiness=str(destination))
        return ready
    except BaseException:
        cancellation.set()
        for future in futures:
            future.cancel()
        # Cleanup must survive repeated interruption while each shared executor
        # terminates and reaps its own Godot children.
        for signum in old_signals:
            signal.signal(signum, signal.SIG_IGN)
        raise
    finally:
        if pool is not None:
            pool.shutdown(wait=True, cancel_futures=True)
        os.close(lock_descriptor)
        for signum, handler in old_signals.items():
            signal.signal(signum, handler)
