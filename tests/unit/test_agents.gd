extends "res://tests/support/poker_gut_test.gd"


func test_human_agent_waits_without_blocking_when_mailbox_is_empty() -> void:
	var agent := HumanAgent.new()

	assert_false(agent.has_pending_action())
	assert_null(agent.choose_action(null))


func test_human_agent_returns_submitted_action_once() -> void:
	var agent := HumanAgent.new()
	var action := PlayerAction.call_action()

	assert_true(agent.submit_action(action))
	assert_true(agent.has_pending_action())
	assert_eq(agent.choose_action(null), action)
	assert_false(agent.has_pending_action())
	assert_null(agent.choose_action(null))


func test_human_agent_does_not_overwrite_pending_input() -> void:
	var agent := HumanAgent.new()
	var first := PlayerAction.fold_action()

	assert_true(agent.submit_action(first))
	assert_false(agent.submit_action(PlayerAction.call_action()))
	assert_eq(agent.choose_action(null), first)


func test_scripted_agent_returns_actions_in_order_then_null() -> void:
	var first := PlayerAction.call_action()
	var second := PlayerAction.raise_to(30)
	var agent := ScriptedAgent.new([first, second])

	assert_eq(agent.choose_action(null), first)
	assert_eq(agent.choose_action(null), second)
	assert_null(agent.choose_action(null))
	assert_eq(agent.remaining_action_count(), 0)


func test_scripted_agent_copies_public_observations() -> void:
	var agent := ScriptedAgent.new()
	var record := PublicActionRecord.new(2, PlayerAction.Kind.BET, 10)

	agent.observe(record)
	var observations: Array[PublicActionRecord] = agent.observed_records
	observations.clear()

	assert_eq(agent.observed_records.size(), 1)
	assert_eq(agent.observed_records[0].seat, 2)
