extends "res://tests/support/poker_gut_test.gd"

const Logo := preload("res://scenes/gui/components/BrandLogo.tscn")
const States := preload("res://tests/support/gui_visual_state_fixtures.gd")
const Assertions := preload("res://tests/support/gui_invariant_assertions.gd")
const Geometry := preload("res://scripts/gui/platform/gui_viewport_geometry.gd")
const MainScene := preload("res://scenes/main.tscn")
const BrowserFixture := preload("res://tests/support/gui_browser_capture_fixture.gd")


func test_shared_logo_cannot_capture_input_or_force_container_minimum() -> void:
	var logo := Logo.instantiate() as TextureRect
	add_child_autofree(logo)
	assert_eq(logo.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(logo.focus_mode, Control.FOCUS_NONE)
	assert_eq(logo.get_combined_minimum_size(), Vector2.ZERO)
	assert_eq(logo.expand_mode, TextureRect.EXPAND_IGNORE_SIZE)
	assert_eq(logo.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert_not_null(logo.texture)
	assert_false(logo.material.get_shader_parameter("embossed"))


func test_branding_asset_contains_real_transparency_and_visible_ink() -> void:
	var logo := Logo.instantiate() as TextureRect
	add_child_autofree(logo)
	var image: Image = logo.texture.get_image()
	assert_ne(
		image.detect_alpha(),
		Image.ALPHA_NONE,
		"A shader must not disguise an opaque checkerboard asset."
	)
	var transparent: int = 0
	var opaque: int = 0
	for y: int in range(0, image.get_height(), 8):
		for x: int in range(0, image.get_width(), 8):
			var alpha: float = image.get_pixel(x, y).a
			transparent += int(alpha < 0.01)
			opaque += int(alpha > 0.99)
	assert_gt(transparent, 0, "The actual imported texture retains transparent background pixels.")
	assert_gt(opaque, 0, "The actual imported texture retains solid logo details.")


func test_table_decoration_does_not_change_layout_or_private_card_observations() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1300)
	add_child_autofree(viewport)
	var table := (
		load("res://scenes/gui/ReplacementPokerTable.tscn").instantiate()
		as GuiReplacementTableController
	)
	table.set_anchors_preset(Control.PRESET_TOP_LEFT)
	viewport.add_child(table)
	table.set_viewport_geometry(GuiViewportGeometry.injected(Vector2(viewport.size)))
	assert_true(table.bind_view(States.by_id(&"human-turn-preflop", 6).view, {}, {}))
	assert_true(await _settle_table(table))
	var logo := table.get_composition().get_control(&"logo") as TextureRect
	assert_true(logo.material.get_shader_parameter("embossed"))
	assert_eq(logo.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(logo.get_combined_minimum_size(), Vector2.ZERO)
	var before: GuiLayoutSnapshot = table.get_layout_snapshot()
	var minimum: Vector2 = table.get_composition().get_combined_minimum_size()
	logo.hide()
	await wait_process_frames(3)
	var after: GuiLayoutSnapshot = table.get_layout_snapshot()
	assert_eq(after.surface_rect, before.surface_rect)
	assert_eq(table.get_composition().get_combined_minimum_size(), minimum)
	for role: StringName in before.elements:
		if role != &"logo":
			assert_eq(after.elements[role].rect, before.elements[role].rect, String(role))
	for seat_id: int in before.seats:
		assert_eq(after.seats[seat_id].footprint, before.seats[seat_id].footprint)
		var cards: Array[GuiCardSnapshot] = before.seats[seat_id].cards
		for index: int in cards.size():
			var other: GuiCardSnapshot = after.seats[seat_id].cards[index]
			assert_eq(other.kind, cards[index].kind)
			assert_eq(other.authorized, cards[index].authorized)
			assert_eq(other.rank.text, cards[index].rank.text)
			assert_eq(other.element.rect, cards[index].element.rect)


func test_startup_branding_keeps_essential_form_fully_visible_without_scrolling() -> void:
	for extent: Vector2i in [
		Vector2i(390, 844), Vector2i(844, 390), Vector2i(390, 640), Vector2i(844, 330)
	]:
		var main: StartupConfigController = _startup(extent)
		await wait_process_frames(5)
		assert_false(main.get_node("Center") is ScrollContainer)
		var bounds := Rect2(Vector2.ZERO, Vector2(extent))
		var logo := main.get_node("%BrandLogo") as TextureRect
		assert_eq(logo.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_true(bounds.grow(0.01).encloses(logo.get_global_rect()), str(extent))
		var snapshot: GuiLayoutSnapshot = main.get_layout_snapshot()
		assert_eq(Assertions.validate_snapshot(snapshot), PackedStringArray(), str(extent))
		for role: StringName in [
			&"player_count",
			&"starting_stack",
			&"small_blind",
			&"big_blind",
			&"start",
			&"quit",
			&"player_count_label",
			&"starting_stack_label",
			&"small_blind_label",
			&"big_blind_label",
			&"legacy_models"
		]:
			var field: GuiLayoutElement = snapshot.startup.fields[role]
			assert_true(field.visible, "%s %s" % [extent, role])
			assert_true(bounds.grow(0.01).encloses(field.rect), "%s %s" % [extent, role])
			assert_gte(field.font_size, 20, String(role))
			if field.interactive:
				assert_gte(field.allocated_size.y, 48.0, String(role))


func test_startup_uses_role_metrics_without_geometry_multiplied_text() -> void:
	for extent: Vector2i in [Vector2i(390, 844), Vector2i(1920, 1080), Vector2i(1200, 1920)]:
		var main: StartupConfigController = _startup(extent)
		await wait_process_frames(5)
		var compact: bool = extent.x == 390
		var form: Control = main.get_node("%Form")
		assert_same(form.theme, GuiTypography.Compact if compact else GuiTypography.Regular)
		var title: Label = main.get_node("%Title")
		assert_eq(title.get_theme_font_size("font_size"), 24 if compact else 28)
		assert_false(title.has_theme_font_size_override("font_size"))
		for name: String in [
			"PlayerCountInput",
			"StartingStackInput",
			"SmallBlindInput",
			"BigBlindInput",
			"PlayerCountLabel",
			"Description",
			"UseLegacyModelsCheckBox",
			"StartButton",
			"QuitApplicationButton",
		]:
			var control: Control = main.get_node("%" + name)
			assert_eq(control.get_theme_font_size("font_size"), 20, name)
			assert_false(control.has_theme_font_size_override("font_size"), name)


func test_phone_table_background_covers_safe_insets_and_resets_for_other_profiles_and_startup(
) -> void:
	var main := MainScene.instantiate() as StartupConfigController
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(390, 844)
	add_child_autofree(main)
	await wait_process_frames(5)
	var background := main.get_node("Background") as ColorRect
	var startup_color: Color = background.color
	assert_ne(startup_color, Color("075c35"))
	main.get_viewport_adapter().inject_geometry(
		Geometry.injected(Vector2(390, 844), Rect2(11, 23, 362, 792))
	)
	var fixture: Dictionary = BrowserFixture.descriptor(2)
	var table := main.get_table_controller() as GuiReplacementTableController
	(main.get_node("Center") as Control).hide()
	table.show()
	assert_true(table.bind_view(fixture.view, fixture.avatars, fixture.names))
	await wait_process_frames(10)
	assert_eq(background.color, Color("075c35"))
	assert_true(background.get_global_rect().encloses(Rect2(Vector2.ZERO, Vector2(390, 844))))
	assert_true(background.get_global_rect().has_point(Vector2(1, 1)))
	main.size = Vector2(844, 390)
	main.get_viewport_adapter().inject_geometry(Geometry.injected(main.size))
	await wait_process_frames(10)
	assert_eq(background.color, startup_color)
	main.size = Vector2(390, 844)
	main.get_viewport_adapter().inject_geometry(Geometry.injected(main.size))
	await wait_process_frames(10)
	assert_eq(background.color, Color("075c35"))
	table.return_to_startup_requested.emit()
	await wait_process_frames(5)
	assert_eq(background.color, startup_color)


func _startup(extent: Vector2i) -> StartupConfigController:
	var viewport := SubViewport.new()
	viewport.size = extent
	viewport.gui_embed_subwindows = true
	add_child_autofree(viewport)
	var main := MainScene.instantiate() as StartupConfigController
	main.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.size = Vector2(extent)
	viewport.add_child(main)
	return main


func _settle_table(table: GuiReplacementTableController) -> bool:
	for _frame: int in 180:
		await get_tree().process_frame
		var snapshot: GuiLayoutSnapshot = table.get_layout_snapshot()
		if snapshot.ready and not snapshot.pending:
			return true
	return false
