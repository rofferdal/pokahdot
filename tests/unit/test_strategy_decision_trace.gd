extends "res://tests/support/poker_gut_test.gd"

const TRACE_SCRIPT := preload("res://scripts/core/agents/strategy_decision_trace.gd")


func test_trace_records_typed_strategy_diagnostics_without_exposing_them_in_game_view() -> void:
	var legal: Array[PlayerAction.Kind] = [
		PlayerAction.Kind.FOLD,
		PlayerAction.Kind.CALL,
		PlayerAction.Kind.RAISE,
	]
	var action := PlayerAction.raise_to(42)
	var trace = (
		TRACE_SCRIPT
		. new(
			&"balanced",
			TRACE_SCRIPT.STRONG_BAND,
			&"value_raise",
			legal,
			action,
		)
	)

	assert_eq(trace.profile_id, &"balanced")
	assert_eq(trace.hand_potential_band, TRACE_SCRIPT.STRONG_BAND)
	assert_eq(trace.selected_branch, &"value_raise")
	assert_eq(trace.legal_alternatives, legal)
	assert_eq(trace.requested_action.kind, PlayerAction.Kind.RAISE)
	assert_eq(trace.requested_action.amount, 42)
	assert_false("decision_trace" in _property_names(GameView.new()))
	assert_false("strategy_trace" in _property_names(GameView.new()))


func test_trace_copies_collections_and_requested_action() -> void:
	var legal: Array[PlayerAction.Kind] = [PlayerAction.Kind.CHECK]
	var trace = (
		TRACE_SCRIPT
		. new(
			&"nit_caller",
			TRACE_SCRIPT.WEAK_BAND,
			&"free_check",
			legal,
			PlayerAction.check_action(),
		)
	)

	legal.append(PlayerAction.Kind.BET)
	var alternatives: Array[PlayerAction.Kind] = trace.legal_alternatives
	alternatives.append(PlayerAction.Kind.RAISE)
	var requested: PlayerAction = trace.requested_action

	assert_eq(trace.legal_alternatives, [PlayerAction.Kind.CHECK])
	assert_eq(alternatives, [PlayerAction.Kind.CHECK, PlayerAction.Kind.RAISE])
	assert_eq(requested.kind, PlayerAction.Kind.CHECK)
	assert_ne(requested, trace.requested_action)


func test_trace_copy_preserves_all_action_shapes() -> void:
	var actions: Array[PlayerAction] = [
		PlayerAction.fold_action(),
		PlayerAction.check_action(),
		PlayerAction.call_action(),
		PlayerAction.bet_to(17),
		PlayerAction.raise_to(33),
		PlayerAction.all_in_action(),
	]

	for action: PlayerAction in actions:
		var trace = TRACE_SCRIPT.new(
			&"balanced", TRACE_SCRIPT.UNKNOWN_BAND, &"baseline", [], action
		)
		var copied = trace.copy()
		assert_ne(copied, trace)
		assert_ne(copied.requested_action, action)
		assert_eq(copied.requested_action.kind, action.kind)
		assert_eq(copied.requested_action.amount, action.amount)


func test_band_for_score_is_bounded_and_stable() -> void:
	assert_eq(TRACE_SCRIPT.band_for_score(-1), TRACE_SCRIPT.UNKNOWN_BAND)
	assert_eq(TRACE_SCRIPT.band_for_score(0), TRACE_SCRIPT.WEAK_BAND)
	assert_eq(TRACE_SCRIPT.band_for_score(29), TRACE_SCRIPT.WEAK_BAND)
	assert_eq(TRACE_SCRIPT.band_for_score(30), TRACE_SCRIPT.MARGINAL_BAND)
	assert_eq(TRACE_SCRIPT.band_for_score(59), TRACE_SCRIPT.MARGINAL_BAND)
	assert_eq(TRACE_SCRIPT.band_for_score(60), TRACE_SCRIPT.STRONG_BAND)
	assert_eq(TRACE_SCRIPT.band_for_score(79), TRACE_SCRIPT.STRONG_BAND)
	assert_eq(TRACE_SCRIPT.band_for_score(80), TRACE_SCRIPT.PREMIUM_BAND)
	assert_eq(TRACE_SCRIPT.band_for_score(100), TRACE_SCRIPT.PREMIUM_BAND)
	assert_eq(TRACE_SCRIPT.band_for_score(101), TRACE_SCRIPT.UNKNOWN_BAND)


func _property_names(object: Object) -> Array[StringName]:
	var names: Array[StringName] = []
	for property: Dictionary in object.get_property_list():
		names.append(property.name)
	return names
