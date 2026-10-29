extends GutTest

const HostScene := preload("res://scenes/gui/components/OverlayHost.tscn")
const Palette := preload("res://resources/gui_theme.tres")

var _viewport: SubViewport
var _root: Control
var _host: GuiOverlayHost
var _underlying: Button
var _advanced: int = 0
var _committed_draft: String = "original"


func test_menu_switches_keep_one_modal_and_hold_advancement_until_final_close() -> void:
	_setup()
	_host.render_log(EventLogViewModel.from_lines(["Blind 10", "Call 20"]))
	_host.render_summary(_summary_model())
	_underlying.grab_focus()
	_host.open_menu()
	await wait_process_frames(5)
	assert_true(_host.is_active())
	assert_eq(_host.get_active_kind(), &"menu")
	assert_true(_host.hold_advance(func() -> void: _advanced += 1))
	await _activate(_host.get_control(&"menu_log"))
	assert_eq(_host.get_active_kind(), &"log")
	assert_eq(_advanced, 0)
	assert_eq(_host.get_log().get_log_text(), "Blind 10\nCall 20")
	_host.open_menu()
	await wait_process_frames(3)
	await _activate(_host.get_control(&"menu_summary"))
	assert_eq(_host.get_active_kind(), &"summary")
	assert_eq(_advanced, 0)
	await _activate(_host.get_control(&"summary_close"))
	assert_false(_host.is_active())
	assert_eq(_advanced, 1)
	assert_true(_underlying.has_focus())
	_host.close()
	await wait_process_frames(3)
	assert_eq(_advanced, 1, "Repeated close cannot replay the pending advance")


func test_backdrop_blocks_native_pointer_touch_and_stray_underlying_keyboard_focus() -> void:
	_setup()
	watch_signals(_underlying)
	_host.open_menu()
	await wait_process_frames(5)
	await _click(Vector2(8, 8))
	assert_signal_not_emitted(_underlying, "pressed")
	_host.open_menu()
	await wait_process_frames(3)
	await _touch(Vector2(8, 8))
	assert_signal_not_emitted(_underlying, "pressed")
	_host.open_menu()
	await wait_process_frames(3)
	_underlying.grab_focus()
	await _key(KEY_ENTER)
	assert_signal_not_emitted(_underlying, "pressed")
	await _key(KEY_TAB)
	var focused: Control = _viewport.gui_get_focus_owner()
	assert_not_null(focused)
	assert_true(_host.is_ancestor_of(focused))
	await _key(KEY_ESCAPE)
	assert_false(_host.is_active())
	assert_true(_underlying.has_focus())
	await _click(Vector2(8, 8))
	assert_signal_emit_count(_underlying, "pressed", 1, "Positive control after modal close")


func test_tab_wraps_within_menu_and_engine_back_restores_the_previous_policy() -> void:
	_setup()
	var original_back_policy: bool = get_tree().quit_on_go_back
	_host.render_summary(_summary_model())
	_host.open_menu()
	await wait_process_frames(5)
	assert_false(get_tree().quit_on_go_back)
	_host.get_control(&"menu_close").grab_focus()
	await _key(KEY_TAB)
	assert_true(_host.get_control(&"menu_log").has_focus())
	await _key(KEY_TAB, true)
	assert_true(_host.get_control(&"menu_close").has_focus())
	var guard_found: bool = false
	for node: Node in _host.find_children("*", "Node", true, false):
		if node is GuiModalGuard:
			guard_found = true
			node.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true(guard_found)
	await wait_process_frames(3)
	assert_false(_host.is_active())
	assert_eq(get_tree().quit_on_go_back, original_back_policy)


func test_menu_keeps_log_and_quit_reachable_without_a_summary_model() -> void:
	_setup()
	_host.render_summary(HandSummaryViewModel.new())
	_host.open_menu()
	await wait_process_frames(5)
	for role: StringName in [&"menu_log", &"menu_quit", &"menu_close"]:
		var button := _host.get_control(role) as BaseButton
		assert_true(button.is_visible_in_tree(), role)
		assert_false(button.disabled, role)
	assert_true((_host.get_control(&"menu_summary") as BaseButton).disabled)
	await _activate(_host.get_control(&"menu_quit"))
	assert_eq(_host.get_active_kind(), &"quit")
	await _activate(_host.get_control(&"quit_keep"))
	assert_false(_host.is_active())


