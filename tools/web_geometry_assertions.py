"""Validate measured Window-to-CSS geometry without assuming nominal DPR parity."""
from __future__ import annotations

import math
import re

FLOAT_TOLERANCE = 0.0001


def minimum_font_size(element: dict, portrait_seat_copy: bool = False) -> int:
    """Only registered semantic seat Labels may use the portrait copy floor."""
    role = element["role"]
    kind = element.get("text_kind")
    if role == "event" and kind == "rich_text":
        return 18
    if (portrait_seat_copy and kind == "label" and not element.get("interactive", False)
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
    surface = snapshot.get("surface_size", [0, 0])
    portrait_seat_copy = snapshot.get("profile") == 0 and surface[1] > surface[0] > 0
    for element in geometry["elements"]:
        role = element["role"]
        if element["text"] and element["font_size"] > 0:
            axes = [element["font_size"] * element["logical_scale"][axis] * transform[index] * css[axis] / backing[axis]
                    for axis, index in enumerate((0, 3))]
            minimum = minimum_font_size(element, portrait_seat_copy)
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
