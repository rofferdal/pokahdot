extends "res://tests/support/poker_gut_test.gd"

const GuiNameCatalogScript := preload("res://scripts/gui/gui_name_catalog.gd")
const NameAssignmentServiceScript := preload("res://scripts/gui/name_assignment_service.gd")
const AvatarAssignmentServiceScript := preload("res://scripts/gui/avatar_assignment_service.gd")
const GuiStartupConfigAdapterScript := preload("res://scripts/gui/gui_startup_config_adapter.gd")


func test_default_catalog_has_exactly_fifty_unique_valid_unicode_first_names() -> void:
	var catalog = GuiNameCatalogScript.new()
	var names: PackedStringArray = catalog.get_names()
	var unique_names: Dictionary[String, bool] = {}

	assert_eq(names.size(), 50)
	assert_eq(catalog.validation_error(), "")
	var returned_names: PackedStringArray = catalog.get_names()
	returned_names[0] = "Changed"
	assert_ne(catalog.get_names()[0], "Changed")
	for display_name: String in names:
		unique_names[display_name] = true
		assert_lte(display_name.length(), 8, display_name)
	assert_eq(unique_names.size(), 50)


func test_catalog_validation_rejects_wrong_cardinality_duplicates_nonletters_and_long_names(
) -> void:
	var names: PackedStringArray = GuiNameCatalogScript.default_names()
	names.remove_at(names.size() - 1)
	assert_eq(
		GuiNameCatalogScript.new(names).validation_error(),
		"GUI name catalog must contain exactly 50 names; found 49.",
	)
	names = GuiNameCatalogScript.default_names()
	names.append("Ravi")
	assert_eq(
		GuiNameCatalogScript.new(names).validation_error(),
		"GUI name catalog must contain exactly 50 names; found 51.",
	)

	names = GuiNameCatalogScript.default_names()
	names[49] = names[0]
	assert_eq(
		GuiNameCatalogScript.new(names).validation_error(),
		"GUI name catalog contains duplicate name: %s." % names[0],
	)

	names = GuiNameCatalogScript.default_names()
	names[0] = "Anne-Marie"
	assert_eq(
		GuiNameCatalogScript.new(names).validation_error(),
		"GUI name catalog entry Anne-Marie must contain only Unicode letters.",
	)

	names = GuiNameCatalogScript.default_names()
	names[0] = "Alexandraa"
	assert_eq(
		GuiNameCatalogScript.new(names).validation_error(),
		"GUI name catalog entry Alexandraa exceeds eight Unicode code points.",
	)


func test_catalog_counts_unicode_code_points_instead_of_utf8_bytes() -> void:
	var names: PackedStringArray = GuiNameCatalogScript.default_names()
	var unicode_letters: PackedStringArray = ["Élodie", "Ελένη", "Олена", "أحمد", "美咲", "민서", "𐐀"]
	for index: int in range(unicode_letters.size()):
		names[index] = unicode_letters[index]
	var catalog = GuiNameCatalogScript.new(names)

	assert_gt(names[0].to_utf8_buffer().size(), names[0].length())
	assert_eq(names[0].length(), 6)
	assert_eq(names[6].length(), 1)
	assert_eq(catalog.validation_error(), "")
	for invalid_name: String in ["A1", "A B", "A-B", "A_B", "A😀", "é"]:
		names = GuiNameCatalogScript.default_names()
		names[0] = invalid_name
		assert_string_contains(
			GuiNameCatalogScript.new(names).validation_error(),
			"must contain only Unicode letters",
		)


func test_assignment_covers_every_bot_seat_without_replacement_for_two_to_nine_players() -> void:
	var service = NameAssignmentServiceScript.new()
	for player_count: int in range(2, 10):
		for human_seat: int in [0, player_count - 1]:
			var result = (
				service
				. assign_for_tournament(
					player_count,
					human_seat,
					_presentation_streams(9000 + player_count).get_rng(
						NameAssignmentServiceScript.RNG_STREAM_ID
					),
				)
			)
			var unique_bot_names: Dictionary[String, bool] = {}
			var catalog_names: PackedStringArray = GuiNameCatalogScript.default_names()

			assert_true(result.is_ok(), result.error_message)
			assert_eq(result.assignments.size(), player_count)
			assert_eq(result.assignments[human_seat], "Human")
			for seat: int in range(player_count):
				if seat == human_seat:
					continue
				assert_true(catalog_names.has(result.assignments[seat]))
				unique_bot_names[result.assignments[seat]] = true
			assert_eq(unique_bot_names.size(), player_count - 1)


