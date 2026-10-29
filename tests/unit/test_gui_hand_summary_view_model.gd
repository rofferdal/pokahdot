extends GutTest

const Fixtures := preload("res://tests/support/gui_visual_state_fixtures.gd")


func test_summary_names_fold_winner_with_exact_share_and_no_revealed_cards() -> void:
	var view: GameView = Fixtures.by_id(&"showdown-long", 6).view
	view._showdown_results = {}
	view._revealed_hole_cards = {}
	view.hand_winner_seat = 1
	view._pot_awards = [PotAward.new(0, 101, [1], {1: 101})]
	var model: HandSummaryViewModel = HandSummaryViewModel.build(view, {1: "Linh"})
	assert_eq(model.text, "Main pot (101): Linh +101")
	assert_eq(model.result_text, "Winner: Linh")
	assert_true(model.lines[0].winner_emphasis)
	assert_true(view.revealed_hole_cards.is_empty())


func test_summary_reports_every_split_and_side_pot_share_and_assigned_winner() -> void:
	var view: GameView = Fixtures.by_id(&"showdown-long", 6).view
	view._pot_awards = [
		PotAward.new(0, 101, [4, 5], {4: 51, 5: 50}),
		PotAward.new(1, 40, [5], {5: 40}),
	]
	view.tournament_status = &"finished"
	view.end_reason = &"winner"
	view.tournament_winner_seat = 5
	var names: Dictionary[int, String] = {4: "Bao", 5: "Linh"}
	var model: HandSummaryViewModel = HandSummaryViewModel.build(view, names)
	assert_string_contains(model.text, "Main pot (101): Bao +51, Linh +50")
	assert_string_contains(model.text, "Side pot 1 (40): Linh +40")
	assert_eq(model.result_text, "Winners: Bao, Linh")
	assert_eq(
		ActionBarViewModel.build(view, names, GuiFitCandidate.Density.COMPACT).status_text,
		"Linh wins"
	)
	for line: HandSummaryLineViewModel in model.lines:
		if line.seat in [4, 5] or line.seat == Table.NO_SEAT:
			assert_true(line.winner_emphasis)


func test_summary_descriptions_are_public_and_ordered_without_private_card_identity() -> void:
	var view: GameView = Fixtures.by_id(&"showdown-long", 6).view
	var model: HandSummaryViewModel = HandSummaryViewModel.build(view)
	for seat: int in view.showdown_results:
		assert_string_contains(model.text, view.seats[seat].display_name)
	assert_false("Player 2 —" in model.text)
	assert_false("Player 3 —" in model.text)
	assert_true(HandSummaryViewModel.build(null).text.is_empty())
