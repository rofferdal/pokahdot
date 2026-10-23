"""Immutable human-review records for evidence-gated profile promotion."""

from __future__ import annotations

import copy
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


def _fail(code: str, message: str) -> None:
    raise ToolError(code, message, ExitCode.INVALID_INPUT)


def create_promotion_review(
    confirmation_artifact: dict[str, Any],
    reviewer_id: str,
    approved: bool,
    review_note: str,
) -> dict[str, Any]:
    """Record a human decision without publishing a profile or touching a roster."""
    confirmation = validate_confirmation(confirmation_artifact)
    reviewer = require_identifier(reviewer_id, "reviewer_id")
    if not isinstance(approved, bool):
        _fail("invalid_promotion_review", "Promotion review approval must be boolean.")
    if not isinstance(review_note, str) or not review_note.strip():
        _fail("invalid_promotion_review", "Promotion review note must be non-empty.")
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
    checksum = payload["confirmation_checksum"]
    if (
        not isinstance(checksum, str)
        or len(checksum) != 64
        or any(character not in "0123456789abcdef" for character in checksum)
    ):
        _fail("invalid_promotion_review", "Promotion review confirmation checksum is invalid.")
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
    if not isinstance(review_note, str) or not review_note or review_note.strip() != review_note:
        _fail("invalid_promotion_review", "Promotion review note is invalid.")
    return {
        "approved": payload["approved"],
        "candidate": candidate,
        "confirmation_checksum": checksum,
        "promotion_eligible": payload["promotion_eligible"],
        "review_note": review_note,
        "reviewer_id": reviewer_id,
    }
