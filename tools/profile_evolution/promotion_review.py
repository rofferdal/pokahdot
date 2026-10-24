"""Consolidated human-review records for evidence-gated profile promotion."""

from __future__ import annotations

import copy
import json
import os
import tempfile
from pathlib import Path
from typing import Any

from .artifacts import create_artifact, validate_artifact_envelope
from .confirmation import validate_confirmation
from .contracts import require_exact_fields, require_identifier, validate_candidate
from .errors import ExitCode, ToolError

PROMOTION_REVIEW_FIELDS = (
    "approved",
    "candidate",
    "confirmation_checksum",
    "promotion_eligible",
    "review_note",
    "reviewer_id",
)
PROMOTION_REVIEW_PLAN_FIELDS = ("candidates", "plan_version", "reviewer_id")
PROMOTION_REVIEW_PLAN_ENTRY_FIELDS = (
    "candidate",
    "confirmation_checksum",
    "decision",
    "display_name",
    "promotion_eligible",
    "review_note",
)
PROMOTION_REVIEW_BATCH_FIELDS = ("decisions", "reviewer_id")
PROMOTION_REVIEW_BATCH_ENTRY_FIELDS = (
    "approved",
    "candidate",
    "confirmation_checksum",
    "display_name",
    "promotion_eligible",
    "review_note",
)
REVIEW_PLAN_VERSION = 1
REVIEW_DECISIONS = ("approve", "reject")


def _fail(code: str, message: str) -> None:
    raise ToolError(code, message, ExitCode.INVALID_INPUT)


def _validate_checksum(value: Any, field_name: str) -> str:
    if (
        not isinstance(value, str)
        or len(value) != 64
        or any(character not in "0123456789abcdef" for character in value)
    ):
        _fail("invalid_promotion_review", f"{field_name} is invalid.")
    return value


def _validate_review_text(value: Any, field_name: str) -> str:
    if not isinstance(value, str) or value.strip() != value:
        _fail("invalid_promotion_review", f"{field_name} is invalid.")
    return value


def _confirmation_index(
    confirmation_artifacts: list[dict[str, Any]],
) -> dict[str, tuple[dict[str, Any], dict[str, Any]]]:
    if not confirmation_artifacts:
        _fail("empty_promotion_review", "At least one confirmation is required.")
    result: dict[str, tuple[dict[str, Any], dict[str, Any]]] = {}
    for artifact in confirmation_artifacts:
        confirmation = validate_confirmation(artifact)
        candidate_id = confirmation["candidate"]["candidate_id"]
        if candidate_id in result:
            _fail(
                "duplicate_promotion_candidate",
                f"Candidate '{candidate_id}' appears more than once.",
            )
        result[candidate_id] = (artifact, confirmation)
    return result


def create_promotion_review_plan(
    confirmation_artifacts: list[dict[str, Any]], reviewer_id: str
) -> dict[str, Any]:
    """Create one editable plan containing every candidate review decision."""
    reviewer = require_identifier(reviewer_id, "reviewer_id")
    confirmations = _confirmation_index(confirmation_artifacts)
    candidates = []
    for artifact, confirmation in confirmations.values():
        candidates.append(
            {
                "candidate": copy.deepcopy(confirmation["candidate"]),
                "confirmation_checksum": artifact["checksum"],
                "decision": "pending",
                "display_name": "",
                "promotion_eligible": confirmation["promotion_eligible"],
                "review_note": "",
            }
        )
    return {
        "candidates": candidates,
        "plan_version": REVIEW_PLAN_VERSION,
        "reviewer_id": reviewer,
    }


