"""Manual, no-clobber publication of approved strategy candidates as Godot Resources."""

from __future__ import annotations

import json
import os
import re
import tempfile
from pathlib import Path
from typing import Any

from .confirmation import validate_confirmation
from .errors import ExitCode, ToolError
from .promotion_review import promotion_decision_for_candidate

VERSION_PATTERN = re.compile(r"[a-z0-9][a-z0-9_-]*")
PROFILE_ID_PATTERN = re.compile(r"[a-zA-Z0-9][a-zA-Z0-9_-]*")


def _fail(code: str, message: str, exit_code: ExitCode = ExitCode.INVALID_INPUT) -> None:
    raise ToolError(code, message, exit_code)


def _profile_id(candidate_id: str, version: str) -> str:
    if not isinstance(version, str) or not VERSION_PATTERN.fullmatch(version):
        _fail(
            "invalid_profile_version",
            "Profile version must use lowercase letters, digits, underscores, or hyphens.",
        )
    profile_id = f"{candidate_id}__{version}"
    if not PROFILE_ID_PATTERN.fullmatch(profile_id):
        _fail("invalid_profile_id", "Published profile ID is not a safe resource filename.")
    return profile_id


def _resource_text(profile_id: str, candidate: dict[str, Any], display_name: str) -> str:
    parameters = candidate["parameters"]
    return "\n".join(
        (
            '[gd_resource type="Resource" script_class="BotProfile" load_steps=3 format=3]',
            "",
            '[ext_resource type="Script" path="res://scripts/core/agents/bot_profile.gd" id="1_profile"]',
            '[ext_resource type="Script" path="res://scripts/core/agents/strategy_decision_model_parameters.gd" id="2_params"]',
            "",
            '[sub_resource type="Resource" id="StrategyParameters_published"]',
            'script = ExtResource("2_params")',
            f'tight_vs_loose = {parameters["tight_vs_loose"]}',
            f'passive_vs_aggressive = {parameters["passive_vs_aggressive"]}',
            f'call_vs_raise = {parameters["call_vs_raise"]}',
            f'bluff_rate = {parameters["bluff_rate"]}',
            "",
            "[resource]",
            'script = ExtResource("1_profile")',
            f"profile_id = &{json.dumps(profile_id)}",
            f"model_id = &{json.dumps(candidate['model_id'])}",
            f"display_name = {json.dumps(display_name)}",
            'parameters = SubResource("StrategyParameters_published")',
            "",
        )
    )


def _write_new_file(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        _fail(
            "published_profile_exists",
            f"Published profile '{path}' already exists and cannot be overwritten.",
            ExitCode.INVARIANT_FAILURE,
        )
    try:
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
        )
        temporary = Path(temporary_name)
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(contents)
            stream.flush()
            os.fsync(stream.fileno())
        try:
            os.link(temporary, path)
        except FileExistsError as error:
            _fail(
                "published_profile_exists",
                f"Published profile '{path}' already exists and cannot be overwritten.",
                ExitCode.INVARIANT_FAILURE,
            )
        finally:
            temporary.unlink(missing_ok=True)
    except OSError as error:
        _fail("published_profile_write_failed", f"Cannot publish profile '{path}': {error}", ExitCode.IO_FAILURE)


def publish_approved_profile(
    confirmation_artifact: dict[str, Any],
    review_artifact: dict[str, Any],
    project_root: Path,
    version: str,
    display_name: str | None = None,
) -> dict[str, str]:
    """Publish one approved snapshot without modifying a roster or source profile."""
    confirmation = validate_confirmation(confirmation_artifact)
    candidate_id = confirmation["candidate"]["candidate_id"]
    review = promotion_decision_for_candidate(review_artifact, candidate_id)
    if review["confirmation_checksum"] != confirmation_artifact["checksum"]:
        _fail("promotion_review_mismatch", "Promotion review is bound to another confirmation.")
    if review["candidate"] != confirmation["candidate"]:
        _fail("promotion_review_candidate_mismatch", "Promotion review candidate differs from confirmation.")
    if not confirmation["promotion_eligible"] or not review["promotion_eligible"]:
        _fail("promotion_not_eligible", "Only eligible confirmation evidence may be published.")
    if review["approved"] is not True:
        _fail("promotion_not_approved", "A reviewer must approve promotion before publication.")

    candidate = confirmation["candidate"]
    profile_id = _profile_id(candidate["candidate_id"], version)
    resolved_name = display_name.strip() if isinstance(display_name, str) else ""
    if not resolved_name:
        resolved_name = review.get("display_name", "")
    if not resolved_name:
        resolved_name = f"Promoted {candidate['candidate_id']} {version}"
    root = project_root.resolve()
    output_path = root / "resources" / "bot_profiles" / "published" / f"{profile_id}.tres"
    _write_new_file(output_path, _resource_text(profile_id, candidate, resolved_name))
    return {
        "candidate_id": candidate["candidate_id"],
        "profile_id": profile_id,
        "resource_path": str(output_path),
    }
