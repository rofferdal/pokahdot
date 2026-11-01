"""Approved, resumable orchestration of the existing Godot simulation CLI."""
from __future__ import annotations

import copy
import fcntl
from functools import wraps
import hashlib
import json
import math
import re
import os
from pathlib import Path
import shutil
import signal
import threading
import subprocess
import time
from typing import Any
import uuid

from .artifacts import canonical_json_bytes, create_artifact, load_artifact, load_json_object, write_artifact_atomic
from .campaign import schema_boundary
from .campaign_schedule import audit_manifest
from .contracts import require_exact_fields, require_identifier, require_integer
from .errors import ExitCode, ToolError
from .fitness import (
    REPORT_FIELDS, TOURNAMENT_FIELDS, _competition_positions_are_valid,
    _normalize_report_integers, _planned_tournaments, _roster_provenance,
    _simulation_manifest_checksum, _validate_execution_provenance,
    _validate_manifest, _validate_profile_result,
)

ROOT = Path(__file__).resolve().parents[2]
LOG_ROOT = ROOT / "localtmp" / "campaign_runner"
RUN_TYPE = "campaign_run_v1"
READY_TYPE = "campaign_run_readiness_v1"
START_TYPE = "campaign_shard_start_v1"
COMPLETE_TYPE = "campaign_shard_complete_v1"
TRACE = {"mode": 0, "max_entries_per_tournament": 0}
PROGRESS_INTERVAL_SECONDS = 5
_EVENT_LOCK = threading.Lock()
PROGRESS_LINE = re.compile(r"Completed (\d+)/(\d+) \| elapsed ([0-9.]+)s \| throughput ([0-9.]+) tournaments/s")


def _fail(code: str, message: str, details: dict[str, Any] | None = None) -> None:
    raise ToolError(code, message, ExitCode.INVALID_INPUT, details)


def _io_boundary(function):
    @wraps(function)
    def checked(*args, **kwargs):
        try:
            return function(*args, **kwargs)
        except OSError as error:
            raise ToolError("campaign_runner_io_failed", str(error), ExitCode.IO_FAILURE) from error
    return checked


def _event(event: str, **values: Any) -> None:
    line = json.dumps({"event": event, **values}, sort_keys=True)
    with _EVENT_LOCK:
        print(line, flush=True)


def _check_cancelled(cancel_event: threading.Event | None) -> None:
    if cancel_event is not None and cancel_event.is_set():
        _fail("campaign_run_interrupted", "Campaign job cancelled; owned checkpoints are preserved.")


def _digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _worker_progress(path: Path, assigned: int) -> dict[str, Any]:
    """Read only the bounded tail of the unchanged CLI's progress stream."""
    with path.open("rb") as stream:
        stream.seek(0, os.SEEK_END)
        stream.seek(max(0, stream.tell() - 4096))
        lines = stream.read(4096).decode("utf-8", errors="replace").splitlines()
    result = {"completed": 0, "assigned": assigned, "elapsed_seconds": None,
              "tournaments_per_second": None, "remaining_seconds": None,
              "latest_progress_line": ""}
    for line in reversed(lines):
        match = PROGRESS_LINE.fullmatch(line)
        if match is None:
            continue
        completed, total = int(match[1]), int(match[2])
        elapsed, rate = float(match[3]), float(match[4])
        if total != assigned or not 0 <= completed <= assigned or not math.isfinite(elapsed) or not math.isfinite(rate):
            continue
        result.update(completed=completed, elapsed_seconds=elapsed, tournaments_per_second=rate,
                      remaining_seconds=round((assigned - completed) / rate, 3) if rate > 0 else None,
                      latest_progress_line=line)
        break
    return result


def _safe(path: Path) -> None:
    if path.is_symlink():
        _fail("unsafe_campaign_path", "Campaign outputs cannot be symbolic links.", {"path": str(path)})


def _provenance(value: Any) -> dict[str, Any]:
    result = _validate_execution_provenance(value)
    if result["algorithm_versions"]["rng_streams"] != "named_stream_sha256_v2":
        _fail("campaign_provenance_mismatch", "Campaign execution requires current named-stream RNG provenance.")
    return result


