"""Ensure quality plus the phone job cover all configured non-matrix scripts."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("ci_gut", ROOT / "tools/run_ci_gut.py")
CI_GUT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CI_GUT)


class CiSuitePartitionTests(unittest.TestCase):
    def test_real_partition_preserves_configured_non_matrix_scripts_and_options(self):
        original = json.loads((ROOT / ".gutconfig.json").read_text())
        result = CI_GUT.quality_config(ROOT, original)
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
            result = CI_GUT.quality_config(root, config)
            self.assertEqual(result["tests"], ["res://explicit.gd",
                             "res://tests/unit/nested/test_nested.gd",
                             "res://tests/unit/test_future.gd"])
            self.assertEqual(result["log_level"], 3)
            config["include_subdirs"] = False
            self.assertNotIn("res://tests/unit/nested/test_nested.gd",
                             CI_GUT.quality_config(root, config)["tests"])

    def test_missing_phone_suite_or_empty_quality_partition_fail_closed(self):
        with self.assertRaisesRegex(ValueError, "was not discovered"):
            CI_GUT.quality_config(ROOT, {"dirs": [], "tests": ["res://other.gd"]})
        with self.assertRaisesRegex(ValueError, "must not be empty"):
            CI_GUT.quality_config(ROOT, {"dirs": [], "tests": [CI_GUT.PHONE_SUITE]})
