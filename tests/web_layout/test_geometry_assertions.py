from __future__ import annotations

import copy
import unittest

from tools.web_geometry_assertions import check_geometry


def observation(base=(389, 843), css=(389, 843), backing=(1023, 2215)):
    sx, sy = backing[0] / base[0], backing[1] / base[1]
    snapshot = {"geometry": {"window": {
        "size": list(backing), "display_server_size": list(backing),
        "content_scale_size": list(base), "viewport_visible_rect": [0, 0, *base],
        "final_transform": [sx, 0, 0, sy, 0, 0]},
        "control": {"main_size": list(base)}, "elements": [{
            "role": "action/fold", "text": "Fold", "font_size": 20,
            "effective_font_size": 20, "logical_scale": [1, 1], "interactive": True,
            "target_output_size": [112 * sx, 48 * sy]}]},
        "usable_rect": [0, 0, *base], "invariant_failures": []}
    environment = {"canvas_backing_size": list(backing), "canvas_css_rect": [0, 0, *css]}
    return snapshot, environment


class WebGeometryAssertionsTests(unittest.TestCase):
    def test_actual_fractional_canvas_axes_restore_twenty_and_forty_eight(self):
        snapshot, environment = observation()
        before = copy.deepcopy(snapshot)
        self.assertEqual(check_geometry(snapshot, environment), [])
        self.assertEqual(snapshot, before, "Measurement checks must remain read-only")

    def test_nominal_dpr_base_retains_the_measured_fractional_phone_defect(self):
        snapshot, environment = observation(base=(390, 844))
        failures = check_geometry(snapshot, environment)
        self.assertTrue(any("actual CSS extent" in failure for failure in failures))
        self.assertTrue(any(failure.startswith("font-floor:") for failure in failures))
        self.assertTrue(any(failure.startswith("touch-target:") for failure in failures))

    def test_fractional_css_extents_conservatively_quantize_the_virtual_base(self):
        snapshot, environment = observation(css=(389.875, 843.5))
        self.assertEqual(check_geometry(snapshot, environment), [])

    def test_smaller_transformed_target_is_rejected_despite_nominal_theme_floor(self):
        snapshot, environment = observation()
        snapshot["geometry"]["elements"][0]["target_output_size"][1] *= 0.99
        self.assertTrue(any(failure.startswith("touch-target:")
                            for failure in check_geometry(snapshot, environment)))

    def test_reduced_control_scale_is_rejected_despite_nominal_theme_font(self):
        snapshot, environment = observation()
        snapshot["geometry"]["elements"][0]["effective_font_size"] = 19
        snapshot["geometry"]["elements"][0]["logical_scale"] = [0.95, 0.95]
        self.assertTrue(any(failure.startswith("font-floor:")
                            for failure in check_geometry(snapshot, environment)))

    def test_opposing_canvas_and_control_axes_are_paired_before_taking_font_minimum(self):
        snapshot, environment = observation(css=(389, 843.875))
        element = snapshot["geometry"]["elements"][0]
        element["logical_scale"] = [1, 0.9995]
        element["effective_font_size"] = 19.99
        self.assertEqual(check_geometry(snapshot, environment), [])

    def test_visual_viewport_intersects_safe_area_without_subtracting_bottom_twice(self):
        snapshot, environment = observation()
        snapshot["usable_rect"] = [0, 24, 389, 675]
        self.assertEqual(check_geometry(snapshot, environment, "safe-and-visual"), [])
        snapshot["usable_rect"][3] -= 34
        self.assertTrue(check_geometry(snapshot, environment, "safe-and-visual"))

    def test_asymmetric_inset_origin_cannot_be_discarded(self):
        snapshot, environment = observation()
        snapshot["usable_rect"] = [11, 23, 361, 791]
        self.assertEqual(check_geometry(snapshot, environment, "asymmetric"), [])
        snapshot["usable_rect"][0] = 0
        self.assertTrue(check_geometry(snapshot, environment, "asymmetric"))


    def test_popup_frame_cannot_escape_safe_usable_rect_into_full_viewport(self):
        snapshot, environment = observation()
        snapshot["usable_rect"] = [11, 23, 361, 791]
        snapshot["geometry"]["overlays"] = [{"kind": "keypad", "rect": [11, 23, 361, 791]}]
        self.assertEqual(check_geometry(snapshot, environment, "asymmetric-keypad"), [])
        snapshot["geometry"]["overlays"][0]["rect"][0] = 0
        self.assertTrue(any(failure.startswith("safe-area:") for failure in
                            check_geometry(snapshot, environment, "asymmetric-keypad")))

    def test_only_actual_semantic_rich_text_event_log_has_eighteen_css_floor(self):
        snapshot, environment = observation()
        element = snapshot["geometry"]["elements"][0]
        element.update(role="event", text_kind="rich_text", text="Player calls 10",
                       font_size=18, effective_font_size=18, interactive=False)
        self.assertEqual(check_geometry(snapshot, environment), [])
        for role, kind in (("event/child/0", "rich_text"), ("table/child/8", "rich_text"),
                           ("overlay/keypad/value", "label"), ("board/cards/0/rank", "label"),
                           ("event", "button")):
            element.update(role=role, text_kind=kind)
            self.assertTrue(any(failure.startswith("font-floor:")
                                for failure in check_geometry(snapshot, environment)))
        element.update(role="event", text_kind="rich_text", font_size=17)
        self.assertTrue(any(failure.startswith("font-floor:")
                            for failure in check_geometry(snapshot, environment)))

    def test_event_log_eighteen_floor_still_pairs_transformed_output_axes(self):
        snapshot, environment = observation()
        element = snapshot["geometry"]["elements"][0]
        element.update(role="event", text_kind="rich_text", text="Player folds",
                       font_size=18, effective_font_size=18, interactive=False)
        element["logical_scale"] = [1, 0.99]
        self.assertTrue(any(failure.startswith("font-floor:")
                            for failure in check_geometry(snapshot, environment)))

    def test_only_registered_portrait_seat_labels_use_eighteen_css_pixels(self):
        snapshot, environment = observation()
        snapshot.update(profile=0, surface_size=[389, 843])
        element = snapshot["geometry"]["elements"][0]
        element.update(role="seat/3/name", text_kind="label", text="Priyanka",
                       font_size=18, effective_font_size=18, interactive=False)
        for role in ("seat/3/name", "seat/3/stack", "seat/3/badge", "seat/3/action", "status/3"):
            element["role"] = role
            self.assertEqual(check_geometry(snapshot, environment), [], role)
        for role in ("table/child/1", "seat/3/cards/0/rank", "seat/3/rank",
                     "seat/3/name/child/0", "seat/03/name", "seat/-1/name", "status/3/child/0"):
            element["role"] = role
            self.assertTrue(any(f.startswith("font-floor:") for f in
                                check_geometry(snapshot, environment)), role)
        element["role"] = "seat/3/name"
        for kind in ("button", "input", "rich_text"):
            element["text_kind"] = kind
            self.assertTrue(any(f.startswith("font-floor:") for f in
                                check_geometry(snapshot, environment)), kind)
        element.update(text_kind="label", interactive=True)
        self.assertTrue(any(f.startswith("font-floor:") for f in
                            check_geometry(snapshot, environment)))

    def test_portrait_seat_copy_floor_retains_context_axes_and_target_requirements(self):
        snapshot, environment = observation()
        snapshot.update(profile=0, surface_size=[389, 843])
        element = snapshot["geometry"]["elements"][0]
        element.update(role="seat/3/action", text_kind="label", text="Raise 1000000",
                       font_size=18, effective_font_size=18, interactive=False)
        self.assertEqual(check_geometry(snapshot, environment), [])
        element["logical_scale"] = [1, 0.99]
        self.assertTrue(any(f.startswith("font-floor:") for f in
                            check_geometry(snapshot, environment)))
        element["logical_scale"] = [1, 1]
        for profile, surface in ((1, [843, 389]), (4, [389, 843]), (0, [843, 389])):
            snapshot.update(profile=profile, surface_size=surface)
            self.assertTrue(any(f.startswith("font-floor:") for f in
                                check_geometry(snapshot, environment)))
        snapshot.update(profile=0, surface_size=[389, 843])
        element.update(font_size=20, interactive=True)
        element["target_output_size"][1] *= 0.99
        self.assertTrue(any(f.startswith("touch-target:") for f in
                            check_geometry(snapshot, environment)))
