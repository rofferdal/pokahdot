extends GutTest

const TokenScene := preload("res://scenes/gui/components/SeatToken.tscn")
const Palette := preload("res://resources/gui_theme.tres")
const GrayMaterial := preload("res://resources/gui_grayscale_material.tres")
const Invariants := preload("res://tests/support/gui_invariant_assertions.gd")
const Content := preload("res://tests/support/gui_snapshot_content_assertions.gd")

var _viewport: SubViewport


func test_fixed_corner_layout_preserves_positions_cards_and_compact_height() -> void:
	var root: Control = _root()
	for metrics: Theme in [GuiTypography.Compact, GuiTypography.Regular]:
		var token: GuiSeatToken = TokenScene.instantiate()
		token.theme = metrics
		root.add_child(token)
		for state: String in [
			"normal", "acting", "heads-up", "folded", "all-in", "busted", "winner", "side-winner"
		]:
			var model: SeatViewModel = _model(state)
			token.render(model)
			await wait_process_frames(6)
			for expanded: bool in [false, true, false]:
				token.size = Vector2(640, 320) if expanded else token.get_combined_minimum_size()
				await wait_process_frames(6)
				var snapshot: GuiSeatSnapshot = token.get_seat_snapshot(root)
				var panel: Control = token.get_node("Panel")
				var content: Control = token.get_node("Panel/Content")
				var cards: Control = token.get_field(&"cards")
				assert_almost_eq(
					cards.get_global_rect().end.x, content.get_global_rect().end.x, 0.1, state
				)
				assert_almost_eq(
					cards.get_global_rect().end.y, content.get_global_rect().end.y, 0.1, state
				)
				assert_false((cards as GuiHoleCards).vertical_pair)
				assert_eq(
					cards.size, cards.get_combined_minimum_size(), "Keep the accepted pair size"
				)
				var markers: Control = token.get_node("%Markers")
				if model.is_dealer:
					assert_almost_eq(
						markers.get_global_rect().end.x, content.get_global_rect().end.x, 0.1
					)
					assert_almost_eq(markers.global_position.y, content.global_position.y, 0.1)
					assert_false(markers.get_global_rect().intersects(cards.get_global_rect()))
				var name: Control = token.get_field(&"name")
				var star: Control = token.get_field(&"winner")
				if model.winner_emphasis:
					assert_gte(star.global_position.x, name.get_global_rect().end.x)
					assert_lt(star.global_position.y, cards.global_position.y)
					assert_false(star.get_global_rect().intersects(cards.get_global_rect()))
				if not expanded:
					assert_lt(panel.size.y, 132.0, "Reduce the previous 132px review box")
				_assert_complete(snapshot)
				_assert_fields_do_not_overlap(snapshot)
		root.remove_child(token)
		token.free()


func test_every_token_state_renders_full_copy_and_safe_cards_at_its_minimum() -> void:
	var root: Control = _root()
	var token: GuiSeatToken = TokenScene.instantiate()
	root.add_child(token)
	for state: String in [
		"normal", "acting", "folded", "all-in", "busted", "heads-up", "winner", "side-winner"
	]:
		var model: SeatViewModel = _model(state)
		token.render(model)
		await wait_process_frames(6)
		token.size = token.get_combined_minimum_size()
		await wait_process_frames(6)
		var snapshot: GuiSeatSnapshot = token.get_seat_snapshot(root)
		assert_eq(snapshot.seat_id, model.seat, state)
		assert_eq(snapshot.fields[&"name"].text, model.display_name, state)
		assert_eq(snapshot.fields[&"stack"].text, model.stack_value_text, state)
		assert_eq(snapshot.fields[&"action"].text, model.wager_text, state)
		assert_eq(snapshot.status.text, _status_copy(model), state)
		assert_eq(snapshot.folded, model.folded, state)
		assert_eq(snapshot.busted, model.busted, state)
		assert_eq(snapshot.cards.size(), 2)
		_assert_complete(snapshot)
		_assert_fields_do_not_overlap(snapshot)


