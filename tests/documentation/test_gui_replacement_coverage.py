"""Mutation checks for the RG-60 coverage map and observer-isolation gate."""

import copy
import json
import unittest

from tools.check_gui_replacement_coverage import MAP, contains_legacy_token, validate


class GuiReplacementCoverageTests(unittest.TestCase):
    def setUp(self):
        self.payload = json.loads(MAP.read_text())

    def test_repository_coverage_map_is_complete_and_independent(self):
        self.assertEqual(validate(self.payload), [])

    def test_controller_identifier_check_distinguishes_replacement_from_reference(self):
        self.assertFalse(contains_legacy_token("GuiReplacementTableController", "PokerTableController"))
        self.assertTrue(contains_legacy_token("var table: PokerTableController", "PokerTableController"))

    def test_missing_replacement_mapping_is_rejected(self):
        mutated = copy.deepcopy(self.payload)
        mutated["legacy_families"][0]["replacement_checks"] = []
        self.assertTrue(any("replacement_checks" in error for error in validate(mutated)))

    def test_removed_legacy_path_requires_explicit_retirement(self):
        mutated = copy.deepcopy(self.payload)
        family = mutated["legacy_families"][0]
        family.pop("retired", None)
        family["legacy_tests"] = ["tests/retired_reference.gd"]
        self.assertTrue(any("missing repository path" in error for error in validate(mutated)))
        family["retired"] = "yes"
        self.assertTrue(any("retired must be a boolean" in error for error in validate(mutated)))
        family["retired"] = True
        self.assertEqual(validate(mutated), [])

    def test_missing_observer_is_rejected(self):
        mutated = copy.deepcopy(self.payload)
        mutated["independent_observers"].append("tests/missing_observer.gd")
        errors = validate(mutated)
        self.assertTrue(any("missing independent observer" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
