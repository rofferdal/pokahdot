"""Protect profiling evidence from empty samples and unexercised workloads."""
import json
import signal
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, call, patch

from tools.profile_gui_refresh import ROOT, WebErrorLog, argument_parser, enrich, fixture_paths, native_case, summarize, terminate_owned_process_group, validate_result


class GuiProfileReportTests(unittest.TestCase):
    def test_native_launch_preserves_results_and_owns_only_its_new_session(self):
        for implementation, players in (("reference", None), ("replacement", 2)):
            with tempfile.TemporaryDirectory(dir=ROOT / "localtmp") as folder:
                work = Path(folder)
                (work / "native-phone-turns.json").write_text(json.dumps({"samples_requested": 120}))
                process = Mock(pid=765432)
                process.wait.return_value = 0

                def spawn(_arguments, **kwargs):
                    kwargs["stdout"].write("1.00 real 0.20 user 0.03 sys\n4096 maximum resident set size\n")
                    return process

                with patch("tools.profile_gui_refresh.subprocess.Popen", side_effect=spawn) as launch, \
                        patch("tools.profile_gui_refresh.os.killpg") as kill:
                    result = native_case("godot", work, "phone", "turns", 120, implementation, players)
                self.assertEqual(result["samples_requested"], 120)
                self.assertEqual(result["native_process_accounting"]["whole_process_seconds"], [1., .2, .03])
                self.assertEqual(result["native_process_accounting"]["whole_process_peak_rss_bytes"], 4096)
                self.assertTrue(launch.call_args.kwargs["start_new_session"])
                self.assertIn(fixture_paths(implementation)[0], launch.call_args.args[0])
                self.assertEqual("--players" in launch.call_args.args[0], players is not None)
                process.wait.assert_called_once_with(timeout=180)
                kill.assert_not_called()

    def test_native_timeout_stops_owned_group_even_when_wrapper_exits_before_its_child(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "localtmp") as folder:
            process = Mock(pid=765432)
            process.wait.side_effect = [subprocess.TimeoutExpired("time", 180), -15, -15]
            with patch("tools.profile_gui_refresh.subprocess.Popen", return_value=process), \
                    patch("tools.profile_gui_refresh.os.killpg") as kill, \
                    patch("tools.profile_gui_refresh.time.monotonic", return_value=10), \
                    patch("tools.profile_gui_refresh.time.sleep") as sleep:
                with self.assertRaisesRegex(RuntimeError, "timed out.*owned process group stopped"):
                    native_case("godot", Path(folder), "phone", "turns", 120)
            self.assertEqual(kill.call_args_list, [call(765432, signal.SIGTERM), call(765432, signal.SIGKILL)])
            self.assertEqual(process.wait.call_args_list, [call(timeout=180), call(timeout=2.), call(timeout=2.)])
            sleep.assert_called_once_with(2.)

    def test_native_failure_is_strict_and_expired_group_is_reaped_without_other_signals(self):
        process = Mock(pid=765432)
        with patch("tools.profile_gui_refresh.os.killpg", side_effect=ProcessLookupError) as kill:
            terminate_owned_process_group(process)
        kill.assert_called_once_with(765432, signal.SIGTERM)
        process.wait.assert_called_once_with(timeout=2.)
        for returncode, text in ((3, ""), (0, "ERROR: engine failure")):
            with tempfile.TemporaryDirectory(dir=ROOT / "localtmp") as folder:
                process = Mock(pid=765432)
                process.wait.return_value = returncode

                def spawn(_arguments, **kwargs):
                    kwargs["stdout"].write(text)
                    return process

                with patch("tools.profile_gui_refresh.subprocess.Popen", side_effect=spawn):
                    with self.assertRaisesRegex(RuntimeError, "Native profiling failed"):
                        native_case("godot", Path(folder), "phone", "turns", 120)

    def test_web_error_summary_is_bounded_and_duplicate_errors_still_fail(self):
        errors = WebErrorLog()
        self.assertFalse(errors)
        for index in range(20):
            errors.add(str(index) + ":" + "x" * 1000)
        errors.add("0:" + "x" * 1000)
        self.assertTrue(errors)
        self.assertEqual(errors.count, 21)
        self.assertEqual(len(errors.messages), 12)
        self.assertTrue(all(len(message) == 500 for message in errors.messages))
    def test_implementation_selection_preserves_reference_default_and_explicit_rosters(self):
        parser = argument_parser()
        defaults = parser.parse_args(["--output", "localtmp/test"])
        self.assertEqual(defaults.implementation, "reference")
        self.assertIsNone(defaults.players)
        selected = parser.parse_args(["--output", "localtmp/test", "--implementation",
                                      "replacement", "--players", "2"])
        self.assertEqual((selected.implementation, selected.players), ("replacement", 2))
        self.assertIn("gui_refresh_native.gd", fixture_paths("reference")[0])
        self.assertIn("gui_replacement_refresh_native.gd", fixture_paths("replacement")[0])
        self.assertNotEqual(fixture_paths("reference")[2], fixture_paths("replacement")[2])
        with self.assertRaises(ValueError):
            fixture_paths("imaginary")

    def test_replacement_requires_settled_outcomes_and_reconciled_probe_counters(self):
        result = self._result("turns")
        result.update(implementation="replacement", input_modality="keypad", settled_latency_usec=[200] * 20,
                      settled_frames=[4] * 20, operation_cpu_usec=[100] * 20,
                      presentation_samples=[{"pending": False, "outcome": "ready"}] * 20,
                      render_counters_after={"composition_mounts": 1, "probe_created": 8,
                                             "probe_freed": 8, "probe_live": 0,
                                             "probe_peak_live": 8})
        validate_result(result, 20)
        result["presentation_samples"] = [
            {"pending": False, "outcome": "guidance", "fit_guidance": "More space needed"}] * 20
        validate_result(result, 20)
        result["presentation_samples"][0] = {"pending": True, "outcome": "ready"}
        with self.assertRaisesRegex(RuntimeError, "did not settle"):
            validate_result(result, 20)
        result["presentation_samples"][0] = {"pending": False, "outcome": "guidance"}
        with self.assertRaisesRegex(RuntimeError, "truthful reason"):
            validate_result(result, 20)
        result["presentation_samples"][0] = {"pending": False, "outcome": "ready"}
        result["render_counters_after"]["probe_live"] = 1
        with self.assertRaisesRegex(RuntimeError, "do not reconcile"):
            validate_result(result, 20)
        result["render_counters_after"]["probe_live"] = 0
        result["settled_latency_usec"][0] = float("nan")
        with self.assertRaisesRegex(RuntimeError, "invalid timing"):
            validate_result(result, 20)
        result["settled_latency_usec"][0] = 200
        result["settled_latency_usec"].pop()
        with self.assertRaisesRegex(RuntimeError, "omitted settled samples"):
            validate_result(result, 20)

    def test_serialized_replacement_report_separates_guidance_from_content_cost(self):
        counters = {"nodes": 1, "static_memory_bytes": 100, "objects": 2}
        probes = {"composition_mounts": 1, "probe_created": 8,
                  "probe_freed": 8, "probe_live": 0, "probe_peak_live": 8}
        result = self._result("turns")
        result.update(implementation="replacement", settled_latency_usec=[1000, 9000],
                      settled_frames=[2, 6], operation_cpu_usec=[100, 500],
                      presentation_samples=[{"outcome": "ready"}, {"outcome": "guidance"}],
                      widget_refresh_usec=[], layout_usec=[], idle={}, node_census=[],
                      counter_samples=[], counters_before=counters, counters_after=counters,
                      render_counters_before=probes, render_counters_after=probes)
        encoded = json.loads(json.dumps(enrich(result)))
        self.assertEqual(encoded["presentation_summary"]["ready"]["samples"], 1)
        self.assertEqual(encoded["presentation_summary"]["ready"]["settled_latency_usec"]["p95"], 1000)
        self.assertEqual(encoded["presentation_summary"]["guidance"]["settled_latency_usec"]["p95"], 9000)
        self.assertEqual(encoded["render_counter_change"]["probe_created"], 0)
        self.assertEqual(encoded["summary_usec"]["widget_refresh_usec"]["p95"], None)
        self.assertEqual(encoded["settled_frames_summary"]["max"], 6)

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
