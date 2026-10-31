extends GutTest

## Independent native replacement matrix; unsupported allocations must guide.
const Progress := preload("res://tests/support/gui_matrix_progress.gd")
const TableScene := preload("res://scenes/gui/ReplacementPokerTable.tscn")
const Invariants := preload("res://tests/support/gui_replacement_invariant_assertions.gd")
const Fixtures := preload("res://tests/support/gui_visual_state_fixtures.gd")


func test_replacement_supported_layouts_and_guidance() -> void:
	var cases: Array[Dictionary] = [
		{"size": Vector2i(390, 844), "count": 2, "ready": true},
		{"size": Vector2i(390, 844), "count": 4, "ready": true},
		{"size": Vector2i(1200, 590), "count": 2, "ready": true},
		{"size": Vector2i(1600, 1200), "count": 2, "ready": true},
		{"size": Vector2i(1600, 1200), "count": 6, "ready": true},
		{"size": Vector2i(1920, 1300), "count": 9, "ready": true},
		{"size": Vector2i(390, 844), "count": 6, "ready": true},
		{"size": Vector2i(390, 844), "count": 9, "ready": false},
		{"size": Vector2i(640, 360), "count": 2, "ready": true},
	]
	for count: int in [2, 3]:
		cases.append({"size": Vector2i(1200, 590), "count": count, "ready": true})
	for count: int in range(2, 10):
		cases.append({"size": Vector2i(1920, 1300), "count": count, "ready": true})
	for count: int in range(2, 8):
		cases.append({"size": Vector2i(480, 1200), "count": count, "ready": true})
	for count: int in [8, 9]:
		cases.append({"size": Vector2i(480, 1200), "count": count, "ready": false})
	var progress := Progress.new("characterization/supported", cases.size())
	for item: Dictionary in cases:
		progress.begin("%s / p%d" % [item.size, item.count])
		var viewport := SubViewport.new()
		viewport.size = item.size
		viewport.gui_embed_subwindows = true
		add_child(viewport)
		var table := TableScene.instantiate() as GuiReplacementTableController
		table.touch_entry = item.size.y < 600 or item.size.x < 600
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = Vector2(item.size)
		viewport.add_child(table)
		table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(item.size)))
		var fixture: Dictionary = Fixtures.replacement_flop(item.count)
		assert_true(table.bind_view(fixture.view, {}, {}), str(item))
		var waited_frames: int = 0
		var snapshot: GuiLayoutSnapshot
		for _frame: int in 180:
			await get_tree().process_frame
			waited_frames += 1
			snapshot = table.get_layout_snapshot()
			if (
				not snapshot.pending
				and (
					snapshot.ready
					or (
						not snapshot.fit_guidance.is_empty()
						and snapshot.fit_guidance != "Waiting for table measurements."
					)
				)
			):
				break
		assert_eq(snapshot.ready, item.ready, "%s: %s" % [item, snapshot.fit_guidance])
		if not item.ready:
			assert_false(snapshot.fit_guidance.is_empty(), str(item))
		assert_eq(Invariants.validate(snapshot), PackedStringArray(), str(item))
		progress.finish(waited_frames)
		viewport.queue_free()
		await get_tree().process_frame


func test_replacement_public_states_at_wide_allocation() -> void:
	var progress := Progress.new("characterization/wide", 40)
	for count: int in [2, 4, 6, 9]:
		for state: StringName in [
			&"human-turn-preflop",
			&"human-turn-river",
			&"bot-turn",
			&"status-blank",
			&"status-retained-fold",
			&"all-in-runout",
			&"showdown-long",
			&"elimination",
			&"tournament-winner",
			&"event-history-full"
		]:
			progress.begin("%s / p%d" % [state, count])
			var viewport := SubViewport.new()
			viewport.size = Vector2i(1920, 1300)
			viewport.gui_embed_subwindows = true
			add_child(viewport)
			var table := TableScene.instantiate() as GuiReplacementTableController
			table.set_anchors_preset(Control.PRESET_TOP_LEFT)
			viewport.add_child(table)
			table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(viewport.size)))
			var fixture: Dictionary = Fixtures.by_id(state, count)
			assert_true(table.bind_view(fixture.view, {}, {}), "%s/%d" % [state, count])
			var waited_frames: int = 0
			var snapshot: GuiLayoutSnapshot
			for _frame: int in 180:
				await get_tree().process_frame
				waited_frames += 1
				snapshot = table.get_layout_snapshot()
				if not snapshot.pending and snapshot.ready:
					break
			assert_true(snapshot.ready, "%s/%d: %s" % [state, count, snapshot.fit_guidance])
			assert_eq(Invariants.validate(snapshot), PackedStringArray(), "%s/%d" % [state, count])
			progress.finish(waited_frames)
			viewport.queue_free()
			await get_tree().process_frame


