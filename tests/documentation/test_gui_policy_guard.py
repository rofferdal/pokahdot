"""Mutation coverage for the scoped replacement-GUI policy guard."""
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location(
    "check_gui_policy", Path(__file__).resolve().parents[2] / "tools/check_gui_policy.py"
)
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)
COMPONENT = "scripts/gui/components/seat_panel.gd"


class GuiPolicyGuardTests(unittest.TestCase):
    def test_rejects_reference_layout_dependencies_and_local_reclassification(self):
        for source in [
            'const Legacy = preload("res://scripts/gui/gui_mobile_table_layout.gd")',
            'var result = GuiLayoutProfile.classify(size)',
            'var result = GuiSizeClass.classify(size)',
            'var result = get_viewport_rect().size',
        ]:
            with self.subTest(source=source):
                self.assertTrue(CHECK.check_source(source, COMPONENT))

    def test_rejects_literal_and_constant_device_thresholds_in_either_direction(self):
        for source in [
            'if usable_size.x < 600.0:\n    pass',
            'if geometry.usable_rect.size.y <= 760:\n    pass',
            'if 1100 > available.x:\n    pass',
            'if size.y < TABLET_MAX_HEIGHT:\n    pass',
        ]:
            with self.subTest(source=source):
                self.assertTrue(CHECK.check_source(source, COMPONENT))

    def test_permits_measured_fit_containment_validation_and_text(self):
        source = '''
if minimum.x <= available.x and minimum.y <= available.y:
    pass
if size.x <= 0.0:
    return
if target.size.x < 48:
    return
var description = "if available.x < 600:"
# if usable_size.x < 600:
'''
        self.assertEqual(CHECK.check_source(source, COMPONENT), [])

    def test_only_policy_owner_classifies_and_only_classifier_owns_breakpoints(self):
        source = 'if size.x < 600:\n    pass'
        self.assertEqual(CHECK.check_source(source, CHECK.CLASSIFIER), [])
        self.assertTrue(CHECK.check_source(source, CHECK.RESOLVER))
        self.assertEqual(CHECK.check_source('GuiSizeClass.classify(size)', CHECK.RESOLVER), [])

    def test_current_replacement_tree_passes(self):
        self.assertEqual(CHECK.main(), 0)