func test_compact_hand_copy_and_all_winners_use_the_reserved_bold_yellow_band() -> void:
	var root: Control = _root()
	var token: GuiSeatToken = TokenScene.instantiate()
	root.add_child(token)
	for state: String in ["winner", "side-winner", "split-winner", "fold-winner"]:
		var model: SeatViewModel = _model(state)
		token.render(model)
		await wait_process_frames(6)
		token.size = token.get_combined_minimum_size()
		await wait_process_frames(5)
		var status: Label = token.get_node("Status")
		assert_eq(status.text, _status_copy(model))
		assert_eq(status.get_theme_color("font_color"), Color.YELLOW)
		assert_true(status.get_theme_font("font") is FontVariation)
		assert_gt((status.get_theme_font("font") as FontVariation).variation_embolden, 0.0)
		var snapshot: GuiSeatSnapshot = token.get_seat_snapshot(root)
		var star: Control = token.get_field(&"winner")
		assert_not_null(star)
		assert_true(star.is_visible_in_tree())
		assert_eq(star.get_theme_color("font_color"), Color.YELLOW)
		assert_gte(star.get_theme_font_size("font_size"), 28)
		assert_true(snapshot.panel.rect.encloses(star.get_global_rect()))
		assert_gte(snapshot.status.rect.size.y, status.get_theme_font("font").get_height(18) * 2)
		_assert_complete(snapshot)
	var model: SeatViewModel = _model("all-in")
	token.render(model)
	await wait_process_frames(6)
	assert_eq((token.get_node("Status") as Label).text, "All In to 1000000")


func test_hidden_to_shown_rebinding_detaches_copy_and_reuses_safe_card_components() -> void:
	var root: Control = _root()
	var token: GuiSeatToken = TokenScene.instantiate()
	var shown: SeatViewModel = _model("winner")
	shown.is_hero = true
	token.render(shown)
	root.add_child(token)
	token.size = Vector2(190, 240)
	await wait_process_frames(6)
	shown.display_name = "Changed"
	shown.stack_value_text = "999"
	shown.is_hero = false
	shown.cards.cards[0].rank_text = "K"
	var first: GuiSeatSnapshot = token.get_seat_snapshot(root)
	assert_true(first.hero)
	assert_eq(first.fields[&"name"].text, "Emiliano")
	assert_eq(first.fields[&"stack"].text, "9000000")
	assert_eq(first.cards[0].rank.text, "10")
	for view: GuiPlayingCard in token.get_card_views():
		assert_eq(view.scene_file_path, "res://scenes/gui/components/PlayingCard.tscn")
	token.render(_model())
	await wait_process_frames(6)
	var hidden: GuiSeatSnapshot = token.get_seat_snapshot(root)
	assert_false(hidden.hero)
	assert_false(hidden.face_authorized)
	for card: GuiCardSnapshot in hidden.cards:
		assert_eq(card.kind, GuiCardSnapshot.Kind.BACK)
		assert_eq(card.rank.text, "")
		assert_eq(card.suit.text, "")
	assert_eq(first.cards[0].rank.text, "10", "Snapshots detach from subsequent bindings")


func test_direct_child_mutation_cannot_authorize_an_unrevealed_card() -> void:
	var root: Control = _root()
	var token: GuiSeatToken = TokenScene.instantiate()
	root.add_child(token)
	token.render(_model())
	await wait_process_frames(6)
	token.get_card_views()[0].render(CardViewModel.face(CardData.new(14, CardData.Suit.SPADES)))
	await wait_process_frames(4)
	var snapshot: GuiSeatSnapshot = token.get_seat_snapshot(root)
	assert_false(snapshot.face_authorized)
	assert_eq(snapshot.cards[0].kind, GuiCardSnapshot.Kind.FACE)
	assert_false(snapshot.cards[0].authorized)
	assert_true(snapshot.cards[0].rank.privacy_redacted)
	assert_true(snapshot.cards[0].suit.privacy_redacted)
	assert_eq(snapshot.cards[0].rank.text, "")
	assert_eq(snapshot.cards[0].suit.text, "")


