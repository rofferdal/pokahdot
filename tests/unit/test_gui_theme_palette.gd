extends GutTest

const ThemeResource := preload("res://resources/gui_theme.tres")
const Gallery := preload("res://tests/visual/gui_theme_gallery.tscn")
const REQUIRED_BASES: Dictionary[StringName, StringName] = {
	&"Felt": &"Panel",
	&"Zone": &"PanelContainer",
	&"SeatPanel": &"PanelContainer",
	&"SeatPanelActing": &"PanelContainer",
	&"SeatPanelFolded": &"PanelContainer",
	&"HeroPanel": &"PanelContainer",
	&"PhoneToken": &"PanelContainer",
	&"OverlayPanel": &"PanelContainer",
	&"CardFace": &"PanelContainer",
	&"CardBack": &"PanelContainer",
	&"StatusBand": &"Label",
	&"WinningHandText": &"Label",
	&"SeatText": &"Label",
	&"BodyText": &"Label",
	&"CardRank": &"Label",
	&"ActionButton": &"Button",
	&"PrimaryActionButton": &"Button",
	&"KeypadKey": &"Button",
	&"InputField": &"LineEdit",
	&"NumberField": &"LineEdit",
	&"WagerTotalField": &"LineEdit",
	&"InputFieldInvalid": &"LineEdit",
	&"EventLogBody": &"RichTextLabel",
}


func test_required_variations_resolve_to_their_native_control_family() -> void:
	assert_eq(ThemeResource.default_font_size, 29, "reference default is preserved")
	for variation: StringName in REQUIRED_BASES:
		assert_true(_inherits(variation, REQUIRED_BASES[variation]), str(variation))
	var root: Control = _root()
	var panels: Dictionary[StringName, PanelContainer] = {}
	for variation: StringName in [
		&"Zone",
		&"SeatPanel",
		&"SeatPanelActing",
		&"SeatPanelFolded",
		&"HeroPanel",
		&"PhoneToken",
		&"OverlayPanel",
		&"CardFace",
		&"CardBack"
	]:
		var panel := PanelContainer.new()
		panel.theme_type_variation = variation
		root.add_child(panel)
		panels[variation] = panel
		assert_true(_has_style(variation, &"panel"), str(variation))
		assert_is(panel.get_theme_stylebox("panel"), StyleBoxFlat)
	var ordinary: StyleBoxFlat = panels[&"SeatPanel"].get_theme_stylebox("panel") as StyleBoxFlat
	var acting: StyleBoxFlat = (
		panels[&"SeatPanelActing"].get_theme_stylebox("panel") as StyleBoxFlat
	)
	var folded: StyleBoxFlat = (
		panels[&"SeatPanelFolded"].get_theme_stylebox("panel") as StyleBoxFlat
	)
	assert_eq(acting.border_color, Color.WHITE)
	assert_eq(acting.border_width_left, ordinary.border_width_left * 6)
	assert_ne(folded.bg_color, ordinary.bg_color)
	var felt := Panel.new()
	felt.theme_type_variation = &"Felt"
	root.add_child(felt)
	assert_true(_has_style(&"Felt", &"panel"))
	assert_is(felt.get_theme_stylebox("panel"), StyleBoxFlat)


