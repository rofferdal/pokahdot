"""GUT timing summaries must reject missing execution and missing scripts."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("gut_report", ROOT / "tools/summarize_gut_report.py")
REPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REPORT)


class CiTimingReportTests(unittest.TestCase):
    def summarize(self, xml, config=None):
        folder = ROOT / "localtmp/ci-layout"
        folder.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=folder) as directory:
            path = Path(directory) / "report.xml"
            path.write_text(xml)
            return REPORT.summarize(path, config)

    def test_real_gut_structure_sorts_script_and_test_timings(self):
        xml = '''<testsuites tests="2" failures="0">
        <testsuite name="tests/unit/test_a.gd" tests="1" failures="0" time="1.25">
          <testcase classname="tests/unit/test_a.gd" name="fast" time="1.25"/>
        </testsuite>
        <testsuite name="tests/unit/test_b.gd" tests="1" failures="0" time="3.5">
          <testcase classname="tests/unit/test_b.gd" name="slow" time="3.5"/>
        </testsuite></testsuites>'''
        config = {"tests": ["res://tests/unit/test_a.gd", "res://tests/unit/test_b.gd"]}
        result = self.summarize(xml, config)
        self.assertIn("2 tests", result)
        self.assertLess(result.index("test_b.gd"), result.index("test_a.gd"))
        self.assertLess(result.index("::slow"), result.index("::fast"))
        with self.assertRaisesRegex(ValueError, "coverage differs"):
            self.summarize(xml, {"tests": ["res://tests/unit/test_missing.gd"]})

    def test_zero_tests_and_failures_are_rejected(self):
        for xml, message in [
            ('<testsuites tests="0"/>', "no executed tests"),
            ('<testsuites failures="1"><testsuite><testcase/></testsuite></testsuites>', "failed tests"),
            ('<testsuites><testsuite errors="1"><testcase/></testsuite></testsuites>', "failed tests"),
        ]:
            with self.subTest(xml=xml), self.assertRaisesRegex(ValueError, message):
                self.summarize(xml)
