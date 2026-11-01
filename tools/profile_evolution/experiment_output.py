"""Reserve output directories and commit complete experiment artifact sets."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .artifacts import canonical_json_bytes
from .atomic_write import publish_bytes_no_replace
from .errors import ExitCode, ToolError


def publish_documents(
    directory: Path,
    documents: dict[str, dict[str, Any]],
    index_name: str,
    index: dict[str, Any],
    *,
    pretty_names: set[str] | None = None,
) -> None:
    """The index is the readiness marker; failed writes roll back owned files only.

    Reserving the directory prevents replacing even an empty competing directory.
    Every file uses no-clobber publication. Unknown files appearing during a failed
    operation are preserved, as is an index that was committed before fsync failed.
    A publication that raises after linking has uncertain ownership and is left
    uncommitted for inspection; byte equality never establishes ownership.
    """
    encoded = {name: canonical_json_bytes(document) for name, document in documents.items()}
    encoded[index_name] = canonical_json_bytes(index)
    selected = set() if pretty_names is None else set(pretty_names)
    if not selected.issubset(encoded):
        raise ToolError("invalid_pretty_document", "Pretty document names must belong to this output set.", ExitCode.INVALID_INPUT)
    for name in selected:
        document = index if name == index_name else documents[name]
        encoded[name] = (json.dumps(document, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8")
    owned: list[Path] = []
    reserved = False
    try:
        directory.mkdir()
        reserved = True
        for name, contents in encoded.items():
            path = directory / name
            publish_bytes_no_replace(path, contents)
            owned.append(path)
    except OSError as error:
        if reserved and not (directory / index_name).exists():
            for path in reversed(owned):
                try:
                    path.unlink()
                except OSError:
                    pass
            try:
                directory.rmdir()
            except OSError:
                pass
        raise ToolError(
            "experiment_output_failed",
            f"Cannot publish experiment output '{directory}': {error}",
            ExitCode.IO_FAILURE, {"path": str(directory)},
        ) from error
