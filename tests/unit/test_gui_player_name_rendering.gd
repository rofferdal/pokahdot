extends "res://tests/support/poker_gut_test.gd"

const GuiAvatarCatalogScript := preload("res://scripts/gui/gui_avatar_catalog.gd")
const PokerTableScene := preload("res://scenes/poker_table.tscn")

const DESKTOP_VIEWPORT := Vector2(1920, 1080)
const COMPACT_VIEWPORT := Vector2(950, 532)
const HUMAN_LABEL := "Human"
const EIGHT_CODE_POINT_NAME := "Alexandr"


func test_assigned_names_replace_core_names_for_representative_table_sizes() -> void:
	for player_count: int in [2, 6, 9]:
		var human_seat: int = player_count / 2
		var table := _table_for(player_count, human_seat, DESKTOP_VIEWPORT)
		var assignments := _name_assignments(player_count, human_seat)
		(
			table
			. bind_view(
				_view(player_count, human_seat),
				_avatar_assignments(player_count),
				assignments,
			)
		)
		await _settle_layout()

		for seat: int in range(player_count):
			var label := _name_label(table, seat)
			assert_eq(label.text, assignments[seat], "%d-player seat %d" % [player_count, seat])
			assert_false(
				label.text.begins_with("Core Player"),
				"GUI labels must not expose core display names",
			)


func test_human_label_is_exact_at_an_arbitrary_core_seat() -> void:
	var player_count: int = 6
	var human_seat: int = 4
	var table := _table_for(player_count, human_seat, DESKTOP_VIEWPORT)
	var assignments := _name_assignments(player_count, human_seat)
	(
		table
		. bind_view(
			_view(player_count, human_seat, "Internal Hero Name"),
			_avatar_assignments(player_count),
			assignments,
		)
	)
	await _settle_layout()

	assert_eq(_name_label(table, human_seat).text, HUMAN_LABEL)
	assert_false("you" in _name_label(table, human_seat).text.to_lower())
	assert_false("Internal Hero Name" in _name_label(table, human_seat).text)
	for seat: int in range(player_count):
		if seat != human_seat:
			assert_eq(_name_label(table, seat).text, assignments[seat])


func test_name_mapping_stays_stable_across_match_refresh_and_resize() -> void:
	var player_count: int = 6
	var human_seat: int = 3
	var assignments := _name_assignments(player_count, human_seat)
	var avatars := _avatar_assignments(player_count)
	var match_instance := _started_match(player_count, human_seat)
	var table := _table_for(player_count, human_seat, DESKTOP_VIEWPORT)
	table.bind_match(match_instance, human_seat, avatars, assignments)
	await _settle_layout()
	_assert_seat_presentations(table, assignments, avatars)

	for viewport_size: Vector2 in [COMPACT_VIEWPORT, DESKTOP_VIEWPORT]:
		table.size = viewport_size
		table.refresh_from_match()
		await _settle_layout()
		_assert_seat_presentations(table, assignments, avatars)


func test_long_names_fit_desktop_and_compact_layouts_without_reducing_text_below_twenty_px(
) -> void:
	for viewport_size: Vector2 in [DESKTOP_VIEWPORT, COMPACT_VIEWPORT]:
		for player_count: int in [2, 6, 9]:
			var human_seat: int = player_count / 2
			var assignments := _name_assignments(player_count, human_seat)
			if player_count > 1:
				assignments[0 if human_seat != 0 else 1] = "Youssef"
			if player_count > 2:
				assignments[1 if human_seat != 1 else 2] = "Leilani"
			if player_count > 3:
				assignments[2 if human_seat != 2 else 3] = EIGHT_CODE_POINT_NAME
			var table := _table_for(player_count, human_seat, viewport_size)
			(
				table
				. bind_view(
					_view(player_count, human_seat),
					_avatar_assignments(player_count),
					assignments,
				)
			)
			await _settle_layout()

			for seat: int in range(player_count):
				var label := _name_label(table, seat)
				var font_size: int = label.get_theme_font_size("font_size")
				var rendered_width: float = (
					label
					. get_theme_font("font")
					. get_string_size(
						label.text,
						HORIZONTAL_ALIGNMENT_LEFT,
						-1.0,
						font_size,
					)
					. x
				)
				var context := (
					"%s, %d-player seat %d (%s)" % [viewport_size, player_count, seat, label.text]
				)
				assert_gte(font_size, 20, context)
				assert_lte(rendered_width, label.size.x, context)
				assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_OFF, context)
				assert_true(label.is_visible_in_tree(), context)
			_assert_seats_are_contained_and_distinct(table, viewport_size, player_count)


