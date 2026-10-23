"""Structured failures and stable process exit codes."""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
from typing import Any, Mapping


class ExitCode(IntEnum):
    SUCCESS = 0
    INVALID_INPUT = 2
    IO_FAILURE = 3
    INVARIANT_FAILURE = 4


@dataclass(frozen=True)
class ToolError(Exception):
    code: str
    message: str
    exit_code: ExitCode
    details: Mapping[str, Any] | None = None

    def as_object(self) -> dict[str, Any]:
        error: dict[str, Any] = {"code": self.code, "message": self.message}
        if self.details:
            error["details"] = dict(self.details)
        return {"error": error}
