#!/usr/bin/env python3
"""Select optional native jobs for the two independent Actions test settings."""
from __future__ import annotations

import json
import os
from pathlib import Path

CHARACTERIZATION_TARGETS = (
    "gui-characterization-supported", "gui-characterization-wide",
    "gui-characterization-phone", "gui-characterization-large-values",
)
INVARIANT_TARGETS = (
    "gui-m3-supported-invariant-gate", "gui-m3-wide-invariant-gate",
    "gui-m3-phone-invariant-gate", "gui-phone-invariant-gate",
    "gui-ipad-invariant-gate", "gui-desktop-invariant-gate",
)
PHONE_TARGET = "gui-phone-table-layout-gate"


def native_targets(run_gui_tests: bool, run_matrix_tests: bool) -> list[str]:
    targets = list(CHARACTERIZATION_TARGETS) if run_matrix_tests else []
    if run_gui_tests:
        targets.append(PHONE_TARGET)
    if run_matrix_tests:
        targets.extend(INVARIANT_TARGETS)
    return targets


def main() -> None:
    targets = native_targets(os.environ.get("RUN_GUI_TESTS", "").lower() == "true",
                             os.environ.get("RUN_GUI_MATRIX_TESTS", "").lower() == "true")
    value = json.dumps(targets)
    print(value, flush=True)
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with Path(output).open("a") as file:
            file.write("targets=" + value + "\n")


if __name__ == "__main__":
    main()
