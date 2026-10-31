extends GutTest

const TableScene := preload("res://scenes/gui/ReplacementPokerTable.tscn")
const DefaultConfig := preload("res://resources/gui_layout_config.tres")
var _viewport: SubViewport
var _table: GuiReplacementTableController


class PassiveAgent:
	extends Agent

	func choose_action(view: GameView) -> PlayerAction:
		return (
			PlayerAction.check_action()
			if PlayerAction.Kind.CHECK in view.legal_actions
			else PlayerAction.call_action()
		)


func test_config_defaults_off_in_code_resource_and_production_scene() -> void:
	assert_false(GuiLayoutConfig.new().useTooLittleRoomWarning)
	assert_false(DefaultConfig.useTooLittleRoomWarning)
	var table := TableScene.instantiate() as GuiReplacementTableController
	assert_same(table.layout_config, DefaultConfig)
	table.free()


func test_portrait_landscape_and_safe_area_changes_keep_table_and_menu_when_warning_is_off(
) -> void:
	await _mount(false)
	assert_true(_table.bind_view(GuiVisualStateFixtures.replacement_flop(6).view, {}, {}))
	for dimensions: Vector2i in [Vector2i(390, 640), Vector2i(780, 320), Vector2i(360, 620)]:
		_viewport.size = dimensions
		_table.size = Vector2(dimensions)
		var safe := Rect2(Vector2(9, 13), Vector2(dimensions) - Vector2(22, 30))
		_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(dimensions), safe))
		for frame: int in 20:
			await wait_process_frames(1)
			_assert_no_warning(_table)
		assert_true(await _settle())
		var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
		assert_true(snapshot.ready)
		assert_true(snapshot.fit_guidance.is_empty())
		assert_eq(snapshot.usable_rect, safe)
		assert_eq(snapshot.seats.size(), 6)
		assert_not_null(_table.get_composition())
		_assert_no_warning(_table)
		var host := _table.get_node("CompositionHost") as GuiCompositionHost
		assert_eq(host.state.status, GuiCompositionState.Status.READY)
		var more := _table.get_node("GuidanceRail/Row/More") as Button
		if more.is_visible_in_tree():
			assert_true(safe.encloses(more.get_global_rect()))
			more.pressed.emit()
			assert_true(_table.get_overlay_host().is_active())
			_table.get_overlay_host().close()


func test_runtime_toggle_restores_warning_without_resetting_match_or_wager_draft() -> void:
	await _mount(false)
	assert_true(_table.bind_view(GuiVisualStateFixtures.replacement_flop(6).view, {}, {}))
	assert_true(await _settle())
	_table.get_composition().set_wager_draft("00125")
	_table.get_composition().wager_edited.emit("00125")
	_table.layout_config.useTooLittleRoomWarning = true
	assert_true(await _settle())
	assert_false(_table.get_layout_snapshot().fit_guidance.is_empty())
	assert_false(_table.get_layout_snapshot().ready)
	_table.layout_config.useTooLittleRoomWarning = false
	assert_true(await _settle())
	assert_true(_table.get_layout_snapshot().ready)
	assert_eq(_table.get_composition().get_wager_draft(), "00125")
	_assert_no_warning(_table)


func test_live_human_action_is_not_blocked_by_an_overflowing_layout() -> void:
	await _mount(false)
	var agents: Dictionary[int, Agent] = {
		0: HumanAgent.new(), 1: PassiveAgent.new(), 2: PassiveAgent.new()
	}
	var ids: Dictionary[int, StringName] = {0: &"human", 1: &"passive", 2: &"passive"}
	var config := ResolvedTournamentConfig.new(3, 100, 5, 10, 9123, &"single_table", ids)
	var game := TournamentMatch.new(config, agents)
	assert_ne(game.start(32).status, StepResult.Status.ERROR)
	_viewport.size = Vector2i(390, 300)
	_table.size = Vector2(_viewport.size)
	_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(_viewport.size)))
	assert_true(_table.bind_match(game, 0, {}, {}))
	assert_true(await _settle())
	var before: GameView = game.get_view_for(0)
	assert_eq(before.acting_seat, 0)
	_table.layout_config.useTooLittleRoomWarning = true
	assert_true(await _settle())
	assert_false(_table.get_layout_snapshot().ready)
	_table.layout_config.useTooLittleRoomWarning = false
	assert_true(await _settle())
	var after: GameView = game.get_view_for(0)
	assert_eq(after.hand_number, before.hand_number)
	assert_eq(after.acting_seat, before.acting_seat)
	assert_eq(after.pot_amount, before.pot_amount)
	assert_eq(after.action_history.size(), before.action_history.size())
	assert_ne(_table.submit_intent(&"check_call").status, StepResult.Status.ERROR)
	assert_gt(game.get_view_for(0).action_history.size(), before.action_history.size())
	_table.teardown()