func test_assignment_is_deterministic_injectable_and_stable_for_one_tournament() -> void:
	var service = NameAssignmentServiceScript.new()
	var first = service.assign_for_tournament(
		9, 4, _presentation_streams(7331).get_rng(NameAssignmentServiceScript.RNG_STREAM_ID)
	)
	var second = service.assign_for_tournament(
		9, 4, _presentation_streams(7331).get_rng(NameAssignmentServiceScript.RNG_STREAM_ID)
	)
	var retained_mapping: Dictionary[int, String] = first.assignments.duplicate()

	assert_true(first.is_ok())
	assert_eq(first.assignments, second.assignments)
	for _render_index: int in range(5):
		assert_eq(first.assignments, retained_mapping)
	var caller_mapping: Dictionary[int, String] = first.assignments
	caller_mapping[0] = "Changed"
	assert_eq(first.assignments, retained_mapping)


func test_assignment_rejects_invalid_table_human_and_rng_inputs() -> void:
	var service = NameAssignmentServiceScript.new()
	var rng := RandomNumberGenerator.new()

	for result: NameAssignmentResult in [
		service.assign_for_tournament(1, 0, rng),
		service.assign_for_tournament(10, 0, rng),
		service.assign_for_tournament(6, -1, rng),
		service.assign_for_tournament(6, 6, rng),
		service.assign_for_tournament(6, 0, null),
	]:
		assert_false(result.is_ok())
		assert_eq(result.assignments, {})
		assert_false(result.error_message.is_empty())


func test_gui_name_and_avatar_named_streams_are_isolated() -> void:
	var consumed = _presentation_streams(424242)
	var untouched = _presentation_streams(424242)
	var avatar_consumed = _presentation_streams(424242)
	var service = NameAssignmentServiceScript.new()
	var avatar_service = AvatarAssignmentServiceScript.new()
	var names_rng: RandomNumberGenerator = consumed.get_rng(
		NameAssignmentServiceScript.RNG_STREAM_ID
	)
	var avatars_rng: RandomNumberGenerator = consumed.get_rng(
		AvatarAssignmentServiceScript.RNG_STREAM_ID
	)

	assert_eq(NameAssignmentServiceScript.RNG_STREAM_ID, "gui_names")
	assert_eq(AvatarAssignmentServiceScript.RNG_STREAM_ID, "gui_avatars")
	assert_ne(names_rng, avatars_rng)
	var name_result = service.assign_for_tournament(9, 0, names_rng)
	assert_true(name_result.is_ok())
	for _draw: int in range(1000):
		consumed.get_rng(NameAssignmentServiceScript.RNG_STREAM_ID).randi()

	assert_ne(
		consumed.get_stream_seed(NameAssignmentServiceScript.RNG_STREAM_ID),
		consumed.get_stream_seed(AvatarAssignmentServiceScript.RNG_STREAM_ID),
	)
	assert_eq(
		(
			avatar_service
			. assign_for_tournament(
				9, consumed.get_rng(AvatarAssignmentServiceScript.RNG_STREAM_ID)
			)
			. assignments
		),
		(
			avatar_service
			. assign_for_tournament(
				9, untouched.get_rng(AvatarAssignmentServiceScript.RNG_STREAM_ID)
			)
			. assignments
		),
	)
	for _draw: int in range(1000):
		avatar_consumed.get_rng(AvatarAssignmentServiceScript.RNG_STREAM_ID).randi()
	assert_eq(
		(
			service
			. assign_for_tournament(
				9, 0, avatar_consumed.get_rng(NameAssignmentServiceScript.RNG_STREAM_ID)
			)
			. assignments
		),
		(
			service
			. assign_for_tournament(
				9, 0, untouched.get_rng(NameAssignmentServiceScript.RNG_STREAM_ID)
			)
			. assignments
		),
	)


