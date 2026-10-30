class_name GuiReplacementCategoryMatrix
extends RefCounted

const Cases := preload("res://tests/support/gui_replacement_capture_cases.gd")
const Support := preload("res://tests/support/gui_replacement_matrix_support.gd")


static func run(host: Node, category: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	for case: Dictionary in Cases.cases_for_category(category):
		var mounted: Dictionary = Support.mount(host, case)
		var context: String = case.case_id
		if not mounted.bound:
			failures.append("%s: replacement rejected its fixture" % context)
			mounted.viewport.queue_free()
			continue
		var table: GuiReplacementTableController = mounted.table
		if not await Support.wait_settled(host.get_tree(), table):
			failures.append("%s: replacement did not settle" % context)
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		for failure: String in Support.validate_case(snapshot, case):
			failures.append("%s: %s" % [context, failure])
		mounted.viewport.queue_free()
		await host.get_tree().process_frame
	return failures