func _table_for(
	_player_count: int,
	_human_seat: int,
	viewport_size: Vector2,
) -> PokerTableController:
	var table := PokerTableScene.instantiate() as PokerTableController
	table.hide()
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = viewport_size
	add_child_autofree(table)
	table.show()
	return table


func _view(
	player_count: int,
	human_seat: int,
	human_core_name: String = "Core Player Human",
) -> GameView:
	var view := GameView.new()
	view.hero_seat = human_seat
	for seat: int in range(player_count):
		var agent: Agent = (
			HumanAgent.new() if seat == human_seat else RandomAgent.new(_seeded_rng(1000 + seat))
		)
		var core_name: String = human_core_name if seat == human_seat else "Core Player %d" % seat
		view._seats.append(
			PlayerView.new(Player.new(&"render_%d" % seat, core_name, seat, 100, agent))
		)
	return view


func _started_match(player_count: int, human_seat: int) -> TournamentMatch:
	var seat_agents: Dictionary[int, StringName] = {}
	var agents: Dictionary[int, Agent] = {}
	for seat: int in range(player_count):
		seat_agents[seat] = &"human" if seat == human_seat else StringName("random_%d" % seat)
		agents[seat] = (
			HumanAgent.new() if seat == human_seat else RandomAgent.new(_seeded_rng(2000 + seat))
		)
	var config := (
		ResolvedTournamentConfig
		. new(
			player_count,
			100,
			5,
			10,
			7331,
			&"single_table",
			seat_agents,
		)
	)
	var match_instance := TournamentMatch.new(config, agents)
	var result: StepResult = match_instance.start(1)
	assert_ne(result.status, StepResult.Status.ERROR, result.message)
	return match_instance


func _name_assignments(player_count: int, human_seat: int) -> Dictionary[int, String]:
	var bot_names: PackedStringArray = [
		"Youssef", "Leilani", "Alexandr", "Minseo", "Haruto", "Anahit", "Adaeze", "Priya"
	]
	var assignments: Dictionary[int, String] = {}
	var bot_index: int = 0
	for seat: int in range(player_count):
		if seat == human_seat:
			assignments[seat] = HUMAN_LABEL
		else:
			assignments[seat] = bot_names[bot_index]
			bot_index += 1
	return assignments


func _avatar_assignments(player_count: int) -> Dictionary[int, String]:
	var paths: PackedStringArray = GuiAvatarCatalogScript.default_avatar_paths()
	var assignments: Dictionary[int, String] = {}
	for seat: int in range(player_count):
		assignments[seat] = paths[seat]
	return assignments


func _name_label(table: PokerTableController, seat: int) -> Label:
	return (
		table.get_node(
			"TableMargin/Felt/TableSurface/Seats/Seat%d/Content/Header/Identity/Name" % seat
		)
		as Label
	)


func _assert_seat_presentations(
	table: PokerTableController,
	names: Dictionary[int, String],
	avatars: Dictionary[int, String],
) -> void:
	for seat: int in names:
		assert_eq(_name_label(table, seat).text, names[seat])
		var avatar: TextureRect = table.get_node(
			"TableMargin/Felt/TableSurface/Seats/Seat%d/Content/Header/AvatarRegion/Avatar" % seat
		)
		assert_not_null(avatar.texture)
		assert_eq(avatar.texture.resource_path, avatars[seat])


func _assert_seats_are_contained_and_distinct(
	table: PokerTableController,
	viewport_size: Vector2,
	player_count: int,
) -> void:
	var surface := table.get_node("TableMargin/Felt/TableSurface") as Control
	var surface_rect := Rect2(Vector2.ZERO, surface.size)
	var placed_rects: Array[Rect2] = []
	for seat: int in table.get_seat_rects():
		var seat_rect: Rect2 = table.get_seat_rects()[seat]
		var context := "%s, %d-player seat %d" % [viewport_size, player_count, seat]
		assert_true(surface_rect.encloses(seat_rect), context)
		for placed_rect: Rect2 in placed_rects:
			assert_false(seat_rect.intersects(placed_rect), context)
		placed_rects.append(seat_rect)


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _settle_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
