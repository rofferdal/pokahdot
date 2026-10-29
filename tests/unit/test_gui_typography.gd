extends GutTest

const Palette := preload("res://resources/gui_theme.tres")
const Host := preload("res://scenes/gui/CompositionHost.tscn")
const Phone := preload("res://tests/fixtures/gui_compositions/phone.tscn")
const DENSITY := GuiFitCandidate.Density


func test_native_metric_layers_preserve_palette_and_change_roles_on_the_same_root() -> void:
	var parent := Control.new()
	parent.theme = Palette
	add_child_autofree(parent)
	var composition := GuiTableComposition.new()
	parent.add_child(composition)
	var seat := Label.new()
	seat.theme_type_variation = &"SeatText"
	seat.text = "Benjamin"
	composition.add_child(seat)
	var winner := Label.new()
	winner.theme_type_variation = &"WinningHandText"
	winner.text = "Full house\nAces / Kings"
	composition.add_child(winner)
	var button := Button.new()
	button.theme_type_variation = &"ActionButton"
	button.text = "Raise"
	button.custom_minimum_size = Vector2(48, 48)
	composition.add_child(button)
	for density: int in [DENSITY.FULL, DENSITY.COMPACT, DENSITY.MINIMAL, DENSITY.FULL]:
		var state := GuiCompositionState.new()
		state.density = density
		composition.apply_policy(state)
		await wait_process_frames(3)
		assert_same(composition.policy, state)
		assert_eq(seat.get_theme_font_size("font_size"), 22 if density == DENSITY.FULL else 18)
		assert_eq(winner.get_theme_font_size("font_size"), 22 if density == DENSITY.FULL else 18)
		assert_is(winner.get_theme_font("font"), FontVariation)
		assert_eq(winner.get_theme_color("font_color"), Color.YELLOW)
		assert_eq(button.get_theme_color("font_disabled_color"), Color("a8a8a8"))
		assert_gte(button.get_combined_minimum_size().y, 48.0)
		assert_eq(button.get_theme_font_size("font_size"), 20)
		assert_eq(
			button.get_theme_stylebox("normal"), Palette.get_stylebox("normal", "ActionButton")
		)


func test_selected_candidate_density_drives_metrics_despite_a_wide_preference() -> void:
	var host: GuiCompositionHost = Host.instantiate()
	add_child_autofree(host)
	host.register_composition(GuiSizeClass.LayoutMode.PHONE, Phone)
	var metrics := GuiFitMetrics.new()
	metrics.opponent = Vector2(160, 84)
	metrics.board = Vector2(280, 84)
	metrics.hero = Vector2(180, 96)
	metrics.actions = Vector2(280, 104)
	metrics.evidence = &"primitive_fixture"
	var ids := PackedInt32Array([0, 1, 2, 3, 4, 5, 6])
	var candidate: GuiFitCandidate = GuiFitCandidate.measure(
		GuiSizeClass.LayoutMode.PHONE, metrics, ids, 0, DENSITY.COMPACT
	)
	var state: GuiCompositionState = host.present(
		GuiViewportGeometry.injected(Vector2(650, 900)), ids, 0, [candidate]
	)
	assert_eq(state.fit.size_class.mode, GuiSizeClass.LayoutMode.WIDE_COMPACT)
	assert_same(host.get_composition().theme, GuiTypography.Compact)
	assert_same(GuiTypography.for_density(DENSITY.MINIMAL), GuiTypography.Compact)


func test_seat_fit_exact_floor_edges_and_blank_reserved_band() -> void:
	var normal: Font = ThemeDB.fallback_font
	var bold: Font = Palette.get_font("font", "WinningHandText")
	var runs: Array[GuiSeatTextRun] = [
		GuiSeatTextRun.new("Benjamin"),
		GuiSeatTextRun.new("9999999 chips"),
		GuiSeatTextRun.new("D SB"),
		GuiSeatTextRun.new("Full house\nAces / Kings", true),
		GuiSeatTextRun.new(""),
	]
	var edge: Vector2 = GuiSeatTextFit.measure(runs, normal, bold, 18, 4)
	var exact: GuiSeatTextFit = GuiSeatTextFit.resolve(runs, normal, bold, edge, 26, 4)
	assert_eq(exact.status, GuiSeatTextFit.Status.FIT)
	assert_eq(exact.font_size, 18)
	for delta: Vector2 in [Vector2(-1, 0), Vector2(0, -1)]:
		var failed: GuiSeatTextFit = GuiSeatTextFit.resolve(runs, normal, bold, edge + delta, 26, 4)
		assert_eq(failed.status, GuiSeatTextFit.Status.TOO_SMALL)
		assert_eq(failed.font_size, 0)
	var blank: Array[GuiSeatTextRun] = [GuiSeatTextRun.new("")]
	assert_gt(GuiSeatTextFit.measure(blank, normal, bold, 18, 4).y, 0.0)