func test_action_states_are_authored_and_keep_the_shared_button_family() -> void:
	var root: Control = _root()
	for variation: StringName in [&"ActionButton", &"PrimaryActionButton", &"KeypadKey"]:
		var button := Button.new()
		button.theme_type_variation = variation
		button.text = "Quit" if variation == &"ActionButton" else "Done"
		button.custom_minimum_size = Vector2(48, 48)
		root.add_child(button)
		button.size = button.get_combined_minimum_size()
		assert_gte(button.size.x, 48.0)
		assert_gte(button.size.y, 48.0)
		assert_gte(button.get_theme_font_size("font_size"), 20)
		assert_eq(button.get_theme_color("font_color"), Color.WHITE)
		for color_name: StringName in [
			&"font_hover_color", &"font_pressed_color", &"font_focus_color"
		]:
			assert_eq(button.get_theme_color(color_name), Color.WHITE)
		assert_eq(button.get_theme_color("font_disabled_color"), Color("a8a8a8"))
		var normal: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
		assert_not_null(normal)
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			assert_true(_has_style(variation, state), "%s/%s" % [variation, state])
			var style: StyleBoxFlat = button.get_theme_stylebox(state) as StyleBoxFlat
			assert_not_null(style)
			_assert_rounded(style)
			if state != &"focus" or style.bg_color.a > 0.0:
				assert_gt(style.bg_color.g, style.bg_color.r)
				assert_gt(style.bg_color.g, style.bg_color.b)
				assert_lt(style.bg_color.get_luminance(), 0.3)
		var hover: StyleBoxFlat = button.get_theme_stylebox("hover") as StyleBoxFlat
		var pressed: StyleBoxFlat = button.get_theme_stylebox("pressed") as StyleBoxFlat
		var disabled: StyleBoxFlat = button.get_theme_stylebox("disabled") as StyleBoxFlat
		assert_ne(normal, hover)
		assert_ne(normal, pressed)
		assert_ne(normal, disabled)
		assert_ne(normal.bg_color, hover.bg_color)
		assert_ne(normal.bg_color, pressed.bg_color)
		assert_ne(normal.bg_color, disabled.bg_color)


