extends "res://tests/support/poker_gut_test.gd"

const GuiLayoutProfileScript := preload("res://scripts/gui/gui_layout_profile.gd")
const GuiWebViewportGeometryScript := preload("res://scripts/gui/gui_web_viewport_geometry.gd")
const GuiVisualStateFixturesScript := preload("res://tests/support/gui_visual_state_fixtures.gd")
const MainScene := preload("res://scenes/main.tscn")
const PokerTableScene := preload("res://scenes/poker_table.tscn")
const OPPONENT_ACTION_PADDING: float = 12.0
const HERO_ACTION_PADDING: float = 4.0


func test_android_backing_canvas_normalizes_to_phone_css_geometry() -> void:
	# The 1080 x 2340 screenshot includes browser and system chrome. The Web
	# canvas occupies a representative 1080 x 1920 backing rectangle within it.
	var backing_size := Vector2i(1080, 1920)
	var logical_size: Vector2i = GuiWebViewportGeometryScript.logical_size(backing_size, 3.0)

	assert_eq(logical_size, Vector2i(360, 640))
	assert_eq(
		GuiLayoutProfileScript.classify(Vector2(logical_size)),
		GuiLayoutProfileScript.Kind.PHONE_PORTRAIT,
	)
	assert_eq(
		GuiLayoutProfileScript.classify(Vector2(backing_size)),
		GuiLayoutProfileScript.Kind.DESKTOP,
		"The unnormalized backing canvas reproduces the physical-phone defect.",
	)


func test_fractional_device_pixel_ratio_recovers_css_viewport() -> void:
	assert_eq(
		GuiWebViewportGeometryScript.logical_size(Vector2i(1023, 2215), 2.625),
		Vector2i(390, 844),
	)


func test_normalized_android_portrait_browser_heights_use_real_phone_composition() -> void:
	await _assert_phone_composition(Vector2i(1080, 1920), 3.0)
	await _assert_phone_composition(Vector2i(360, 780), 1.0)
	await _assert_phone_composition(Vector2i(720, 1560), 2.0)
	await _assert_phone_composition(Vector2i(1080, 2340), 3.0)


func test_web_dpr_paths_keep_showdown_rank_suit_and_privacy() -> void:
	for web_case: Dictionary in [
		{"backing_size": Vector2i(360, 780), "pixel_ratio": 1.0},
		{"backing_size": Vector2i(720, 1560), "pixel_ratio": 2.0},
		{"backing_size": Vector2i(1080, 2340), "pixel_ratio": 3.0},
	]:
		var logical_size: Vector2i = GuiWebViewportGeometryScript.logical_size(
			web_case.backing_size, web_case.pixel_ratio
		)
		var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"showdown-long", 6)
		descriptor.view._revealed_hole_cards[5] = [
			CardData.new(10, CardData.Suit.DIAMONDS),
			CardData.new(14, CardData.Suit.CLUBS),
		]
		var table := PokerTableScene.instantiate() as PokerTableController
		table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		table.size = Vector2(logical_size)
		add_child_autofree(table)
		table.bind_view(descriptor.view, {}, {})
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		for seat: int in range(1, 6):
			var panel := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat)
			var is_revealed: bool = descriptor.view.revealed_hole_cards.has(seat)
			for card_index: int in range(1, 3):
				var card_face := (
					panel.find_child("ShowdownCard%d" % card_index, true, false) as Control
				)
				var card_back := panel.find_child("CardBack%d" % card_index, true, false)
				if not is_revealed:
					assert_null(card_face, "DPR %s seat %d privacy" % [web_case.pixel_ratio, seat])
					assert_not_null(
						card_back, "DPR %s seat %d card back" % [web_case.pixel_ratio, seat]
					)
					continue
				assert_not_null(card_face)
				assert_null(card_back)
				var rank := card_face.get_node("Content/Rank") as Label
				var suit := card_face.get_node("Content/Suit") as TextureRect
				assert_eq(rank.get_theme_font("font"), ThemeDB.fallback_font)
				assert_true(card_face.get_global_rect().encloses(rank.get_global_rect()))
				assert_true(card_face.get_global_rect().encloses(suit.get_global_rect()))
				assert_gte(suit.size.x, 18.0)
				assert_gte(suit.size.y, 18.0)