func test_measured_groups_render_complete_copy_for_seven_phone_and_nine_wide_seats() -> void:
	var parent := Control.new()
	parent.theme = Palette
	add_child_autofree(parent)
	for count: int in [7, 9]:
		var layer := Control.new()
		layer.theme = GuiTypography.for_density(DENSITY.COMPACT if count == 7 else DENSITY.FULL)
		parent.add_child(layer)
		for index: int in count:
			var runs: Array[GuiSeatTextRun] = [
				GuiSeatTextRun.new("Benjamin"),
				GuiSeatTextRun.new("9999999 chips"),
				GuiSeatTextRun.new("D SB" if index == 0 else "BB"),
				GuiSeatTextRun.new("Full house\nAces / Kings", true),
			]
			var normal: Font = layer.get_theme_font("font", "SeatText")
			var bold: Font = layer.get_theme_font("font", "WinningHandText")
			var available := Vector2(180, 190) if count == 7 else Vector2(280, 240)
			var preferred: int = layer.get_theme_font_size("font_size", "SeatText")
			var result: GuiSeatTextFit = GuiSeatTextFit.resolve(
				runs, normal, bold, available, preferred, 4
			)
			assert_eq(result.status, GuiSeatTextFit.Status.FIT)
			var column := VBoxContainer.new()
			column.add_theme_constant_override("separation", 4)
			layer.add_child(column)
			for run: GuiSeatTextRun in runs:
				var label := Label.new()
				label.text = run.text
				label.add_theme_font_override("font", bold if run.emphasized else normal)
				label.add_theme_font_size_override("font_size", result.font_size)
				column.add_child(label)
			await wait_process_frames(2)
			var rendered: Vector2 = column.get_combined_minimum_size()
			assert_lte(rendered.x, available.x)
			assert_lte(rendered.y, available.y)
			for index_label: int in runs.size():
				assert_eq((column.get_child(index_label) as Label).text, runs[index_label].text)


func test_invalid_measurements_never_lower_the_seat_floor() -> void:
	var normal: Font = ThemeDB.fallback_font
	var runs: Array[GuiSeatTextRun] = [GuiSeatTextRun.new("Name")]
	for available: Vector2 in [Vector2.ZERO, Vector2(-1, 20), Vector2(NAN, 20), Vector2(20, INF)]:
		assert_eq(
			GuiSeatTextFit.resolve(runs, normal, normal, available, 22).status,
			GuiSeatTextFit.Status.INVALID
		)
	for preferred: int in [0, 17, 65]:
		assert_eq(
			GuiSeatTextFit.resolve(runs, normal, normal, Vector2(500, 500), preferred).status,
			GuiSeatTextFit.Status.INVALID
		)
	assert_eq(
		GuiSeatTextFit.resolve([], normal, normal, Vector2(100, 100), 22).status,
		GuiSeatTextFit.Status.INVALID
	)