func test_replacement_public_states_on_phone_show_content_or_guidance() -> void:
	var progress := Progress.new("characterization/phone", 32)
	for count: int in [2, 4, 6, 7]:
		for state: StringName in [
			&"human-turn-preflop",
			&"human-turn-river",
			&"bot-turn",
			&"status-retained-fold",
			&"all-in-runout",
			&"showdown-long",
			&"elimination",
			&"tournament-winner"
		]:
			progress.begin("%s / p%d" % [state, count])
			var viewport := SubViewport.new()
			viewport.size = Vector2i(390, 844)
			viewport.gui_embed_subwindows = true
			add_child(viewport)
			var table := TableScene.instantiate() as GuiReplacementTableController
			table.touch_entry = true
			table.set_anchors_preset(Control.PRESET_TOP_LEFT)
			viewport.add_child(table)
			table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(viewport.size)))
			var fixture: Dictionary = Fixtures.by_id(state, count)
			assert_true(table.bind_view(fixture.view, {}, {}), "%s/%d" % [state, count])
			var waited_frames: int = 0
			var snapshot: GuiLayoutSnapshot
			for _frame: int in 180:
				await get_tree().process_frame
				waited_frames += 1
				snapshot = table.get_layout_snapshot()
				if (
					not snapshot.pending
					and (
						snapshot.ready
						or (
							not snapshot.fit_guidance.is_empty()
							and snapshot.fit_guidance != "Waiting for table measurements."
						)
					)
				):
					break
			assert_true(
				snapshot.ready or not snapshot.fit_guidance.is_empty(), "%s/%d" % [state, count]
			)
			assert_eq(Invariants.validate(snapshot), PackedStringArray(), "%s/%d" % [state, count])
			assert_eq(table.get_table_view_model().seats.size(), count, "%s/%d" % [state, count])
			progress.finish(waited_frames)
			viewport.queue_free()
			await get_tree().process_frame


func test_independent_large_values_remain_exact_or_show_guidance() -> void:
	var progress := Progress.new("characterization/large-values", 10)
	for allocation: Vector2i in [Vector2i(390, 844), Vector2i(1920, 1300)]:
		for target: String in ["hero", "opponent", "pot", "blinds", "all-in"]:
			progress.begin("%s / %s" % [allocation, target])
			var viewport := SubViewport.new()
			viewport.size = allocation
			viewport.gui_embed_subwindows = true
			add_child(viewport)
			var table := TableScene.instantiate() as GuiReplacementTableController
			table.touch_entry = allocation.x < 600
			table.set_anchors_preset(Control.PRESET_TOP_LEFT)
			viewport.add_child(table)
			table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(allocation)))
			var view: GameView = Fixtures.by_id(&"human-turn-preflop", 4).view
			match target:
				"hero":
					view._seats[0].stack = 6999999
					view._action_history = [
						PublicActionRecord.new(0, PlayerAction.Kind.RAISE, 6999999)
					]
				"opponent":
					view._seats[1].stack = 6999999
					view._action_history = [
						PublicActionRecord.new(1, PlayerAction.Kind.RAISE, 999999)
					]
				"pot":
					view.pot_amount = 8999999
				"blinds":
					view.small_blind = 500000
					view.big_blind = 1000000
				"all-in":
					view._action_history = [
						PublicActionRecord.new(1, PlayerAction.Kind.ALL_IN, 6999999)
					]
			assert_true(table.bind_view(view, {}, {}), target)
			var waited_frames: int = 0
			var snapshot: GuiLayoutSnapshot
			for _frame: int in 180:
				await get_tree().process_frame
				waited_frames += 1
				snapshot = table.get_layout_snapshot()
				if (
					not snapshot.pending
					and (
						snapshot.ready
						or (
							not snapshot.fit_guidance.is_empty()
							and snapshot.fit_guidance != "Waiting for table measurements."
						)
					)
				):
					break
			assert_eq(
				Invariants.validate(snapshot), PackedStringArray(), "%s/%s" % [allocation, target]
			)
			var model: TableViewModel = table.get_table_view_model()
			match target:
				"hero":
					assert_eq(model.seat_for(0).stack_value_text, "6999999")
				"opponent":
					assert_eq(model.seat_for(1).stack_value_text, "6999999")
					assert_string_contains(model.seat_for(1).latest_action_text, "999999")
				"pot":
					assert_string_contains(model.center.pot_text, "8999999")
				"blinds":
					assert_string_contains(model.center.blind_level_text, "1000000")
				"all-in":
					assert_string_contains(model.seat_for(1).latest_action_text, "6999999")
			progress.finish(waited_frames)
			viewport.queue_free()
			await get_tree().process_frame
