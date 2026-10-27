extends "res://tests/support/poker_gut_test.gd"

const Fixture := preload("res://tests/support/gui_browser_capture_fixture.gd")
const Harness := preload("res://tests/support/gui_scene_harness.gd")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const Layout := preload("res://scripts/gui/table_seat_layout.gd")


func test_capture_seats_keep_clockwise_identity_through_resize_and_source_reordering() -> void:
	for hero: int in [0, 3]:
		var descriptor: Dictionary = Fixture.descriptor()
		descriptor.view.hero_seat = hero
		descriptor.view.acting_seat = hero
		if hero != 0:
			descriptor.names[0] = descriptor.names[hero]
			descriptor.names[hero] = "Human"
		for player: PlayerView in descriptor.view._seats:
			player.is_human = player.seat == hero
		descriptor.view._seats.reverse()
		var harness: Node = Harness.new()
		add_child(harness)
		var rendered: Dictionary = harness.render(descriptor, Vector2i(950, 532))
		(rendered.table as PokerTableController).bind_view(
			descriptor.view, descriptor.avatars, descriptor.names
		)
		assert_true(await harness.settle_layout())
		for dimensions: Vector2i in [
			Vector2i(950, 532),
			Vector2i(1024, 600),
			Vector2i(1201, 800),
			Vector2i(1247, 636),
			Vector2i(1377, 777),
			Vector2i(1920, 1080),
			Vector2i(1024, 768),
			Vector2i(1247, 636),
			Vector2i(1201, 800),
			Vector2i(1024, 600),
			Vector2i(950, 532)
		]:
			harness.resize_viewport(dimensions)
			assert_true(await harness.settle_layout())
			var table: PokerTableController = rendered.table
			_assert_order(table, hero, 6, str(dimensions))
			assert_eq(Invariants.validate(rendered), PackedStringArray(), str(dimensions))
			for seat: int in range(6):
				var panel: PanelContainer = table._seat_widgets[seat]
				var label := panel.find_child("Name", true, false) as Label
				assert_eq(label.text, descriptor.names[seat], "Name belongs to source seat")
				var amount: String = str(descriptor.view.seats[5 - seat].stack)
				assert_has(
					[amount, amount + " chips"],
					(panel.find_child("Stack", true, false) as Label).text,
					"Stack belongs to source seat"
				)
				_assert_marker(panel, seat, descriptor.view)
				assert_eq(descriptor.view.seats[5 - seat].seat, seat, "Source order is unchanged")
		harness.queue_free()
		await get_tree().process_frame


func test_small_desktop_perimeter_preserves_occupied_cells_for_all_counts() -> void:
	for surface: Vector2 in [Vector2(886, 476), Vector2(960, 544), Vector2(1137, 744)]:
		var center := Rect2((surface - Vector2(280, 198)) * 0.5, Vector2(280, 198))
		var cell_size := Vector2((center.position.x - 6.0) * 0.5, 88)
		var prefix: Array[int] = [1, 2, 0, 3, 5, 6, 4, 7]
		var columns: Array[float] = [
			0.0, center.position.x - cell_size.x, center.end.x, surface.x - cell_size.x
		]
		for count: int in range(2, 10):
			var ordered: Array[Vector2] = Layout.small_desktop_opponent_positions(
				count, surface, center, cell_size
			)
			assert_eq(ordered.size(), count - 1)
			var previous: float = 0.0
			for index: int in range(count - 1):
				var cell: int = prefix[index]
				assert_has(ordered, Vector2(columns[cell % 4], (cell / 4) * 172.0))
				var delta: Vector2 = ordered[index] + cell_size * 0.5 - surface * 0.5
				var angle: float = fposmod(atan2(delta.x, -delta.y) - PI, TAU)
				assert_gt(angle, previous)
				previous = angle


func test_all_counts_keep_actual_order_with_nonzero_recipient_and_reversed_source() -> void:
	for count: int in range(2, 10):
		for hero: int in [0, count - 1]:
			var descriptor: Dictionary = _count_descriptor(count, hero)
			var harness: Node = Harness.new()
			add_child(harness)
			var rendered: Dictionary = harness.render(descriptor, Vector2i(950, 532))
			var table: PokerTableController = rendered.table
			table.bind_view(descriptor.view, descriptor.avatars, descriptor.names)
			assert_true(await harness.settle_layout())
			_assert_order(table, hero, count, "%d players, hero %d" % [count, hero])
			for seat: int in count:
				var panel: PanelContainer = table._seat_widgets[seat]
				assert_eq(
					(panel.find_child("Name", true, false) as Label).text, descriptor.names[seat]
				)
				_assert_marker(panel, seat, descriptor.view)
				assert_eq(descriptor.view.seats[count - 1 - seat].seat, seat)
			harness.queue_free()
			await get_tree().process_frame


func _count_descriptor(count: int, hero: int) -> Dictionary:
	var descriptor: Dictionary = Fixture.descriptor()
	var view := GameView.new()
	view.hero_seat = hero
	view.button_seat = hero
	view.small_blind_seat = hero if count == 2 else posmod(hero + 1, count)
	view.big_blind_seat = posmod(view.small_blind_seat + 1, count)
	view.acting_seat = hero
	view.small_blind = 5
	view.big_blind = 10
	view._legal_actions = [PlayerAction.Kind.CHECK]
	view._hero_hole_cards = descriptor.view.hero_hole_cards.duplicate()
	var names: Dictionary[int, String] = {}
	var avatars: Dictionary[int, String] = {}
	var paths: PackedStringArray = GuiAvatarCatalog.default_avatar_paths()
	for seat: int in count:
		var player := Player.new(StringName("order_%d" % seat), "P%d" % seat, seat, 1000 + seat)
		var public_player := PlayerView.new(player)
		public_player.is_human = seat == hero
		view._seats.append(public_player)
		names[seat] = "Human" if seat == hero else "P%d" % seat
		avatars[seat] = paths[seat]
	view._seats.reverse()
	descriptor.view = view
	descriptor.names = names
	descriptor.avatars = avatars
	descriptor.player_count = count
	descriptor.events = []
	return descriptor


func _assert_marker(panel: PanelContainer, seat: int, view: GameView) -> void:
	var expected: Array[String] = []
	if seat == view.button_seat:
		expected.append("D")
	if seat == view.small_blind_seat:
		expected.append("SB")
	if seat == view.big_blind_seat:
		expected.append("BB")
	var marker := panel.find_child("Marker", true, false) as Label
	var text: String = marker.text
	if text == "S":
		text = "SB"
	elif text == "B":
		text = "BB"
	elif text == "D/S":
		text = "D SB"
	assert_eq(text, " ".join(expected), "Role belongs to source seat")


func _assert_order(table: PokerTableController, hero: int, count: int, context: String) -> void:
	var rects: Dictionary[int, Rect2] = table.get_seat_rects()
	var surface := table.get_node("TableMargin/Felt/TableSurface") as Control
	var center: Vector2 = surface.size * 0.5
	var hero_delta: Vector2 = rects[hero].get_center() - center
	var origin: float = atan2(hero_delta.x, -hero_delta.y)
	var previous: float = 0.0
	for relative: int in range(1, count):
		var seat: int = posmod(hero + relative, count)
		var delta: Vector2 = rects[seat].get_center() - center
		var angle: float = fposmod(atan2(delta.x, -delta.y) - origin, TAU)
		assert_gt(angle, previous, "%s clockwise seat %d" % [context, seat])
		assert_gt(rects[hero].get_center().y, rects[seat].get_center().y, context)
		previous = angle