func test_finished_tournament_menu_exit_skips_confirmation_and_discards_pending_advance() -> void:
	_setup()
	watch_signals(_host)
	_host.set_quit_confirmation_required(false)
	_host.open_menu()
	await wait_process_frames(5)
	assert_true(_host.hold_advance(func() -> void: _advanced += 1))
	await _activate(_host.get_control(&"menu_quit"))
	assert_false(_host.is_active())
	assert_eq(_host.get_active_kind(), &"")
	assert_signal_emit_count(_host, "quit_confirmed", 1)
	assert_eq(_advanced, 0)
	_host.close()
	await wait_process_frames(3)
	assert_eq(_advanced, 0)
	_host.set_quit_confirmation_required(true)
	_host.open_menu()
	await wait_process_frames(3)
	await _activate(_host.get_control(&"menu_quit"))
	assert_eq(_host.get_active_kind(), &"quit")
	assert_signal_emit_count(_host, "quit_confirmed", 1)


func test_quit_confirmation_cancels_pending_advancement_and_emits_once() -> void:
	_setup()
	watch_signals(_host)
	_host.open_quit()
	assert_true(_host.hold_advance(func() -> void: _advanced += 1))
	await wait_process_frames(5)
	await _activate(_host.get_control(&"quit_confirm"))
	assert_signal_emit_count(_host, "quit_confirmed", 1)
	assert_false(_host.is_active())
	assert_eq(_advanced, 0)
	_host.close()
	await wait_process_frames(3)
	assert_signal_emit_count(_host, "quit_confirmed", 1)
	assert_eq(_advanced, 0)


func test_hidden_log_updates_survive_other_modal_models_without_interpreting_markup() -> void:
	_setup()
	var public_copy: String = "[b]Call 9000000[/b]\n[color=red]Winner[/color]"
	_host.render_log(EventLogViewModel.from_lines([public_copy]))
	_host.open_log()
	await wait_process_frames(5)
	var log: GuiEventLog = _host.get_log()
	assert_eq(log.get_log_text(), public_copy)
	assert_false(log.get_body().bbcode_enabled)
	assert_eq(log.get_body().get_parsed_text(), public_copy)
	assert_gte(log.get_body().get_theme_font_size("normal_font_size"), 18)
	_host.open_summary(_summary_model())
	await wait_process_frames(5)
	assert_false(log.is_visible_in_tree())
	var summary := _host.get_control(&"summary_body") as RichTextLabel
	assert_true(summary.is_visible_in_tree())
	assert_false(summary.bbcode_enabled)
	assert_eq(summary.get_parsed_text(), _summary_model().text)
	assert_gte(summary.get_theme_font_size("normal_font_size"), 20)
	assert_gte(summary.get_theme_font_size("bold_font_size"), 20)
	var bold: Font = summary.get_theme_font("bold_font")
	assert_true(bold is FontVariation)
	if bold is FontVariation:
		assert_gt((bold as FontVariation).variation_embolden, 0.0)
	_host.render_log(EventLogViewModel.from_lines([public_copy, "Next hand 2"]))
	_host.open_log()
	await wait_process_frames(5)
	assert_same(_host.get_log(), log)
	assert_eq(log.get_log_text(), public_copy + "\nNext hand 2")
	_host.close()


func test_number_escape_and_mode_exit_discard_local_drafts_without_commit() -> void:
	_setup()
	watch_signals(_host)
	_host.number_committed.connect(func(value: String) -> void: _committed_draft = value)
	var model := NumberEntryViewModel.new()
	model.value = "00042"
	_host.open_number(model)
	await wait_process_frames(5)
	await _activate(_host.get_keypad().get_control(&"clear"))
	await _activate(_host.get_keypad().get_control(&"7"))
	assert_eq(_host.get_keypad().get_draft(), "7")
	await _key(KEY_ESCAPE)
	assert_false(_host.is_active())
	assert_eq(_committed_draft, "original")
	assert_signal_emit_count(_host, "number_cancelled", 1)
	assert_signal_not_emitted(_host, "number_committed")
	_host.open_number(model)
	await wait_process_frames(4)
	await _activate(_host.get_keypad().get_control(&"9"))
	_host.on_layout_mode_changed()
	await wait_process_frames(3)
	assert_false(_host.is_active())
	assert_eq(_committed_draft, "original")
	assert_signal_emit_count(_host, "number_cancelled", 2)
	assert_signal_not_emitted(_host, "number_committed")
	_host.open_log()
	_host.on_layout_mode_changed()
	await wait_process_frames(4)
	assert_true(_host.is_active())
	assert_eq(_host.get_active_kind(), &"log")
	_host.close()


