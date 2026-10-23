"""Review-only export of independently confirmed candidates."""

from __future__ import annotations

import copy
from typing import Any, Iterable

from .artifacts import create_artifact
from .confirmation import validate_confirmation
from .contracts import validate_candidate
from .errors import ExitCode, ToolError
from .lineage import validate_lineage_registry


def export_candidates(
    registry_artifact: dict[str, Any],
    confirmation_artifacts: Iterable[dict[str, Any]],
    candidate_ids: Iterable[str],
) -> dict[str, Any]:
    registry = validate_lineage_registry(registry_artifact)
    requested = list(candidate_ids)
    if not requested or len(set(requested)) != len(requested):
        raise ToolError(
            "invalid_export_candidates",
            "Export candidate IDs must be non-empty and unique.",
            ExitCode.INVALID_INPUT,
        )
    confirmations: dict[str, tuple[dict[str, Any], str]] = {}
    for artifact in confirmation_artifacts:
        payload = validate_confirmation(artifact)
        candidate = validate_candidate(payload["candidate"])
        candidate_id = candidate["candidate_id"]
        if candidate_id in confirmations:
            raise ToolError(
                "duplicate_confirmation",
                f"Candidate '{candidate_id}' has more than one confirmation artifact.",
                ExitCode.INVALID_INPUT,
            )
        confirmations[candidate_id] = (payload, artifact["checksum"])
    exported = []
    for candidate_id in requested:
        if candidate_id not in registry["entries"] or candidate_id not in confirmations:
            raise ToolError(
                "missing_export_evidence",
                f"Candidate '{candidate_id}' lacks lineage or confirmation evidence.",
                ExitCode.INVALID_INPUT,
            )
        entry = registry["entries"][candidate_id]
        confirmation, confirmation_checksum = confirmations[candidate_id]
        if confirmation["registry_checksum"] != registry_artifact["checksum"]:
            raise ToolError(
                "confirmation_registry_mismatch",
                f"Candidate '{candidate_id}' confirmation references another registry.",
                ExitCode.INVALID_INPUT,
            )
        if confirmation["candidate"] != entry["candidate"]:
            raise ToolError(
                "confirmation_candidate_mismatch",
                f"Candidate '{candidate_id}' confirmation snapshot differs from lineage.",
                ExitCode.INVALID_INPUT,
            )
        opponents = {
            profile["profile_id"]: profile for profile in confirmation["opponent_profiles"]
        }
        for champion_id in confirmation["historical_champion_ids"]:
            if champion_id not in registry["entries"]:
                raise ToolError(
                    "confirmation_champion_missing",
                    f"Historical champion '{champion_id}' is absent from lineage.",
                    ExitCode.INVALID_INPUT,
                )
            champion = registry["entries"][champion_id]["candidate"]
            expected_profile = {
                "profile_id": champion["candidate_id"],
                "model_id": champion["model_id"],
                "parameters": champion["parameters"],
            }
            if opponents.get(champion_id) != expected_profile:
                raise ToolError(
                    "confirmation_champion_mismatch",
                    f"Historical champion '{champion_id}' snapshot differs from lineage.",
                    ExitCode.INVALID_INPUT,
                )
        if not confirmation["promotion_eligible"]:
            raise ToolError(
                "candidate_not_confirmed",
                f"Candidate '{candidate_id}' did not pass independent confirmation.",
                ExitCode.INVALID_INPUT,
                {"reasons": confirmation["ineligibility_reasons"]},
            )
        exported.append(
            {
                "candidate": copy.deepcopy(entry["candidate"]),
                "confirmation": copy.deepcopy(confirmation),
                "confirmation_checksum": confirmation_checksum,
                "lineage_entry": copy.deepcopy(entry),
            }
        )
    return create_artifact(
        "candidate_bundle",
        {
            "candidates": exported,
            "purpose": "review_only",
            "registry_checksum": registry_artifact["checksum"],
        },
    )
