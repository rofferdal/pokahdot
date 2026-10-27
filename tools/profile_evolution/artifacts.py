"""Strict JSON and immutable artifact persistence boundaries."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from typing import Any, Iterable

from .atomic_write import publish_bytes_no_replace
from .errors import ExitCode, ToolError

ARTIFACT_SCHEMA_VERSION = 1
TOOL_VERSION = "0.1.0"
_ENVELOPE_FIELDS = frozenset(
    {"schema_version", "type", "tool_version", "payload", "checksum"}
)


def _reject_duplicate_keys(pairs: Iterable[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate object key: {key}")
        result[key] = value
    return result


def _reject_non_finite(value: str) -> None:
    raise ValueError(f"non-finite number is not valid JSON: {value}")


def canonical_json_bytes(value: Any) -> bytes:
    """Return deterministic compact UTF-8 JSON terminated by one newline."""
    try:
        document = json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
    except (TypeError, ValueError) as error:
        raise ToolError(
            "invalid_json_value",
            f"Value cannot be represented as canonical JSON: {error}",
            ExitCode.INVALID_INPUT,
        ) from error
    return (document + "\n").encode("utf-8")


def load_json_object(path: str | os.PathLike[str]) -> dict[str, Any]:
    """Load a strict UTF-8 JSON document whose root must be an object."""
    source = Path(path)
    try:
        raw = source.read_bytes()
    except OSError as error:
        raise ToolError(
            "input_read_failed",
            f"Cannot read JSON input '{source}': {error}",
            ExitCode.IO_FAILURE,
            {"path": str(source)},
        ) from error
    try:
        text = raw.decode("utf-8")
        value = json.loads(
            text,
            object_pairs_hook=_reject_duplicate_keys,
            parse_constant=_reject_non_finite,
        )
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
        raise ToolError(
            "invalid_json",
            f"Invalid strict JSON in '{source}': {error}",
            ExitCode.INVALID_INPUT,
            {"path": str(source)},
        ) from error
    if not isinstance(value, dict):
        raise ToolError(
            "json_root_not_object",
            f"JSON input '{source}' must contain an object at its root.",
            ExitCode.INVALID_INPUT,
            {"path": str(source)},
        )
    return value


def load_artifact(
    path: str | os.PathLike[str], expected_type: str | None = None
) -> dict[str, Any]:
    artifact = load_json_object(path)
    validate_artifact_envelope(artifact, expected_type)
    return artifact


def artifact_checksum(artifact: dict[str, Any]) -> str:
    """Hash the canonical envelope with the checksum member omitted."""
    checksum_input = dict(artifact)
    checksum_input.pop("checksum", None)
    return hashlib.sha256(canonical_json_bytes(checksum_input)).hexdigest()


def create_artifact(artifact_type: str, payload: dict[str, Any]) -> dict[str, Any]:
    if not artifact_type or not isinstance(artifact_type, str):
        raise ToolError(
            "invalid_artifact_type",
            "Artifact type must be a non-empty string.",
            ExitCode.INVALID_INPUT,
        )
    if not isinstance(payload, dict):
        raise ToolError(
            "invalid_artifact_payload",
            "Artifact payload must be an object.",
            ExitCode.INVALID_INPUT,
        )
    artifact: dict[str, Any] = {
        "schema_version": ARTIFACT_SCHEMA_VERSION,
        "type": artifact_type,
        "tool_version": TOOL_VERSION,
        "payload": payload,
    }
    artifact["checksum"] = artifact_checksum(artifact)
    return artifact


def validate_artifact_envelope(
    artifact: dict[str, Any], expected_type: str | None = None
) -> None:
    unknown = sorted(set(artifact) - _ENVELOPE_FIELDS)
    missing = sorted(_ENVELOPE_FIELDS - set(artifact))
    if unknown or missing:
        raise ToolError(
            "invalid_artifact_envelope",
            "Artifact envelope fields do not match the schema.",
            ExitCode.INVALID_INPUT,
            {"missing_fields": missing, "unknown_fields": unknown},
        )
    if artifact["schema_version"] != ARTIFACT_SCHEMA_VERSION:
        raise ToolError(
            "unsupported_artifact_schema",
            "Artifact schema version is not supported.",
            ExitCode.INVALID_INPUT,
        )
    if artifact["tool_version"] != TOOL_VERSION:
        raise ToolError(
            "unsupported_tool_version",
            "Artifact tool version is not supported.",
            ExitCode.INVALID_INPUT,
        )
    if not isinstance(artifact["type"], str) or not isinstance(
        artifact["tool_version"], str
    ) or not isinstance(artifact["payload"], dict) or not isinstance(
        artifact["checksum"], str
    ):
        raise ToolError(
            "invalid_artifact_envelope",
            "Artifact envelope field types are invalid.",
            ExitCode.INVALID_INPUT,
        )
    if expected_type is not None and artifact["type"] != expected_type:
        raise ToolError(
            "unexpected_artifact_type",
            f"Expected artifact type '{expected_type}'.",
            ExitCode.INVALID_INPUT,
        )
    if artifact["checksum"] != artifact_checksum(artifact):
        raise ToolError(
            "artifact_checksum_mismatch",
            "Artifact checksum does not match its canonical content.",
            ExitCode.INVALID_INPUT,
        )


def write_artifact_atomic(
    path: str | os.PathLike[str], artifact: dict[str, Any]
) -> None:
    """Atomically publish an artifact without replacing an existing target."""
    destination = Path(path)
    parent = destination.parent
    if not parent.is_dir():
        raise ToolError(
            "output_directory_missing",
            f"Output directory does not exist: '{parent}'.",
            ExitCode.IO_FAILURE,
            {"path": str(parent)},
        )
    try:
        publish_bytes_no_replace(destination, canonical_json_bytes(artifact))
    except FileExistsError as error:
        raise ToolError(
            "output_exists",
            f"Output already exists: '{destination}'.",
            ExitCode.IO_FAILURE,
            {"path": str(destination)},
        ) from error
    except OSError as error:
        raise ToolError(
            "output_write_failed",
            f"Cannot write output '{destination}': {error}",
            ExitCode.IO_FAILURE,
            {"path": str(destination)},
        ) from error
