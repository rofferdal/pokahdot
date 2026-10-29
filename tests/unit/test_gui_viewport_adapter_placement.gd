extends GutTest


class TableBoundary:
	extends Control
	var geometry: GuiViewportGeometry
	var pending: bool = false

	func set_viewport_geometry(value: GuiViewportGeometry, _transform: Transform2D) -> void:
		geometry = value

	func set_viewport_geometry_pending(value: bool) -> void:
		pending = value


func test_full_viewport_table_keeps_safe_origin_for_its_composition_host() -> void:
	await _assert_placement(true)


func test_reference_table_retains_direct_usable_rectangle_placement() -> void:
	await _assert_placement(false)


func _assert_placement(full_table: bool) -> void:
	var host := Control.new()
	host.size = Vector2(1200, 900)
	add_child_autofree(host)
	var startup := Control.new()
	var table := TableBoundary.new()
	var adapter := GuiViewportAdapter.new()
	host.add_child(startup)
	host.add_child(table)
	host.add_child(adapter)
	adapter.bind(host, startup, table, full_table)
	var safe := Rect2(31, 47, 1100, 800)
	adapter.inject_geometry(GuiViewportGeometry.injected(host.size, safe))
	await wait_process_frames(4)
	assert_false(adapter.is_pending())
	assert_false(table.pending)
	assert_true(table.geometry.valid)
	assert_eq(table.geometry.usable_rect, safe)
	assert_eq(table.position, Vector2.ZERO if full_table else safe.position)
	assert_eq(table.size, host.size if full_table else safe.size)
	assert_eq(startup.position, safe.position + Vector2(12, 12))
	assert_eq(startup.size, safe.size - Vector2(24, 24))
	host.size = Vector2(1300, 1000)
	adapter.inject_geometry(GuiViewportGeometry.injected(host.size, safe))
	await wait_process_frames(4)
	assert_eq(table.position, Vector2.ZERO if full_table else safe.position)
	assert_eq(table.size, host.size if full_table else safe.size)
	assert_eq(table.geometry.usable_rect, safe)
