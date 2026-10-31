extends GutTest


class FailedCreationFactory:
	extends RefCounted

	func create(_config: ResolvedTournamentConfig) -> GuiMatchCreationResult:
		return GuiMatchCreationResult.new(
			null, {}, {}, 0, "Expected creation failure", {1: "Stale"}
		)


class FailedStartMatch:
	extends TournamentMatch

	func start(_max_transitions: int = 32) -> StepResult:
		return StepResult.new(StepResult.Status.ERROR, "Expected start failure")


class FailedStartFactory:
	extends RefCounted

	func create(config: ResolvedTournamentConfig) -> GuiMatchCreationResult:
		return GuiMatchCreationResult.new(
			FailedStartMatch.new(config, {}), {}, {}, 0, "", {1: "Stale"}
		)


func test_validation_preserves_public_unicode_identity_and_rejects_invalid_names() -> void:
	for value: String in [
		"Tight Passive", "Équilibré", "策略", "[Public] <profile>", "A".repeat(500)
	]:
		assert_true(GuiBotProfileMetadata.is_valid_name(value), value)
	for value: String in [
		"", " ", " A", "A ", "A\nB", "A\tB", "A\u007fB", "A\u009fB", "A\u2028B", "A\u2029B"
	]:
		assert_false(GuiBotProfileMetadata.is_valid_name(value))


func test_seat_identity_is_detached_and_uses_human_flag_independent_of_recipient() -> void:
	var view: GameView = GuiVisualStateFixtures.replacement_flop(3).view
	var names: Dictionary[int, String] = {1: "Amina", 2: "Human"}
	var profiles: Dictionary[int, String] = {
		0: "Wrong human metadata", 1: "Tight Passive", 2: "Tight Passive"
	}
	for recipient: int in [0, 1, 2]:
		view.hero_seat = recipient
		var model: TableViewModel = TableViewModel.build(
			view, names, {}, {}, {}, [], GuiFitCandidate.Density.FULL, profiles
		)
		assert_true(model.valid)
		assert_false(model.seat_for(0).bot_profile_tooltip_eligible)
		assert_eq(model.seat_for(0).bot_profile_name, "")
		assert_eq(model.seat_for(0).bot_profile_tooltip_text, "")
		for seat: int in [1, 2]:
			assert_true(model.seat_for(seat).bot_profile_tooltip_eligible)
			assert_eq(model.seat_for(seat).bot_profile_name, "Tight Passive")
			assert_eq(model.seat_for(seat).bot_profile_tooltip_text, "Bot profile: Tight Passive")
		assert_eq(model.seat_for(1).display_name, "Amina")
		assert_eq(model.seat_for(2).display_name, "Human")
	var detached: SeatViewModel = SeatViewModel.build(
		view.seats[1], view, names, {}, null, null, GuiFitCandidate.Density.FULL, profiles
	)
	profiles[1] = "Changed"
	assert_eq(detached.bot_profile_name, "Tight Passive")
	assert_eq(detached.bot_profile_tooltip_text, "Bot profile: Tight Passive")
	assert_eq(typeof(detached.bot_profile_name), TYPE_STRING)
	assert_eq(typeof(detached.bot_profile_tooltip_text), TYPE_STRING)
	assert_eq(typeof(detached.bot_profile_tooltip_eligible), TYPE_BOOL)


func test_missing_invalid_folded_and_eliminated_seat_metadata() -> void:
	var view: GameView = GuiVisualStateFixtures.replacement_flop(3).view
	for value: String in ["", " ", "Invalid\nName", " Wrong"]:
		var model: SeatViewModel = SeatViewModel.build(
			view.seats[1], view, {}, {}, null, null, GuiFitCandidate.Density.FULL, {1: value}
		)
		assert_false(model.bot_profile_tooltip_eligible)
		assert_eq(model.bot_profile_name, "")
		assert_eq(model.bot_profile_tooltip_text, "")
	assert_eq(SeatViewModel.build(view.seats[1], view, {}, {}).bot_profile_tooltip_text, "")
	for state: String in ["folded", "busted"]:
		view._seats[1].set(state, true)
		var model: SeatViewModel = SeatViewModel.build(
			view.seats[1],
			view,
			{},
			{},
			null,
			null,
			GuiFitCandidate.Density.FULL,
			{1: "Original Profile"}
		)
		assert_eq(model.bot_profile_tooltip_text, "Bot profile: Original Profile")