func test_number_done_commits_the_exact_raw_draft_once() -> void:
	_setup()
	watch_signals(_host)
	_host.number_committed.connect(func(value: String) -> void: _committed_draft = value)
	var model := NumberEntryViewModel.new()
	model.value = " 00042 "
	_host.open_number(model)
	await wait_process_frames(5)
	assert_eq(_host.get_keypad().get_draft(), " 00042 ")
	await _activate(_host.get_keypad().get_control(&"done"))
	assert_eq(_committed_draft, " 00042 ")
	assert_signal_emit_count(_host, "number_committed", 1)
	assert_signal_not_emitted(_host, "number_cancelled")
	assert_false(_host.is_active())
	await _key(KEY_ENTER)
	assert_signal_emit_count(_host, "number_committed", 1)


func test_keypad_geometry_respects_nonzero_usable_origin_and_guides_when_infeasible() -> void:
	_setup()
	for usable: Rect2 in [Rect2(28, 34, 360, 740), Rect2(32, 24, 740, 330)]:
		_host.set_usable_rect(usable)
		_host.open_number(NumberEntryViewModel.new())
		await wait_process_frames(7)
		assert_eq(_host.get_active_kind(), &"number")
		assert_almost_eq(
			_host.get_control(&"active").get_global_rect().get_center().x,
			usable.get_center().x,
			0.5
		)
		assert_almost_eq(
			_host.get_control(&"active").get_global_rect().get_center().y,
			usable.get_center().y,
			0.5
		)
		for node: Node in _host.get_keypad().find_children("*", "Control", true, false):
			var control := node as Control
			if control.is_visible_in_tree() and control is BaseButton:
				assert_true(usable.encloses(control.get_global_rect()), str(control.get_path()))
				assert_gte(control.size.x, 48.0)
				assert_gte(control.size.y, 48.0)
		_host.close()
		await wait_process_frames(3)
	_host.set_usable_rect(Rect2(30, 40, 180, 150))
	_host.open_number(NumberEntryViewModel.new())
	await wait_process_frames(6)
	assert_true(_host.is_active())
	assert_ne(_host.get_active_kind(), &"number")
	assert_true(_host.get_control(&"guide_close").is_visible_in_tree())
	await _activate(_host.get_control(&"guide_close"))
	assert_false(_host.is_active())


func test_removed_host_restores_back_policy_and_discards_pending_advancement() -> void:
	_setup()
	var previous_policy: bool = get_tree().quit_on_go_back
	_host.open_log()
	assert_true(_host.hold_advance(func() -> void: _advanced += 1))
	await wait_process_frames(4)
	_root.remove_child(_host)
	_host.free()
	await wait_process_frames(4)
	assert_eq(_advanced, 0)
	assert_eq(get_tree().quit_on_go_back, previous_policy)


