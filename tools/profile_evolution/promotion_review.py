"""Consolidated human-review records for evidence-gated profile promotion."""

from __future__ import annotations

import copy
import json
import math
import os
import tempfile
from pathlib import Path
from typing import Any

from .artifacts import create_artifact, validate_artifact_envelope
from .confirmation import MEASURED_BEHAVIOR_FIELDS, validate_confirmation
from .contracts import GENES, require_exact_fields, require_identifier, validate_candidate
from .errors import ExitCode, ToolError

PROMOTION_REVIEW_FIELDS = (
    "approved",
    "candidate",
    "confirmation_checksum",
    "promotion_eligible",
    "review_note",
    "reviewer_id",
)
PROMOTION_REVIEW_PLAN_FIELDS = (
    "candidates",
    "plan_version",
    "reviewer_id",
    "roster_diversity",
)
PROMOTION_REVIEW_PLAN_ENTRY_FIELDS = (
    "candidate",
    "confirmation_checksum",
    "decision",
    "display_name",
    "promotion_eligible",
    "review_note",
)
PROMOTION_REVIEW_BATCH_FIELDS = ("decisions", "reviewer_id", "roster_diversity")
PROMOTION_REVIEW_BATCH_ENTRY_FIELDS = (
    "approved",
    "candidate",
    "confirmation_checksum",
    "display_name",
    "promotion_eligible",
    "review_note",
)
ROSTER_DIVERSITY_FIELDS = ("candidate_ids", "pairwise_comparisons")
ROSTER_DIVERSITY_COMPARISON_FIELDS = (
    "first_candidate_id",
    "genetic_parameter_distance",
    "measured_behavior_absolute_differences",
    "measured_behavior_l1_distance",
    "second_candidate_id",
)
REVIEW_PLAN_VERSION = 2
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


def _roster_diversity(
    confirmations: dict[str, tuple[dict[str, Any], dict[str, Any]]],
) -> dict[str, Any]:
    candidate_ids = sorted(confirmations)
    comparisons = []
    for index, first_id in enumerate(candidate_ids):
        first = confirmations[first_id][1]
        for second_id in candidate_ids[index + 1 :]:
            second = confirmations[second_id][1]
            genetic_distance = sum(
                abs(
                    first["candidate"]["parameters"][gene]
                    - second["candidate"]["parameters"][gene]
                )
                for gene in GENES
            )
            behavior_differences = {
                field: abs(
                    first["measured_behavior"]["metrics"][field]["rate"]
                    - second["measured_behavior"]["metrics"][field]["rate"]
                )
                for field in MEASURED_BEHAVIOR_FIELDS
            }
            comparisons.append(
                {
                    "first_candidate_id": first_id,
                    "genetic_parameter_distance": genetic_distance,
                    "measured_behavior_absolute_differences": behavior_differences,
                    "measured_behavior_l1_distance": sum(
                        behavior_differences.values()
                    ),
                    "second_candidate_id": second_id,
                }
            )
    return {
        "candidate_ids": candidate_ids,
        "pairwise_comparisons": comparisons,
    }