func test_nine_seat_resize_keeps_every_seat_with_warnings_off() -> void:
	await _mount(false)
	assert_true(_table.bind_view(GuiVisualStateFixtures.replacement_flop(9).view, {}, {}))
	assert_true(await _settle())
	assert_true(_table.get_layout_snapshot().ready)
	assert_eq(_table.get_layout_snapshot().seats.size(), 9)
	_assert_no_warning(_table)


func test_overflow_policy_preserves_validation_and_prefers_a_fitting_candidate() -> void:
	var ids := PackedInt32Array([0, 1])
	var geometry := GuiViewportGeometry.injected(Vector2(390, 640))
	var small := _candidate(ids, Vector2(400, 700))
	var large := _candidate(ids, Vector2(500, 800))
	var strict: GuiFitPolicy = GuiFitPolicy.resolve(geometry, ids, 0, [large, small])
	assert_eq(strict.status, GuiFitPolicy.Status.TOO_SMALL)
	var overflow: GuiFitPolicy = GuiFitPolicy.resolve(
		geometry, ids, 0, [large, small], GuiSizeClass.AUTOMATIC, true
	)
	assert_eq(overflow.status, GuiFitPolicy.Status.OVERFLOW)
	assert_same(overflow.selected, small)
	var fitting := _candidate(ids, Vector2(350, 600))
	var fit: GuiFitPolicy = GuiFitPolicy.resolve(
		geometry, ids, 0, [large, small, fitting], GuiSizeClass.AUTOMATIC, true
	)
	assert_eq(fit.status, GuiFitPolicy.Status.FIT)
	assert_same(fit.selected, fitting)
	var invalid: GuiFitPolicy = GuiFitPolicy.resolve(
		GuiViewportGeometry.new(), ids, 0, [small], GuiSizeClass.AUTOMATIC, true
	)
	assert_eq(invalid.status, GuiFitPolicy.Status.NOT_READY)
	assert_null(invalid.selected)
	invalid = GuiFitPolicy.resolve(
		geometry, PackedInt32Array([0, 0]), 0, [small], GuiSizeClass.AUTOMATIC, true
	)
	assert_eq(invalid.status, GuiFitPolicy.Status.INVALID_INPUT)
	assert_null(invalid.selected)


func _candidate(ids: PackedInt32Array, minimum: Vector2) -> GuiFitCandidate:
	var result := GuiFitCandidate.new()
	result.mode = GuiSizeClass.LayoutMode.PHONE
	result.minimum = minimum
	result.seats = GuiSeatRows.compose(ids, 0, true)
	result.valid = true
	return result


func _mount(warning: bool) -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(390, 540)
	add_child_autofree(_viewport)
	_table = TableScene.instantiate() as GuiReplacementTableController
	_table.layout_config = GuiLayoutConfig.new()
	_table.layout_config.useTooLittleRoomWarning = warning
	_table.touch_entry = true
	_table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_table.size = Vector2(_viewport.size)
	_viewport.add_child(_table)
	_table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(_viewport.size)))
	var timing := GuiActionTimingConfig.new()
	timing.default_pause_seconds = 10.0
	_table.set_action_timing_config(timing)
	await wait_process_frames(1)


func _settle() -> bool:
	for frame: int in 180:
		await wait_process_frames(1)
		var snapshot: GuiLayoutSnapshot = _table.get_layout_snapshot()
		if not snapshot.pending and (snapshot.ready or not snapshot.fit_guidance.is_empty()):
			return true
	return false


func _assert_no_warning(node: Node) -> void:
	if node is SubViewport:
		return  # Offscreen measurement probes are not presented to the player.
	if node is GuiSpaceGuidance:
		assert_false((node as Control).is_visible_in_tree(), str(node.get_path()))
	for child: Node in node.get_children():
		_assert_no_warning(child)