def write_promotion_review_plan_atomic(path: Path, plan: dict[str, Any]) -> None:
    """Write an editable, pretty-printed review plan without replacing a file."""
    validate_promotion_review_plan(plan, require_complete=False)
    parent = path.parent
    if not parent.is_dir():
        raise ToolError(
            "output_directory_missing",
            f"Output directory does not exist: '{parent}'.",
            ExitCode.IO_FAILURE,
            {"path": str(parent)},
        )
    temporary_path: Path | None = None
    try:
        descriptor, name = tempfile.mkstemp(
            prefix=f".{path.name}.", suffix=".tmp", dir=parent
        )
        temporary_path = Path(name)
        contents = json.dumps(plan, ensure_ascii=False, indent=2) + "\n"
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(contents)
            stream.flush()
            os.fsync(stream.fileno())
        os.link(temporary_path, path)
        temporary_path.unlink()
        temporary_path = None
        directory_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
        directory_descriptor = os.open(parent, directory_flags)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)
    except FileExistsError as error:
        raise ToolError(
            "output_exists",
            f"Output already exists: '{path}'.",
            ExitCode.IO_FAILURE,
            {"path": str(path)},
        ) from error
    except OSError as error:
        raise ToolError(
            "output_write_failed",
            f"Cannot write output '{path}': {error}",
            ExitCode.IO_FAILURE,
            {"path": str(path)},
        ) from error
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def validate_promotion_review_plan(
    plan: dict[str, Any], *, require_complete: bool
) -> dict[str, Any]:
    """Validate the editable plan and optionally require every decision."""
    require_exact_fields(plan, PROMOTION_REVIEW_PLAN_FIELDS, "promotion review plan")
    if plan["plan_version"] != REVIEW_PLAN_VERSION:
        _fail("invalid_promotion_review", "Promotion review plan version is invalid.")
    reviewer_id = require_identifier(plan["reviewer_id"], "reviewer_id")
    entries = plan["candidates"]
    if not isinstance(entries, list) or not entries:
        _fail("invalid_promotion_review", "Promotion review candidates must be non-empty.")
    candidates = []
    seen_ids: set[str] = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            _fail("invalid_promotion_review", f"Review candidate {index} must be an object.")
        require_exact_fields(
            entry,
            PROMOTION_REVIEW_PLAN_ENTRY_FIELDS,
            f"promotion review candidate {index}",
        )
        candidate = validate_candidate(entry["candidate"])
        candidate_id = candidate["candidate_id"]
        if candidate_id in seen_ids:
            _fail(
                "duplicate_promotion_candidate",
                f"Candidate '{candidate_id}' appears more than once.",
            )
        seen_ids.add(candidate_id)
        decision = entry["decision"]
        allowed = REVIEW_DECISIONS if require_complete else (*REVIEW_DECISIONS, "pending")
        if decision not in allowed:
            expected = "approve or reject" if require_complete else "pending, approve, or reject"
            _fail(
                "invalid_review_decision",
                f"Candidate '{candidate_id}' decision must be {expected}.",
            )
        if not isinstance(entry["promotion_eligible"], bool):
            _fail("invalid_promotion_review", "Promotion eligibility must be boolean.")
        candidates.append(
            {
                "candidate": candidate,
                "confirmation_checksum": _validate_checksum(
                    entry["confirmation_checksum"], "Confirmation checksum"
                ),
                "decision": decision,
                "display_name": _validate_review_text(entry["display_name"], "Display name"),
                "promotion_eligible": entry["promotion_eligible"],
                "review_note": _validate_review_text(entry["review_note"], "Review note"),
            }
        )
    return {"candidates": candidates, "reviewer_id": reviewer_id}


def finalize_promotion_review(
    plan: dict[str, Any], confirmation_artifacts: list[dict[str, Any]]
) -> dict[str, Any]:
    """Bind every completed plan decision to its exact confirmation snapshot."""
    review = validate_promotion_review_plan(plan, require_complete=True)
    confirmations = _confirmation_index(confirmation_artifacts)
    plan_ids = {entry["candidate"]["candidate_id"] for entry in review["candidates"]}
    if plan_ids != set(confirmations):
        _fail(
            "promotion_review_confirmation_mismatch",
            "Review plan candidates must exactly match the supplied confirmations.",
        )
    decisions = []
    for entry in review["candidates"]:
        candidate_id = entry["candidate"]["candidate_id"]
        artifact, confirmation = confirmations[candidate_id]
        if entry["confirmation_checksum"] != artifact["checksum"]:
            _fail(
                "promotion_review_mismatch",
                f"Candidate '{candidate_id}' review is bound to another confirmation.",
            )
        if entry["candidate"] != confirmation["candidate"]:
            _fail(
                "promotion_review_candidate_mismatch",
                f"Candidate '{candidate_id}' snapshot differs from its confirmation.",
            )
        if entry["promotion_eligible"] != confirmation["promotion_eligible"]:
            _fail(
                "promotion_review_eligibility_mismatch",
                f"Candidate '{candidate_id}' eligibility differs from its confirmation.",
            )
        approved = entry["decision"] == "approve"
        if approved and not confirmation["promotion_eligible"]:
            _fail(
                "ineligible_promotion_review",
                f"Ineligible candidate '{candidate_id}' cannot receive approval.",
            )
        decisions.append(
            {
                "approved": approved,
                "candidate": copy.deepcopy(confirmation["candidate"]),
                "confirmation_checksum": artifact["checksum"],
                "display_name": entry["display_name"],
                "promotion_eligible": confirmation["promotion_eligible"],
                "review_note": entry["review_note"],
            }
        )
    return create_artifact(
        "promotion_review_batch",
        {"decisions": decisions, "reviewer_id": review["reviewer_id"]},
    )


