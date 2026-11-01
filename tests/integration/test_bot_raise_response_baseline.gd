extends "res://tests/support/poker_gut_test.gd"

const BENCHMARK := preload("res://tests/support/bot_raise_response_benchmark.gd")


func test_controlled_raise_responses_are_legal_and_reproducible() -> void:
	for scenario: Array in [[true, 1, false], [false, 191, false], [false, 1, true]]:
		var first: Array[Dictionary] = BENCHMARK.controlled_round(
			scenario[0], scenario[1], scenario[2]
		)
		var second: Array[Dictionary] = BENCHMARK.controlled_round(
			scenario[0], scenario[1], scenario[2]
		)
		assert_eq(first, second)
		assert_false(first.is_empty())
		for row: Dictionary in first:
			assert_true(row.legal, row.error)
		assert_true(first[-1].action in ["FOLD", "CALL"])


func test_complete_tournament_measurement_covers_real_transitions_and_conserves_chips() -> void:
	var catalog: Array[BotProfile] = BENCHMARK.profiles()
	assert_eq(catalog.size(), 15)
	var first: Dictionary = BENCHMARK.run_tournament(catalog, 0, 2, 100, false, 61001)
	var second: Dictionary = BENCHMARK.run_tournament(catalog, 0, 2, 100, false, 61001)
	assert_eq(first, second)
	assert_true(first.completed)
	assert_eq(first.invalid_actions, 0)
	assert_eq(first.chip_total, 200)
	assert_gt(first.hands, 0)
	assert_gt(first.decisions, 0)


func test_summary_keeps_denominators_and_bounded_uncertainty() -> void:
	var rows: Array[Dictionary] = []
	for action: String in ["FOLD", "CALL", "RAISE", "FOLD"]:
		rows.append(
			{
				"profile": "test",
				"street": "preflop",
				"previous_branch": "bluff_raise",
				"cheap": true,
				"expensive": false,
				"weak": true,
				"action": action,
				"opponents": 1,
				"stack_pressure": 0.1
			}
		)
	var summary: Dictionary = BENCHMARK.summarize(rows)
	assert_eq(summary.all.opportunities, 4)
	assert_eq(summary.all.FOLD, 2)
	assert_eq(summary.all.CALL, 1)
	assert_eq(summary.all.RAISE, 1)
	assert_eq(summary.all.fold_rate, 0.5)
	assert_between(summary.all.fold_wilson95[0], 0.0, 0.5)
	assert_between(summary.all.fold_wilson95[1], 0.5, 1.0)
