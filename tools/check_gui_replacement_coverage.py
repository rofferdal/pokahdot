#!/usr/bin/env python3
"""Validate RG-60's legacy-to-replacement coverage map and observer isolation."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "tests/fixtures/gui_replacement_coverage.json"
FORBIDDEN = (
    "PokerTableController",
    "res://scenes/poker_table.tscn",
    "gui_reference_fixture_driver.gd",
    "gui_layout_profile.gd",
    "gui_table_layout_pass.gd",
    "gui_mobile_table_layout.gd",
    "gui_table_seat_layout.gd",
    "table_seat_layout.gd",
)


def contains_legacy_token(text: str, token: str) -> bool:
    if token == "PokerTableController":
        return re.search(r"\bPokerTableController\b", text) is not None
    return token in text


def validate(payload: dict) -> list[str]:
    errors: list[str] = []
    if payload.get("schema_version") != 1:
        errors.append("coverage map must use schema_version 1")
    families = payload.get("legacy_families")
    if not isinstance(families, list) or not families:
        errors.append("coverage map must declare legacy_families")
        families = []
    mapped_checks: set[str] = set()
    for index, family in enumerate(families):
        if not isinstance(family, dict) or not family.get("contract"):
            errors.append(f"legacy_families[{index}] needs a contract")
            continue
        if "retired" in family and not isinstance(family["retired"], bool):
            errors.append(f"{family['contract']}: retired must be a boolean")
        for field in ("legacy_tests", "replacement_checks"):
            values = family.get(field)
            if not isinstance(values, list) or not values:
                errors.append(f"{family['contract']}: {field} must be non-empty")
                continue
            for relative in values:
                if (not isinstance(relative, str) or not relative
                        or Path(relative).is_absolute() or ".." in Path(relative).parts):
                    errors.append(f"{family['contract']}: invalid repository path {relative!r}")
                elif field == "legacy_tests" and family.get("retired") is True:
                    continue  # Historical path names remain recorded after retirement.
                elif not (ROOT / relative).is_file():
                    errors.append(f"{family['contract']}: missing repository path {relative!r}")
                elif field == "replacement_checks":
                    mapped_checks.add(relative)
    observers = payload.get("independent_observers")
    if not isinstance(observers, list) or not observers:
        errors.append("coverage map must declare independent_observers")
        observers = []
    for relative in observers:
        path = ROOT / relative
        if relative not in mapped_checks:
            errors.append(f"independent observer is not mapped to a contract: {relative}")
        if not path.is_file():
            errors.append(f"missing independent observer: {relative}")
            continue
        text = path.read_text()
        for token in FORBIDDEN:
            if contains_legacy_token(text, token):
                errors.append(f"{relative}: replacement observer imports legacy token {token}")
    return errors


def main() -> int:
    errors = validate(json.loads(MAP.read_text()))
    if errors:
        print("Replacement GUI coverage check failed:")
        for error in errors:
            print("- " + error)
        return 1
    print("Replacement GUI coverage map and independent observers verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