func test_every_modal_fits_portrait_and_short_landscape_with_one_safe_origin() -> void:
	_setup()
	_host.render_log(EventLogViewModel.from_lines(["Raise 9000000", "Winner Emiliano +999"]))
	_host.render_summary(_summary_model())
	var seat := SeatViewModel.new()
	seat.valid = true
	seat.display_name = "Emiliano"
	seat.stack_text = "9000000"
	seat.wager_text = "Bet 1000000"
	seat.cards = CardRowViewModel.new()
	seat.cards.cards = [
		CardViewModel.face(CardData.new(10, CardData.Suit.SPADES)),
		CardViewModel.face(CardData.new(14, CardData.Suit.HEARTS))
	]
	for kind: StringName in [&"menu", &"summary", &"log", &"seat", &"quit", &"number", &"presets"]:
		_host.set_usable_rect(Rect2(32, 24, 360, 740))
		match kind:
			&"menu":
				_host.open_menu()
			&"summary":
				_host.open_summary(_summary_model())
			&"log":
				_host.open_log()
			&"seat":
				_host.open_seat(seat)
			&"quit":
				_host.open_quit()
			_:
				var model := NumberEntryViewModel.new()
				model.show_presets = kind == &"presets"
				model.minimum_preset = "1000000"
				model.pot_preset = "9000000"
				model.pot_enabled = true
				_host.open_number(model)
		var expected_kind: StringName = &"number" if kind == &"presets" else kind
		for usable: Rect2 in [Rect2(32, 24, 360, 740), Rect2(32, 24, 740, 330)]:
			_host.set_usable_rect(usable)
			await wait_process_frames(8)
			assert_eq(_host.get_active_kind(), expected_kind, kind)
			_assert_modal_geometry(usable)
			if kind == &"seat":
				var cards := _host.get_control(&"seat_cards") as GuiHoleCards
				for view: GuiPlayingCard in cards.cards:
					var card: GuiCardSnapshot = view.get_card_snapshot(_root, &"detail", true)
					assert_true(usable.encloses(card.element.rect))
					assert_gte(card.element.rect.size.x / card.element.rect.size.y, 5.0 / 7.0)
					assert_gte(card.rank.font_size, 20)
					assert_gte(card.suit.font_size, 20)
		_host.close()
		await wait_process_frames(3)


func test_infeasible_menu_guidance_restores_requested_modal_without_resuming_advance() -> void:
	_setup()
	_host.open_menu()
	assert_true(_host.hold_advance(func() -> void: _advanced += 1))
	_host.set_usable_rect(Rect2(32, 24, 740, 200))
	await wait_process_frames(8)
	assert_true(_host.is_active())
	assert_eq(_host.get_active_kind(), &"guidance")
	assert_true(_host.get_control(&"guide_close").is_visible_in_tree())
	_assert_modal_geometry(Rect2(32, 24, 740, 200))
	assert_eq(_advanced, 0)
	_host.set_usable_rect(Rect2(32, 24, 740, 700))
	await wait_process_frames(8)
	assert_true(_host.is_active())
	assert_eq(_host.get_active_kind(), &"menu")
	assert_eq(_advanced, 0)
	_assert_modal_geometry(Rect2(32, 24, 740, 700))
	await _activate(_host.get_control(&"menu_close"))
	assert_eq(_advanced, 1)


func test_seat_detail_keeps_unrevealed_cards_private_with_a_nonzero_usable_origin() -> void:
	_setup()
	var usable := Rect2(42, 36, 700, 750)
	_host.set_usable_rect(usable)
	var model := SeatViewModel.new()
	model.valid = true
	model.seat = 3
	model.display_name = "Emiliano"
	model.stack_value_text = "9000000"
	model.stack_text = "9000000"
	model.wager_text = "Bet 1000000"
	model.cards = CardRowViewModel.new()
	model.cards.cards = [CardViewModel.back(), CardViewModel.back()]
	_host.open_seat(model)
	await wait_process_frames(7)
	assert_eq(_host.get_active_kind(), &"seat")
	var body := _host.get_control(&"seat_body") as RichTextLabel
	assert_false(body.bbcode_enabled)
	for copy: String in [model.display_name, model.stack_value_text, model.wager_text]:
		assert_true(body.text.contains(copy), copy)
	assert_true(usable.encloses(_host.get_control(&"active").get_global_rect()))
	var cards := _host.get_control(&"seat_cards") as GuiHoleCards
	assert_eq(cards.cards.size(), 2)
	for view: GuiPlayingCard in cards.cards:
		var card: GuiCardSnapshot = view.get_card_snapshot(_root, &"seat-detail")
		assert_eq(card.kind, GuiCardSnapshot.Kind.BACK)
		assert_false(card.authorized)
		assert_eq(card.rank.text, "")
		assert_eq(card.suit.text, "")
		assert_true(usable.encloses(card.element.rect))
	assert_true(usable.encloses(_host.get_control(&"seat_close").get_global_rect()))
	await _activate(_host.get_control(&"seat_close"))
	assert_false(_host.is_active())