func test_folded_grayscale_propagates_through_every_rendered_descendant() -> void:
	var root: Control = _root()
	var token: GuiSeatToken = TokenScene.instantiate()
	root.add_child(token)
	token.render(_model("folded"))
	await wait_process_frames(6)
	assert_same(token.material, GrayMaterial)
	for node: Node in token.find_children("*", "CanvasItem", true, false):
		assert_true((node as CanvasItem).use_parent_material, str(token.get_path_to(node)))
	assert_true(token.find_children("*", "TextureRect", true, false).is_empty())
	token.render(_model())
	await wait_process_frames(6)
	assert_null(token.material)
	_assert_complete(token.get_seat_snapshot(root))


func test_dealer_and_blind_markers_have_separate_equal_readable_allocations() -> void:
	var root: Control = _root()
	var token: GuiSeatToken = TokenScene.instantiate()
	root.add_child(token)
	for small: bool in [true, false]:
		var model: SeatViewModel = _model("heads-up")
		model.is_small_blind = small
		model.is_big_blind = not small
		token.render(model)
		await wait_process_frames(6)
		token.size = token.get_combined_minimum_size()
		await wait_process_frames(4)
		var dealer: Control = token.get_field(&"marker")
		var blind: Control = token.get_field(&"badge" if small else &"badge_row_2")
		assert_true(dealer.is_visible_in_tree())
		assert_true(blind.is_visible_in_tree())
		assert_gte(dealer.get_theme_font_size("font_size"), 18)
		assert_gte(blind.get_theme_font_size("font_size"), 18)
		assert_false(dealer.get_global_rect().intersects(blind.get_global_rect()))
		var blind_size: Vector2 = blind.size
		assert_eq(blind_size, Vector2(30, 30))
		assert_eq(dealer.get_parent_control().size, blind_size)
		_assert_complete(token.get_seat_snapshot(root))


func test_resize_and_density_changes_keep_copy_complete_and_minima_recoverable() -> void:
	var root: Control = _root()
	for metrics: Theme in [GuiTypography.Compact, GuiTypography.Regular]:
		for state: String in ["normal", "winner", "folded"]:
			var host := VBoxContainer.new()
			host.theme = metrics
			root.add_child(host)
			var token: GuiSeatToken = TokenScene.instantiate()
			token.size_flags_vertical = Control.SIZE_EXPAND_FILL
			host.add_child(token)
			token.render(_model(state))
			await wait_process_frames(8)
			var minimum: Vector2 = host.get_combined_minimum_size()
			host.size = minimum
			await wait_process_frames(6)
			_assert_complete(token.get_seat_snapshot(root))
			host.size = Vector2(800, 600)
			await wait_process_frames(8)
			assert_eq(host.get_combined_minimum_size(), minimum)
			_assert_complete(token.get_seat_snapshot(root))
			host.size = minimum
			await wait_process_frames(8)
			assert_eq(host.size, minimum)
			var snapshot: GuiSeatSnapshot = token.get_seat_snapshot(root)
			assert_true(Rect2(host.global_position, minimum).encloses(snapshot.footprint))
			_assert_complete(snapshot)
			root.remove_child(host)
			host.free()


