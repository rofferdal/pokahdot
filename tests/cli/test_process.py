"""Captured process contracts for the interactive CLI."""

from __future__ import annotations

import os
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT", "godot")


class InteractiveCliProcessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if shutil.which(GODOT) is None:
            raise RuntimeError(f"Godot executable unavailable: {GODOT}; set GODOT to its path")

    def run_cli(self, options: list[str], transcript: str = "") -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [GODOT, "--headless", "--no-header", "--path", str(ROOT), "--script",
             "res://scripts/cli/cli_app.gd", "--", *options],
            input=transcript, text=True, capture_output=True, cwd=ROOT, timeout=30,
        )

    def test_help_needs_no_stdin_and_does_not_construct_a_game(self) -> None:
        result = self.run_cli(["--help"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--seed INTEGER", result.stdout)
        self.assertNotIn("Seat agents:", result.stdout)
        self.assertNotIn("tournament setup", result.stdout)

    def test_invalid_options_fail_the_real_process_before_startup(self) -> None:
        for options in [["--typo"], ["--seed"], ["--seed", "9223372036854775808"],
                        ["--players", "3", "--players", "4"], ["--players", "10"],
                        ["--small-blind", "20", "--big-blind", "10"]]:
            with self.subTest(options=options):
                result = self.run_cli(options, "\nquit\n")
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn("Hand 1 -", result.stdout)

    def test_seeded_transcript_repeats_profiles_cards_and_actions(self) -> None:
        options = ["--players", "3", "--stack", "100", "--seed", "4242"]
        transcript = "\nstate\nhistory\nraise 20\nstate\nhistory\nquit\n"
        first, second = self.run_cli(options, transcript), self.run_cli(options, transcript)
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(first.stdout, second.stdout)
        self.assertIn("Effective seed: 4242", first.stdout)
        self.assertIn("Reproduce options: --players 3 --stack 100 --small-blind 5 --big-blind 10 --seed 4242", first.stdout)
        self.assertIn("Hand 1 -", first.stdout)
        self.assertIn("Action history:", first.stdout)
        self.assertIn("Goodbye.", first.stdout)

    def test_time_seed_can_reproduce_the_reported_game(self) -> None:
        first = self.run_cli(["--players", "3"], "\nquit\n")
        self.assertEqual(first.returncode, 0, first.stderr)
        match = re.search(r"Effective seed: (-?\d+)", first.stdout)
        self.assertIsNotNone(match, first.stdout)
        seed = match.group(1)
        self.assertNotEqual(seed, "0")
        repeated = self.run_cli(["--players", "3", "--seed", seed], "\nquit\n")
        self.assertEqual(repeated.returncode, 0, repeated.stderr)
        self.assertEqual(first.stdout, repeated.stdout)

    def test_configure_switch_retains_valid_edits_when_correcting_blinds(self) -> None:
        result = self.run_cli(["--configure", "--seed", "4242"], "3\n200\n20\n10\n5\nquit\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("Players [6]:"), 1)
        self.assertIn("Small blind [20]:", result.stdout)
        self.assertIn("Players: 3", result.stdout)
        self.assertIn("Starting stack: 200", result.stdout)
        self.assertIn("Blinds: 5/10", result.stdout)
        self.assertIn("Effective seed: 4242", result.stdout)
