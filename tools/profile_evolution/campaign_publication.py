"""Explicit human-selected publication, separate from strict confirmation policies.

This policy accepts documented benchmark failures or absent confirmation only
when the human approves the exact selection and expressly replaces that gate.
It never changes original ranking, confirmation eligibility, or their validators.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

from .artifacts import canonical_json_bytes, create_artifact, validate_artifact_envelope
from .contracts import validate_candidates
from .errors import ExitCode, ToolError
from .profile_publisher import _profile_id, _resource_text, _write_new_file

POLICY = "campaign_human_selection_publication_v1"
REVIEW_TYPE = "campaign_human_publication_review_v1"


def _fail(message: str) -> None:
    raise ToolError("invalid_human_campaign_publication", message, ExitCode.INVALID_INPUT)


def validate_selection(selection: dict[str, Any], comparison: dict[str, Any]) -> list[dict[str, Any]]:
    """Bind the human-selected twenty to exact original round-two identities."""
    validate_artifact_envelope(selection, "campaign_human_selection_v1")
    validate_artifact_envelope(comparison, "campaign_round_result_v1")
    s, r = selection["payload"], comparison["payload"]
    if r["round_number"] != 2 or s["round2_comparison_checksum"] != comparison["checksum"] or s["campaign_checksum"] != r["campaign_checksum"]:
        _fail("Selection does not bind the original round-two comparison.")
    entries = s["selected"]
    if not isinstance(entries, list) or len(entries) != 20:
        _fail("Exactly twenty selected profiles are required.")
    validate_candidates([e["candidate"] for e in entries])
    original = {e["candidate_id"]: e for e in r["ranking"]}
    if len(original) != 25:
        _fail("Round two must account for twenty-five contenders.")
    ids = {e["candidate"]["candidate_id"] for e in entries}
    expected = (set(r["survivor_ids"]) - {s["excluded_candidate_id"]}) | {s["included_candidate_id"]}
    if s["excluded_candidate_id"] not in r["survivor_ids"] or s["included_candidate_id"] not in r["rejected_ids"] or ids != expected:
        _fail("Selected membership differs from the exact approved single swap.")
    names: set[str] = set()
    for e in entries:
        cid = e["candidate"]["candidate_id"]
        if cid not in original:
            _fail("Selected identity is not a round-two contender.")
        row = original[cid]
        candidate = {"candidate_id": cid, "model_id": row["profile_snapshot"]["model_id"], "parameters": row["profile_snapshot"]["parameters"], "parent_ids": row["parent_ids"]}
        if e["candidate"] != candidate or e["display_name"] != row["display_name"] or e["original_creation_checksum"] != row["original_creation_checksum"] or e["round2_rank"] != row["rank"] or e["win_rate"] != row["component_means"]["win_score"]:
            _fail("Selected identity, name, parameters, ancestry or measured result changed.")
        if not row["eligible"] or candidate["model_id"] != "strategy_parameterized":
            _fail("Only technically eligible strategic contenders may be selected.")
        if e["retain_existing_resource"] is not (row["origin"] == "incumbent"):
            _fail("Incumbent resource retention changed.")
        expected_id = row["profile_id"] if e["retain_existing_resource"] else _profile_id(cid, "20261101_r2")
        if e["proposed_profile_id"] != expected_id:
            _fail("Publication profile identity differs from the selected snapshot.")
        name = e["display_name"].casefold()
        if name in names:
            _fail("Selected display names must be unique.")
        names.add(name)
    return entries


def approve_selection(selection: dict[str, Any], comparison: dict[str, Any], *, reviewer_id: str,
                      approval: dict[str, Any]) -> dict[str, Any]:
    """Record an explicit human policy decision; never infer it from ranking."""
    entries = validate_selection(selection, comparison)
    if not reviewer_id or approval.get("source") != "user" or approval.get("approved") is not True or approval.get("replace_strict_performance_gate") is not True or approval.get("selection_checksum") != selection["checksum"] or not approval.get("instruction"):
        _fail("Explicit user approval of this selection and replacement policy is required.")
    return create_artifact(REVIEW_TYPE, {
        "policy_version": POLICY, "reviewer_id": reviewer_id,
        "selection_checksum": selection["checksum"], "comparison_checksum": comparison["checksum"],
        "approval": approval,
        "decisions": [{"candidate_id": e["candidate"]["candidate_id"], "display_name": e["display_name"],
                       "approved": True, "strict_confirmation_eligible": e["strict_confirmation_eligible"],
                       "confirmation_checksum": e["confirmation_checksum"], "confirmation_status": e["confirmation_status"]} for e in entries],
    })


def publish_selection(selection: dict[str, Any], comparison: dict[str, Any], review: dict[str, Any],
                      project_root: Path) -> dict[str, Any]:
    """Publish fourteen immutable resources and bind six retained incumbents.

    All destinations are checked before writes. On a write failure, newly
    created files are rolled back; retained resources are never modified.
    """
    entries = validate_selection(selection, comparison)
    validate_artifact_envelope(review, REVIEW_TYPE)
    p = review["payload"]
    expected = approve_selection(selection, comparison, reviewer_id=p["reviewer_id"], approval=p["approval"])
    if expected != review:
        _fail("Publication review differs from exact approved selection.")
    directory = project_root / "resources/bot_profiles/published"
    pending: list[tuple[Path, str]] = []
    results = []
    for e in entries:
        pid = e["proposed_profile_id"]
        path = directory / (pid + ".tres")
        generated = _resource_text(pid, e["candidate"], e["display_name"])
        if e["retain_existing_resource"]:
            if not path.is_file() or path.read_text() != generated:
                _fail("Retained incumbent resource differs from the approved exact snapshot.")
            text = path.read_text()
        else:
            text = generated
            if path.exists():
                _fail("New publication destination already exists.")
            pending.append((path, text))
        digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
        provenance = {"policy_version": POLICY, "candidate_id": e["candidate"]["candidate_id"],
                      "profile_id": pid, "resource_sha256": digest,
                      "review_checksum": review["checksum"], "selection_checksum": selection["checksum"],
                      "comparison_checksum": comparison["checksum"],
                      "original_creation_checksum": e["original_creation_checksum"],
                      "strict_confirmation_eligible": e["strict_confirmation_eligible"],
                      "confirmation_checksum": e["confirmation_checksum"], "confirmation_status": e["confirmation_status"]}
        sidecar = directory / (pid + ".campaign_20261101.provenance.json")
        if sidecar.exists():
            _fail("Campaign publication provenance already exists.")
        pending.append((sidecar, canonical_json_bytes(provenance).decode("utf-8")))
        results.append(dict(provenance, resource_path=path.relative_to(project_root).as_posix(),
                            provenance_path=sidecar.relative_to(project_root).as_posix(),
                            retained_existing_resource=e["retain_existing_resource"]))
    created = []
    try:
        for path, text in pending:
            _write_new_file(path, text)
            created.append(path)
    except (OSError, ToolError):
        for path in reversed(created):
            path.unlink(missing_ok=True)
        raise
    return create_artifact("campaign_human_publication_result_v1", {
        "policy_version": POLICY, "selection_checksum": selection["checksum"],
        "review_checksum": review["checksum"], "profiles": results,
    })
