"""Pure checks for exported six-seat browser observations; no browser dependency."""
from __future__ import annotations

import math

EXPECTED_ORDER = tuple(range(6))
CONTENT_PREFIXES = ("text-clipping:", "font-floor:", "seat-content:", "community-cards:")


def intersects(first: list[float], second: list[float]) -> bool:
    """Godot-style positive-area intersection; touching edges are permitted."""
    x, y, width, height = first
    other_x, other_y, other_width, other_height = second
    return (width > 0 and height > 0 and other_width > 0 and other_height > 0
            and x < other_x + other_width and x + width > other_x
            and y < other_y + other_height and y + height > other_y)


def footprint(seat: dict) -> list[float]:
    x, y, width, height = seat["rect"]
    sx, sy, sw, sh = seat["status_rect"]
    left, top = min(x, sx), min(y, sy)
    return [left, top, max(x + width, sx + sw) - left, max(y + height, sy + sh) - top]


def clockwise_order(snapshot: dict) -> list[int]:
    origin_x, origin_y, width, height = snapshot["surface_rect"]
    def angle(seat: dict) -> float:
        x, y, w, h = seat["rect"]
        return math.atan2(x + w / 2 - origin_x - width / 2, origin_y + height / 2 - y - h / 2)
    origin = angle(next(seat for seat in snapshot["seats"] if seat["seat"] == 0))
    return [seat["seat"] for seat in sorted(snapshot["seats"],
            key=lambda seat: (angle(seat) - origin) % math.tau)]


def geometry_failures(snapshot: dict) -> list[str]:
    failures = []
    seats = snapshot["seats"]
    regions = snapshot["regions"]
    for index, seat in enumerate(seats):
        complete = footprint(seat)
        for other in seats[index + 1:]:
            if intersects(complete, footprint(other)):
                failures.append(f"footprint: seat_{seat['seat']} intersects seat_{other['seat']}")
        for name in ("center", "board", "action", "event", "quit"):
            if intersects(complete, regions[name]):
                failures.append(f"footprint: seat_{seat['seat']} intersects {name}")
    return failures


def order_failures(snapshot: dict) -> list[str]:
    ids = [seat["seat"] for seat in snapshot["seats"]]
    if sorted(ids) != list(EXPECTED_ORDER):
        return [f"clockwise-order: expected unique core seats {list(EXPECTED_ORDER)}, got {ids}"]
    order = clockwise_order(snapshot)
    failures = [] if order == list(EXPECTED_ORDER) else [
        f"clockwise-order: expected {list(EXPECTED_ORDER)}, got {order}"]
    centers = {seat["seat"]: (seat["rect"][1] + seat["rect"][3] / 2)
               for seat in snapshot["seats"]}
    if any(centers[0] <= centers[seat] for seat in EXPECTED_ORDER[1:]):
        failures.append("clockwise-order: human recipient is not below every opponent")
    return failures


def identity_failures(snapshot: dict) -> list[str]:
    """Require actual visible identity/role labels to match the public fixture.

    Observer labels contain visible semantic roles, independent of node names. Complete shaping/fit remains
    independently checked by the engine, including labels that enable ellipsis.
    """
    failures = []
    for seat in snapshot["seats"]:
        prefix = f"seat/{seat['seat']}/"
        labels = [label for label in snapshot["labels"]
                  if label["role"].startswith(prefix)]
        expected = {"name": {seat["name"]},
                    "stack": {str(seat["stack"]), f"{seat['stack']} chips"}}
        for field, values in expected.items():
            candidates = [label for label in labels if label["role"] == prefix + field]
            if len(candidates) != 1 or candidates[0]["text"] not in values:
                failures.append(f"required-content: seat_{seat['seat']} {field} expected "
                                f"{sorted(values)}, got {[label['text'] for label in candidates]}")
        markers = " ".join(marker for marker, key in (
            ("D", "button_seat"), ("SB", "small_blind_seat"), ("BB", "big_blind_seat"))
            if snapshot[key] == seat["seat"])
        # Existing compact presentation uses S/B for SB/BB. Both explicit
        # spellings identify the same public role; wrong-seat roles still fail.
        compact = " ".join({"SB": "S", "BB": "B"}.get(part, part)
                           for part in markers.split())
        allowed_markers = {markers, compact}
        candidates = [label for label in labels
                      if label["role"] in (prefix + "marker", prefix + "badge",
                                           prefix + "badge_row_2", prefix + "badge_row_3")]
        actual = [label["text"] for label in candidates]
        if ((markers and (len(actual) != 1 or actual[0] not in allowed_markers))
                or (not markers and any(actual))):
            failures.append(f"required-content: seat_{seat['seat']} role expected "
                            f"{markers!r}, got {actual}")
    return failures


def check_snapshot(snapshot: dict) -> dict[str, list[str]]:
    """Keep every engine observation; group it only for staged explicit gates.

    Unrecognized engine failures remain geometry failures, so new checks cannot
    silently disappear from the strict gate. The complete raw list is untouched.
    """
    raw = snapshot["invariant_failures"]
    if snapshot.get("schema_version") == 2:
        identity = identity_failures(snapshot)
        contract = []
        if snapshot.get("fit_guidance"):
            contract.append("supported-fit: replacement rendered guidance")
        if not snapshot.get("ready") or snapshot.get("pending"):
            contract.append("layout-readiness: replacement snapshot is not settled")
        return {"geometry": list(raw), "content": identity,
                "order": [], "all": list(raw) + identity + contract}
    content = [failure for failure in raw if failure.startswith(CONTENT_PREFIXES)]
    identity = identity_failures(snapshot)
    content += identity
    geometry = [failure for failure in raw if not failure.startswith(CONTENT_PREFIXES)]
    geometry += geometry_failures(snapshot)
    order = order_failures(snapshot)
    return {"geometry": geometry, "content": content, "order": order,
            "all": list(raw) + geometry_failures(snapshot) + identity + order}
