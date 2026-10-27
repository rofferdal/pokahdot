"""Serializer-independent, no-clobber publication of complete file contents."""

from __future__ import annotations

import os
import tempfile
from pathlib import Path


def publish_bytes_no_replace(
    destination: Path, contents: bytes, *, sync_parent: bool = True
) -> None:
    """Publish through a sibling hard link; filesystem errors belong to the caller.

    The parent must already exist. A competing destination is never replaced,
    even when it appears after temporary-file creation. A directory-sync error
    can occur after publication and must not remove the published destination.
    """
    temporary_path: Path | None = None
    try:
        descriptor, name = tempfile.mkstemp(
            prefix=f".{destination.name}.", suffix=".tmp", dir=destination.parent
        )
        temporary_path = Path(name)
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(contents)
            stream.flush()
            os.fsync(stream.fileno())
        os.link(temporary_path, destination)
        temporary_path.unlink()
        temporary_path = None
        if sync_parent:
            directory_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
            directory_descriptor = os.open(destination.parent, directory_flags)
            try:
                os.fsync(directory_descriptor)
            finally:
                os.close(directory_descriptor)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)