func test_all_native_text_roles_respect_floors_and_preserve_palette_inheritance() -> void:
	var parent := Control.new()
	parent.theme = Palette
	add_child_autofree(parent)
	for density: int in [DENSITY.FULL, DENSITY.COMPACT, DENSITY.MINIMAL]:
		var layer := Control.new()
		layer.theme = GuiTypography.for_density(density)
		parent.add_child(layer)
		for role: String in Palette.get_type_list():
			var base: StringName = Palette.get_type_variation_base(role)
			if not base.is_empty():
				assert_eq(layer.theme.get_type_variation_base(role), base, role)
		for role: StringName in [
			&"BodyText",
			&"HeadingText",
			&"CardRank",
			&"CardRankRed",
			&"DealerText",
			&"SeatText",
			&"HeroText",
			&"StatusBand",
			&"HeroStatusBand",
			&"WinningHandText",
			&"HeroWinningHandText",
			&"BlindMarker",
			&"WinnerStar"
		]:
			var label := Label.new()
			label.theme_type_variation = role
			layer.add_child(label)
			var floor_size: int = (
				18
				if (
					role
					in [
						&"SeatText",
						&"HeroText",
						&"StatusBand",
						&"HeroStatusBand",
						&"WinningHandText",
						&"HeroWinningHandText",
						&"BlindMarker"
					]
				)
				else 20
			)
			assert_gte(label.get_theme_font_size("font_size"), floor_size, str(role))
			assert_false(label.has_theme_font_size_override("font_size"), str(role))
		var log_body := RichTextLabel.new()
		log_body.theme_type_variation = &"EventLogBody"
		layer.add_child(log_body)
		for item: StringName in [
			&"normal_font_size",
			&"bold_font_size",
			&"italics_font_size",
			&"bold_italics_font_size",
			&"mono_font_size"
		]:
			assert_eq(log_body.get_theme_font_size(item), 18)
		for role: StringName in [&"ActionButton", &"PrimaryActionButton", &"KeypadKey"]:
			var button := Button.new()
			button.theme_type_variation = role
			button.custom_minimum_size = Vector2(48, 48)
			layer.add_child(button)
			assert_gte(button.get_theme_font_size("font_size"), 20)
			assert_gte(button.get_combined_minimum_size().x, 48.0)
			assert_gte(button.get_combined_minimum_size().y, 48.0)
		for role: StringName in [
			&"InputField", &"InputFieldInvalid", &"NumberField", &"WagerTotalField"
		]:
			var field := LineEdit.new()
			field.theme_type_variation = role
			layer.add_child(field)
			assert_gte(field.get_theme_font_size("font_size"), 20)


func test_bounded_seat_fit_sweep_matches_native_normal_and_bold_label_minimums() -> void:
	var parent := Control.new()
	parent.theme = Palette
	add_child_autofree(parent)
	var layer := Control.new()
	layer.theme = GuiTypography.Regular
	parent.add_child(layer)
	var normal: Font = layer.get_theme_font("font", "SeatText")
	var bold: Font = layer.get_theme_font("font", "WinningHandText")
	var runs: Array[GuiSeatTextRun] = [
		GuiSeatTextRun.new("Benjamin"),
		GuiSeatTextRun.new("9999999 chips"),
		GuiSeatTextRun.new("Raise to 9999999"),
		GuiSeatTextRun.new("Full house\nAces / Kings", true),
		GuiSeatTextRun.new("")
	]
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	layer.add_child(column)
	for run: GuiSeatTextRun in runs:
		var label := Label.new()
		label.text = run.text
		label.add_theme_font_override("font", bold if run.emphasized else normal)
		column.add_child(label)
	var rendered: Dictionary[int, Vector2] = {}
	for font_size: int in range(18, 27):
		for label: Label in column.get_children():
			label.add_theme_font_size_override("font_size", font_size)
		await wait_process_frames(2)
		rendered[font_size] = column.get_combined_minimum_size()
		assert_eq(GuiSeatTextFit.measure(runs, normal, bold, font_size, 4), rendered[font_size])
	for available: Vector2 in [
		Vector2(140, 140), Vector2(180, 190), Vector2(240, 240), Vector2(320, 280)
	]:
		for preferred: int in range(18, 27):
			var expected: int = 0
			for font_size: int in range(18, preferred + 1):
				if rendered[font_size].x <= available.x and rendered[font_size].y <= available.y:
					expected = font_size
			var fit: GuiSeatTextFit = GuiSeatTextFit.resolve(
				runs, normal, bold, available, preferred, 4
			)
			assert_eq(fit.font_size, expected)
			assert_eq(
				fit.status,
				GuiSeatTextFit.Status.FIT if expected > 0 else GuiSeatTextFit.Status.TOO_SMALL
			)
