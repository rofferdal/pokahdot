extends "res://tests/support/poker_gut_test.gd"


func test_input_copies_profile_snapshots_and_validates_identity() -> void:
	var profile := _profile(&"candidate")
	var matchup := SimulationMatchup.new(&"candidate_vs_candidate", [profile, profile])
	var input := SimulationTournamentInput.new(4, 801, matchup, {0: profile, 1: profile})
	profile.profile_id = &"changed"

	assert_true(input.validate(2).is_empty())
	assert_eq(input.get_seat_profiles()[0].profile_id, &"candidate")
	assert_eq(input.matchup.get_profiles()[0].profile_id, &"candidate")


func test_input_rejects_invalid_identity_and_missing_seat() -> void:
	var input := SimulationTournamentInput.new(
		-1, 0, SimulationMatchup.new(&"", []), {0: _profile(&"only")}
	)

	var errors := input.validate(2)

	assert_true(errors.size() >= 4)
	assert_has(errors, "Tournament index must be non-negative.")
	assert_has(errors, "Simulation effective seed must be non-zero.")
	assert_has(errors, "Every simulation seat must have one bot profile.")


func test_outcome_copies_mapping_and_retains_structured_diagnostics() -> void:
	var mapping: Dictionary[int, StringName] = {0: &"first", 1: &"second"}
	var diagnostic := SimulationDiagnostic.new(SimulationDiagnostic.Stage.EXECUTION, "stalled", 1)
	var outcome := (
		SimulationTournamentOutcome
		. new(
			7,
			912,
			&"first_vs_second",
			mapping,
			SimulationCompletionResult.new(SimulationCompletionResult.Status.FAILED),
			[diagnostic],
		)
	)
	mapping[0] = &"changed"

	assert_eq(outcome.final_seat_mapping[0], &"first")
	assert_eq(outcome.diagnostics[0].stage, SimulationDiagnostic.Stage.EXECUTION)
	assert_eq(outcome.diagnostics[0].seat, 1)
	assert_false(outcome.is_success())


func _profile(profile_id: StringName) -> BotProfile:
	var profile := BotProfile.new()
	profile.profile_id = profile_id
	profile.model_id = &"random"
	profile.parameters = RandomDecisionModelParameters.new()
	return profile
