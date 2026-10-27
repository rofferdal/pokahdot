"""Actual simulation process stdout/stderr, progress and replay contracts."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from tests.cli.test_process import GODOT, ROOT


class SimulationCliProcessTests(unittest.TestCase):
    def setUp(self) -> None:
        (ROOT / "localtmp").mkdir(exist_ok=True)
        self.directory = tempfile.TemporaryDirectory(prefix="cli03-", dir=ROOT / "localtmp")
        self.addCleanup(self.directory.cleanup)
        self.work = Path(self.directory.name)
        self.manifest = self.work / "manifest.json"
        data = json.loads((ROOT / "tests/fixtures/simulation_manifest_v2.json").read_text())
        first = dict(data["evaluation_plans"][0], plan_id="first_plan", tournament_count=1)
        second = dict(first, plan_id="second_plan")
        data["evaluation_plans"] = [first, second]
        self.manifest.write_text(json.dumps(data), encoding="utf-8")

    def execute(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [GODOT, "--headless", "--no-header", "--path", str(ROOT), "--script",
             "res://scripts/simulation/simulation_cli_app.gd", "--", *arguments],
            text=True, capture_output=True, cwd=ROOT, timeout=30,
        )

    def run_report(self, format: str = "json") -> tuple[Path, subprocess.CompletedProcess[str]]:
        report = self.work / f"{format}-report.json"
        result = self.execute("run", "--config", str(self.manifest), "--output", str(report),
                              "--format", format, "--trace", "none")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return report, result

    def test_both_formats_keep_progress_on_stderr_and_results_on_stdout(self) -> None:
        for format in ("json", "text"):
            with self.subTest(format=format):
                report, result = self.run_report(format)
                self.assertTrue(report.is_file())
                self.assertNotIn("Evaluation plan:", result.stdout)
                self.assertNotIn("Completed ", result.stdout)
                self.assertEqual(result.stderr.count("Evaluation plan: first_plan"), 1)
                self.assertEqual(result.stderr.count("Evaluation plan: second_plan"), 1)
                self.assertRegex(result.stderr, r"Completed 0/2 \| elapsed \d+\.\d+s")
                self.assertRegex(result.stderr, r"Completed 2/2 \| elapsed \d+\.\d+s \| throughput \d+\.\d+ tournaments/s")
                if format == "json":
                    completion = json.loads(result.stdout)
                    self.assertEqual(completion["tournament_count"], 2)
                else:
                    self.assertIn("tournament_count: 2", result.stdout)
                self.assertNotIn("report_path", result.stderr)

    def test_replay_collects_requested_bounded_traces_without_changing_outcome(self) -> None:
        report, _ = self.run_report()
        self.assertEqual(json.loads(report.read_text())["traces"], [])
        traces = None
        for attempt in range(2):
            artifact = self.work / f"replay-{attempt}.json"
            result = self.execute("replay", "--report", str(report), "--tournament-index", "0",
                                  "--trace", "sampled", "--trace-sample", "3",
                                  "--output", str(artifact))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            comparison = json.loads(result.stdout)
            self.assertTrue(comparison["match"])
            replay = json.loads(artifact.read_text())
            self.assertEqual(replay["trace_policy"], {"mode": "sampled", "max_entries_per_tournament": 3})
            self.assertGreater(len(replay["traces"]), 0)
            self.assertLessEqual(len(replay["traces"]), 3)
            self.assertEqual(comparison["trace_count"], len(replay["traces"]))
            if traces is not None:
                self.assertEqual(replay["traces"], traces)
            traces = replay["traces"]
            for trace in traces:
                self.assertNotIn("hole_cards", trace)
                self.assertNotIn("deck", trace)
                self.assertNotIn("rng", trace)
        no_trace = self.work / "replay-none.json"
        result = self.execute("replay", "--report", str(report), "--tournament-index", "0",
                              "--trace", "none", "--output", str(no_trace), "--format", "text")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("trace_count: 0", result.stdout)
        self.assertEqual(json.loads(no_trace.read_text())["traces"], [])

    def test_failed_run_diagnostics_do_not_pollute_json_stdout(self) -> None:
        result = self.execute("run", "--config", str(self.work / "missing.json"),
                              "--output", str(self.work / "failed.json"))
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertIn("Manifest file does not exist", result.stderr)
        invalid = self.execute("run", "--unknown")
        self.assertEqual(invalid.returncode, 2)
        self.assertEqual(invalid.stdout, "")
        self.assertIn("Usage:", invalid.stderr)

    def test_resumed_progress_counts_reused_completed_records(self) -> None:
        report, _ = self.run_report()
        result = self.execute("run", "--config", str(self.manifest), "--output", str(report),
                              "--resume", "--overwrite", "--trace", "none")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Completed 2/2", result.stderr)
        self.assertEqual(json.loads(result.stdout)["tournament_count"], 2)