func test_six_opponent_tokens_fit_two_native_columns_without_claiming_a_full_table() -> void:
	var root: Control = _root()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	root.add_child(grid)
	grid.size = Vector2(480, 900)
	var tokens: Array[GuiSeatToken] = []
	for index: int in 6:
		var token: GuiSeatToken = TokenScene.instantiate()
		token.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(token)
		var model: SeatViewModel = _model("winner" if index == 0 else "normal")
		model.seat = index + 1
		token.render(model)
		tokens.append(token)
	await wait_process_frames(10)
	assert_lte(grid.size.x, 480.0)
	var rows: Dictionary[float, int] = {}
	for token: GuiSeatToken in tokens:
		var snapshot: GuiSeatSnapshot = token.get_seat_snapshot(root)
		assert_true(Rect2(grid.global_position, Vector2(480, 900)).encloses(snapshot.footprint))
		rows[snapshot.footprint.position.y] = rows.get(snapshot.footprint.position.y, 0) + 1
		_assert_complete(snapshot)
	assert_eq(rows.size(), 3)
	for count: int in rows.values():
		assert_eq(count, 2, "Six opponents represent the seven-player component stress case")


func test_resizing_keeps_horizontal_pair_gap_and_identity() -> void:
	var root: Control = _root()
	var token: GuiSeatToken = TokenScene.instantiate()
	root.add_child(token)
	token.render(_model())
	await wait_process_frames(8)
	for wide: bool in [false, true, false]:
		token.size = Vector2(640, 260) if wide else token.get_combined_minimum_size()
		await wait_process_frames(8)
		var snapshot: GuiSeatSnapshot = token.get_seat_snapshot(root)
		var first: Rect2 = snapshot.cards[0].element.rect
		var second: Rect2 = snapshot.cards[1].element.rect
		var card_width: float = (first.size.x + second.size.x) * 0.5
		assert_eq(first.position.y, second.position.y)
		assert_almost_eq(second.position.x - first.end.x, card_width * 0.06, 1.5)
		assert_eq(snapshot.fields[&"name"].text, "Emiliano")
		_assert_complete(snapshot)


func test_native_keyboard_pointer_and_touch_emit_one_detail_intent_per_activation() -> void:
	var root: Control = _input_root()
	var token: GuiSeatToken = TokenScene.instantiate()
	root.add_child(token)
	token.render(_model())
	token.size = Vector2(190, 250)
	watch_signals(token)
	await wait_process_frames(8)
	token.grab_focus()
	await _key(KEY_ENTER)
	assert_signal_emit_count(token, "detail_requested", 1)
	assert_signal_emitted_with_parameters(token, "detail_requested", [1])
	await _click(token.get_global_rect().get_center())
	assert_signal_emit_count(token, "detail_requested", 2)
	await _click(token.get_global_rect().get_center(), -1)
	assert_signal_emit_count(token, "detail_requested", 2)
	await _touch(token.get_global_rect().get_center())
	assert_signal_emit_count(token, "detail_requested", 3)


func test_invalid_binding_clears_old_copy_and_cancels_detail_intents() -> void:
	var root: Control = _input_root()
	var token: GuiSeatToken = TokenScene.instantiate()
	root.add_child(token)
	token.render(_model("winner"))
	token.size = Vector2(190, 250)
	await wait_process_frames(6)
	watch_signals(token)
	token.grab_focus()
	token.render(null)
	assert_push_error_count(1)
	await wait_process_frames(5)
	assert_eq((token.get_field(&"name") as Label).text, "")
	assert_eq((token.get_node("Status") as Label).text, "")
	assert_true(token.get_card_views().is_empty())
	assert_false(token.has_focus())
	await _key(KEY_ENTER)
	await _click(token.get_global_rect().get_center())
	await _touch(token.get_global_rect().get_center())
	assert_signal_not_emitted(token, "detail_requested")
	token.render(SeatViewModel.new())
	assert_push_error_count(2)


