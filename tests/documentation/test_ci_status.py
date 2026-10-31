"""Exercise the actual aggregate CI script against every upstream job result."""
from __future__ import annotations

import itertools
import os
from pathlib import Path
import re
import shutil
import subprocess
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CiStatusTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("bash"), "GitHub's bash shell is unavailable")
    def test_pr_aggregate_accepts_only_two_successful_dependencies(self):
        workflow = (ROOT / ".github/workflows/check-pr.yml").read_text()
        step = workflow.split("      - name: Require every validation job to succeed\n", 1)[1]
        match = re.search(r"(?m)^        run: \|\n((?:          [^\n]*\n)+)", step)
        self.assertIsNotNone(match)
        script = textwrap.dedent(match.group(1))
        states = ("success", "failure", "cancelled", "skipped")
        for quality, layouts in itertools.product(states, repeat=2):
            with self.subTest(quality=quality, layouts=layouts):
                result = subprocess.run(
                    [shutil.which("bash"), "-e", "-c", script],
                    env=dict(os.environ, QUALITY_RESULT=quality, LAYOUT_RESULT=layouts),
                    capture_output=True, text=True, timeout=5,
                )
                self.assertEqual(result.returncode == 0,
                                 quality == layouts == "success",
                                 result.stdout + result.stderr)