def _checkpoint(path: Path, checksum: str, shard: int, workers: int,
                reference: dict[str, Any] | None) -> dict[str, Any]:
    """Validate ownership-bound header identity; the engine validates records."""
    _safe(path)
    header_path = path / "header.json"
    _safe(header_path)
    if not header_path.is_file():
        _fail("invalid_campaign_checkpoint", "Existing checkpoint has no complete header.", {"path": str(path)})
    header = load_json_object(header_path)
    require_exact_fields(header, ("checkpoint_schema_version", "identity", "identity_checksum", "started_at"), "checkpoint header")
    require_integer(header["checkpoint_schema_version"], "checkpoint schema", 1, 1)
    identity = header["identity"]
    require_exact_fields(identity, ("manifest_checksum", "execution_provenance", "shard", "trace"), "checkpoint identity")
    require_exact_fields(identity["shard"], ("index", "count"), "checkpoint shard")
    require_integer(identity["shard"]["index"], "checkpoint shard index", shard, shard)
    require_integer(identity["shard"]["count"], "checkpoint shard count", workers, workers)
    require_exact_fields(identity["trace"], ("mode", "max_entries_per_tournament"), "checkpoint trace")
    require_integer(identity["trace"]["mode"], "checkpoint trace mode", 0, 0)
    require_integer(identity["trace"]["max_entries_per_tournament"], "checkpoint trace samples", 0, 0)
    if identity["manifest_checksum"] != checksum or identity["shard"] != {"index": shard, "count": workers} or identity["trace"] != TRACE:
        _fail("invalid_campaign_checkpoint", "Checkpoint manifest, shard or trace identity differs from this run.")
    # Header JSON contains only strings and integers, so compact sorted JSON
    # matches Godot's identity serialization without numeric spelling ambiguity.
    serialized = canonical_json_bytes(identity)[:-1]
    if header["identity_checksum"] != hashlib.sha256(serialized).hexdigest() or not isinstance(header["started_at"], str):
        _fail("invalid_campaign_checkpoint", "Checkpoint header checksum or start time is invalid.")
    actual = _provenance(identity["execution_provenance"])
    if reference is not None and actual != reference:
        _fail("campaign_provenance_mismatch", "Checkpoint executable provenance differs from the approved run reference.")
    for child in path.iterdir():
        _safe(child)
    return actual


