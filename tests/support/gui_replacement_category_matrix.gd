class_name GuiReplacementCategoryMatrix
extends RefCounted

const Progress := preload("res://tests/support/gui_matrix_progress.gd")
const Cases := preload("res://tests/support/gui_replacement_capture_cases.gd")
const Support := preload("res://tests/support/gui_replacement_matrix_support.gd")


static func run(host: Node, category: StringName) -> PackedStringArray:
	return await run_cases(host, Cases.cases_for_category(category), "invariant/" + str(category))


static func run_cases(host: Node, cases: Array[Dictionary], group: String) -> PackedStringArray:
	var failures := PackedStringArray()
	var progress := Progress.new(group, cases.size())
	for case: Dictionary in cases:
		progress.begin(case.case_id)
		var mounted: Dictionary = Support.mount(host, case)
		var context: String = case.case_id
		if not mounted.bound:
			failures.append("%s: replacement rejected its fixture" % context)
			progress.finish()
			mounted.viewport.queue_free()
			continue
		var table: GuiReplacementTableController = mounted.table
		if not await Support.wait_settled(host.get_tree(), table):
			failures.append("%s: replacement did not settle" % context)
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		for failure: String in Support.validate_case(snapshot, case):
			failures.append("%s: %s" % [context, failure])
		progress.finish()
		mounted.viewport.queue_free()
		await host.get_tree().process_frame
	return failures
