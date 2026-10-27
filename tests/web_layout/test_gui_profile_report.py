"""Protect profiling evidence from empty samples and unexercised workloads."""
import unittest

from tools.profile_gui_refresh import summarize, validate_result


class GuiProfileReportTests(unittest.TestCase):
    def test_empty_measurements_stay_missing_instead_of_claiming_zero_cost(self):
        self.assertEqual(summarize([]), {"n": 0, "p50": None, "p95": None, "max": None})

    def test_nearest_rank_percentiles_keep_tail_and_single_sample(self):
        self.assertEqual(summarize(list(range(20, 0, -1))),
                         {"n": 20, "p50": 10, "p95": 19, "max": 20})
        self.assertEqual(summarize([8]), {"n": 1, "p50": 8, "p95": 8, "max": 8})

    def test_resize_rejects_unmeasured_or_single_profile_layout(self):
        result = self._result("resize")
        result.update(layout_usec=[], selected_layouts=[])
        with self.assertRaisesRegex(RuntimeError, "actual profile transitions"):
            validate_result(result, 20)
        result.update(layout_usec=[100], selected_layouts=[
            {"profile": 0, "requested": [390, 844]},
            {"profile": 0, "requested": [398, 852]},
            {"profile": 0, "requested": [406, 860]}])
        with self.assertRaisesRegex(RuntimeError, "actual profile transitions"):
            validate_result(result, 20)

    def test_runout_rejects_missing_streets_and_missing_settlement(self):
        result = self._result("runouts")
        result.update(streets_observed={"preflop": 20}, completed_hands_observed=0)
        with self.assertRaisesRegex(RuntimeError, "every dealt street"):
            validate_result(result, 20)
        result["streets_observed"].update(flop=1, turn=1, river=1)
        with self.assertRaisesRegex(RuntimeError, "complete a real hand"):
            validate_result(result, 20)
        result["completed_hands_observed"] = 1
        validate_result(result, 20)

    def test_privacy_failure_cannot_be_published_as_success(self):
        result = self._result("turns")
        result["failures"] = ["Unrevealed opponent card rendered"]
        with self.assertRaisesRegex(RuntimeError, "privacy/core failures"):
            validate_result(result, 20)

    @staticmethod
    def _result(scenario):
        return {"scenario": scenario, "failures": [], "refresh_usec": [100] * 20,
                "active": {"step_to_post_draw_usec": [100] * 20}}
