extends "res://tests/support/poker_gut_test.gd"

const REGIME_SCRIPT := preload("res://scripts/simulation/simulation_regime.gd")


func test_approved_heads_up_six_max_and_full_ring_regimes_resolve_with_product_rules() -> void:
	for regime in [
		REGIME_SCRIPT.new(&"heads_up", 2, 1000, 5, 10),
		REGIME_SCRIPT.new(&"six_max", 6, 500, 10, 20),
		REGIME_SCRIPT.new(&"full_ring", 9, 2000, 25, 50),
	]:
		var resolution: ConfigResolution = regime.resolve(711)
		assert_true(regime.validate().is_empty())
		assert_true(resolution.is_ok())
		var config: ResolvedTournamentConfig = resolution.get_config()
		assert_eq(config.player_count, regime.player_count)
		assert_eq(config.starting_stack, regime.starting_stack)
		assert_eq(config.small_blind, regime.starting_small_blind)
		assert_eq(config.big_blind, regime.starting_big_blind)
		assert_eq(config.tournament_mode, &"single_table")


func test_regime_reuses_product_validation_for_invalid_structural_values() -> void:
	var invalid := REGIME_SCRIPT.new(&"bad", 10, 0, 20, 10)

	var errors := invalid.validate()

	assert_has(errors, "Player count must be between 2 and 9.")
	assert_has(errors, "Starting stack must be a positive integer.")
	assert_has(errors, "Small blind cannot exceed big blind.")