func test_active_number_removal_cancels_once_and_reentry_recovers_a_closed_host() -> void:
	_setup()
	watch_signals(_host)
	_underlying.grab_focus()
	var model := NumberEntryViewModel.new()
	model.value = "00042"
	_host.open_number(model)
	assert_true(_host.hold_advance(func() -> void: _advanced += 1))
	await wait_process_frames(5)
	await _activate(_host.get_keypad().get_control(&"clear"))
	await _activate(_host.get_keypad().get_control(&"7"))
	assert_eq(_host.get_keypad().get_draft(), "7")
	_root.remove_child(_host)
	await wait_process_frames(4)
	assert_signal_emit_count(_host, "number_cancelled", 1)
	assert_signal_not_emitted(_host, "number_committed")
	assert_eq(_advanced, 0)
	assert_eq(_host.get_keypad().get_draft(), "00042")
	assert_false(_host.get_keypad().is_active())
	assert_false(_host.is_active())
	assert_false(_host.visible)
	_root.add_child(_host)
	await wait_process_frames(4)
	assert_false(_host.is_active())
	assert_false(_host.visible)
	assert_false(_host.get_keypad().is_active())
	assert_signal_emit_count(_host, "number_cancelled", 1)
	assert_signal_not_emitted(_host, "number_committed")
	assert_eq(_advanced, 0)
	_host.open_menu()
	await wait_process_frames(4)
	assert_true(_host.is_active())
	await _activate(_host.get_control(&"menu_close"))
	assert_false(_host.is_active())
	assert_true(_underlying.has_focus())
	assert_eq(_advanced, 0)


func test_freed_original_focus_uses_fallback_and_host_uses_no_native_windows() -> void:
	_setup()
	var original := Button.new()
	original.text = "Original"
	original.position = Vector2(800, 20)
	_root.add_child(original)
	original.grab_focus()
	_host.open_menu()
	await wait_process_frames(4)
	original.free()
	_host.close()
	await wait_process_frames(3)
	assert_true(_underlying.has_focus())
	assert_true(_host.find_children("*", "Window", true, false).is_empty())


func _setup() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1100, 1000)
	add_child_autofree(_viewport)
	_root = Control.new()
	_root.size = Vector2(1100, 1000)
	_root.theme = Palette
	_viewport.add_child(_root)
	_underlying = Button.new()
	_underlying.text = "Underlying action"
	_underlying.size = _root.size
	_root.add_child(_underlying)
	_host = HostScene.instantiate()
	_root.add_child(_host)
	_host.set_usable_rect(Rect2(24, 20, 850, 850))
	_host.set_fallback_focus(_underlying)
	_advanced = 0
	_committed_draft = "original"


func _summary_model() -> HandSummaryViewModel:
	var model := HandSummaryViewModel.new()
	model.visible = true
	model.text = "Main pot (999): [b]Emiliano +999[/b]\nPair of Queens & literal <text>"
	model.lines = [
		HandSummaryLineViewModel.create("Main pot (999): [b]Emiliano +999[/b]", true),
		HandSummaryLineViewModel.create("Pair of Queens & literal <text>", false)
	]
	return model


func _assert_modal_geometry(usable: Rect2) -> void:
	var active: Control = _host.get_control(&"active")
	assert_true(
		usable.encloses(active.get_global_rect()),
		"%s: usable %s, panel %s" % [_host.get_active_kind(), usable, active.get_global_rect()]
	)
	for node: Node in active.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		if control is BaseButton:
			assert_true(usable.encloses(control.get_global_rect()), str(control.get_path()))
			assert_gte(control.size.x, 48.0)
			assert_gte(control.size.y, 48.0)
			assert_gte(control.get_theme_font_size("font_size"), 20)
		elif control is Label or control is LineEdit:
			assert_gte(control.get_theme_font_size("font_size"), 20, str(control.get_path()))
		elif control is RichTextLabel:
			var floor_size: int = 18 if _host.get_active_kind() == &"log" else 20
			assert_gte(control.get_theme_font_size("normal_font_size"), floor_size)
			assert_gte(control.get_theme_font_size("bold_font_size"), floor_size)


func _activate(control: Control) -> void:
	assert_not_null(control)
	assert_true(control.is_visible_in_tree(), str(control.get_path()))
	await _click(control.get_global_rect().get_center())
	await wait_process_frames(3)


func _key(code: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		_viewport.push_input(event)
		await get_tree().process_frame


func _click(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
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