func test_native_focus_remains_visible_for_normal_acting_and_folded_tokens() -> void:
	var root: Control = _input_root()
	var token: GuiSeatToken = TokenScene.instantiate()
	root.add_child(token)
	for state: String in ["normal", "acting", "folded"]:
		token.render(_model(state))
		token.size = Vector2(200, 260)
		await wait_process_frames(6)
		var panel := token.get_node("Panel") as PanelContainer
		var original_variation: StringName = panel.theme_type_variation
		var original_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		var original_snapshot: GuiSeatSnapshot = token.get_seat_snapshot(root)
		token.grab_focus()
		await wait_process_frames(2)
		assert_true(token.has_focus(), state)
		assert_eq(panel.theme_type_variation, &"SeatTokenFocused", state)
		var focused_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		assert_ne(focused_style.border_color, original_style.border_color, state)
		assert_gte(focused_style.border_width_left, 3, state)
		var focused_snapshot: GuiSeatSnapshot = token.get_seat_snapshot(root)
		for role: StringName in [&"name", &"stack", &"action"]:
			assert_eq(
				focused_snapshot.fields[role].text, original_snapshot.fields[role].text, state
			)
		assert_eq(focused_snapshot.status.text, original_snapshot.status.text, state)
		assert_eq(focused_snapshot.folded, state == "folded", state)
		if state == "folded":
			assert_same(token.material, GrayMaterial)
			for node: Node in token.find_children("*", "CanvasItem", true, false):
				assert_true((node as CanvasItem).use_parent_material, str(token.get_path_to(node)))
		else:
			assert_null(token.material)
		token.release_focus()
		await wait_process_frames(2)
		assert_false(token.has_focus(), state)
		assert_eq(panel.theme_type_variation, original_variation, state)
		assert_same(panel.get_theme_stylebox("panel"), original_style, state)


func test_replacement_token_palette_keeps_legacy_padding_and_unique_resource_ids() -> void:
	var legacy: StyleBox = Palette.get_stylebox("panel", "PhoneToken")
	var replacement: StyleBox = Palette.get_stylebox("panel", "SeatTokenFrame")
	assert_not_same(legacy, replacement)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_eq(legacy.get_content_margin(side), 6.0)
		assert_eq(replacement.get_content_margin(side), 4.0)
	var pattern := RegEx.new()
	assert_eq(pattern.compile('\\[sub_resource[^\\n]*id="([^"]+)"'), OK)
	var source: String = FileAccess.get_file_as_string("res://resources/gui_theme.tres")
	assert_false(source.is_empty())
	var ids := PackedStringArray()
	for matched: RegExMatch in pattern.search_all(source):
		var resource_id: String = matched.get_string(1)
		assert_false(resource_id in ids, "Subresource IDs must be unique: " + resource_id)
		ids.append(resource_id)
	assert_gt(ids.size(), 0)


func test_pre_tree_binding_and_removal_reentry_preserve_assigned_identity() -> void:
	var root: Control = _root()
	var token: GuiSeatToken = TokenScene.instantiate()
	var model: SeatViewModel = _model("side-winner")
	token.render(model)
	root.add_child(token)
	root.remove_child(token)
	await wait_process_frames(4)
	root.add_child(token)
	token.size = Vector2(200, 260)
	await wait_process_frames(8)
	assert_eq((token.get_field(&"name") as Label).text, model.display_name)
	assert_eq((token.get_node("Status") as Label).text, model.status_compact)
	_assert_complete(token.get_seat_snapshot(root))
	assert_push_error_count(0)