def _report(path: Path, manifest: dict[str, Any], planned: dict[int, dict[str, Any]],
            shard: int, workers: int, reference: dict[str, Any] | None) -> tuple[dict[str, Any], dict[str, Any]]:
    _safe(path)
    if not path.is_file():
        _fail("missing_campaign_report", "Successful producer did not create its simulation report.", {"path": str(path)})
    report = _normalize_report_integers(load_json_object(path))
    require_exact_fields(report, REPORT_FIELDS, "campaign simulation report")
    require_integer(report["report_schema_version"], "report schema", 4, 4)
    checksum = _simulation_manifest_checksum(manifest)
    if report["command_version"] != "simulation_cli_v6" or report["manifest"] != manifest or report["manifest_checksum"] != checksum:
        _fail("campaign_report_mismatch", "Report command or manifest differs from the approved input.")
    require_exact_fields(report["shard"], ("index", "count"), "report shard")
    require_integer(report["shard"]["index"], "report shard index", shard, shard)
    require_integer(report["shard"]["count"], "report shard count", workers, workers)
    if report["shard"] != {"index": shard, "count": workers}:
        _fail("campaign_shard_mismatch", "Report shard differs from its assigned worker.")
    if report["roster"] != _roster_provenance(manifest):
        _fail("campaign_report_mismatch", "Report roster snapshots differ from the manifest.")
    actual = _provenance(report["execution_provenance"])
    if actual["code_revision"] != report["code_revision"] or (reference is not None and actual != reference):
        _fail("campaign_provenance_mismatch", "Report executable provenance differs across workers or from the reference.")
    if any(not isinstance(report[k], str) or not report[k] for k in ("started_at", "finished_at")) or not isinstance(report["aggregates"], dict) or not isinstance(report["traces"], list):
        _fail("invalid_campaign_report", "Report completion metadata is invalid.")
    tournaments = report["tournaments"]
    if not isinstance(tournaments, list):
        _fail("invalid_campaign_report", "Report tournaments must be an array.")
    indexes = _validate_manifest(manifest)
    seen = set()
    for tournament in tournaments:
        require_exact_fields(tournament, TOURNAMENT_FIELDS, "campaign tournament")
        index = require_integer(tournament["tournament_index"], "tournament index", 0, len(planned) - 1)
        if index in seen or index % workers != shard:
            _fail("campaign_tournament_coverage", "Unexpected or duplicate shard tournament index.")
        seen.add(index)
        for key in ("plan_tournament_index", "matchup_occurrence", "rotation", "effective_seed"):
            require_integer(tournament[key], key, 0, 2**53 - 1)
        for seat in tournament["seat_map"]:
            require_exact_fields(seat, ("seat", "profile_id"), "starting seat")
            require_integer(seat["seat"], "starting seat index", 0, 8)
        if any(tournament[k] != v for k, v in planned[index].items()):
            _fail("campaign_tournament_coverage", "Tournament identity or starting seats differ from the frozen plan.")
        if tournament["termination_reason"] != "winner" or tournament["diagnostics"] != []:
            _fail("unsuccessful_campaign_tournament", "Every tournament must finish with a winner and no diagnostics.")
        hands = require_integer(tournament["tournament_hand_count"], "tournament hand count", 1, 2**53 - 1)
        results = tournament["profile_results"]
        regime = indexes["regimes"][tournament["regime_id"]]
        if not isinstance(results, list) or len(results) != 9:
            _fail("invalid_campaign_report", "Each tournament must contain nine seat results.")
        seats, winners = set(), []
        for result in results:
            seat = require_integer(result["seat"], "result seat", 0, 8)
            if seat in seats or planned[index]["seat_map"][seat]["profile_id"] != result["profile_id"]:
                _fail("invalid_campaign_report", "Result seats do not match their starting identities.")
            seats.add(seat)
            _validate_profile_result(result, regime, hands)
            if result["won_tournament"]:
                winners.append(result["profile_id"])
        total = 9 * regime["starting_stack"]
        if winners != [tournament["winner_profile_id"]] or not _competition_positions_are_valid(results):
            _fail("invalid_campaign_report", "Tournament winner or finishing positions are inconsistent.")
        if any(r["final_stack"] != (total if r["won_tournament"] else 0) for r in results) or sum(r["chip_differential"] for r in results) != 0:
            _fail("invalid_campaign_report", "Terminal tournament stacks do not conserve chips.")
    expected = set(range(shard, len(planned), workers))
    if seen != expected:
        _fail("campaign_tournament_coverage", "Completed report omits assigned tournament indexes.")
    return {"path": str(path), "sha256": _digest(path), "shard": {"index": shard, "count": workers}, "tournament_count": len(seen)}, actual


def _stop(processes: dict[int, tuple[subprocess.Popen, Any, Any]]) -> None:
    for process, _, _ in processes.values():
        if process.poll() is None:
            process.terminate()
    for process, stdout, stderr in processes.values():
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
        stdout.close()
        stderr.close()


@_io_boundary
@schema_boundary
def run_manifest(manifest_path: Path, godot: str, output_dir: Path, approval: dict,
                 workers: int = 4, expected_provenance: dict | None = None) -> dict[str, Any]:
    """Run explicitly approved shards and publish readiness only after validation."""
    manifest = load_json_object(manifest_path)
    checksum = _simulation_manifest_checksum(manifest)
    if not isinstance(approval, dict) or approval.get("approved") is not True or approval.get("manifest_checksum") != checksum:
        _fail("campaign_approval_required", "Explicit user approval of this exact manifest is required before execution.")
    if set(approval) - {"approved", "manifest_checksum", "source", "reviewer_id", "note"} or approval.get("source", "user") != "user":
        _fail("campaign_approval_required", "Unsupported approval source or fields; no approval is inferred.")
    require_integer(workers, "campaign workers", 1, 4)
    audit = audit_manifest(manifest)
    if audit["profile_count"] not in (35, 30) or audit["matchup_count"] != audit["profile_count"]:
        _fail("invalid_campaign_schedule", "Competitive execution requires thirty-five or thirty nine-player matchups.")
    return _execute_validated_manifest(manifest_path, manifest, godot, output_dir,
                                       {"approval": approval}, workers, expected_provenance, audit)


