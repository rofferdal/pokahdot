#!/usr/bin/env python3
"""Keep replacement components free of legacy policies and viewport breakpoints."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SCOPES = ("layout", "view_models", "components", "compositions")
CLASSIFIER = "scripts/gui/layout/gui_size_class.gd"
RESOLVER = "scripts/gui/layout/gui_fit_policy.gd"
LEGACY = re.compile(
    r"\b(?:GuiLayoutProfile|GuiMobileTableLayout|GuiTableLayoutPass|"
    r"GuiSixSeatDesktopPlan|GuiTableSeatLayout|GuiPhoneSeatLayout|"
    r"GuiPhoneLayoutPlan|GuiPhonePortraitTokenPlan|GuiPhoneTokenContentPlan|"
    r"TableSeatLayout)\b|res://scripts/gui/(?:gui_layout_profile|"
    r"gui_mobile_table_layout|gui_table_layout_pass|gui_six_seat_desktop_plan|"
    r"gui_table_seat_layout|gui_phone_seat_layout|gui_phone_layout_plan|"
    r"gui_phone_portrait_token_plan|gui_phone_token_content_plan|table_seat_layout)\.gd"
)
TOKENS = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'|#[^\n]*')
DIMENSION = (
    r"(?<![\w.])(?:_?(?:size|usable_size|surface_size|available|root_size|viewport_size|"
    r"logical_size|full_rect|usable_rect|geometry))\b(?:\.[a-z_]+)*"
)
LITERAL = r"(?:\d+(?:\.\d+)?|[A-Z][A-Z0-9_]+)\b"
THRESHOLDS = (
    re.compile(rf"{DIMENSION}\s*(?:[<>]=?|==|!=)\s*({LITERAL})"),
    re.compile(rf"({LITERAL})\s*(?:[<>]=?|==|!=)\s*{DIMENSION}"),
)


def check_source(source: str, path: str) -> list[str]:
    """Conservative scoped source guard, not a general GDScript parser."""
    imports = TOKENS.sub(lambda match: "" if match[0].startswith("#") else match[0], source)
    code = TOKENS.sub(lambda match: "\n" * match[0].count("\n"), source)
    errors = []
    if LEGACY.search(imports):
        errors.append(f"{path}: replacement code imports a reference layout policy")
    if path == CLASSIFIER:
        return errors
    if path != RESOLVER and re.search(r"\bGuiSizeClass\s*\.\s*classify\s*\(", code):
        errors.append(f"{path}: consume the policy snapshot instead of reclassifying geometry")
    if re.search(r"\b(?:get_viewport_rect|get_window|DisplayServer|JavaScriptBridge)\b", code):
        errors.append(f"{path}: consume adapter geometry instead of reading platform geometry")
    for pattern in THRESHOLDS:
        for match in pattern.finditer(code):
            value = match[1]
            if value.replace(".", "", 1).isdigit() and float(value) == 0:
                continue  # Invalid-size validation is not a global breakpoint.
            errors.append(f"{path}: compare available space with measured content, not {value}")
    return errors


def main() -> int:
    paths = sorted(path for scope in SCOPES
                   for path in (ROOT / "scripts/gui" / scope).rglob("*.gd"))
    errors = [error for path in paths
              for error in check_source(path.read_text(), path.relative_to(ROOT).as_posix())]
    for error in errors:
        print(error, file=sys.stderr)
    print(f"Checked {len(paths)} replacement GUI scripts; {len(errors)} policy violations.")
    return int(bool(errors))


if __name__ == "__main__":
    sys.exit(main())
