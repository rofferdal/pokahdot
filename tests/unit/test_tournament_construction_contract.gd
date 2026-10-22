extends "res://tests/support/poker_gut_test.gd"


func test_product_contract_rejects_an_all_bot_match() -> void:
	var match_instance := TournamentMatch.new(_config(), _all_bot_agents())

	var result: StepResult = match_instance.start()

	assert_eq(result.status, StepResult.Status.ERROR)
	assert_true(result.message.contains("exactly one human"))


func test_simulation_contract_accepts_an_all_bot_match() -> void:
	var match_instance := TournamentMatch.new(
		_config(), _all_bot_agents(), TournamentConstructionContract.simulation()
	)

	var result: StepResult = match_instance.start()

	assert_ne(result.status, StepResult.Status.ERROR)


func test_simulation_contract_rejects_a_human_agent() -> void:
	var agents := _all_bot_agents()
	agents[0] = HumanAgent.new()
	var match_instance := TournamentMatch.new(
		_config(), agents, TournamentConstructionContract.simulation()
	)

	var result: StepResult = match_instance.start()

	assert_eq(result.status, StepResult.Status.ERROR)
	assert_true(result.message.contains("all seats"))


func _config() -> ResolvedTournamentConfig:
	return ResolvedTournamentConfig.new(
		2, 100, 5, 10, 731, &"single_table", {0: &"random", 1: &"random"}
	)


func _all_bot_agents() -> Dictionary[int, Agent]:
	return {
		0: RandomAgent.new(_rng(1)),
		1: RandomAgent.new(_rng(2)),
	}


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
