"""Validate measured Window-to-CSS geometry without assuming nominal DPR parity."""
from __future__ import annotations

import math
import re

FLOAT_TOLERANCE = 0.0001
FONT_METRIC_TOLERANCE = 0.5


def minimum_font_size(element: dict) -> int:
    """Only registered semantic seat Labels may use the shared seat-copy floor."""
    role = element["role"]
    kind = element.get("text_kind")
    if role == "event" and kind == "rich_text":
        return 18
    if (kind == "label" and not element.get("interactive", False)
            and re.fullmatch(r"(?:status/(?:0|[1-9][0-9]*)|seat/(?:0|[1-9][0-9]*)/(?:name|stack|badge|badge_row_2|badge_row_3|marker|action))", role)):
        return 18
    return 20


def check_geometry(snapshot: dict, environment: dict, preset: str = "ordinary") -> list[str]:
    """Use actual canvas axes for text/target floors and inspect detached values only."""
    failures: list[str] = []
    geometry = snapshot["geometry"]
    window = geometry["window"]
    backing = environment["canvas_backing_size"]
    css = environment["canvas_css_rect"][2:]
    if min(*backing, *css) <= 0:
        return ["geometry: canvas is not initialized"]
    base = [math.floor(size) for size in css]
    if window["size"] != backing or window["display_server_size"] != backing:
        failures.append("geometry: Window/DisplayServer does not match backing size")
    if window["content_scale_size"] != base:
        failures.append("geometry: virtual base does not use actual CSS extent")
    if window["viewport_visible_rect"][2:] != base:
        failures.append("geometry: visible logical viewport does not match CSS base")
    if geometry["control"]["main_size"] != base:
        failures.append("geometry: application root does not match CSS base")
    expected_usable = [0, 0, *base]
    if preset in ("asymmetric", "asymmetric-keypad"):
        expected_usable = [11, 23, base[0] - 28, base[1] - 52]
    elif preset == "safe-and-visual":
        expected_usable = [0, 24, base[0], base[1] - 168]
    elif preset != "ordinary":
        raise ValueError(f"Unknown geometry preset: {preset}")
    if any(abs(actual - expected) > FLOAT_TOLERANCE
           for actual, expected in zip(snapshot["usable_rect"], expected_usable)):
        failures.append("geometry: usable rectangle loses origin or applies reductions twice")
    ux, uy, uw, uh = expected_usable
    for overlay in geometry.get("overlays", []):
        x, y, width, height = overlay["rect"]
        if (x < ux - FLOAT_TOLERANCE or y < uy - FLOAT_TOLERANCE
                or x + width > ux + uw + FLOAT_TOLERANCE
                or y + height > uy + uh + FLOAT_TOLERANCE):
            failures.append(f"safe-area: {overlay['kind']} is outside usable geometry")
    transform = window["final_transform"]
    for element in geometry["elements"]:
        role = element["role"]
        if element["text"] and element["font_size"] > 0:
            axes = [element["font_size"] * element["logical_scale"][axis] * transform[index] * css[axis] / backing[axis]
                    for axis, index in enumerate((0, 3))]
            minimum = minimum_font_size(element)
            if min(axes) < minimum - FLOAT_TOLERANCE:
                failures.append(f"font-floor: {role} displays {axes} CSS pixels")
        if element["interactive"]:
            size = [element["target_output_size"][axis] * css[axis] / backing[axis]
                    for axis in (0, 1)]
            if min(size) < 48 - FLOAT_TOLERANCE:
                failures.append(f"touch-target: {role} displays {size} CSS pixels")
    if snapshot["invariant_failures"]:
        failures.extend(snapshot["invariant_failures"])
    return failures


def check_default_font_metrics(snapshot: dict, native: dict) -> list[str]:
    """Compare real Godot metrics while allowing only sub-pixel raster rounding."""
    failures: list[str] = []
    exported = snapshot.get("default_font_metrics", {})
    if not exported.get("built_in") or exported.get("resource_path"):
        failures.append("default-font: exported layout does not use the built-in font")
    if not native.get("built_in") or native.get("resource_path"):
        failures.append("default-font: headless probe does not use the built-in font")
    native_by_id = {item["id"]: item for item in native.get("specimens", [])}
    for item in exported.get("specimens", []):
        reference = native_by_id.get(item["id"])
        if reference is None:
            failures.append(f"default-font: native specimen {item['id']} is missing")
            continue
        for axis in ("width", "height"):
            if abs(item[axis] - reference[axis]) > FONT_METRIC_TOLERANCE:
                failures.append(
                    f"default-font: {item['id']} {axis} differs "
                    f"({item[axis]} Web vs {reference[axis]} headless)"
                )
    if len(exported.get("specimens", [])) != len(native_by_id):
        failures.append("default-font: exported and native specimen sets differ")
    return failures


def check_font_stress_copy(snapshot: dict) -> list[str]:
    """Require the RG-62 stress strings to fit their real semantic allocations."""
    failures: list[str] = []
    elements = {item["role"]: item for item in snapshot["geometry"]["elements"]}
    expected = {
        "seat/1/name": lambda text: text == "Annalise",
        "seat/1/stack": lambda text: text == "1000000",
        "seat/1/action": lambda text: text.endswith("1000000"),
        "action/check_call": lambda text: text == "Call 1000000",
    }
    for role, predicate in expected.items():
        element = elements.get(role)
        if element is None or not predicate(element.get("text", "")):
            failures.append(f"font-stress: {role} does not expose the exact stress copy")
            continue
        required = element["required_size"]
        allocated = element["allocated_size"]
        if any(required[axis] > allocated[axis] + FONT_METRIC_TOLERANCE
               for axis in (0, 1)):
            failures.append(f"font-stress: {role} exceeds its actual allocation")
    return failures