func test_gallery_wide_seats_show_assigned_avatars_while_phone_can_omit_them() -> void:
	var gallery: Control = _gallery()
	await wait_process_frames(6)
	for index: int in 4:
		var path: String = "Margin/Gallery/Seats/Seat%d/Panel/Identity/Avatar" % index
		var avatar: TextureRect = gallery.get_node(path)
		assert_eq(
			avatar.texture.resource_path, "res://assets/avatars/avatar_%02d.png" % (index + 1)
		)
		assert_eq(avatar.size, Vector2(80, 80) if index == 3 else Vector2(64, 64))
		assert_eq(avatar.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		assert_eq(avatar.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_false(gallery.has_node("Margin/Gallery/Seats/Seat4/Panel/Identity/Avatar"))


func test_gallery_cards_keep_poker_proportions_and_maximal_equal_glyph_fonts() -> void:
	var gallery: Control = _gallery()
	await wait_process_frames(6)
	for name: String in ["Face", "RedFace", "Back"]:
		var card: PanelContainer = gallery.get_node("Margin/Gallery/Lower/Cards/" + name)
		assert_eq(card.size, Vector2(120, 168))
		assert_gte(card.size.x / card.size.y, 5.0 / 7.0 - 0.00001)
		if name == "Back":
			continue
		var value: GuiCardGlyphSample = card.get_node("Glyphs/Value")
		var suit: GuiCardGlyphSample = card.get_node("Glyphs/Suit")
		var font_size: int = value.font_size
		assert_eq(suit.font_size, font_size)
		assert_gt(font_size, 55)
		var box: StyleBox = card.get_theme_stylebox("panel")
		var available: Vector2 = card.size - box.get_minimum_size()
		var glyphs: VBoxContainer = card.get_node("Glyphs")
		assert_lte(glyphs.get_combined_minimum_size().x, available.x)
		assert_lte(glyphs.get_combined_minimum_size().y, available.y)
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			assert_gt(box.get_content_margin(side), 0.0)
		# Ask the Container for the next ink-sized controls' complete minimum.
		var probe := VBoxContainer.new()
		probe.theme = ThemeResource
		probe.add_theme_constant_override("separation", glyphs.get_theme_constant("separation"))
		add_child_autofree(probe)
		for text: String in [value.text, suit.text]:
			var label := GuiCardGlyphSample.new()
			label.text = text
			label.add_theme_font_override("font", value.get_theme_font("font"))
			label.font_size = font_size + 1
			probe.add_child(label)
		var next: Vector2 = probe.get_combined_minimum_size()
		assert_true(
			next.x > available.x or next.y > available.y,
			"next font size must exceed safe content allocation"
		)


func test_folded_gallery_surface_inherits_grayscale_and_human_has_more_reading_space() -> void:
	var gallery: Control = _gallery()
	await wait_process_frames(6)
	var folded: VBoxContainer = gallery.get_node("Margin/Gallery/Seats/Seat2")
	assert_is(folded.material, ShaderMaterial)
	assert_eq(
		(folded.material as ShaderMaterial).shader.resource_path,
		"res://resources/gui_grayscale.gdshader"
	)
	for descendant: Node in folded.find_children("*", "CanvasItem", true, false):
		assert_true((descendant as CanvasItem).use_parent_material)
	var panel: PanelContainer = folded.get_node("Panel")
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	assert_eq(style.bg_color.r, style.bg_color.g)
	assert_eq(style.bg_color.g, style.bg_color.b)
	assert_eq(style.border_color.r, style.border_color.g)
	assert_eq(style.border_color.g, style.border_color.b)
	var bot: PanelContainer = gallery.get_node("Margin/Gallery/Seats/Seat0/Panel")
	var human: PanelContainer = gallery.get_node("Margin/Gallery/Seats/Seat3/Panel")
	assert_gt(human.size.x, bot.size.x)
	assert_gt(human.size.y, bot.size.y)
	var bot_name: Label = bot.get_node("Identity/Copy/Title/Name")
	var human_name: Label = human.get_node("Identity/Copy/Title/Name")
	assert_gt(
		human_name.get_theme_font_size("font_size"), bot_name.get_theme_font_size("font_size")
	)
	for name: String in ["Face", "RedFace"]:
		var card: PanelContainer = gallery.get_node("Margin/Gallery/Lower/Cards/" + name)
		for glyph_name: String in ["Value", "Suit"]:
			var glyph: GuiCardGlyphSample = card.get_node("Glyphs/" + glyph_name)
			var font: Font = glyph.get_theme_font("font")
			var before: Vector2 = GuiCardGlyphSample.ink_bounds(font, glyph.text, 55).size
			var after: Vector2 = (
				GuiCardGlyphSample.ink_bounds(font, glyph.text, glyph.font_size).size
			)
			assert_gt(before.y, 0.0)
			assert_gte(after.y / before.y, 1.35, "visible ink is substantially larger than review2")
			assert_true(card.get_global_rect().grow(-6).encloses(glyph.get_global_rect()))


func test_dealer_is_a_separate_white_circle_and_winners_have_visible_stars() -> void:
	var gallery: Control = _gallery()
	await wait_process_frames(6)
	var path: String = "Margin/Gallery/Seats/Seat3/Panel/Markers/"
	for index: int in 5:
		var seat: Control = gallery.get_node("Margin/Gallery/Seats/Seat%d" % index)
		var surface: Control = seat.get_node("Panel")
		var status: Label = seat.get_node("Status")
		assert_eq(status.global_position.x, surface.global_position.x)
		assert_eq(status.size.x, surface.size.x)
	var dealer: PanelContainer = gallery.get_node(path + "Dealer")
	var blind: Label = gallery.get_node(path + "Blind")
	var style: StyleBoxFlat = dealer.get_theme_stylebox("panel")
	assert_eq(dealer.size, Vector2(40, 40))
	assert_eq(style.bg_color, Color.WHITE)
	assert_eq(style.corner_radius_top_left, 20)
	assert_eq(dealer.get_node("D").text, "D")
	assert_eq(blind.text, "SB")
	assert_gt(blind.global_position.x, dealer.get_global_rect().end.x)
	assert_eq(dealer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(blind.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var panel: PanelContainer = dealer.get_parent().get_parent()
	var markers: Control = dealer.get_parent()
	assert_almost_eq(markers.get_global_rect().end.x, panel.get_global_rect().end.x - 8, 1.0)
	assert_almost_eq(markers.global_position.y, panel.global_position.y + 8, 1.0)
	for index: int in [0, 3, 4]:
		var star: GuiCardGlyphSample = gallery.get_node(
			"Margin/Gallery/Seats/Seat%d/Panel/WinnerStar" % index
		)
		assert_true(star.is_visible_in_tree())
		assert_eq(star.text, "★")
		assert_eq(star.get_theme_color("font_color"), Color.YELLOW)
		assert_eq(star.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_gte(star.size.y, 32.0)
		var badges: Control = star.get_parent().get_node("Markers")
		assert_false(star.get_global_rect().intersects(badges.get_global_rect()))
	assert_eq(gallery.get_node("Margin/Gallery/Seats/Seat4/Panel/Markers/Blind").text, "BB")


func _gallery() -> Control:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 980)
	add_child_autofree(viewport)
	var gallery: Control = Gallery.instantiate()
	viewport.add_child(gallery)
	return gallery


func test_fields_stay_white_and_sharp_in_focused_and_read_only_states() -> void:
	var root: Control = _root()
	for variation: StringName in [&"InputField", &"NumberField"]:
		var field: LineEdit = _field(root, variation)
		assert_gte(field.get_theme_font_size("font_size"), 20)
		for color_name: StringName in [
			&"font_color", &"caret_color", &"font_placeholder_color", &"font_uneditable_color"
		]:
			var color: Color = field.get_theme_color(color_name)
			assert_gt(color.g, color.r)
			assert_gt(color.g, color.b)
			assert_lt(color.srgb_to_linear().get_luminance(), 0.3)
		for state: StringName in [&"normal", &"focus", &"read_only"]:
			assert_true(_has_style(variation, state), "%s/%s" % [variation, state])
			var style: StyleBoxFlat = field.get_theme_stylebox(state) as StyleBoxFlat
			assert_not_null(style)
			_assert_sharp(style)
			if state == &"focus":
				assert_false(style.draw_center, "focus overlays the unchanged white face")
			elif state == &"read_only":
				assert_eq(style.bg_color, Color("edf3ef"))
			else:
				assert_eq(style.bg_color, Color.WHITE)
		field.editable = false
		assert_eq(
			field.get_theme_color("font_uneditable_color"), field.get_theme_color("font_color")
		)
		var normal: StyleBoxFlat = field.get_theme_stylebox("normal") as StyleBoxFlat
		var focused: StyleBoxFlat = field.get_theme_stylebox("focus") as StyleBoxFlat
		assert_ne(normal.border_color, focused.border_color)
	var invalid: LineEdit = _field(root, &"InputFieldInvalid")
	var error_style: StyleBoxFlat = invalid.get_theme_stylebox("normal") as StyleBoxFlat
	assert_gt(error_style.border_color.r, error_style.border_color.g)
	assert_gt(error_style.border_color.r, error_style.border_color.b)
	_assert_sharp(error_style)
	assert_eq(error_style.bg_color, Color.WHITE)
	var invalid_focus: StyleBoxFlat = invalid.get_theme_stylebox("focus") as StyleBoxFlat
	assert_gt(invalid_focus.border_color.r, invalid_focus.border_color.g)
	assert_gt(invalid_focus.border_color.r, invalid_focus.border_color.b)
	assert_false(invalid_focus.draw_center)


func test_total_keeps_the_full_target_while_insetting_only_its_drawn_face() -> void:
	var root: Control = _root()
	var total: LineEdit = _field(root, &"WagerTotalField")
	total.size = Vector2(100, 48)
	assert_eq(total.size.y, 48.0)
	assert_gte(total.size.x, 48.0)
	for color_name: StringName in [
		&"font_color", &"caret_color", &"font_placeholder_color", &"font_uneditable_color"
	]:
		assert_eq(total.get_theme_color(color_name), Color("b8c3bb"))
	for state: StringName in [&"normal", &"focus", &"read_only"]:
		assert_true(_has_style(&"WagerTotalField", state), str(state))
		var style: StyleBoxFlat = total.get_theme_stylebox(state) as StyleBoxFlat
		assert_not_null(style)
		_assert_sharp(style)
		if state == &"focus":
			assert_false(style.draw_center, "focus overlays the unchanged dark face")
		else:
			assert_gt(style.bg_color.g, style.bg_color.r)
			assert_gt(style.bg_color.g, style.bg_color.b)
			assert_lt(style.bg_color.get_luminance(), 0.3)
		assert_eq(style.expand_margin_top, -4.0)
		assert_eq(style.expand_margin_bottom, -4.0)
		var drawn: Rect2 = Rect2(Vector2.ZERO, total.size).grow_individual(
			style.expand_margin_left,
			style.expand_margin_top,
			style.expand_margin_right,
			style.expand_margin_bottom
		)
		assert_eq(drawn.position.y, 4.0)
		assert_eq(drawn.size.y, 40.0)
		assert_eq(drawn.get_center().y, total.size.y / 2.0)
		assert_eq(total.size.y, 48.0, "style face does not change the interactive allocation")


func test_effective_text_roles_use_readable_default_font_metrics() -> void:
	var root: Control = _root()
	for variation: StringName in [
		&"BodyText", &"CardRank", &"SeatText", &"StatusBand", &"WinningHandText"
	]:
		var label := Label.new()
		label.theme_type_variation = variation
		label.text = "10♠" if variation == &"CardRank" else "Full house: Aces full of Kings"
		root.add_child(label)
		var font_size: int = label.get_theme_font_size("font_size")
		var minimum: int = 20 if variation in [&"BodyText", &"CardRank"] else 18
		assert_eq(font_size, minimum, str(variation))
		var font: Font = label.get_theme_font("font")
		assert_not_null(font)
		assert_gt(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, 0.0)
		assert_gt(font.get_height(font_size), 0.0)
		if variation == &"WinningHandText":
			assert_eq(label.get_theme_color("font_color"), Color.YELLOW)
			assert_is(font, FontVariation)
			var bold: FontVariation = font as FontVariation
			assert_null(bold.base_font, "use the built-in default font")
			assert_almost_eq(bold.variation_embolden, 0.8, 0.0001)
	var log := RichTextLabel.new()
	log.theme_type_variation = &"EventLogBody"
	root.add_child(log)
	for size_name: StringName in [
		&"normal_font_size", &"bold_font_size", &"italics_font_size", &"bold_italics_font_size"
	]:
		assert_eq(log.get_theme_font_size(size_name), 18, str(size_name))


func test_theme_does_not_load_external_or_system_fonts() -> void:
	assert_null(ThemeResource.default_font)
	var source: String = FileAccess.get_file_as_string("res://resources/gui_theme.tres")
	assert_false(source.contains('type="FontFile"'))
	assert_false(source.contains('type="SystemFont"'))
	for dependency: String in ResourceLoader.get_dependencies("res://resources/gui_theme.tres"):
		for extension: String in [".ttf", ".otf", ".woff", ".woff2"]:
			assert_false(dependency.to_lower().contains(extension), dependency)


func _root() -> Control:
	var root := Control.new()
	root.theme = ThemeResource
	add_child_autofree(root)
	return root


func _field(root: Control, variation: StringName) -> LineEdit:
	var field := LineEdit.new()
	field.theme_type_variation = variation
	field.custom_minimum_size = Vector2(48, 48)
	field.text = "1234567"
	root.add_child(field)
	field.size = field.get_combined_minimum_size()
	return field


func _inherits(variation: StringName, native_base: StringName) -> bool:
	var seen: Dictionary[StringName, bool] = {}
	var current: StringName = variation
	while not current.is_empty() and not seen.has(current):
		if current == native_base:
			return true
		seen[current] = true
		current = ThemeResource.get_type_variation_base(current)
	return false


func _has_style(variation: StringName, state: StringName) -> bool:
	var seen: Dictionary[StringName, bool] = {}
	var current: StringName = variation
	while not current.is_empty() and not seen.has(current):
		if ThemeResource.has_stylebox(state, current):
			return true
		seen[current] = true
		current = ThemeResource.get_type_variation_base(current)
	return false


func _assert_sharp(style: StyleBoxFlat) -> void:
	for radius: int in [
		style.corner_radius_top_left,
		style.corner_radius_top_right,
		style.corner_radius_bottom_left,
		style.corner_radius_bottom_right
	]:
		assert_eq(radius, 0)


func _assert_rounded(style: StyleBoxFlat) -> void:
	for radius: int in [
		style.corner_radius_top_left,
		style.corner_radius_top_right,
		style.corner_radius_bottom_left,
		style.corner_radius_bottom_right
	]:
		assert_gt(radius, 0)