def create_promotion_review(
    confirmation_artifact: dict[str, Any],
    reviewer_id: str,
    approved: bool,
    review_note: str = "",
) -> dict[str, Any]:
    """Record a human decision without publishing a profile or touching a roster."""
    confirmation = validate_confirmation(confirmation_artifact)
    reviewer = require_identifier(reviewer_id, "reviewer_id")
    if not isinstance(approved, bool):
        _fail("invalid_promotion_review", "Promotion review approval must be boolean.")
    if not isinstance(review_note, str):
        _fail("invalid_promotion_review", "Promotion review note must be a string.")
    if approved and not confirmation["promotion_eligible"]:
        _fail(
            "ineligible_promotion_review",
            "An ineligible confirmation cannot receive approval.",
        )
    return create_artifact(
        "promotion_review",
        {
            "approved": approved,
            "candidate": copy.deepcopy(confirmation["candidate"]),
            "confirmation_checksum": confirmation_artifact["checksum"],
            "promotion_eligible": confirmation["promotion_eligible"],
            "review_note": review_note.strip(),
            "reviewer_id": reviewer,
        },
    )


def validate_promotion_review(artifact: dict[str, Any]) -> dict[str, Any]:
    validate_artifact_envelope(artifact, "promotion_review")
    payload = artifact["payload"]
    require_exact_fields(payload, PROMOTION_REVIEW_FIELDS, "promotion review payload")
    candidate = validate_candidate(payload["candidate"])
    checksum = _validate_checksum(
        payload["confirmation_checksum"], "Promotion review confirmation checksum"
    )
    if not isinstance(payload["approved"], bool) or not isinstance(
        payload["promotion_eligible"], bool
    ):
        _fail("invalid_promotion_review", "Promotion review decision fields are invalid.")
    if payload["approved"] and not payload["promotion_eligible"]:
        _fail(
            "invalid_promotion_review",
            "Promotion review cannot approve ineligible evidence.",
        )
    reviewer_id = require_identifier(payload["reviewer_id"], "reviewer_id")
    review_note = payload["review_note"]
    if not isinstance(review_note, str) or review_note.strip() != review_note:
        _fail("invalid_promotion_review", "Promotion review note is invalid.")
    return {
        "approved": payload["approved"],
        "candidate": candidate,
        "confirmation_checksum": checksum,
        "promotion_eligible": payload["promotion_eligible"],
        "review_note": review_note,
        "reviewer_id": reviewer_id,
    }


def validate_promotion_review_batch(artifact: dict[str, Any]) -> dict[str, Any]:
    validate_artifact_envelope(artifact, "promotion_review_batch")
    payload = artifact["payload"]
    require_exact_fields(
        payload, PROMOTION_REVIEW_BATCH_FIELDS, "promotion review batch payload"
    )
    reviewer_id = require_identifier(payload["reviewer_id"], "reviewer_id")
    raw_decisions = payload["decisions"]
    if not isinstance(raw_decisions, list) or not raw_decisions:
        _fail("invalid_promotion_review", "Promotion review decisions must be non-empty.")
    decisions = []
    seen_ids: set[str] = set()
    for index, entry in enumerate(raw_decisions):
        if not isinstance(entry, dict):
            _fail("invalid_promotion_review", f"Promotion decision {index} must be an object.")
        require_exact_fields(
            entry,
            PROMOTION_REVIEW_BATCH_ENTRY_FIELDS,
            f"promotion review decision {index}",
        )
        candidate = validate_candidate(entry["candidate"])
        candidate_id = candidate["candidate_id"]
        if candidate_id in seen_ids:
            _fail(
                "duplicate_promotion_candidate",
                f"Candidate '{candidate_id}' appears more than once.",
            )
        seen_ids.add(candidate_id)
        approved = entry["approved"]
        eligible = entry["promotion_eligible"]
        if not isinstance(approved, bool) or not isinstance(eligible, bool):
            _fail("invalid_promotion_review", "Promotion review decision fields are invalid.")
        if approved and not eligible:
            _fail(
                "invalid_promotion_review",
                "Promotion review cannot approve ineligible evidence.",
            )
        decisions.append(
            {
                "approved": approved,
                "candidate": candidate,
                "confirmation_checksum": _validate_checksum(
                    entry["confirmation_checksum"], "Confirmation checksum"
                ),
                "display_name": _validate_review_text(
                    entry["display_name"], "Display name"
                ),
                "promotion_eligible": eligible,
                "review_note": _validate_review_text(
                    entry["review_note"], "Review note"
                ),
            }
        )
    return {"decisions": decisions, "reviewer_id": reviewer_id}


def promotion_decision_for_candidate(
    artifact: dict[str, Any], candidate_id: str
) -> dict[str, Any]:
    """Resolve one candidate decision from current or legacy review data."""
    if artifact.get("type") == "promotion_review_batch":
        review = validate_promotion_review_batch(artifact)
        for decision in review["decisions"]:
            if decision["candidate"]["candidate_id"] == candidate_id:
                return decision
        _fail(
            "promotion_review_candidate_missing",
            f"Promotion review has no decision for candidate '{candidate_id}'.",
        )
    review = validate_promotion_review(artifact)
    if review["candidate"]["candidate_id"] != candidate_id:
        _fail(
            "promotion_review_candidate_missing",
            f"Promotion review has no decision for candidate '{candidate_id}'.",
        )
    return review
