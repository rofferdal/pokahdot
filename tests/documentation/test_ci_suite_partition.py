"""Ensure quality plus the phone job cover all configured non-matrix scripts."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("ci_gut", ROOT / "tools/run_ci_gut.py")
CI_GUT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CI_GUT)


class CiSuitePartitionTests(unittest.TestCase):
    def test_real_partition_preserves_configured_non_matrix_scripts_and_options(self):
        original = json.loads((ROOT / ".gutconfig.json").read_text())
        result = CI_GUT.quality_config(ROOT, original, run_gui_tests=True)
        expected = set(original.get("tests", []))
        for directory in original["dirs"]:
            folder = ROOT / directory.removeprefix("res://")
            expected.update("res://" + path.relative_to(ROOT).as_posix()
                            for path in folder.rglob("test_*.gd"))
        expected = {path for path in expected if not path.endswith("_matrix_runner.gd")}
        self.assertEqual(set(result["tests"]) | {CI_GUT.PHONE_SUITE}, expected)
        self.assertNotIn(CI_GUT.PHONE_SUITE, result["tests"])
        self.assertFalse(any(path.endswith("_matrix_runner.gd") for path in result["tests"]))
        self.assertEqual(len(result["tests"]), len(set(result["tests"])))
        self.assertEqual(result["dirs"], [])
        self.assertEqual(result["should_exit"], original["should_exit"])
        self.assertTrue(original["dirs"], "Partition must not mutate the source config")

    def test_new_scripts_explicit_scripts_and_discovery_options_are_preserved(self):
        output = ROOT / "localtmp/ci-layout"
        output.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=output) as directory:
            root = Path(directory)
            phone = root / CI_GUT.PHONE_SUITE.removeprefix("res://")
            phone.parent.mkdir(parents=True)
            phone.touch()
            (phone.parent / "test_future.gd").touch()
            (phone.parent / "test_slow_matrix_runner.gd").touch()
            nested = phone.parent / "nested"
            nested.mkdir()
            (nested / "test_nested.gd").touch()
            config = {"dirs": ["res://tests/unit/"], "include_subdirs": True,
                      "tests": ["res://explicit.gd", "res://explicit_matrix_runner.gd"], "log_level": 3}
            result = CI_GUT.quality_config(root, config, run_gui_tests=True)
            self.assertEqual(result["tests"], ["res://explicit.gd",
                             "res://tests/unit/nested/test_nested.gd",
                             "res://tests/unit/test_future.gd"])
            self.assertEqual(result["log_level"], 3)
            config["include_subdirs"] = False
            self.assertNotIn("res://tests/unit/nested/test_nested.gd",
                             CI_GUT.quality_config(root, config, run_gui_tests=True)["tests"])

    def test_gui_suites_are_excluded_by_default_and_can_be_enabled(self):
        original = json.loads((ROOT / ".gutconfig.json").read_text())
        disabled = CI_GUT.quality_config(ROOT, original)
        enabled = CI_GUT.quality_config(ROOT, original, run_gui_tests=True)
        self.assertFalse(any(Path(path).name.startswith("test_gui_")
                             for path in disabled["tests"]))
        expected = [path for path in enabled["tests"]
                    if not Path(path).name.startswith("test_gui_")]
        self.assertEqual(disabled["tests"], expected)
        self.assertGreater(len(enabled["tests"]), len(disabled["tests"]))

    def test_missing_phone_suite_or_empty_quality_partition_fail_closed(self):
        with self.assertRaisesRegex(ValueError, "was not discovered"):
            CI_GUT.quality_config(ROOT, {"dirs": [], "tests": ["res://other.gd"]}, run_gui_tests=True)
        with self.assertRaisesRegex(ValueError, "must not be empty"):
            CI_GUT.quality_config(ROOT, {"dirs": [], "tests": [CI_GUT.PHONE_SUITE]})

    def test_runner_creates_config_before_launch_in_a_fresh_project(self):
        output = ROOT / "localtmp"
        output.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=output) as directory:
            root = Path(directory)
            (root / ".gutconfig.json").write_text(json.dumps({
                "dirs": [], "tests": ["res://tests/unit/test_example.gd"],
                "should_exit": True,
            }))
            config_path = root / "localtmp/ci-layout/quality.gutconfig.json"
            self.assertFalse((root / "localtmp").exists())

            def launch(command, **kwargs):
                config = json.loads(config_path.read_text())
                self.assertEqual(config["tests"], ["res://tests/unit/test_example.gd"])
                self.assertEqual(config["junit_xml_file"], "res://localtmp/ci-layout/quality.xml")
                self.assertIn("-gconfig=res://localtmp/ci-layout/quality.gutconfig.json", command)
                self.assertEqual(kwargs["cwd"], root)
                return Mock(returncode=0)

            with patch.object(CI_GUT, "ROOT", root), \
                    patch("sys.argv", ["run_ci_gut.py", "--godot", "fixture-godot"]), \
                    patch.object(CI_GUT.subprocess, "run", side_effect=launch) as run:
                self.assertEqual(CI_GUT.main(), 0)
                run.assert_called_once()

    def test_report_validation_requires_successful_producer_but_upload_is_unconditional(self):
        for name in ("check-quality.yml", "check-native-layouts.yml"):
            with self.subTest(workflow=name):
                workflow = (ROOT / ".github/workflows" / name).read_text()
                summary = workflow.split("- name: Validate coverage and summarize slow tests", 1)[1]
                summary, upload = summary.split("- name: Retain test timing report", 1)
                self.assertIn("if: success()", summary)
                self.assertNotIn("if: always()", summary)
                self.assertIn("tools/summarize_gut_report.py", summary)
                self.assertIn("if: always()", upload)