func test_name_assignment_does_not_change_fixed_seed_core_snapshot_or_cli_labels() -> void:
	var before = _fixed_seed_adapter()
	var presentation_streams: RngStreams = _presentation_streams(5150)
	var name_result = (
		NameAssignmentServiceScript
		. new()
		. assign_for_tournament(
			6,
			0,
			presentation_streams.get_rng(NameAssignmentServiceScript.RNG_STREAM_ID),
		)
	)
	(
		AvatarAssignmentServiceScript
		. new()
		. assign_for_tournament(
			6,
			presentation_streams.get_rng(AvatarAssignmentServiceScript.RNG_STREAM_ID),
		)
	)
	var after = _fixed_seed_adapter()

	assert_true(name_result.is_ok())
	assert_eq(
		_view_signature(before.match_instance.get_view_for(0)),
		_view_signature(after.match_instance.get_view_for(0))
	)
	var io := FakeCliIO.new()
	CliRenderer.new(io).render_hand(after.match_instance.get_view_for(0))
	assert_eq(io.count_writes_containing("Seat 0: Player 1 (you)"), 1)
	for generated_name: String in name_result.assignments.values():
		if generated_name != "Human":
			assert_eq(io.count_writes_containing(generated_name), 0, generated_name)
	assert_eq(_play_to_outcome(before), _play_to_outcome(after))


func _presentation_streams(seed: int) -> RngStreams:
	return (
		RngStreamFactory
		. new()
		. create_named(
			seed,
			PackedStringArray(
				[
					NameAssignmentServiceScript.RNG_STREAM_ID,
					AvatarAssignmentServiceScript.RNG_STREAM_ID,
				]
			),
		)
	)


func _fixed_seed_adapter():
	var defaults := TournamentConfig.new()
	defaults.player_count = 3
	defaults.starting_stack = 20
	defaults.rng_seed = 5150
	var adapter = GuiStartupConfigAdapterScript.new(defaults)
	assert_true(adapter.try_start())
	return adapter


func _play_to_outcome(adapter) -> Array:
	var result: StepResult = adapter.start_result
	for _transition: int in range(200):
		if result.status == StepResult.Status.WAITING_FOR_HUMAN:
			result = adapter.match_instance.submit_human_action(PlayerAction.fold_action())
		elif result.status == StepResult.Status.HAND_COMPLETED:
			result = adapter.match_instance.advance_until_blocked()
		elif result.status == StepResult.Status.TOURNAMENT_FINISHED:
			break
		else:
			result = adapter.match_instance.advance_until_blocked()
		assert_ne(result.status, StepResult.Status.ERROR, result.message)
	assert_eq(result.status, StepResult.Status.TOURNAMENT_FINISHED)

	var view: GameView = adapter.match_instance.get_view_for(0)
	var stacks: Array[int] = []
	for seat_view: PlayerView in view.seats:
		stacks.append(seat_view.stack)
	var final_actions: Array[String] = []
	for record: PublicActionRecord in view.action_history:
		final_actions.append(
			"%d:%d:%d:%d" % [record.record_kind, record.seat, record.kind, record.amount]
		)
	return [
		adapter.match_instance.end_reason,
		adapter.match_instance.winner_seat,
		view.hand_number,
		stacks,
		final_actions,
	]


func _view_signature(view: GameView) -> Array:
	var hero_cards: Array[String] = []
	for card: CardData in view.hero_hole_cards:
		hero_cards.append(card.code())
	var seat_rows: Array[String] = []
	for seat_view: PlayerView in view.seats:
		seat_rows.append("%d:%s:%d" % [seat_view.seat, seat_view.display_name, seat_view.stack])
	return [
		view.hand_number,
		view.button_seat,
		view.small_blind_seat,
		view.big_blind_seat,
		view.acting_seat,
		hero_cards,
		seat_rows,
	]
