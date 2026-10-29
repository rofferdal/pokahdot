from __future__ import annotations

import copy
import unittest

from tools.web_layout_assertions import check_snapshot, clockwise_order, intersects


def observation() -> dict:
    # Six seats around the perimeter, hero bottom, increasing clockwise IDs.
    positions = [(45, 85), (5, 65), (5, 15), (45, 0), (85, 15), (85, 65)]
    return {"surface_rect": [0, 0, 100, 100],
            "button_seat": 0, "small_blind_seat": 1, "big_blind_seat": 2,
            "labels": [{"role": f"seat/{seat}/{field}", "text": text}
                       for seat in range(6) for field, text in (
                           ("name", f"Name{seat}"), ("stack", "1000 chips"),
                           ("marker", {0: "D", 1: "SB", 2: "BB"}.get(seat, "")))],
            "seats": [{"seat": seat, "name": f"Name{seat}", "stack": 1000,
                       "rect": [x, y, 10, 8],
                       "status_rect": [x, y + 9, 10, 2]}
                      for seat, (x, y) in enumerate(positions)],
            "regions": {key: [40, 40, 20, 10]
                for key in ("center", "board", "action", "event", "quit")},
            "invariant_failures": []}


class BrowserLayoutAssertionTests(unittest.TestCase):
    def test_clear_surface_has_no_failures_and_does_not_depend_on_global_origin(self):
        snapshot = observation()
        self.assertEqual(clockwise_order(snapshot), list(range(6)))
        self.assertTrue(all(not failures for failures in check_snapshot(snapshot).values()))
        # Every rectangle shares viewport units, including nonzero usable origin.
        for rect in [snapshot["surface_rect"], *snapshot["regions"].values(),
                     *(seat[key] for seat in snapshot["seats"] for key in ("rect", "status_rect"))]:
            rect[0] -= 999
            rect[1] += 888
        self.assertEqual(clockwise_order(snapshot), list(range(6)))

    def test_touching_edges_and_empty_regions_are_allowed(self):
        self.assertFalse(intersects([0, 0, 10, 10], [10, 0, 10, 10]))
        self.assertFalse(intersects([0, 0, 10, 10], [1, 1, 0, 5]))
        self.assertTrue(intersects([0, 0, 10, 10], [9, 9, 1, 1]))

    def test_reserved_status_band_collision_fails_even_if_seat_panels_are_clear(self):
        snapshot = observation()
        snapshot["seats"][1]["status_rect"] = snapshot["seats"][2]["rect"].copy()
        failures = check_snapshot(snapshot)["geometry"]
        self.assertIn("footprint: seat_1 intersects seat_2", failures)

    def test_complete_footprint_reserves_gap_between_panel_and_status(self):
        snapshot = observation()
        snapshot["seats"][0]["status_rect"] = [45, 99, 10, 1]
        snapshot["regions"]["action"] = [45, 94, 10, 2]
        self.assertIn("footprint: seat_0 intersects action", check_snapshot(snapshot)["geometry"])

    def test_each_protected_major_region_is_checked(self):
        for region in ("center", "board", "action", "event", "quit"):
            with self.subTest(region=region):
                snapshot = observation()
                snapshot["regions"][region] = [45, 85, 1, 1]
                self.assertIn(f"footprint: seat_0 intersects {region}",
                              check_snapshot(snapshot)["geometry"])

    def test_pair_reversal_and_nonadjacent_displacement_fail_complete_order(self):
        for first, second in ((1, 2), (4, 5), (1, 4)):
            with self.subTest(pair=(first, second)):
                snapshot = observation()
                a, b = snapshot["seats"][first], snapshot["seats"][second]
                a["rect"], b["rect"] = b["rect"], a["rect"]
                self.assertTrue(check_snapshot(snapshot)["order"])

    def test_missing_and_duplicate_core_seats_fail_without_inventing_order(self):
        for ids in ((0, 1, 2, 3, 4), (0, 1, 2, 3, 4, 4)):
            snapshot = observation()
            snapshot["seats"] = [dict(snapshot["seats"][index], seat=seat)
                                 for index, seat in enumerate(ids)]
            self.assertIn("expected unique core seats", check_snapshot(snapshot)["order"][0])

    def test_human_recipient_must_remain_below_opponents(self):
        snapshot = observation()
        snapshot["seats"][0]["rect"][1] = 1
        self.assertIn("clockwise-order: human recipient is not below every opponent",
                      check_snapshot(snapshot)["order"])

    def test_missing_or_misbound_visible_identity_fields_fail(self):
        for field in ("name", "stack", "marker"):
            for mutation in ("missing", "wrong", "duplicate"):
                with self.subTest(field=field, mutation=mutation):
                    snapshot = observation()
                    index = next(index for index, label in enumerate(snapshot["labels"])
                                 if label["role"] == f"seat/0/{field}")
                    if mutation == "missing":
                        snapshot["labels"].pop(index)
                    elif mutation == "wrong":
                        snapshot["labels"][index]["text"] = "Wrong"
                    else:
                        snapshot["labels"].append(dict(snapshot["labels"][index]))
                    self.assertTrue(check_snapshot(snapshot)["content"])

    def test_stack_suffix_is_optional_but_decimal_must_be_complete(self):
        snapshot = observation()
        stack = next(label for label in snapshot["labels"]
                     if label["role"] == "seat/0/stack")
        stack["text"] = "1000"
        self.assertFalse(check_snapshot(snapshot)["content"])
        for text in ("100", "1k", "1000 ch", "1000…"):
            stack["text"] = text
            self.assertTrue(check_snapshot(snapshot)["content"])

    def test_role_badge_follows_public_ids_and_combined_roles(self):
        snapshot = observation()
        snapshot["small_blind_seat"] = 0
        for label in snapshot["labels"]:
            if label["role"] == "seat/0/marker":
                label["role"] = "seat/0/badge"
                label["text"] = "D SB"
            elif label["role"] == "seat/1/marker":
                label["text"] = ""
        self.assertFalse(check_snapshot(snapshot)["content"])
        snapshot["button_seat"] = 1
        self.assertTrue(check_snapshot(snapshot)["content"])

    def test_existing_compact_role_aliases_preserve_public_identity(self):
        snapshot = observation()
        for label in snapshot["labels"]:
            if label["role"].endswith("/marker"):
                label["text"] = {"SB": "S", "BB": "B"}.get(label["text"], label["text"])
        self.assertFalse(check_snapshot(snapshot)["content"])
        next(label for label in snapshot["labels"]
             if label["role"] == "seat/1/marker")["text"] = "B"
        self.assertTrue(check_snapshot(snapshot)["content"])

    def test_raw_engine_failures_remain_complete_and_input_is_not_mutated(self):
        snapshot = observation()
        raw = ["text-clipping: Name", "font-floor: Name", "containment: action",
               "future-invariant: do not drop"]
        snapshot["invariant_failures"] = raw
        original = copy.deepcopy(snapshot)
        checked = check_snapshot(snapshot)
        self.assertEqual(checked["content"], raw[:2])
        self.assertEqual(checked["geometry"], raw[2:])
        self.assertEqual(checked["all"], raw)
        self.assertEqual(snapshot, original)


if __name__ == "__main__":
    unittest.main()
