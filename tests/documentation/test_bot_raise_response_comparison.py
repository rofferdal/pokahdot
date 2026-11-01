"""Matched bot-policy evidence must preserve cohorts and fail corrupt evidence."""
from __future__ import annotations

import copy
import unittest

from tools.compare_bot_raise_response import BENCHMARK, compare, summarize_responses, validate_report


def report() -> dict:
    tournaments = []
    for index in range(180):
        tournaments.append({
            "seed": index + 1, "player_count": 2, "starting_stack": 100,
            "mirrored": bool(index % 2), "seat_profiles": [f"p{index % 15}", f"p{(index + 1) % 15}"],
            "winner": 0, "hands": 1, "completed": True, "error": "", "chip_total": 200,
            "expected_chip_total": 200, "invalid_actions": 0, "fallback_folds": 0,
            "decisions": 10, "long_chains": 10 if index == 0 else 0,
            "repeated_weak_bluffs": 2 if index == 0 else 0,
        })
    rows = []
    for action in ["FOLD", "CALL", "RAISE", "FOLD"]:
        rows.append({
            "tournament": 0, "profile": "p0", "hand": 1, "street": "preflop", "seat": 0,
            "previous_branch": "continue_aggressive", "branch": "test", "action": action,
            "call": 10, "pot": 90, "stack": 90, "call_price": 0.1, "stack_pressure": 0.1,
            "opponents": 1, "score": 40, "legacy_threshold": 35.0,
            "cheap": True, "expensive": False, "weak": False, "threshold_crossing": False,
        })
    return {
        "schema": "bfcr_behavior_v1", "seed_start": 1,
        "profile_hashes": {f"p{index}": "a" * 64 for index in range(15)},
        "source_hashes": {BENCHMARK: "b" * 64}, "decisions": 1800,
        "long_chains": 10, "repeated_weak_bluffs": 2, "invalid_actions": 0,
        "runtime_seconds": 1.0, "branches": {"test": 1800}, "responses": rows,
        "response_summary": summarize_responses(rows),
        "controlled_value": [{"action": "RAISE", "branch": "continue_aggressive"},
                             {"action": "RAISE", "branch": "scripted_min_raise"},
                             {"action": "FOLD", "branch": "fold"}],
        "controlled_published": [{"action": "RAISE", "branch": "bluff_raise"},
                                 {"action": "FOLD", "branch": "fold"}],
        "tournaments": tournaments,
    }


def candidate_report() -> dict:
    candidate = report()
    candidate.update(long_chains=5, repeated_weak_bluffs=0)
    candidate["tournaments"][0].update(long_chains=5, repeated_weak_bluffs=0)
    candidate["responses"][0]["action"] = "CALL"
    candidate["response_summary"] = summarize_responses(candidate["responses"])
    candidate["controlled_value"][-1]["action"] = "CALL"
    return candidate


class BotRaiseResponseComparisonTests(unittest.TestCase):
    def test_candidate_must_pass_all_preregistered_margins(self):
        baseline = report()
        candidate = candidate_report()
        self.assertTrue(compare(baseline, candidate)["passed"])
        candidate["repeated_weak_bluffs"] = 1
        candidate["tournaments"][0]["repeated_weak_bluffs"] = 1
        self.assertFalse(compare(baseline, candidate)["passed"])
        candidate = candidate_report()
        candidate["tournaments"][0]["chip_total"] = 199
        self.assertFalse(compare(baseline, candidate)["passed"])

    def test_matching_seeds_profiles_harness_and_assignments_are_required(self):
        for mutate in (
            lambda row: row.update(seed_start=2),
            lambda row: row["profile_hashes"].update(p0="c" * 64),
            lambda row: row["source_hashes"].update({BENCHMARK: "c" * 64}),
            lambda row: row["tournaments"][0].update(seed=2),
        ):
            candidate = report()
            mutate(candidate)
            with self.assertRaises(ValueError):
                compare(report(), candidate)

    def test_summary_counts_rates_intervals_and_group_set_are_reconstructed(self):
        mutations = [
            lambda row: row["response_summary"]["cheap_nonweak"].update(FOLD=0),
            lambda row: row["response_summary"]["cheap_nonweak"].update(fold_rate=0.0),
            lambda row: row["response_summary"]["all"].update(opportunities=99),
            lambda row: row["response_summary"]["all"].update(fold_wilson95=[0.0, 1.0]),
            lambda row: row["response_summary"].pop("cheap_nonweak"),
            lambda row: row["responses"][0].update(cheap=False),
        ]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                value = report()
                mutate(value)
                with self.assertRaises(ValueError):
                    validate_report(value)

    def test_tournament_counters_and_response_counts_must_reconcile(self):
        mutations = [
            lambda row: row.update(long_chains=9),
            lambda row: row.update(decisions=1801),
            lambda row: row.update(repeated_weak_bluffs=0),
            lambda row: row["tournaments"][0].update(invalid_actions=1),
            lambda row: row["branches"].update(test=1),
            lambda row: row.update(response_count=3),
            lambda row: row["tournaments"][0].update(response_count=1),
            lambda row: row["tournaments"][0].update(winner=2),
            lambda row: row["responses"][0].update(seat=2),
        ]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                value = report()
                mutate(value)
                with self.assertRaises(ValueError):
                    validate_report(value)

    def test_numeric_fields_reject_nan_infinity_and_boolean_aliases(self):
        mutations = [
            lambda row: row.update(runtime_seconds=float("nan")),
            lambda row: row.update(runtime_seconds=float("inf")),
            lambda row: row.update(runtime_seconds=True),
            lambda row: row.update(decisions=True),
            lambda row: row["tournaments"][0].update(winner=False),
            lambda row: row["responses"][0].update(call=True),
            lambda row: row["responses"][0].update(call_price=float("nan")),
            lambda row: row["response_summary"]["all"].update(FOLD=True),
            lambda row: row["response_summary"]["all"].update(fold_rate=float("nan")),
            lambda row: row["response_summary"]["all"].update(fold_wilson95=[True, 1.0]),
        ]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                value = report()
                mutate(value)
                with self.assertRaises(ValueError):
                    validate_report(value)

    def test_valid_frozen_shape_is_accepted_without_saved_files(self):
        baseline = report()
        validate_report(baseline)
        self.assertEqual(baseline, copy.deepcopy(baseline))