def _validate_roster_diversity(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail("invalid_promotion_review", "Roster diversity review is invalid.")
    require_exact_fields(value, ROSTER_DIVERSITY_FIELDS, "roster diversity review")
    raw_ids = value["candidate_ids"]
    if not isinstance(raw_ids, list):
        _fail("invalid_promotion_review", "Roster diversity candidate IDs are invalid.")
    candidate_ids = [require_identifier(item, "roster candidate_id") for item in raw_ids]
    if candidate_ids != sorted(set(candidate_ids)) or not candidate_ids:
        _fail("invalid_promotion_review", "Roster diversity candidate IDs are invalid.")
    raw_comparisons = value["pairwise_comparisons"]
    if not isinstance(raw_comparisons, list):
        _fail("invalid_promotion_review", "Roster diversity comparisons are invalid.")
    comparisons = []
    actual_pairs: set[tuple[str, str]] = set()
    for comparison in raw_comparisons:
        if not isinstance(comparison, dict):
            _fail("invalid_promotion_review", "Roster diversity comparison is invalid.")
        require_exact_fields(
            comparison,
            ROSTER_DIVERSITY_COMPARISON_FIELDS,
            "roster diversity comparison",
        )
        first_id = require_identifier(
            comparison["first_candidate_id"], "first candidate_id"
        )
        second_id = require_identifier(
            comparison["second_candidate_id"], "second candidate_id"
        )
        pair = (first_id, second_id)
        if (
            first_id not in candidate_ids
            or second_id not in candidate_ids
            or first_id >= second_id
            or pair in actual_pairs
        ):
            _fail("invalid_promotion_review", "Roster diversity comparison pair is invalid.")
        actual_pairs.add(pair)
        genetic_distance = comparison["genetic_parameter_distance"]
        if (
            isinstance(genetic_distance, bool)
            or not isinstance(genetic_distance, int)
            or not 0 <= genetic_distance <= 400
        ):
            _fail("invalid_promotion_review", "Roster genetic distance is invalid.")
        differences = comparison["measured_behavior_absolute_differences"]
        if not isinstance(differences, dict):
            _fail("invalid_promotion_review", "Roster behavior differences are invalid.")
        require_exact_fields(
            differences,
            MEASURED_BEHAVIOR_FIELDS,
            "roster behavior differences",
        )
        normalized_differences = {}
        for field, difference in differences.items():
            if (
                isinstance(difference, bool)
                or not isinstance(difference, (int, float))
                or not 0.0 <= float(difference) <= 1.0
            ):
                _fail("invalid_promotion_review", "Roster behavior difference is invalid.")
            normalized_differences[field] = float(difference)
        behavior_l1 = comparison["measured_behavior_l1_distance"]
        if (
            isinstance(behavior_l1, bool)
            or not isinstance(behavior_l1, (int, float))
            or not math.isclose(
                float(behavior_l1),
                sum(normalized_differences.values()),
                rel_tol=1e-12,
                abs_tol=1e-12,
            )
        ):
            _fail("invalid_promotion_review", "Roster behavior distance is inconsistent.")
        comparisons.append(
            {
                "first_candidate_id": first_id,
                "genetic_parameter_distance": genetic_distance,
                "measured_behavior_absolute_differences": normalized_differences,
                "measured_behavior_l1_distance": float(behavior_l1),
                "second_candidate_id": second_id,
            }
        )
    expected_pairs = {
        (first_id, second_id)
        for index, first_id in enumerate(candidate_ids)
        for second_id in candidate_ids[index + 1 :]
    }
    if actual_pairs != expected_pairs:
        _fail("invalid_promotion_review", "Roster diversity review is incomplete.")
    return {
        "candidate_ids": candidate_ids,
        "pairwise_comparisons": comparisons,
    }


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
        "roster_diversity": _roster_diversity(confirmations),
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
    roster_diversity = _validate_roster_diversity(plan["roster_diversity"])
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
    if roster_diversity["candidate_ids"] != sorted(seen_ids):
        _fail(
            "invalid_promotion_review",
            "Roster diversity candidates do not match review candidates.",
        )
    return {
        "candidates": candidates,
        "reviewer_id": reviewer_id,
        "roster_diversity": roster_diversity,
    }


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
    expected_roster_diversity = _roster_diversity(confirmations)
    if review["roster_diversity"] != expected_roster_diversity:
        _fail(
            "promotion_review_diversity_mismatch",
            "Roster diversity review differs from the supplied confirmations.",
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
        {
            "decisions": decisions,
            "reviewer_id": review["reviewer_id"],
            "roster_diversity": expected_roster_diversity,
        },
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
    roster_diversity = _validate_roster_diversity(payload["roster_diversity"])
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
    if roster_diversity["candidate_ids"] != sorted(seen_ids):
        _fail(
            "invalid_promotion_review",
            "Roster diversity candidates do not match promotion decisions.",
        )
    return {
        "decisions": decisions,
        "reviewer_id": reviewer_id,
        "roster_diversity": roster_diversity,
    }


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