func test_creation_result_and_session_own_copies_and_clear_or_replace_binding() -> void:
	var profiles: Dictionary[int, String] = {1: "Original Profile"}
	var result := GuiMatchCreationResult.new(null, {}, {}, 0, "", profiles)
	profiles[1] = "Source changed"
	var exposed: Dictionary[int, String] = result.profile_names
	exposed.clear()
	assert_eq(result.profile_names, {1: "Original Profile"})
	var session := GuiTableSession.new()
	var view: GameView = GuiVisualStateFixtures.replacement_flop(3).view
	assert_true(session.bind_view(view, {}, {}, [], profiles))
	profiles[1] = "Source changed again"
	assert_eq(session.get_model().seat_for(1).bot_profile_name, "Source changed")
	assert_true(session.refresh())
	assert_eq(session.get_model().seat_for(1).bot_profile_name, "Source changed")
	assert_true(session.bind_view(view, {}, {}, [], {1: "New tournament"}))
	assert_eq(session.get_model().seat_for(1).bot_profile_name, "New tournament")
	assert_true(session.bind_view(view, {}))
	assert_eq(session.get_model().seat_for(1).bot_profile_name, "")
	assert_true(session.bind_view(view, {}, {}, [], profiles))
	session.stop()
	assert_eq(session.get_model().seat_for(1).bot_profile_name, "")
	assert_false(session.bind_view(null, {}, {}, [], profiles))
	assert_false(session.get_model().valid)


func test_startup_captures_selected_catalog_names_and_clears_metadata_on_failure_and_reset(
) -> void:
	var catalog := PlayableBotRoster.new().get_catalog_profiles()
	var by_id: Dictionary[StringName, String] = {}
	for profile: BotProfile in catalog:
		by_id[profile.profile_id] = profile.display_name
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 5150
	var adapter := GuiStartupConfigAdapter.new(defaults)
	for legacy: bool in [false, true]:
		adapter.use_legacy_models = legacy
		assert_true(adapter.try_start())
		assert_eq(adapter.profile_names.size(), 5)
		assert_false(adapter.profile_names.has(0))
		for seat: int in range(1, 6):
			var bot := adapter.match_instance.get_agent_for_simulation(seat) as BotAgent
			assert_eq(adapter.profile_names[seat], by_id[bot.profile_id])
		var exposed: Dictionary[int, String] = adapter.profile_names
		exposed.clear()
		assert_eq(adapter.profile_names.size(), 5)
	adapter.player_count_text = "invalid"
	assert_false(adapter.try_start())
	assert_eq(adapter.profile_names, {})
	adapter.reset_to_defaults()
	assert_eq(adapter.profile_names, {})
	adapter.player_count_text = "2"
	assert_true(adapter.try_start())
	assert_eq(adapter.profile_names.size(), 1)
	adapter.reset_to_defaults()
	assert_eq(adapter.profile_names, {})


func test_factory_copies_shared_profiles_and_invalid_names_do_not_block_startup() -> void:
	var profile := load("res://resources/bot_profiles/balanced.tres").duplicate(true) as BotProfile
	profile.display_name = "Shared public profile"
	var roster := PlayableBotRoster.new([profile])
	var defaults := TournamentConfig.new()
	defaults.rng_seed = 5150
	var adapter := GuiStartupConfigAdapter.new(defaults, GuiMatchFactory.new(roster))
	profile.display_name = "Changed source Resource"
	assert_true(adapter.try_start())
	for seat: int in range(1, 6):
		assert_eq(adapter.profile_names[seat], "Shared public profile")
	profile.display_name = "Private\nInvalid"
	adapter = GuiStartupConfigAdapter.new(
		defaults, GuiMatchFactory.new(PlayableBotRoster.new([profile]))
	)
	assert_true(adapter.try_start())
	assert_eq(adapter.profile_names, {})
	for seat: int in range(1, 6):
		assert_push_warning("Bot profile name unavailable for seat %d: invalid public name." % seat)


func test_creation_and_start_failures_do_not_adopt_returned_metadata() -> void:
	for factory: RefCounted in [FailedCreationFactory.new(), FailedStartFactory.new()]:
		var adapter := GuiStartupConfigAdapter.new(TournamentConfig.new(), factory)
		assert_false(adapter.try_start())
		assert_eq(adapter.profile_names, {})
		assert_null(adapter.match_instance)
		assert_false(adapter.error_for(&"form").is_empty())
