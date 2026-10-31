"""Optional GUI/matrix modes must select exactly the intended native jobs."""
from __future__ import annotations

import importlib.util
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("ci_selection", ROOT / "tools/ci_test_selection.py")
SELECT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SELECT)


class CiTestSelectionTests(unittest.TestCase):
    def test_all_four_modes_have_exact_non_overlapping_targets(self):
        self.assertEqual(SELECT.native_targets(False, False), [])
        self.assertEqual(SELECT.native_targets(True, False), [SELECT.PHONE_TARGET])
        matrices = SELECT.native_targets(False, True)
        self.assertEqual(len(matrices), 10)
        self.assertNotIn(SELECT.PHONE_TARGET, matrices)
        complete = SELECT.native_targets(True, True)
        self.assertEqual(len(complete), 11)
        self.assertEqual(set(complete), set(matrices) | {SELECT.PHONE_TARGET})
        self.assertEqual(len(set(complete)), len(complete))

    def test_workflow_selector_defaults_off_and_outputs_valid_json(self):
        result = subprocess.run(
            [os.sys.executable, str(ROOT / "tools/ci_test_selection.py")],
            env=dict(os.environ, RUN_GUI_TESTS="false", RUN_GUI_MATRIX_TESTS="false"),
            capture_output=True, text=True, check=True,
        )
        self.assertEqual(json.loads(result.stdout), [])

    @unittest.skipUnless(shutil.which("bash"), "GitHub's bash shell is unavailable")
    def test_completion_allows_only_success_or_explicitly_disabled_layouts(self):
        workflow = (ROOT / ".github/workflows/check-native-layouts.yml").read_text()
        step = workflow.split("      - name: Require enabled suites and allow only intentional skips\n", 1)[1]
        match = re.search(r"(?m)^        run: \|\n((?:          [^\n]*\n)+)", step)
        self.assertIsNotNone(match)
        script = textwrap.dedent(match.group(1))
        states = ("success", "failure", "cancelled", "skipped")
        for enabled, selection, layouts in itertools.product((False, True), states, states):
            with self.subTest(enabled=enabled, selection=selection, layouts=layouts):
                result = subprocess.run(
                    [shutil.which("bash"), "-e", "-c", script], capture_output=True, text=True,
                    env=dict(os.environ, SELECTION_RESULT=selection, LAYOUT_RESULT=layouts,
                             TARGETS='["gui-phone-table-layout-gate"]' if enabled else '[]'),
                    timeout=5,
                )
                expected = selection == "success" and layouts == ("success" if enabled else "skipped")
                self.assertEqual(result.returncode == 0, expected)
