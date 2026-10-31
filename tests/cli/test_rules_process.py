"""Real-process Rules inspection preserves setup, gameplay and exit contracts."""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT", "godot")
OPTIONS = ["--players", "3", "--stack", "200", "--seed", "4242", "--use-legacy-models"]
EVIDENCE = ROOT / "localtmp/rules-in-game/cli-rules-transcripts"


def shared_document_text() -> str:
    """Read authored literals, independently checking the plain-render contract."""
    source = (ROOT / "resources/presentation/tournament_rules.tres").read_text()
    titles = [json.loads(value) for value in re.findall(r'^title = (".*")$', source, re.M)]
    bodies = [json.loads(value) for value in re.findall(r'^body = (".*")$', source, re.M)]
    if len(titles) != 7 or len(bodies) != 6:
        raise AssertionError("Expected one title and all six shared rules sections")
    return "\n\n".join([titles[-1], *(f"{title}\n{body}" for title, body in zip(titles, bodies))])


class RulesCliProcessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if shutil.which(GODOT) is None:
            raise RuntimeError(f"Godot executable unavailable: {GODOT}; set GODOT to its path")
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        cls.rules = shared_document_text()

    def run_cli(self, label: str, transcript: str, options: list[str] | None = None,
                expected_code: int = 0) -> subprocess.CompletedProcess[str]:
        prefix = EVIDENCE / label
        prefix.with_suffix(".stdin").write_text(transcript)
        selected = OPTIONS if options is None else options
        prefix.with_suffix(".options.json").write_text(json.dumps(selected) + "\n")
        result = subprocess.run(
            [GODOT, "--headless", "--no-header", "--log-file", str(prefix.with_suffix(".godot.log")),
             "--path", str(ROOT), "--script", "res://scripts/cli/cli_app.gd", "--", *selected],
            input=transcript, text=True, capture_output=True, cwd=ROOT, timeout=30,
        )
        prefix.with_suffix(".stdout").write_text(result.stdout)
        prefix.with_suffix(".stderr").write_text(result.stderr)
        self.assertEqual(result.returncode, expected_code, result.stdout + result.stderr)
        self.assertNotIn("SCRIPT ERROR", result.stderr)
        return result

    def without_rules_and_prompts(self, output: str) -> str:
        # Remove only the exact shared document and known repeated input prompts.
        # Keep all state/history/action/configuration lines, including duplicates.
        output = output.replace(self.rules + "\n", "")
        output = output.replace("pokahdot> ", "")
        output = re.sub(r"Press Enter to start, or type [^\n]*?: ", "", output)
        output = re.sub(r"Press Enter or type 'continue' for the next hand, [^\n]*?: ", "", output)
        return output

    def test_setup_rules_are_exact_repeatable_and_recover_after_extra_arguments(self) -> None:
        for ending, message in [("quit\n", "Startup cancelled."),
                                ("", "Input closed before startup completed.")]:
            with self.subTest(ending=ending):
                result = self.run_cli(f"setup-{'quit' if ending else 'eof'}",
                                      "  RuLeS \t\nrules now\nRULES\n" + ending)
                self.assertEqual(result.stdout.count(self.rules), 2)
                self.assertEqual(result.stdout.count("Unknown setup option"), 1)
                self.assertIn(message, result.stdout)
                self.assertNotIn("Seat agents:", result.stdout)
                self.assertNotIn("Effective seed:", result.stdout)
                self.assertNotIn("Hand 1 -", result.stdout)

    def test_rules_preserve_partial_edits_malformed_input_and_cross_field_correction(self) -> None:
        result = self.run_cli(
            "edited-invalid-config", "3\nrules\nrules 1\nchips\n200\n20\n10\n  RuLeS \n5\nrules\nquit\n",
            ["--configure", "--seed", "4242", "--use-legacy-models"],
        )
        self.assertEqual(result.stdout.count(self.rules), 3)
        self.assertEqual(result.stdout.count("Players [6]:"), 1)
        self.assertEqual(result.stdout.count("Starting stack [1000]:"), 4)
        self.assertEqual(result.stdout.count("Small blind [20]:"), 2)
        self.assertIn("Correct the invalid fields; other edits are retained.", result.stdout)
        self.assertIn("  Players: 3\n  Starting stack: 200\n  Blinds: 5/10", result.stdout)
        self.assertIn("Legacy heuristic models: included", result.stdout)
        self.assertIn("Goodbye.", result.stdout)

    def test_numeric_rules_then_eof_or_quit_do_not_start_a_match(self) -> None:
        for ending, message in [("quit\n", "Startup cancelled."),
                                ("", "Input closed before startup completed.")]:
            with self.subTest(ending=ending):
                result = self.run_cli(f"numeric-{'quit' if ending else 'eof'}", "3\n rules \n" + ending,
                                      ["--configure", "--seed", "4242"])
                self.assertEqual(result.stdout.count(self.rules), 1)
                self.assertEqual(result.stdout.count("Starting stack [1000]:"), 2)
                self.assertIn(message, result.stdout)
                self.assertNotIn("Tournament configuration:", result.stdout)
                self.assertNotIn("Seat agents:", result.stdout)

    def test_human_turn_repeated_rules_and_extra_argument_recovery_preserve_full_output(self) -> None:
        control = self.run_cli("human-control", "\nrules extra\nstate\nhistory\nquit\n")
        inspected = self.run_cli("human-rules", "\n  RuLeS \t\nRULES\nrules extra\nstate\nhistory\nquit\n")
        self.assertEqual(inspected.stdout.count(self.rules), 2)
        self.assertIn("pokahdot> ", control.stdout)
        self.assertNotIn("Hand complete.", control.stdout)
        self.assertIn("Unknown command 'rules extra'", inspected.stdout)
        self.assertIn("Action history:", inspected.stdout)
        self.assertEqual(self.without_rules_and_prompts(inspected.stdout),
                         self.without_rules_and_prompts(control.stdout))

    def test_same_seed_actions_cards_and_incremental_history_are_unchanged_across_hands(self) -> None:
        control = self.run_cli("two-hands-control", "\nstate\nhistory\nfold\nhistory\ncontinue\nstate\nhistory\nfold\nquit\n")
        inspected = self.run_cli(
            "two-hands-rules",
            "rules\n\nrules\nstate\nhistory\nrules\nfold\n RuLeS \nrules\nhistory\ncontinue\n"
            "rules\nstate\nhistory\nrules\nfold\nrules\nquit\n",
        )
        self.assertEqual(inspected.stdout.count(self.rules), 8)
        self.assertIn("Hand 2 -", control.stdout)
        self.assertIn("Press Enter or type 'continue' for the next hand", control.stdout)
        self.assertIn("Effective seed: 4242", inspected.stdout)
        self.assertEqual(self.without_rules_and_prompts(inspected.stdout),
                         self.without_rules_and_prompts(control.stdout))

    def test_eof_after_rules_keeps_human_and_between_hand_exit_behavior(self) -> None:
        for phase, prefix in [("human", "\n"), ("between", "\nfold\n")]:
            with self.subTest(phase=phase):
                control = self.run_cli(f"{phase}-eof-control", prefix)
                inspected = self.run_cli(f"{phase}-eof-rules", prefix + "rules\n")
                self.assertEqual(inspected.stdout.count(self.rules), 1)
                if phase == "human":
                    self.assertNotIn("Hand complete.", control.stdout)
                    self.assertIn("pokahdot> ", control.stdout)
                else:
                    self.assertIn("Hand complete.", control.stdout)
                    self.assertIn("Press Enter or type 'continue'", control.stdout)
                self.assertIn("Input closed. Goodbye.", inspected.stdout)
                self.assertNotIn("Tournament winner:", inspected.stdout)
                self.assertEqual(self.without_rules_and_prompts(inspected.stdout),
                                 self.without_rules_and_prompts(control.stdout))

    def test_natural_completion_does_not_read_trailing_rules_or_quit(self) -> None:
        options = ["--players", "2", "--stack", "1", "--small-blind", "1", "--big-blind", "1", "--seed", "4242"]
        control = self.run_cli("completion-control", "\n", options)
        inspected = self.run_cli("completion-rules", "rules\n\nrules\nrules\nquit\n", options)
        self.assertEqual(inspected.stdout.count(self.rules), 1)
        self.assertIn("Tournament winner:", inspected.stdout)
        self.assertNotIn("Tournament ended: player_quit", inspected.stdout)
        self.assertNotIn("Input closed.", inspected.stdout)
        self.assertNotIn("Goodbye.", inspected.stdout)
        self.assertEqual(self.without_rules_and_prompts(inspected.stdout),
                         self.without_rules_and_prompts(control.stdout))

    def test_rules_is_a_prompt_command_and_never_a_startup_flag(self) -> None:
        result = self.run_cli("unsupported-rules-flag", "rules\n\n", ["--rules"], expected_code=1)
        self.assertNotIn(self.rules, result.stdout)
        self.assertNotIn("Pokahdot tournament setup", result.stdout)
        self.assertNotIn("Seat agents:", result.stdout)
        self.assertIn("Unknown option", result.stdout)