@_io_boundary
@schema_boundary
def _execute_validated_manifest(
    manifest_path: Path, manifest: dict[str, Any], godot: str, output_dir: Path,
    authorization_fields: dict[str, Any], workers: int, expected_provenance: dict | None,
    audit: dict[str, Any], run_type: str = RUN_TYPE, ready_type: str = READY_TYPE,
    cancel_event: threading.Event | None = None,
) -> dict[str, Any]:
    """Execute inputs already authorized and policy-validated by their public API.

    Competitive callers supply their explicit user manifest approval. Separate
    confirmation APIs validate campaign-policy authorization before calling;
    this helper never manufactures either form of authorization.
    """
    _check_cancelled(cancel_event)
    require_integer(workers, "campaign workers", 1, 4)
    require_identifier(run_type, "execution artifact type")
    require_identifier(ready_type, "readiness artifact type")
    manifest = copy.deepcopy(manifest)
    audit = copy.deepcopy(audit)
    indexes = _validate_manifest(manifest)
    checksum = _simulation_manifest_checksum(manifest)
    if any(p["model_id"] != "strategy_parameterized" for p in indexes["profiles"].values()) or any(r["player_count"] != 9 for r in indexes["regimes"].values()):
        _fail("invalid_campaign_schedule", "Campaign execution requires strategic profiles and nine-player starts.")
    if not isinstance(audit, dict) or audit.get("manifest_checksum") != checksum:
        _fail("invalid_campaign_schedule", "Execution audit must bind the exact validated manifest.")
    if set(authorization_fields) == {"approval"}:
        if run_type != RUN_TYPE or ready_type != READY_TYPE:
            _fail("invalid_campaign_authorization", "Competitive approval must retain competitive artifact types.")
    elif set(authorization_fields) == {"policy_authorization"}:
        if run_type == RUN_TYPE or ready_type == READY_TYPE or not isinstance(authorization_fields["policy_authorization"], dict):
            _fail("invalid_campaign_authorization", "Policy-authorized jobs require distinct run/readiness types and validated authorization.")
    else:
        _fail("invalid_campaign_authorization", "Exactly one explicit authorization form is required.")
    if expected_provenance is not None:
        _provenance(expected_provenance)
    executable = shutil.which(godot)
    if executable is None:
        _fail("campaign_engine_missing", "Godot executable could not be resolved.")
    executable = str(Path(executable).resolve())
    manifest_path = manifest_path.resolve()
    _safe(output_dir)
    output_dir = output_dir.absolute()
    request = {"manifest": copy.deepcopy(manifest), "manifest_checksum": checksum, "workers": workers,
               "godot": executable, "expected_provenance": copy.deepcopy(expected_provenance),
               **copy.deepcopy(authorization_fields)}
    run = create_artifact(run_type, request)
    marker = output_dir / "run.json"
    frozen_manifest = output_dir / "manifest.json"
    try:
        output_dir.mkdir()
    except FileExistsError:
        _safe(marker)
        if not marker.is_file() or load_artifact(marker, run_type) != run:
            _fail("campaign_run_mismatch", "Existing output directory does not belong to these approved run inputs.")
    else:
        write_artifact_atomic(marker, run)
    _safe(frozen_manifest)
    if frozen_manifest.exists():
        if load_json_object(frozen_manifest) != manifest:
            _fail("campaign_run_mismatch", "Frozen runner manifest differs from the approved input.")
    else:
        from .atomic_write import publish_bytes_no_replace
        publish_bytes_no_replace(frozen_manifest, canonical_json_bytes(manifest))
    manifest_path = frozen_manifest
    _safe(output_dir / "runner.lock")
    lock_descriptor = os.open(output_dir / "runner.lock", os.O_CREAT | os.O_RDWR | getattr(os, "O_NOFOLLOW", 0), 0o600)
    processes: dict[int, tuple[subprocess.Popen, Any, Any]] = {}
    previous_sigterm = None
    if threading.current_thread() is threading.main_thread():
        previous_sigterm = signal.getsignal(signal.SIGTERM)
        def interrupt_signal(signum, frame):
            raise KeyboardInterrupt(f"signal {signum}")
        signal.signal(signal.SIGTERM, interrupt_signal)
    try:
        try:
            fcntl.flock(lock_descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            _fail("campaign_run_busy", "Another runner owns this campaign output directory.")
        return _run_locked(manifest_path, manifest, checksum, executable, output_dir, run,
                           workers, expected_provenance, audit, processes, ready_type, cancel_event)
    except KeyboardInterrupt:
        _event("interrupted", manifest_checksum=checksum)
        _fail("campaign_run_interrupted", "Campaign execution interrupted; validated checkpoints are preserved.")
    except ToolError as error:
        _event("failed", manifest_checksum=checksum, error=error.as_object()["error"])
        raise
    finally:
        # Repeated termination signals cannot interrupt child cleanup.
        if previous_sigterm is not None:
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
        try:
            _stop(processes)
        finally:
            os.close(lock_descriptor)
            if previous_sigterm is not None:
                signal.signal(signal.SIGTERM, previous_sigterm)


def _run_locked(manifest_path: Path, manifest: dict[str, Any], checksum: str, executable: str,
                output_dir: Path, run: dict[str, Any], workers: int, expected_provenance: dict | None,
                audit: dict[str, Any], processes: dict[int, tuple[subprocess.Popen, Any, Any]],
                ready_type: str = READY_TYPE, cancel_event: threading.Event | None = None) -> dict[str, Any]:
    planned = _planned_tournaments(manifest, _validate_manifest(manifest))
    reference = copy.deepcopy(expected_provenance)
    reports: dict[int, dict[str, Any]] = {}
    checkpoints = {}
    for shard in range(workers):
        _check_cancelled(cancel_event)
        report = output_dir / f"shard_{shard:04d}.json"
        checkpoint = output_dir / f"shard_{shard:04d}.checkpoint"
        start = output_dir / f"shard_{shard:04d}.started.json"
        complete = output_dir / f"shard_{shard:04d}.completed.json"
        _safe(report); _safe(checkpoint); _safe(start); _safe(complete)
        expected_start = create_artifact(START_TYPE, {"run_checksum": run["checksum"], "shard": {"index": shard, "count": workers}})
        owned = start.is_file() and load_artifact(start, START_TYPE) == expected_start
        if start.exists() and not owned:
            _fail("campaign_run_mismatch", "Shard start marker belongs to another run.")
        if (report.exists() or checkpoint.exists() or complete.exists()) and not owned:
            _fail("campaign_run_mismatch", "Unowned shard output or checkpoint cannot be resumed.")
        if checkpoint.exists():
            reference = _checkpoint(checkpoint, checksum, shard, workers, reference)
            checkpoints[shard] = True
        if complete.exists() and not report.exists():
            _fail("missing_campaign_report", "A previously successful shard report is missing.")
        if report.exists():
            if not complete.is_file():
                _fail("unverified_campaign_report", "Existing report has no verified successful-producer receipt; it cannot be consumed.")
            evidence, actual = _report(report, manifest, planned, shard, workers, reference)
            receipt = create_artifact(COMPLETE_TYPE, {"run_checksum": run["checksum"], "exit_code": 0, "report": evidence})
            if load_artifact(complete, COMPLETE_TYPE) != receipt:
                _fail("campaign_report_changed", "Completed report differs from its successful-producer receipt.")
            reference = actual
            reports[shard] = evidence
            _event("shard_reused", shard=shard, tournaments=evidence["tournament_count"])
    if len(reports) != workers:
        LOG_ROOT.mkdir(parents=True, exist_ok=True)
        logs = LOG_ROOT / f"{checksum[:12]}-{uuid.uuid4().hex}"
        logs.mkdir()
        for shard in range(workers):
            _check_cancelled(cancel_event)
            if shard in reports:
                continue
            start = output_dir / f"shard_{shard:04d}.started.json"
            if not start.exists():
                write_artifact_atomic(start, create_artifact(START_TYPE, {"run_checksum": run["checksum"], "shard": {"index": shard, "count": workers}}))
            command = [executable, "--headless", "--path", str(ROOT), "--log-file", str(logs / f"shard_{shard:04d}.engine.log"),
                       "--script", "res://scripts/simulation/simulation_cli_app.gd", "--", "run", "--config", str(manifest_path),
                       "--output", str(output_dir / f"shard_{shard:04d}.json"), "--shard", f"{shard}/{workers}",
                       "--checkpoint", str(output_dir / f"shard_{shard:04d}.checkpoint"), "--trace", "none"]
            if shard in checkpoints:
                command.append("--resume")
            stdout = (logs / f"shard_{shard:04d}.stdout.log").open("xb")
            stderr = (logs / f"shard_{shard:04d}.stderr.log").open("xb")
            try:
                process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr)
            except BaseException:
                stdout.close(); stderr.close()
                raise
            processes[shard] = (process, stdout, stderr)
            _event("shard_started", shard=shard, workers=workers, resumed=shard in checkpoints, logs=str(logs))
        started = last_progress = time.monotonic()
        checked_headers = set(checkpoints)
        while processes:
            _check_cancelled(cancel_event)
            # The engine atomically publishes its header before tournament work.
            # Pin provenance immediately, rather than after a long shard finishes.
            for shard in processes:
                header = output_dir / f"shard_{shard:04d}.checkpoint" / "header.json"
                if shard not in checked_headers and header.exists():
                    reference = _checkpoint(header.parent, checksum, shard, workers, reference)
                    checked_headers.add(shard)
                    _event("shard_provenance_verified", shard=shard)
            for shard, (process, stdout, stderr) in list(processes.items()):
                code = process.poll()
                if code is None:
                    continue
                stdout.close(); stderr.close()
                if code != 0:
                    _fail("campaign_producer_failed", "Simulation shard failed; dependent consumers were not run.", {"shard": shard, "exit_code": code, "logs": str(logs)})
                evidence, actual = _report(output_dir / f"shard_{shard:04d}.json", manifest, planned, shard, workers, reference)
                reference = actual
                write_artifact_atomic(output_dir / f"shard_{shard:04d}.completed.json",
                                      create_artifact(COMPLETE_TYPE, {"run_checksum": run["checksum"], "exit_code": 0, "report": evidence}))
                reports[shard] = evidence
                del processes[shard]
                _event("shard_completed", shard=shard, tournaments=evidence["tournament_count"])
            if processes:
                if time.monotonic() - last_progress >= PROGRESS_INTERVAL_SECONDS:
                    progress = {shard: _worker_progress(logs / f"shard_{shard:04d}.stderr.log",
                                                       len(range(shard, len(planned), workers))) for shard in processes}
                    remaining = [value["remaining_seconds"] for value in progress.values()]
                    _event("running", active_shards=sorted(processes), completed_shards=len(reports),
                           completed_tournaments=sum(row["tournament_count"] for row in reports.values())
                           + sum(value["completed"] for value in progress.values()),
                           elapsed_seconds=round(time.monotonic() - started, 3),
                           estimated_remaining_seconds=max(remaining) if all(value is not None for value in remaining) else None,
                           worker_progress=progress, manifest_checksum=checksum)
                    last_progress = time.monotonic()
                time.sleep(0.05)
    _check_cancelled(cancel_event)
    payload = {"run_checksum": run["checksum"], "manifest_checksum": checksum,
               "manifest": manifest, "workers": workers, "reports": [reports[i] for i in range(workers)],
               "execution_provenance": reference, "tournament_count": len(planned), "schedule_audit": audit}
    ready = create_artifact(ready_type, payload)
    destination = output_dir / "readiness.json"
    _safe(destination)
    if destination.exists():
        if load_artifact(destination, ready_type) != ready:
            _fail("campaign_readiness_mismatch", "Existing readiness evidence differs from validated reports.")
    else:
        write_artifact_atomic(destination, ready)
    _event("ready", manifest_checksum=checksum, tournaments=len(planned), readiness=str(destination))
    return ready
