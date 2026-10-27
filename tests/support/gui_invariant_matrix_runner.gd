class_name GuiInvariantMatrixRunner
extends RefCounted

## One renderer/settler/invariant loop for the declared diagnostic suites.
const Assertions := preload("res://tests/support/gui_invariant_assertions.gd")
const Harness := preload("res://tests/support/gui_scene_harness.gd")
const Suites := preload("res://tests/support/gui_invariant_matrix_suites.gd")
const PhoneContract := preload("res://tests/support/gui_phone_matrix_contract.gd")


static func run_suite(host: Node, suite: Suites.Suite) -> PackedStringArray:
	var failures := PackedStringArray()
	var selected := Suites.definition(suite)
	for case: Dictionary in Suites.cases(suite):
		var viewport: Dictionary = case.viewport
		var descriptor: Dictionary = case.descriptor
		var harness: Node = Harness.new()
		host.add_child(harness)
		var signature: String = (
			PhoneContract.view_signature(descriptor.view) if selected.phone_contract else ""
		)
		var rendered: Dictionary = harness.render(
			descriptor, viewport.size, viewport.profile_override
		)
		var settled: bool = await harness.settle_layout()
		var context := "%s / p%d / %s" % [viewport.key, descriptor.player_count, descriptor.id]
		if not settled:
			failures.append("%s: layout did not settle" % context)
		for failure: String in Assertions.validate(rendered):
			failures.append("%s: %s" % [context, failure])
		if selected.phone_contract:
			PhoneContract.validate(rendered, context, failures)
			if PhoneContract.view_signature(descriptor.view) != signature:
				failures.append("%s: presentation render changed the core view" % context)
			if descriptor.id == &"human-turn-preflop":
				var rotated_size := (
					Vector2i(844, 390) if viewport.size.y > viewport.size.x else Vector2i(390, 844)
				)
				harness.resize_viewport(rotated_size)
				if not await harness.settle_layout():
					failures.append("%s: rotated layout did not settle" % context)
				harness.resize_viewport(viewport.size)
				if not await harness.settle_layout():
					failures.append("%s: restored layout did not settle" % context)
				for failure: String in Assertions.validate(rendered):
					failures.append("%s after resize cycle: %s" % [context, failure])
				if PhoneContract.view_signature(descriptor.view) != signature:
					failures.append("%s: resize cycle changed the core view" % context)
		harness.free()
	return failures
