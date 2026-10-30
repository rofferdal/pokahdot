extends GutTest

const CardScene := preload("res://scenes/gui/components/PlayingCard.tscn")
const RowScene := preload("res://scenes/gui/components/CardRow.tscn")
const CenterScene := preload("res://scenes/gui/components/CenterBoard.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const Content := preload("res://tests/support/gui_snapshot_content_assertions.gd")
const IndependentInk := preload("res://tests/visual/gui_card_glyph_sample.gd")


func test_missing_suit_font_uses_visible_safe_ink_without_invalid_textserver_calls() -> void:
	var font := ThemeDB.fallback_font.duplicate() as FontFile
	font.allow_system_fallback = false
	assert_false(font.has_char("♠".unicode_at(0)))
	var ink: Rect2 = GuiCardInk.bounds(font, "♠", 20)
	assert_true(ink.has_area())
	assert_gte(ink.size.y, 20.0)


func test_all_faces_remain_readable_with_only_the_embedded_font_and_vector_suit_fallback() -> void:
	var root: Control = _root()
	var host := Control.new()
	host.size = root.size
	host.theme = Theme.new()
	var font := ThemeDB.fallback_font.duplicate() as FontFile
	font.allow_system_fallback = false
	host.theme.set_font("font", &"CardRank", font)
	host.theme.set_font("font", &"CardRankRed", font)
	root.add_child(host)
	var card: GuiPlayingCard = CardScene.instantiate()
	host.add_child(card)
	card.render(CardViewModel.empty())
	await wait_process_frames(3)
	var minimum: Vector2 = card.get_combined_minimum_size()
	assert_same(card.get_theme_font("font", &"CardRank"), font)
	for rank: int in range(2, 15):
		for suit: int in 4:
			var model: CardViewModel = CardViewModel.face(CardData.new(rank, suit))
			card.render(model)
			card.size = minimum
			await wait_process_frames(2)
			var snapshot: GuiCardSnapshot = card.get_card_snapshot(root, &"card", true)
			assert_eq(card.get_combined_minimum_size(), minimum)
			assert_eq(snapshot.rank.text, model.rank_text)
			assert_eq(snapshot.suit.text, model.suit_text)
			assert_true(snapshot.suit.texture_present)
			assert_gte(snapshot.suit.rect.size.y, 20.0)
			_assert_face(snapshot)
			var redacted: GuiCardSnapshot = card.get_card_snapshot(root, &"card", false)
			assert_eq(redacted.rank.text, "")
			assert_eq(redacted.suit.text, "")
	for model: CardViewModel in [CardViewModel.back(), CardViewModel.empty()]:
		card.render(model)
		await wait_process_frames(3)
		var snapshot: GuiCardSnapshot = card.get_card_snapshot(root, &"card", false)
		assert_eq(card.get_combined_minimum_size(), minimum)
		assert_eq(snapshot.rank.text, "")
		assert_eq(snapshot.suit.text, "")
		assert_false(snapshot.rank.visible)
		assert_false(snapshot.suit.visible)
	assert_push_error_count(0)


func test_vector_suit_masks_preserve_alpha_shape_and_take_the_exact_theme_color() -> void:
	var font := ThemeDB.fallback_font.duplicate() as FontFile
	font.allow_system_fallback = false
	for copy: String in ["♣", "♦", "♥", "♠"]:
		var texture: Texture2D = GuiCardInk.suit_fallback_texture(font, copy, 20)
		assert_not_null(texture)
		var image: Image = texture.get_image()
		assert_true(GuiCardInk.suit_texture_region(copy).has_area())
		assert_true(
			Rect2(Vector2.ZERO, image.get_size()).encloses(GuiCardInk.suit_texture_region(copy))
		)
		var visible: int = 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				var pixel: Color = image.get_pixel(x, y)
				if pixel.a > 0.0:
					assert_eq(Vector3(pixel.r, pixel.g, pixel.b), Vector3.ONE)
					visible += 1
		assert_gt(visible, 0)


func test_available_native_shaped_suits_keep_the_original_glyph_ink() -> void:
	var font: Font = ThemeDB.fallback_font
	for copy: String in ["♣", "♦", "♥", "♠"]:
		var line := TextLine.new()
		assert_true(line.add_string(copy, font, 20))
		var available: bool = true
		for glyph: Dictionary in TextServerManager.get_primary_interface().shaped_text_get_glyphs(
			line.get_rid()
		):
			available = available and (glyph.font_rid as RID).is_valid()
		if available:
			assert_null(GuiCardInk.suit_fallback_texture(font, copy, 20))
			assert_eq(GuiCardInk.bounds(font, copy, 20), IndependentInk.ink_bounds(font, copy, 20))


func test_embedded_font_decorations_keep_readable_stars_and_card_backs_without_tofu() -> void:
	var root: Control = _root()
	var host := Control.new()
	host.theme = Theme.new()
	var font := ThemeDB.fallback_font.duplicate() as FontFile
	font.allow_system_fallback = false
	for role: StringName in [
		&"CardRank", &"CardRankRed", &"CardBackMark", &"TokenWinnerStar", &"SeatWinnerStar"
	]:
		host.theme.set_font("font", role, font)
	root.add_child(host)
	for size: int in [28, 64]:
		var star := GuiSeatStar.new()
		star.theme_type_variation = &"TokenWinnerStar" if size == 28 else &"SeatWinnerStar"
		star.add_theme_font_size_override("font_size", size)
		host.add_child(star)
		star.size = star.get_combined_minimum_size()
		assert_gte(star.size.y, float(size))
		assert_gt(star.size.x, 0.0)
		assert_not_null(GuiCardInk.symbol_fallback_texture(star.get_theme_font("font"), "★", size))
		assert_eq(star.get_theme_color("font_color"), Color.YELLOW)
	var card: GuiPlayingCard = CardScene.instantiate()
	host.add_child(card)
	card.render(CardViewModel.back())
	card.size = card.get_combined_minimum_size()
	await wait_process_frames(3)
	var back: GuiCardBack = card.get_node("Back")
	assert_false((back.get_node("Mark") as Label).visible)
	assert_true(GuiCardInk.bounds(font, "◆", 20).has_area())
	assert_not_null(GuiCardInk.symbol_fallback_texture(font, "◆", 20))
	var snapshot: GuiCardSnapshot = card.get_card_snapshot(root, &"back")
	assert_eq(snapshot.kind, GuiCardSnapshot.Kind.BACK)
	assert_eq(snapshot.rank.text, "")
	assert_eq(snapshot.suit.text, "")
	host.material = load("res://resources/gui_grayscale_material.tres") as ShaderMaterial
	GuiSeatPanel._inherit_material(host)
	for descendant: Node in host.find_children("*", "CanvasItem", true, false):
		assert_true((descendant as CanvasItem).use_parent_material)
	assert_push_error_count(0)


func test_available_native_star_and_back_mark_keep_their_glyph_and_label_path() -> void:
	var font: Font = ThemeDB.fallback_font
	for copy: String in ["★", "◆"]:
		var line := TextLine.new()
		assert_true(line.add_string(copy, font, 28))
		var available: bool = true
		for glyph: Dictionary in TextServerManager.get_primary_interface().shaped_text_get_glyphs(
			line.get_rid()
		):
			available = available and (glyph.font_rid as RID).is_valid()
		if available:
			assert_null(GuiCardInk.symbol_fallback_texture(font, copy, 28))
			assert_eq(GuiCardInk.bounds(font, copy, 28), IndependentInk.ink_bounds(font, copy, 28))
	var root: Control = _root()
	var card: GuiPlayingCard = CardScene.instantiate()
	root.add_child(card)
	card.render(CardViewModel.back())
	await wait_process_frames(3)
	var mark := card.get_node("Back/Mark") as Label
	assert_eq(
		mark.visible,
		(
			GuiCardInk.symbol_fallback_texture(
				mark.get_theme_font("font"), "◆", mark.get_theme_font_size("font_size")
			)
			== null
		)
	)


func test_all_faces_fit_at_the_same_minimum_with_complete_rank_and_suit() -> void:
	var root: Control = _root()
	var card: GuiPlayingCard = CardScene.instantiate()
	root.add_child(card)
	card.render(CardViewModel.empty())
	await wait_process_frames(3)
	var stable_minimum: Vector2 = card.get_combined_minimum_size()
	for rank: int in range(2, 15):
		for suit: int in range(4):
			var model := CardViewModel.face(CardData.new(rank, suit))
			card.render(model)
			card.size = card.get_combined_minimum_size()
			await wait_process_frames(2)
			assert_eq(card.get_combined_minimum_size(), stable_minimum)
			var snapshot: GuiCardSnapshot = card.get_card_snapshot(root, &"card", true)
			assert_eq(snapshot.kind, GuiCardSnapshot.Kind.FACE)
			assert_eq(snapshot.rank.text, model.rank_text)
			assert_eq(snapshot.suit.text, model.suit_text)
			var glyphs: GuiCardGlyphs = card.get_node("Face/Glyphs")
			assert_eq(
				glyphs.get_theme_color("font_color"),
				Palette.get_color("font_color", "CardRankRed" if suit in [1, 2] else "CardRank")
			)
			_assert_face(snapshot)
			_assert_surface(card, card.get_node("Face"))


func test_face_back_and_empty_preserve_reserved_minimum_and_clear_hidden_copy() -> void:
	var root: Control = _root()
	var card: GuiPlayingCard = CardScene.instantiate()
	root.add_child(card)
	card.render(CardViewModel.face(CardData.new(10, CardData.Suit.HEARTS)))
	await wait_process_frames(3)
	var stable_minimum: Vector2 = card.get_combined_minimum_size()
	card.size = stable_minimum
	for model: CardViewModel in [CardViewModel.back(), CardViewModel.empty()]:
		card.render(model)
		await wait_process_frames(3)
		assert_eq(card.get_combined_minimum_size(), stable_minimum)
		var snapshot: GuiCardSnapshot = card.get_card_snapshot(root, &"card")
		assert_eq(
			snapshot.kind,
			(
				GuiCardSnapshot.Kind.BACK
				if model.state == CardViewModel.State.BACK
				else GuiCardSnapshot.Kind.EMPTY
			)
		)
		assert_false(card.get_node("Face").visible)
		assert_eq((card.get_node("Face/Glyphs") as GuiCardGlyphs).rank_text, "")
		assert_eq((card.get_node("Face/Glyphs") as GuiCardGlyphs).suit_text, "")
		assert_eq(card.tooltip_text, "")
		assert_false(snapshot.rank.visible)
		assert_false(snapshot.suit.visible)
		assert_eq(snapshot.rank.text, "")
		assert_eq(snapshot.suit.text, "")
		var surface: Control = card.get_node(
			"Back" if model.state == CardViewModel.State.BACK else "Empty"
		)
		assert_true(surface.visible)
		_assert_surface(card, surface)


func test_native_container_allocations_keep_actual_surfaces_inside_and_in_proportion() -> void:
	var root: Control = _root()
	var host := VBoxContainer.new()
	root.add_child(host)
	var row: GuiCardRow = RowScene.instantiate()
	host.add_child(row)
	var model := CardRowViewModel.new()
	model.cards = [
		CardViewModel.face(CardData.new(10, CardData.Suit.SPADES)),
		CardViewModel.back(),
		CardViewModel.empty(),
	]
	row.render(model)
	await wait_process_frames(3)
	var minimum: Vector2 = host.get_combined_minimum_size()
	for allocation: Vector2 in [
		minimum,
		Vector2(maxf(minimum.x, 360), maxf(minimum.y, 90)),
		Vector2(maxf(minimum.x, 260), maxf(minimum.y, 420)),
		Vector2(maxf(minimum.x, 840), maxf(minimum.y, 200)),
	]:
		host.size = allocation
		await wait_process_frames(4)
		for index: int in row.cards.size():
			var card: GuiPlayingCard = row.cards[index]
			var surface: Control = card.get_node(["Face", "Back", "Empty"][index])
			_assert_surface(card, surface)
			assert_true(row.get_global_rect().encloses(surface.get_global_rect()))
			if index > 0:
				var previous: Control = row.cards[index - 1].get_node(["Face", "Back"][index - 1])
				assert_false(previous.get_global_rect().intersects(surface.get_global_rect()))
		_assert_face(row.cards[0].get_card_snapshot(root, &"card", true))


func test_snapshot_redaction_and_rebinding_never_retain_previous_visible_identity() -> void:
	var root: Control = _root()
	var card: GuiPlayingCard = CardScene.instantiate()
	root.add_child(card)
	card.render(CardViewModel.face(CardData.new(14, CardData.Suit.SPADES)))
	card.size = Vector2(120, 168)
	await wait_process_frames(3)
	var shown: GuiCardSnapshot = card.get_card_snapshot(root, &"card", true)
	assert_eq(shown.rank.text, "A")
	var redacted: GuiCardSnapshot = card.get_card_snapshot(root, &"card", false)
	assert_false(redacted.authorized)
	assert_true(redacted.rank.privacy_redacted)
	assert_true(redacted.suit.privacy_redacted)
	assert_eq(redacted.rank.text, "")
	assert_eq(redacted.suit.text, "")
	card.render(CardViewModel.back())
	await wait_process_frames(3)
	assert_eq(card.get_card_snapshot(root, &"card").kind, GuiCardSnapshot.Kind.BACK)
	assert_eq(shown.rank.text, "A", "Snapshots detach values from future renders")
	card.render(CardViewModel.face(CardData.new(10, CardData.Suit.DIAMONDS)))
	await wait_process_frames(3)
	assert_eq(card.get_card_snapshot(root, &"card", true).rank.text, "10")
	assert_eq(card.get_card_snapshot(root, &"card", true).suit.text, "♦")


func test_rank_ten_and_all_suits_choose_the_largest_fitting_ink_font_after_resize() -> void:
	var root: Control = _root()
	var card: GuiPlayingCard = CardScene.instantiate()
	root.add_child(card)
	for suit: int in range(4):
		card.render(CardViewModel.face(CardData.new(10, suit)))
		var previous_font: int = 0
		for allocation: Vector2 in [Vector2(70, 98), Vector2(120, 168), Vector2(200, 280)]:
			card.size = allocation.max(card.get_combined_minimum_size())
			await wait_process_frames(3)
			var glyphs: GuiCardGlyphs = card.get_node("Face/Glyphs")
			var font: Font = glyphs.get_theme_font("font")
			var next_size: int = glyphs.font_size + 1
			var next_rank: Vector2 = IndependentInk.ink_bounds(font, "10", next_size).size.ceil()
			var next_suit: Vector2 = (
				IndependentInk.ink_bounds(font, ["♣", "♦", "♥", "♠"][suit], next_size).size.ceil()
			)
			var gap: int = glyphs.get_theme_constant("glyph_separation", "CardGlyphs")
			assert_true(
				(
					maxf(next_rank.x, next_suit.x) > glyphs.size.x
					or next_rank.y + next_suit.y + gap > glyphs.size.y
				),
				"The next larger font must fail the actual padded allocation"
			)
			assert_gt(glyphs.font_size, previous_font)
			previous_font = glyphs.font_size
			var ink: Array[Rect2] = glyphs.get_ink_rects()
			assert_eq(ink.size(), 2)
			for rect: Rect2 in ink:
				assert_true(Rect2(Vector2.ZERO, glyphs.size).encloses(rect))
			assert_gte(ink[1].position.y - ink[0].end.y, float(gap))
			_assert_face(card.get_card_snapshot(root, &"card", true))


func test_rows_reuse_the_same_card_scenes_for_board_hero_and_opponents() -> void:
	var root: Control = _root()
	var view: GameView = _view()
	view._community_cards = [CardData.new(10, CardData.Suit.HEARTS)]
	view._hero_hole_cards = [CardData.new(14), CardData.new(13)]
	var row: GuiCardRow = RowScene.instantiate()
	root.add_child(row)
	row.render(CardRowViewModel.board(view))
	await wait_process_frames(3)
	assert_eq(row.cards.size(), 5)
	var original: Array[GuiPlayingCard] = row.cards.duplicate()
	view._community_cards.append(CardData.new(11, CardData.Suit.CLUBS))
	row.render(CardRowViewModel.board(view))
	assert_eq(row.cards, original, "Equal slot counts preserve existing component instances")
	assert_eq(row.cards[1].get_card_snapshot(root, &"board/1", true).rank.text, "J")
	row.render(CardRowViewModel.for_seat(view, 0))
	await wait_process_frames(3)
	assert_eq(row.cards.size(), 2)
	for card: GuiPlayingCard in row.cards:
		assert_eq(card.scene_file_path, "res://scenes/gui/components/PlayingCard.tscn")
		assert_eq(card.get_card_snapshot(root, &"hero", true).kind, GuiCardSnapshot.Kind.FACE)
	row.render(CardRowViewModel.board(view))
	assert_eq(row.cards, original, "Returning to five slots reuses the authored cards")
	for card: GuiPlayingCard in original:
		assert_same(card.get_parent(), row)
	row.render(CardRowViewModel.for_seat(view, 1))
	await wait_process_frames(3)
	assert_eq(row.cards.size(), 2)
	for card: GuiPlayingCard in row.cards:
		var hidden: GuiCardSnapshot = card.get_card_snapshot(root, &"opponent")
		assert_eq(hidden.kind, GuiCardSnapshot.Kind.BACK)
		assert_eq(hidden.rank.text, "")
		assert_eq(hidden.suit.text, "")
		assert_eq(card.scene_file_path, "res://scenes/gui/components/PlayingCard.tscn")


func test_center_board_composes_shared_rows_and_preserves_exact_model_copy_at_minimum() -> void:
	var root: Control = _root()
	var center: GuiCenterBoard = CenterScene.instantiate()
	root.add_child(center)
	var view: GameView = _view()
	view.pot_amount = 9000000
	view._community_cards = [CardData.new(10, CardData.Suit.HEARTS)]
	var model: CenterViewModel = CenterViewModel.build(view)
	center.render(model)
	await wait_process_frames(3)
	center.size = center.get_combined_minimum_size()
	await wait_process_frames(3)
	assert_eq((center.get_node("BoardTitle") as Label).text, model.board_title)
	assert_eq((center.get_node("Totals/Pot") as Label).text, model.phone_pot_text)
	assert_eq((center.get_node("Totals/Wager") as Label).text, model.phone_wager_text)
	assert_eq((center.get_node("BlindLevel") as Label).text, model.blind_level_text)
	var row: GuiCardRow = center.get_node("Cards")
	assert_eq(row.cards.size(), 5)
	assert_eq(row.scene_file_path, "res://scenes/gui/components/CardRow.tscn")
	var measured: Array[GuiLayoutElement] = []
	GuiSnapshotMeasurement.descendants(center, root, &"center", measured)
	for element: GuiLayoutElement in measured:
		var failures := PackedStringArray()
		Invariants.validate_element(element, failures)
		assert_eq(failures, PackedStringArray())
		if element.visible:
			assert_true(center.get_global_rect().encloses(element.rect))
	_assert_face(row.cards[0].get_card_snapshot(root, &"board/0", true))


func test_invalid_center_and_missing_card_models_clear_previously_rendered_content() -> void:
	var root: Control = _root()
	var center: GuiCenterBoard = CenterScene.instantiate()
	root.add_child(center)
	center.render(CenterViewModel.build(_view()))
	await wait_process_frames(3)
	var error_count: int = 0
	for model: CenterViewModel in [CenterViewModel.new(), null]:
		center.render(model)
		error_count += 1
		assert_push_error_count(error_count)
		await wait_process_frames(3)
		for path: String in ["BoardTitle", "Totals/Pot", "Totals/Wager", "BlindLevel"]:
			assert_eq((center.get_node(path) as Label).text, "")
		assert_eq((center.get_node("Cards") as GuiCardRow).cards.size(), 0)
	var card: GuiPlayingCard = CardScene.instantiate()
	root.add_child(card)
	card.render(CardViewModel.face(CardData.new(14, CardData.Suit.SPADES)))
	card.render(null)
	assert_push_error_count(3)
	await wait_process_frames(3)
	var snapshot: GuiCardSnapshot = card.get_card_snapshot(root, &"card")
	assert_eq(snapshot.kind, GuiCardSnapshot.Kind.EMPTY)
	assert_eq(snapshot.rank.text, "")
	assert_eq(snapshot.suit.text, "")
	assert_false((card.get_node("Face") as Control).visible)


func test_pre_tree_render_detaches_values_and_inherits_composition_theme() -> void:
	var card: GuiPlayingCard = CardScene.instantiate()
	var model := CardViewModel.face(CardData.new(10, CardData.Suit.HEARTS))
	card.render(model)
	model.rank_text = "A"
	model.suit_text = "♠"
	model.state = CardViewModel.State.BACK
	var root: Control = _root()
	root.add_child(card)
	await wait_process_frames(3)
	card.size = card.get_combined_minimum_size()
	await wait_process_frames(3)
	var snapshot: GuiCardSnapshot = card.get_card_snapshot(root, &"card", true)
	assert_eq(snapshot.kind, GuiCardSnapshot.Kind.FACE)
	assert_eq(snapshot.rank.text, "10")
	assert_eq(snapshot.suit.text, "♥")
	for control: Control in [card, card.get_node("Face"), card.get_node("Face/Glyphs")]:
		assert_null(control.theme, "Composition ancestors own the metric and palette Themes")
	_assert_face(snapshot)


func test_constrained_center_containers_keep_maximum_value_copy_readable() -> void:
	var root: Control = _root()
	var host := VBoxContainer.new()
	root.add_child(host)
	var center: GuiCenterBoard = CenterScene.instantiate()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_child(center)
	var view: GameView = _view()
	view.pot_amount = 9000000
	view.small_blind = 500000
	view.big_blind = 1000000
	view._seats[1].bet_this_round = 1000000
	view._community_cards = [
		CardData.new(10, CardData.Suit.SPADES),
		CardData.new(11, CardData.Suit.HEARTS),
		CardData.new(12, CardData.Suit.CLUBS),
	]
	var model: CenterViewModel = CenterViewModel.build(view)
	center.render(model)
	for allocation: Vector2 in [Vector2(320, 350), Vector2(844, 240)]:
		host.size = allocation
		await wait_process_frames(5)
		assert_lte(center.size.x, allocation.x)
		assert_lte(center.size.y, allocation.y)
		assert_eq((center.get_node("Totals/Pot") as Label).text, model.phone_pot_text)
		assert_eq((center.get_node("Totals/Wager") as Label).text, model.phone_wager_text)
		assert_eq((center.get_node("BlindLevel") as Label).text, model.blind_level_text)
		var measured: Array[GuiLayoutElement] = []
		GuiSnapshotMeasurement.descendants(center, root, &"center", measured)
		for element: GuiLayoutElement in measured:
			var failures := PackedStringArray()
			Invariants.validate_element(element, failures)
			assert_eq(failures, PackedStringArray())
			if element.visible:
				assert_true(host.get_global_rect().encloses(element.rect))
		var row: GuiCardRow = center.get_node("Cards")
		for index: int in 3:
			_assert_face(row.cards[index].get_card_snapshot(root, &"board", true))


func test_malformed_face_with_no_visible_ink_clears_without_an_unbounded_fit_search() -> void:
	var root: Control = _root()
	var card: GuiPlayingCard = CardScene.instantiate()
	root.add_child(card)
	card.render(CardViewModel.face(CardData.new(10, CardData.Suit.SPADES)))
	card.size = Vector2(120, 168)
	await wait_process_frames(3)
	var malformed := CardViewModel.new()
	malformed.state = CardViewModel.State.FACE
	malformed.rank_text = " "
	malformed.suit_text = " "
	card.render(malformed)
	await wait_process_frames(3)
	assert_push_error_count(1)
	var glyphs: GuiCardGlyphs = card.get_node("Face/Glyphs")
	assert_eq(glyphs.rank_text, "")
	assert_eq(glyphs.suit_text, "")
	assert_true(glyphs.get_ink_rects().is_empty())
	card.size = Vector2(160, 224)
	await wait_process_frames(3)
	assert_push_error_count(1)


func test_full_card_validation_rejects_overlapping_rank_and_suit() -> void:
	var root: Control = _root()
	var card: GuiPlayingCard = CardScene.instantiate()
	root.add_child(card)
	card.render(CardViewModel.face(CardData.new(10, CardData.Suit.SPADES)))
	card.size = Vector2(120, 168)
	await wait_process_frames(3)
	var snapshot: GuiCardSnapshot = card.get_card_snapshot(root, &"card", true)
	var failures := PackedStringArray()
	Content.validate_card(snapshot, "component", failures)
	assert_eq(failures, PackedStringArray())
	snapshot.rank.rect = snapshot.suit.rect
	Content.validate_card(snapshot, "component", failures)
	assert_true(failures.has("component rank intersects suit"))


func _assert_surface(card: GuiPlayingCard, surface: Control) -> void:
	assert_gt(surface.size.y, 0.0)
	assert_gte(surface.size.x / surface.size.y, 5.0 / 7.0 - 0.001)
	assert_true(card.get_global_rect().encloses(surface.get_global_rect()))


func _assert_face(snapshot: GuiCardSnapshot) -> void:
	var card_failures := PackedStringArray()
	Content.validate_card(snapshot, "component", card_failures)
	assert_eq(card_failures, PackedStringArray())
	assert_true(snapshot.rank.visible)
	assert_true(snapshot.suit.visible)
	assert_true(snapshot.element.rect.encloses(snapshot.rank.rect))
	assert_true(snapshot.element.rect.encloses(snapshot.suit.rect))
	assert_false(snapshot.rank.rect.intersects(snapshot.suit.rect))
	assert_gte(snapshot.rank.font_size, 20)
	assert_eq(snapshot.rank.font_size, snapshot.suit.font_size)
	for element: GuiLayoutElement in [snapshot.rank, snapshot.suit]:
		var failures := PackedStringArray()
		Invariants.validate_element(element, failures)
		assert_eq(failures, PackedStringArray())
		assert_lte(element.required_size.x, element.local_content_size.x + 0.5)
		assert_lte(element.required_size.y, element.local_content_size.y + 0.5)


func _root() -> Control:
	var root := Control.new()
	root.theme = Palette
	root.size = Vector2(1600, 1000)
	add_child_autofree(root)
	return root


func _view() -> GameView:
	var view := GameView.new()
	view.hero_seat = 0
	view.pot_amount = 150
	view.small_blind = 5
	view.big_blind = 10
	view.blind_level = 2
	view.hands_until_next_level = 7
	for seat: int in 3:
		view._seats.append(
			PlayerView.new(Player.new(StringName("p%d" % seat), "Player", seat, 1000))
		)
	view._seats[1].bet_this_round = 60
	return view


func test_center_deferred_binding_survives_removal_and_reentry() -> void:
	var root: Control = _root()
	var center: GuiCenterBoard = CenterScene.instantiate()
	var model: CenterViewModel = CenterViewModel.build(_view())
	root.add_child(center)
	center.render(model)
	root.remove_child(center)
	await wait_process_frames(3)
	root.add_child(center)
	center.size = Vector2(320, 350)
	await wait_process_frames(4)
	assert_eq((center.get_node("BlindLevel") as Label).text, model.blind_level_text)
	assert_push_error_count(0)
	center.render(model)
	await wait_process_frames(1)
	root.remove_child(center)
	await wait_process_frames(3)
	assert_push_error_count(0)
	center.free()