func _assert_complete(snapshot: GuiSeatSnapshot) -> void:
	assert_true(snapshot.footprint.encloses(snapshot.panel.rect))
	assert_true(snapshot.footprint.encloses(snapshot.status.rect))
	assert_gte(snapshot.footprint.size.x, 48.0)
	assert_gte(snapshot.footprint.size.y, 48.0)
	assert_eq(snapshot.panel.rect.position.x, snapshot.status.rect.position.x)
	assert_eq(snapshot.panel.rect.end.x, snapshot.status.rect.end.x)
	assert_gte(snapshot.status.rect.position.y, snapshot.panel.rect.end.y)
	for element: GuiLayoutElement in snapshot.fields.values():
		if not element.present or not element.visible:
			continue
		assert_true(
			snapshot.panel.rect.encloses(element.rect),
			"%s: panel %s, field %s" % [element.role, snapshot.panel.rect, element.rect]
		)
		var failures := PackedStringArray()
		Invariants.validate_element(element, failures)
		assert_eq(failures, PackedStringArray(), str(element.role))
	var failures := PackedStringArray()
	Invariants.validate_element(snapshot.status, failures)
	assert_eq(failures, PackedStringArray())
	for card: GuiCardSnapshot in snapshot.cards:
		assert_true(snapshot.panel.rect.encloses(card.element.rect))
		assert_gte(card.element.rect.size.x / card.element.rect.size.y, 5.0 / 7.0)
		if card.kind == GuiCardSnapshot.Kind.FACE:
			assert_true(card.authorized)
			var card_failures := PackedStringArray()
			Content.validate_card(card, "token", card_failures)
			assert_eq(card_failures, PackedStringArray())
			for glyph: GuiLayoutElement in [card.rank, card.suit]:
				var glyph_failures := PackedStringArray()
				Invariants.validate_element(glyph, glyph_failures)
				assert_eq(glyph_failures, PackedStringArray())
				assert_gte(glyph.font_size, 20)


func _assert_fields_do_not_overlap(snapshot: GuiSeatSnapshot) -> void:
	var fields: Array[GuiLayoutElement] = []
	for role: StringName in [
		&"name", &"stack", &"action", &"marker", &"badge", &"badge_row_2", &"cards"
	]:
		var field: GuiLayoutElement = snapshot.fields[role]
		if field.present and field.visible and field.opacity > 0.0:
			fields.append(field)
	for first: int in fields.size():
		for second: int in range(first + 1, fields.size()):
			assert_false(fields[first].rect.intersects(fields[second].rect))


func _model(state: String = "normal") -> SeatViewModel:
	var model := SeatViewModel.new()
	model.valid = true
	model.seat = 1
	model.display_name = "Emiliano"
	model.stack_text = "9000000 chips"
	model.stack_value_text = "9000000"
	model.wager_text = "Bet 1000000"
	model.cards = CardRowViewModel.new()
	model.cards.cards = [CardViewModel.back(), CardViewModel.back()]
	match state:
		"acting":
			model.acting = true
			model.status_text = "Raise to 1000000"
		"folded":
			model.folded = true
			model.status_text = "Fold"
			model.cards.cards = [CardViewModel.empty(), CardViewModel.empty()]
		"all-in":
			model.all_in = true
			model.state_text = "All In"
			model.status_text = "All In to 1000000"
		"busted":
			model.busted = true
			model.state_text = "Out"
			model.cards.cards = [CardViewModel.empty(), CardViewModel.empty()]
		"heads-up":
			model.is_dealer = true
			model.is_small_blind = true
		"winner", "side-winner", "split-winner", "fold-winner":
			model.winner_emphasis = true
			model.status_text = "Full house: Queens full of Sevens"
			model.status_compact = "Full house\nQueens / Sevens"
			if state == "side-winner":
				model.status_compact = "Two pair\nAces / Kings"
			if state == "fold-winner":
				model.pre_showdown_winner = true
				model.status_text = "Winner"
				model.status_compact = ""
			model.cards.cards = [
				CardViewModel.face(CardData.new(10, CardData.Suit.SPADES)),
				CardViewModel.face(CardData.new(14, CardData.Suit.HEARTS))
			]
	return model


func _status_copy(model: SeatViewModel) -> String:
	if not model.status_compact.is_empty():
		return model.status_compact
	return model.status_text if not model.status_text.is_empty() else model.state_text


func _root() -> Control:
	var root := Control.new()
	root.theme = Palette
	root.size = Vector2(1800, 1400)
	add_child_autofree(root)
	return root


func _input_root() -> Control:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 700)
	add_child_autofree(_viewport)
	var root := Control.new()
	root.size = Vector2(800, 700)
	root.theme = Palette
	_viewport.add_child(root)
	return root


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame


func _click(position: Vector2, device: int = 0) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.device = device
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame


func _touch(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = position
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame
