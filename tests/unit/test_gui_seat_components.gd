extends GutTest

const SeatScene := preload("res://scenes/gui/components/SeatPanel.tscn")
const HeroScene := preload("res://scenes/gui/components/HeroPanel.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const GrayMaterial := preload("res://resources/gui_grayscale_material.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const Content := preload("res://tests/support/gui_snapshot_content_assertions.gd")
const AVATAR: String = "res://assets/avatars/avatar_01.png"


func test_every_seat_state_renders_complete_copy_and_footprint_at_minimum() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	for state: String in [
		"normal", "acting", "folded", "all-in", "busted", "heads-up", "winner", "side-winner"
	]:
		var model: SeatViewModel = _model(state)
		seat.render(model)
		await wait_process_frames(4)
		seat.size = seat.get_combined_minimum_size()
		await wait_process_frames(4)
		var snapshot: GuiSeatSnapshot = seat.get_seat_snapshot(root)
		assert_eq(snapshot.seat_id, model.seat, state)
		assert_eq(snapshot.fields[&"name"].text, model.display_name, state)
		assert_eq(snapshot.fields[&"stack"].text, model.stack_text, state)
		assert_eq(snapshot.status.text, model.status_text, state)
		assert_false(snapshot.fields.has(&"badge"), "The redundant body state line is removed")
		assert_eq(snapshot.folded, model.folded, state)
		assert_eq(snapshot.busted, model.busted, state)
		_assert_complete(snapshot)
		assert_eq(snapshot.cards.size(), 2)
		for card: GuiCardSnapshot in snapshot.cards:
			assert_true(snapshot.panel.rect.encloses(card.element.rect), state)
			if card.kind == GuiCardSnapshot.Kind.FACE:
				var failures := PackedStringArray()
				Content.validate_card(card, "seat", failures)
				assert_eq(failures, PackedStringArray(), state)
				assert_gte(card.rank.font_size, 20)
				assert_gte(card.suit.font_size, 20)


func test_status_band_stays_reserved_and_aligned_across_actions_and_results() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	var model: SeatViewModel = _model()
	seat.render(model)
	await wait_process_frames(4)
	seat.size = seat.get_combined_minimum_size()
	await wait_process_frames(3)
	var blank: GuiSeatSnapshot = seat.get_seat_snapshot(root)
	assert_gt(blank.status.rect.size.y, 0.0)
	assert_gte(
		blank.status.rect.size.y,
		2.0 * (seat.get_node("Status") as Label).get_theme_font("font").get_height(18)
	)
	for copy: String in [
		"Raise to 1000000",
		"Winner",
		"Full house: Queens full of Sevens",
		"Two pair\nAces / Kings",
		""
	]:
		model.status_text = copy
		model.winner_emphasis = (
			copy in ["Winner", "Full house: Queens full of Sevens", "Two pair\nAces / Kings"]
		)
		seat.render(model)
		await wait_process_frames(4)
		var rendered: GuiSeatSnapshot = seat.get_seat_snapshot(root)
		assert_eq(rendered.status.text, copy)
		assert_eq(rendered.status.rect.size.y, blank.status.rect.size.y)
		assert_eq(rendered.status.rect.position.x, rendered.panel.rect.position.x)
		assert_eq(rendered.status.rect.end.x, rendered.panel.rect.end.x)
		assert_gte(rendered.status.rect.position.y, rendered.panel.rect.end.y)
		_assert_complete(rendered)


func test_all_award_kinds_use_bright_bold_copy_and_an_independent_large_star() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	for state: String in ["winner", "side-winner", "fold-winner", "split-winner"]:
		var model: SeatViewModel = _model(state)
		seat.render(model)
		await wait_process_frames(4)
		seat.size = seat.get_combined_minimum_size()
		await wait_process_frames(3)
		var status: Label = seat.get_node("Status")
		var star: Control = seat.get_node("%Winner")
		assert_eq(status.text, model.status_text)
		assert_eq(status.get_theme_color("font_color"), Color.YELLOW)
		assert_true(status.get_theme_font("font") is FontVariation)
		assert_gt((status.get_theme_font("font") as FontVariation).variation_embolden, 0.0)
		assert_eq(star.get_theme_color("font_color"), Color.YELLOW)
		assert_true(star.is_visible_in_tree())
		assert_gt(star.modulate.a * star.self_modulate.a, 0.0)
		assert_eq(star.get_theme_font_size("font_size"), 28)
		assert_eq(star.theme_type_variation, &"TokenWinnerStar")
		assert_false(star.get_global_rect().intersects(status.get_global_rect()))
		assert_false(
			star.get_global_rect().intersects(
				(seat.get_node("%Markers") as Control).get_global_rect()
			)
		)


func test_heads_up_dealer_and_blind_markers_are_separate_in_the_upper_right() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	seat.render(_model("heads-up"))
	await wait_process_frames(4)
	seat.size = seat.get_combined_minimum_size()
	await wait_process_frames(3)
	var panel: Control = seat.get_node("Panel")
	var markers: Control = seat.get_node("%Markers")
	var dealer: PanelContainer = seat.get_node("%Dealer")
	var sb: Label = seat.get_node("%SB")
	assert_eq((dealer.get_node("D") as Label).text, "D")
	assert_eq(sb.text, "SB")
	assert_true(dealer.is_visible_in_tree())
	assert_gt(dealer.modulate.a * dealer.self_modulate.a, 0.0)
	assert_true(sb.is_visible_in_tree())
	assert_false(dealer.get_global_rect().intersects(sb.get_global_rect()))
	assert_eq(dealer.get_theme_stylebox("panel").bg_color, Color.WHITE)
	assert_gte((dealer.get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_top_left, 20)
	assert_true(panel.get_global_rect().encloses(markers.get_global_rect()))
	assert_gt(markers.get_global_rect().get_center().x, panel.get_global_rect().get_center().x)
	assert_lt(markers.get_global_rect().get_center().y, panel.get_global_rect().get_center().y)


func test_folded_material_covers_every_descendant_and_rebind_restores_color() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	seat.render(_model("folded"))
	await wait_process_frames(4)
	assert_same(seat.material, GrayMaterial)
	for node: Node in seat.find_children("*", "CanvasItem", true, false):
		assert_true((node as CanvasItem).use_parent_material, str(seat.get_path_to(node)))
	var avatar: TextureRect = seat.get_node("%Avatar")
	assert_not_null(avatar.texture)
	assert_eq(avatar.texture.resource_path, AVATAR)
	seat.render(_model())
	await wait_process_frames(4)
	assert_null(seat.material)
	assert_eq(avatar.texture.resource_path, AVATAR)


func test_hero_allocates_more_space_avatar_and_preferred_text_than_bots() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	var hero: GuiSeatPanel = HeroScene.instantiate()
	root.add_child(seat)
	root.add_child(hero)
	var bot_model: SeatViewModel = _model()
	var hero_model: SeatViewModel = _model()
	hero_model.seat = 0
	hero_model.is_hero = true
	hero_model.display_name = "You"
	seat.render(bot_model)
	hero.render(hero_model)
	await wait_process_frames(4)
	seat.size = Vector2(620, 260)
	hero.size = Vector2(700, 300)
	await wait_process_frames(4)
	var bot_avatar: TextureRect = seat.get_node("%Avatar")
	var hero_avatar: TextureRect = hero.get_node("%Avatar")
	assert_gt(hero_avatar.custom_minimum_size.x, bot_avatar.custom_minimum_size.x)
	assert_gt(hero_avatar.custom_minimum_size.y, bot_avatar.custom_minimum_size.y)
	assert_gt(hero.get_combined_minimum_size().y, seat.get_combined_minimum_size().y)
	assert_gt(
		(hero.get_node("%Name") as Label).get_theme_font_size("font_size"),
		(seat.get_node("%Name") as Label).get_theme_font_size("font_size")
	)
	assert_true(hero.get_seat_snapshot(root).hero)
	assert_false(seat.get_seat_snapshot(root).hero)

	await _assert_human_corner_layout()


func test_pre_tree_render_and_resizing_keep_assigned_identity_and_card_reuse() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	var model: SeatViewModel = _model("winner")
	seat.render(model)
	model.display_name = "Changed"
	model.avatar_path = ""
	model.cards.cards[0].rank_text = "Changed"
	root.add_child(seat)
	await wait_process_frames(4)
	var avatar: TextureRect = seat.get_node("%Avatar")
	var texture: Texture2D = avatar.texture
	var cards: GuiHoleCards = seat.get_node("%Cards")
	var first: GuiPlayingCard = cards.cards[0]
	for allocation: Vector2 in [
		seat.get_combined_minimum_size(), Vector2(620, 240), Vector2(480, 300)
	]:
		seat.size = allocation.max(seat.get_combined_minimum_size())
		await wait_process_frames(4)
		var snapshot: GuiSeatSnapshot = seat.get_seat_snapshot(root)
		assert_eq(snapshot.fields[&"name"].text, "Leilani")
		assert_eq(snapshot.cards[0].rank.text, "10")
		assert_same(avatar.texture, texture)
		assert_same(cards.cards[0], first)
		assert_eq(avatar.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		assert_eq(avatar.expand_mode, TextureRect.EXPAND_IGNORE_SIZE)
		_assert_complete(snapshot)


func test_density_changes_preserve_role_floors_without_affecting_cards() -> void:
	var root: Control = _root()
	var layer := Control.new()
	root.add_child(layer)
	var seat: GuiSeatPanel = SeatScene.instantiate()
	layer.add_child(seat)
	seat.render(_model("side-winner"))
	for metrics: Theme in [GuiTypography.Compact, GuiTypography.Regular, GuiTypography.Compact]:
		layer.theme = metrics
		seat.size = Vector2(650, 280)
		await wait_process_frames(5)
		var snapshot: GuiSeatSnapshot = seat.get_seat_snapshot(root)
		_assert_complete(snapshot)
		for path: String in ["%Name", "%Stack", "%Wager", "Status"]:
			var label: Label = seat.get_node(path)
			assert_gte(label.get_theme_font_size("font_size"), 18)
			assert_lte(
				label.get_theme_font_size("font_size"),
				metrics.get_font_size("font_size", "SeatText")
			)
		for card: GuiCardSnapshot in snapshot.cards:
			assert_gte(card.rank.font_size, 20)
			assert_gte(card.suit.font_size, 20)


func test_rebinding_hidden_cards_and_invalid_models_clears_old_identity() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	seat.render(_model("winner"))
	await wait_process_frames(4)
	var shown: GuiSeatSnapshot = seat.get_seat_snapshot(root)
	seat.render(_model())
	await wait_process_frames(4)
	var hidden: GuiSeatSnapshot = seat.get_seat_snapshot(root)
	assert_eq(shown.cards[0].rank.text, "10")
	for card: GuiCardSnapshot in hidden.cards:
		assert_eq(card.kind, GuiCardSnapshot.Kind.BACK)
		assert_eq(card.rank.text, "")
		assert_eq(card.suit.text, "")
	seat.render(_model("heads-up"))
	seat.render(null)
	assert_push_error_count(1)
	await wait_process_frames(4)
	assert_eq((seat.get_node("%Name") as Label).text, "")
	assert_eq((seat.get_node("Status") as Label).text, "")
	assert_null((seat.get_node("%Avatar") as TextureRect).texture)
	assert_eq((seat.get_node("%Cards") as GuiHoleCards).cards.size(), 0)
	assert_false(seat.get_field(&"dealer").visible)
	assert_false((seat.get_field(&"badge_row_2").get_parent() as Control).visible)
	seat.render(SeatViewModel.new())
	assert_push_error_count(2)


func _assert_wide_bot_corner_states() -> void:
	var root: Control = _root()
	for metrics: Theme in [GuiTypography.Compact, GuiTypography.Regular]:
		var layer := Control.new()
		layer.theme = metrics
		root.add_child(layer)
		var seat: GuiSeatPanel = SeatScene.instantiate()
		layer.add_child(seat)
		for state: String in [
			"normal",
			"heads-up",
			"dealer-only",
			"small-blind",
			"big-blind",
			"winner",
			"folded",
			"all-in"
		]:
			var model: SeatViewModel = _model(state)
			model.is_dealer = model.is_dealer or state == "dealer-only"
			model.is_small_blind = model.is_small_blind or state == "small-blind"
			model.is_big_blind = model.is_big_blind or state == "big-blind"
			model.stack_text = "9000000 chips"
			model.stack_value_text = "9000000"
			seat.render(model)
			await wait_process_frames(5)
			var minimum: Vector2 = seat.get_combined_minimum_size()
			for allocation: Vector2 in [minimum, Vector2(900, 400), minimum]:
				seat.size = allocation
				await wait_process_frames(5)
				assert_eq(seat.get_combined_minimum_size(), minimum)
				var panel: Control = seat.get_node("Panel")
				var style: StyleBox = panel.get_theme_stylebox("panel")
				var cards: Control = seat.get_field(&"cards")
				var markers: Control = seat.get_field(&"markers")
				var avatar: Control = seat.get_field(&"avatar")
				assert_eq(avatar.custom_minimum_size, Vector2(64, 64))
				var name_label: Control = seat.get_field(&"name")
				var star: Control = seat.get_field(&"winner")
				assert_almost_eq(
					cards.get_global_rect().end.x,
					panel.get_global_rect().end.x - style.get_margin(SIDE_RIGHT),
					0.1
				)
				assert_almost_eq(
					cards.get_global_rect().end.y,
					panel.get_global_rect().end.y - style.get_margin(SIDE_BOTTOM),
					0.1
				)
				assert_almost_eq(
					markers.get_global_rect().end.x,
					panel.get_global_rect().end.x - style.get_margin(SIDE_RIGHT),
					0.1
				)
				assert_almost_eq(
					markers.global_position.y,
					panel.global_position.y + style.get_margin(SIDE_TOP),
					0.1
				)
				assert_almost_eq(avatar.global_position.y, markers.global_position.y, 0.1)
				assert_false(markers.get_global_rect().intersects(cards.get_global_rect()))
				assert_almost_eq(
					star.global_position.x - name_label.get_global_rect().end.x,
					float((star.get_parent() as BoxContainer).get_theme_constant("separation")),
					0.1
				)
				var dealer: Control = seat.get_field(&"dealer")
				var blind: Control = seat.get_field(
					&"badge_row_2" if model.is_small_blind else &"badge_row_3"
				)
				if model.is_dealer:
					assert_true(dealer.is_visible_in_tree())
					assert_eq(dealer.size, Vector2(40, 40))
				else:
					assert_false(dealer.is_visible_in_tree())
				if model.is_small_blind or model.is_big_blind:
					assert_eq(blind.size, Vector2(40, 40))
					assert_almost_eq(
						blind.get_global_rect().end.x, markers.get_global_rect().end.x, 0.1
					)
					if model.is_dealer:
						assert_almost_eq(
							blind.global_position.x - dealer.get_global_rect().end.x,
							float(
								(dealer.get_parent() as BoxContainer).get_theme_constant(
									"separation"
								)
							),
							0.1
						)
				elif model.is_dealer:
					assert_almost_eq(
						dealer.get_global_rect().end.x, markers.get_global_rect().end.x, 0.1
					)
					assert_false((seat.get_field(&"badge_row_2").get_parent() as Control).visible)
				var copy: Array[Label] = _copy_labels(seat)
				assert_lt(copy[0].global_position.y, copy[1].global_position.y)
				assert_lt(copy[1].global_position.y, copy[2].global_position.y)
				assert_eq(copy[1].text, "9000000")
				_assert_complete(seat.get_seat_snapshot(root))
		root.remove_child(layer)
		layer.free()


func _assert_bot_amount_room_is_stable_and_configurable() -> void:
	var root: Control = _root()
	for metrics: Theme in [GuiTypography.Compact, GuiTypography.Regular]:
		var layer := Control.new()
		layer.theme = metrics
		root.add_child(layer)
		var seat: GuiSeatPanel = SeatScene.instantiate()
		layer.add_child(seat)
		var model: SeatViewModel = _model()
		var baseline := Vector2.ZERO
		for amount: String in ["60", "9000000", "60"]:
			model.stack_value_text = amount
			model.stack_text = amount + " chips"
			model.wager_text = "Bet " + amount
			seat.render(model)
			await wait_process_frames(5)
			var minimum: Vector2 = seat.get_combined_minimum_size()
			if baseline == Vector2.ZERO:
				baseline = minimum
			assert_eq(minimum, baseline, "Small and seven-digit amounts reserve the same box")
			for allocation: Vector2 in [minimum, Vector2(900, 400), minimum]:
				seat.size = allocation
				await wait_process_frames(5)
				assert_eq(seat.get_combined_minimum_size(), baseline)
				var snapshot: GuiSeatSnapshot = seat.get_seat_snapshot(root)
				assert_eq(snapshot.fields[&"stack"].text, amount)
				assert_eq(snapshot.fields[&"action"].text, "Bet " + amount)
				assert_eq(
					snapshot.fields[&"stack"].font_size,
					metrics.get_font_size("font_size", "SeatText")
				)
				_assert_complete(snapshot)
		model.stack_value_text = "999999999"
		model.wager_text = "Bet 999999999"
		seat.render(model)
		await wait_process_frames(5)
		assert_gt(
			seat.get_combined_minimum_size().x, baseline.x, "Actual longer copy still expands"
		)
		seat.size = seat.get_combined_minimum_size()
		await wait_process_frames(5)
		_assert_complete(seat.get_seat_snapshot(root))
		model.stack_value_text = "60"
		model.wager_text = "Bet 60"
		seat.render(model)
		await wait_process_frames(5)
		assert_eq(seat.get_combined_minimum_size(), baseline)
		var custom: Theme = metrics.duplicate(true)
		custom.set_constant("amount_digits", "SeatPanel", 9)
		layer.theme = custom
		await wait_process_frames(5)
		assert_gt(
			seat.get_combined_minimum_size().x,
			baseline.x,
			"Presentation digit room is configurable"
		)
		layer.theme = metrics
		await wait_process_frames(5)
		assert_eq(seat.get_combined_minimum_size(), baseline)
		root.remove_child(layer)
		layer.free()


func _assert_human_corner_layout() -> void:
	var root: Control = _root()
	for metrics: Theme in [GuiTypography.Compact, GuiTypography.Regular]:
		var layer := Control.new()
		layer.theme = metrics
		root.add_child(layer)
		var hero: GuiSeatPanel = HeroScene.instantiate()
		layer.add_child(hero)
		for state: String in ["normal", "heads-up", "winner", "folded", "all-in"]:
			var model: SeatViewModel = _model(state)
			model.stack_text = "9000000 chips"
			model.stack_value_text = "9000000"
			hero.render(model)
			await wait_process_frames(5)
			var minimum: Vector2 = hero.get_combined_minimum_size()
			for allocation: Vector2 in [minimum, Vector2(1000, 500), minimum]:
				hero.size = allocation
				await wait_process_frames(5)
				assert_eq(hero.get_combined_minimum_size(), minimum)
				assert_true(hero.hero_presentation)
				var panel: Control = hero.get_node("Panel")
				var style: StyleBox = panel.get_theme_stylebox("panel")
				var cards: Control = hero.get_field(&"cards")
				var markers: Control = hero.get_field(&"markers")
				var avatar: Control = hero.get_field(&"avatar")
				var name_label: Control = hero.get_field(&"name")
				var star: Control = hero.get_field(&"winner")
				assert_eq(avatar.custom_minimum_size, Vector2(80, 80))
				assert_almost_eq(
					avatar.global_position.x,
					panel.global_position.x + style.get_margin(SIDE_LEFT),
					0.1
				)
				assert_almost_eq(
					avatar.global_position.y,
					panel.global_position.y + style.get_margin(SIDE_TOP),
					0.1
				)
				assert_almost_eq(
					cards.get_global_rect().end.x,
					panel.get_global_rect().end.x - style.get_margin(SIDE_RIGHT),
					0.1
				)
				assert_almost_eq(
					cards.get_global_rect().end.y,
					panel.get_global_rect().end.y - style.get_margin(SIDE_BOTTOM),
					0.1
				)
				assert_almost_eq(
					markers.get_global_rect().end.x, cards.get_global_rect().end.x, 0.1
				)
				assert_false(markers.get_global_rect().intersects(cards.get_global_rect()))
				assert_eq(star.get_theme_font_size("font_size"), 64)
				assert_almost_eq(
					star.global_position.x - name_label.get_global_rect().end.x,
					float((star.get_parent() as BoxContainer).get_theme_constant("separation")),
					0.1
				)
				var snapshot: GuiSeatSnapshot = hero.get_seat_snapshot(root)
				assert_true(snapshot.hero)
				assert_eq(snapshot.fields[&"stack"].text, "9000000 chips")
				for label: Label in _copy_labels(hero):
					assert_eq(
						label.get_theme_font_size("font_size"),
						metrics.get_font_size("font_size", "HeroText")
					)
				var first: Rect2 = snapshot.cards[0].element.rect
				var second: Rect2 = snapshot.cards[1].element.rect
				assert_almost_eq(second.position.x - first.end.x, first.size.x * 0.06, 1.5)
				_assert_complete(snapshot)
			hero.render(_model())
			await wait_process_frames(4)
			(hero.get_field(&"cards") as GuiHoleCards).cards[0].render(
				CardViewModel.face(CardData.new(14, CardData.Suit.SPADES))
			)
			await wait_process_frames(3)
			var private_snapshot: GuiSeatSnapshot = hero.get_seat_snapshot(root)
			assert_false(private_snapshot.face_authorized)
			assert_false(private_snapshot.cards[0].authorized)
			assert_true(private_snapshot.cards[0].rank.privacy_redacted)
			assert_eq(private_snapshot.cards[0].rank.text, "")
		root.remove_child(layer)
		layer.free()


func _assert_bot_stack_fallback() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	var model: SeatViewModel = _model()
	model.stack_text = "940 chips"
	model.stack_value_text = ""
	seat.render(model)
	await wait_process_frames(5)
	assert_eq((seat.get_field(&"stack") as Label).text, "940 chips")
	_assert_complete(seat.get_seat_snapshot(root))


func _assert_complete(snapshot: GuiSeatSnapshot) -> void:
	assert_true(snapshot.footprint.encloses(snapshot.panel.rect))
	assert_true(snapshot.footprint.encloses(snapshot.status.rect))
	assert_gt(snapshot.footprint.size.y, snapshot.panel.rect.size.y)
	assert_eq(snapshot.panel.rect.position.x, snapshot.status.rect.position.x)
	assert_eq(snapshot.panel.rect.end.x, snapshot.status.rect.end.x)
	for element: GuiLayoutElement in snapshot.fields.values():
		if not element.present:
			continue
		var failures := PackedStringArray()
		Invariants.validate_element(element, failures)
		assert_eq(failures, PackedStringArray(), str(element.role))
	var failures := PackedStringArray()
	Invariants.validate_element(snapshot.status, failures)
	assert_eq(failures, PackedStringArray())


func _copy_labels(seat: GuiSeatPanel) -> Array[Label]:
	return [
		seat.get_field(&"name") as Label,
		seat.get_field(&"stack") as Label,
		seat.get_field(&"action") as Label
	]


func _root() -> Control:
	var root := Control.new()
	root.theme = Palette
	root.size = Vector2(1800, 1200)
	add_child_autofree(root)
	return root


func _model(state: String = "normal") -> SeatViewModel:
	var model := SeatViewModel.new()
	model.valid = true
	model.seat = 1
	model.display_name = "Leilani"
	model.avatar_path = AVATAR
	model.stack_text = "1000000"
	model.stack_value_text = "1000000"
	model.wager_text = "Bet 1000000"
	model.cards = CardRowViewModel.new()
	model.cards.cards = [CardViewModel.back(), CardViewModel.back()]
	match state:
		"acting":
			model.acting = true
		"folded":
			model.folded = true
			model.status_text = "Fold"
			model.cards.cards = [CardViewModel.empty(), CardViewModel.empty()]
		"all-in":
			model.all_in = true
			model.status_text = "All In to 1000000"
		"busted":
			model.busted = true
			model.status_text = "Out"
			model.cards.cards = [CardViewModel.empty(), CardViewModel.empty()]
		"heads-up":
			model.is_dealer = true
			model.is_small_blind = true
		"winner", "side-winner", "fold-winner", "split-winner":
			model.winner_emphasis = true
			model.main_pot_winner = state == "winner"
			model.pre_showdown_winner = state == "fold-winner"
			model.status_text = (
				"Winner" if state == "fold-winner" else "Full house: Queens full of Sevens"
			)
			if state == "side-winner":
				model.status_text = "Two pair\nAces / Kings"
			model.cards.cards = [
				CardViewModel.face(CardData.new(10, CardData.Suit.SPADES)),
				CardViewModel.face(CardData.new(14, CardData.Suit.HEARTS))
			]
	model.badge_text = (
		{"acting": "Turn", "folded": "Fold", "all-in": "AI", "busted": "Out", "heads-up": "D SB"}
		. get(state, "")
	)
	model.state_text = model.badge_text.replace("AI", "All In") if state != "heads-up" else ""
	return model


func test_missing_avatar_clears_previous_texture_and_valid_rebind_recovers() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	seat.render(_model())
	await wait_process_frames(4)
	var avatar: TextureRect = seat.get_node("%Avatar")
	assert_not_null(avatar.texture)
	var bad: SeatViewModel = _model()
	bad.avatar_path = "res://assets/avatars/does_not_exist.png"
	seat.render(bad)
	assert_push_error_count(1)
	assert_null(avatar.texture)
	seat.render(_model())
	await wait_process_frames(4)
	assert_not_null(avatar.texture)
	assert_eq(avatar.texture.resource_path, AVATAR)


func test_pending_fit_survives_removal_and_reentry_without_changing_identity() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	seat.render(_model("heads-up"))
	root.remove_child(seat)
	await wait_process_frames(3)
	root.add_child(seat)
	seat.size = Vector2(650, 280)
	await wait_process_frames(4)
	var snapshot: GuiSeatSnapshot = seat.get_seat_snapshot(root)
	assert_eq(snapshot.fields[&"name"].text, "Leilani")
	assert_false(snapshot.fields.has(&"badge"))
	assert_push_error_count(0)
	_assert_complete(snapshot)
	root.remove_child(seat)
	seat.free()


func test_acting_frame_strengthens_both_bot_and_human_without_runtime_style_copies() -> void:
	var root: Control = _root()
	for scene: PackedScene in [SeatScene, HeroScene]:
		var seat: GuiSeatPanel = scene.instantiate()
		root.add_child(seat)
		seat.render(_model())
		var panel: PanelContainer = seat.get_node("Panel")
		var normal: StyleBoxFlat = panel.get_theme_stylebox("panel")
		seat.render(_model("acting"))
		var acting: StyleBoxFlat = panel.get_theme_stylebox("panel")
		assert_eq(acting.border_color, Color.WHITE)
		for edge: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			assert_gt(acting.get_border_width(edge), normal.get_border_width(edge))
		assert_false(panel.has_theme_stylebox_override("panel"))
		seat.render(_model())
		assert_same(panel.get_theme_stylebox("panel"), normal)


func test_longest_permitted_name_and_maximum_live_stack_keep_every_digit_at_minimum() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	var model: SeatViewModel = _model("winner")
	model.display_name = "Annalise"
	model.stack_text = "9000000 chips"
	model.stack_value_text = "9000000"
	model.wager_text = "Bet 9000000"
	seat.render(model)
	await wait_process_frames(4)
	seat.size = seat.get_combined_minimum_size()
	await wait_process_frames(4)
	var snapshot: GuiSeatSnapshot = seat.get_seat_snapshot(root)
	assert_eq(snapshot.fields[&"name"].text, "Annalise")
	assert_eq(snapshot.fields[&"stack"].text, "9000000")
	assert_eq(snapshot.fields[&"action"].text, "Bet 9000000")
	_assert_complete(snapshot)

	await _assert_bot_stack_fallback()
	await _assert_bot_amount_room_is_stable_and_configurable()


func test_marker_free_state_copy_comes_from_model_while_legacy_badges_remain_intact() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	for state: String in ["normal", "acting", "folded", "all-in", "busted"]:
		var view := GameView.new()
		view.hero_seat = 0
		view.button_seat = 1
		view.small_blind_seat = 1
		view.big_blind_seat = 0
		view.acting_seat = 1 if state == "acting" else Table.NO_SEAT
		var player := PlayerView.new(Player.new(&"bot", "Leilani", 1, 1000))
		player.folded = state == "folded"
		player.all_in = state == "all-in"
		player.busted = state == "busted"
		view._seats = [player]
		var model: SeatViewModel = SeatViewModel.build(player, view, {}, {})
		var expected: String = (
			{"acting": "Turn", "folded": "Fold", "all-in": "All In", "busted": "Out"}.get(state, "")
		)
		assert_eq(model.state_text, expected)
		var legacy_state: String = "AI" if state == "all-in" else expected
		assert_eq(
			model.badge_text, "D SB" + (" " + legacy_state if not legacy_state.is_empty() else "")
		)
		seat.render(model)
		await wait_process_frames(4)
		assert_false(seat.has_node("Panel/Body/Copy/State"))
		assert_eq(_copy_labels(seat).size(), 3)
		assert_eq((seat.get_node("%D") as Label).text, "D")
		assert_eq((seat.get_node("%SB") as Label).text, "SB")


func test_snapshot_keeps_original_hidden_card_authorization_after_child_mutation() -> void:
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	seat.render(_model())
	await wait_process_frames(4)
	var cards: GuiHoleCards = seat.get_node("%Cards")
	cards.cards[0].render(CardViewModel.face(CardData.new(14, CardData.Suit.SPADES)))
	await wait_process_frames(3)
	var snapshot: GuiSeatSnapshot = seat.get_seat_snapshot(root)
	assert_false(snapshot.face_authorized)
	assert_eq(snapshot.cards[0].kind, GuiCardSnapshot.Kind.FACE)
	assert_false(snapshot.cards[0].authorized)
	assert_true(snapshot.cards[0].rank.privacy_redacted)
	assert_true(snapshot.cards[0].suit.privacy_redacted)
	assert_eq(snapshot.cards[0].rank.text, "")
	assert_eq(snapshot.cards[0].suit.text, "")


func test_three_line_body_keeps_avatar_at_the_upper_left_for_bots_and_human() -> void:
	var root: Control = _root()
	for scene: PackedScene in [SeatScene, HeroScene]:
		var seat: GuiSeatPanel = scene.instantiate()
		root.add_child(seat)
		for state: String in ["normal", "acting", "winner"]:
			seat.render(_model(state))
			seat.size = Vector2(700, 300).max(seat.get_combined_minimum_size())
			await wait_process_frames(5)
			var body: Control = seat.get_node("%Body")
			var avatar: TextureRect = seat.get_node("%Avatar")
			assert_eq(avatar.global_position.x, body.global_position.x)
			assert_eq(avatar.global_position.y, body.global_position.y)
			var copy: Array[Label] = _copy_labels(seat)
			assert_eq(copy.size(), 3)
			assert_false(seat.has_node("%State"))
			assert_eq(copy[0].text, "Leilani")
			assert_eq(copy[1].text, "1000000")
			assert_eq(copy[2].text, "Bet 1000000")
			_assert_complete(seat.get_seat_snapshot(root))

	await _assert_wide_bot_corner_states()


func test_blind_badges_match_the_dealer_button_square_in_both_metric_densities() -> void:
	var root: Control = _root()
	var layer := Control.new()
	root.add_child(layer)
	for metrics: Theme in [GuiTypography.Compact, GuiTypography.Regular]:
		layer.theme = metrics
		for scene: PackedScene in [SeatScene, HeroScene]:
			var seat: GuiSeatPanel = scene.instantiate()
			layer.add_child(seat)
			for small: bool in [true, false]:
				var model: SeatViewModel = _model("heads-up")
				model.is_small_blind = small
				model.is_big_blind = not small
				seat.render(model)
				seat.size = Vector2(700, 300).max(seat.get_combined_minimum_size())
				await wait_process_frames(5)
				var dealer: Control = seat.get_node("%Dealer")
				var badge: Label = seat.get_node("%" + ("SB" if small else "BB"))
				assert_eq(dealer.size, Vector2(40, 40))
				assert_eq(badge.size, dealer.size)
				assert_gte(badge.get_theme_font_size("font_size"), 20)
				assert_eq(badge.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
				assert_eq(badge.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)
				assert_false(dealer.get_global_rect().intersects(badge.get_global_rect()))
				_assert_complete(seat.get_seat_snapshot(root))


func test_visible_hole_card_gaps_scale_equally_for_bots_and_human_at_each_allocation() -> void:
	var root: Control = _root()
	for scene: PackedScene in [SeatScene, HeroScene]:
		var seat: GuiSeatPanel = scene.instantiate()
		root.add_child(seat)
		for state: String in ["normal", "winner", "folded"]:
			seat.render(_model(state))
			await wait_process_frames(4)
			for allocation: Vector2 in [
				seat.get_combined_minimum_size(),
				Vector2(620, 240),
				Vector2(900, 400),
				Vector2(480, 280)
			]:
				seat.size = allocation.max(seat.get_combined_minimum_size())
				await wait_process_frames(6)
				var snapshot: GuiSeatSnapshot = seat.get_seat_snapshot(root)
				var first: Rect2 = snapshot.cards[0].element.rect
				var second: Rect2 = snapshot.cards[1].element.rect
				var width: float = (first.size.x + second.size.x) * 0.5
				var gap: float = second.position.x - first.end.x
				assert_gte(gap, 0.0)
				assert_almost_eq(
					gap, width * 0.06, 1.5, "%s/%s" % [scene.resource_path, allocation]
				)
				assert_almost_eq(first.size.x, second.size.x, 1.0)
				assert_gte(first.size.x / first.size.y, 5.0 / 7.0)
				assert_gte(second.size.x / second.size.y, 5.0 / 7.0)
				_assert_complete(snapshot)


func test_all_in_action_is_written_in_full_in_the_model_and_reserved_status_band() -> void:
	var view := GameView.new()
	view.hero_seat = 0
	var player := PlayerView.new(Player.new(&"bot", "Leilani", 1, 1000000))
	player.all_in = true
	view._seats = [player]
	var action := PublicActionRecord.new(1, PlayerAction.Kind.ALL_IN, 1000000)
	var model: SeatViewModel = SeatViewModel.build(player, view, {}, {}, action)
	assert_eq(model.state_text, "All In")
	assert_eq(model.status_text, "All In to 1000000")
	assert_eq(model.badge_text, "AI", "Legacy rendering keeps its existing badge contract")
	var root: Control = _root()
	var seat: GuiSeatPanel = SeatScene.instantiate()
	root.add_child(seat)
	seat.render(model)
	seat.size = Vector2(700, 300).max(seat.get_combined_minimum_size())
	await wait_process_frames(5)
	assert_eq((seat.get_node("Status") as Label).text, "All In to 1000000")
	assert_false(seat.has_node("Panel/Body/Copy/State"))
	_assert_complete(seat.get_seat_snapshot(root))


func test_native_container_recovers_exact_initial_minimum_after_a_large_allocation() -> void:
	var root: Control = _root()
	for metrics: Theme in [GuiTypography.Compact, GuiTypography.Regular]:
		for scene: PackedScene in [SeatScene, HeroScene]:
			for state: String in ["normal", "winner", "folded"]:
				var host := VBoxContainer.new()
				host.theme = metrics
				root.add_child(host)
				var seat: GuiSeatPanel = scene.instantiate()
				seat.size_flags_vertical = Control.SIZE_EXPAND_FILL
				host.add_child(seat)
				seat.render(_model(state))
				await wait_process_frames(6)
				var initial_minimum: Vector2 = host.get_combined_minimum_size()
				host.size = initial_minimum
				await wait_process_frames(6)
				var initial: GuiSeatSnapshot = seat.get_seat_snapshot(root)
				var requested := Rect2(host.global_position, initial_minimum)
				assert_true(requested.encloses(initial.footprint))
				host.size = Vector2(1800, 800)
				await wait_process_frames(8)
				assert_eq(
					host.get_combined_minimum_size(),
					initial_minimum,
					(
						"An expanded allocation must not increase the intrinsic minimum: %s/%s"
						% [scene.resource_path, state]
					)
				)
				# Request the original allocation exactly, rather than hiding a latched
				# minimum behind max(current_minimum, requested_size).
				host.size = initial_minimum
				await wait_process_frames(8)
				assert_eq(host.size, initial_minimum)
				var recovered: GuiSeatSnapshot = seat.get_seat_snapshot(root)
				assert_true(requested.encloses(recovered.footprint))
				_assert_complete(recovered)
				root.remove_child(host)
				host.free()