func test_normalized_android_landscape_uses_real_phone_composition() -> void:
	await _assert_phone_composition(Vector2i(1920, 1080), 3.0)


func test_real_phone_startup_to_table_transition_keeps_phone_composition() -> void:
	var main := MainScene.instantiate() as StartupConfigController
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(360, 780)
	add_child_autofree(main)
	await get_tree().process_frame

	main._on_start_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var table := main.get_node("PokerTable") as PokerTableController
	assert_eq(table.size, Vector2(360, 780))
	assert_true(GuiLayoutProfileScript.is_phone(table.get_layout_profile()))
	assert_false((table.get_node("%EventLog") as Control).visible)
	assert_false((table.get_node("%QuitButton") as Control).visible)
	assert_true((table.get_node("%PhoneMoreButton") as Control).visible)


func test_high_density_desktop_stays_desktop_after_normalization() -> void:
	var logical_size: Vector2i = GuiWebViewportGeometryScript.logical_size(
		Vector2i(2880, 1800), 2.0
	)

	assert_eq(logical_size, Vector2i(1440, 900))
	assert_eq(
		GuiLayoutProfileScript.classify(Vector2(logical_size)),
		GuiLayoutProfileScript.Kind.DESKTOP,
	)


func test_invalid_geometry_and_pixel_ratio_fail_safely() -> void:
	assert_eq(
		GuiWebViewportGeometryScript.logical_size(Vector2i(390, 844), 1.0),
		Vector2i(390, 844),
	)
	assert_eq(GuiWebViewportGeometryScript.logical_size(Vector2i.ZERO, 3.0), Vector2i.ZERO)
	assert_eq(
		GuiWebViewportGeometryScript.logical_size(Vector2i(390, 844), 0.0),
		Vector2i(390, 844),
	)


func _assert_phone_composition(backing_size: Vector2i, pixel_ratio: float) -> void:
	var logical_size: Vector2i = GuiWebViewportGeometryScript.logical_size(
		backing_size, pixel_ratio
	)
	var descriptor: Dictionary = GuiVisualStateFixturesScript.by_id(&"human-turn-preflop", 6)
	descriptor.view._seats[5].stack = 0
	descriptor.view._seats[5].all_in = true
	var actions: Array[PublicActionRecord] = [
		PublicActionRecord.new(1, PlayerAction.Kind.RAISE, 310),
		PublicActionRecord.new(2, PlayerAction.Kind.BET, 7),
		PublicActionRecord.new(3, PlayerAction.Kind.CALL, 42),
		PublicActionRecord.new(4, PlayerAction.Kind.BET, 120),
		PublicActionRecord.new(5, PlayerAction.Kind.ALL_IN, 1000),
		PublicActionRecord.new(0, PlayerAction.Kind.RAISE, 310),
	]
	descriptor.view._action_history = actions
	var table := PokerTableScene.instantiate() as PokerTableController
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	table.size = Vector2(logical_size)
	add_child_autofree(table)
	table.bind_view(descriptor.view, {}, {})
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(GuiLayoutProfileScript.is_phone(table.get_layout_profile()))
	assert_null(table.get_node("TableMargin/Felt/TableSurface/Seats/Seat1").find_child("Avatar"))
	assert_false((table.get_node("%EventLog") as Control).visible)
	assert_false((table.get_node("%QuitButton") as Control).visible)
	assert_true((table.get_node("%PhoneMoreButton") as Control).visible)
	for seat: int in range(1, 6):
		var panel := table.get_node("TableMargin/Felt/TableSurface/Seats/Seat%d" % seat)
		var badge := panel.find_child("ActionBadge", true, false) as Label
		_assert_action_padding(badge, OPPONENT_ACTION_PADDING, "seat %d" % seat)
	var hero_badge := table.get_node("%PhoneHeroActionBadge") as Label
	_assert_action_padding(hero_badge, HERO_ACTION_PADDING, "hero")


func _assert_action_padding(label: Label, padding: float, context: String) -> void:
	var rendered_width: float = (
		label
		. get_theme_font("font")
		. get_string_size(
			label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			label.get_theme_font_size("font_size"),
		)
		. x
	)
	assert_lte(rendered_width + padding, label.size.x, "%s action padding" % context)
