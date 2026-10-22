class_name SimulationMatchFactory
extends RefCounted

## Headless composition root for one all-bot simulation tournament.
##
## This adapter is intentionally separate from the product GUI and interactive
## CLI roots. It never renders views or reads stdin.

const RANDOM_MODEL_SCRIPT := preload("res://scripts/core/agents/random_decision_model.gd")
const RANDOM_PARAMETERS_SCRIPT := preload(
	"res://scripts/core/agents/random_decision_model_parameters.gd"
)
const TIGHT_PASSIVE_MODEL_SCRIPT := preload(
	"res://scripts/core/agents/tight_passive_decision_model.gd"
)
const TIGHT_PASSIVE_PARAMETERS_SCRIPT := preload(
	"res://scripts/core/agents/tight_passive_decision_model_parameters.gd"
)
const LOOSE_AGGRESSIVE_MODEL_SCRIPT := preload(
	"res://scripts/core/agents/loose_aggressive_decision_model.gd"
)
const LOOSE_AGGRESSIVE_PARAMETERS_SCRIPT := preload(
	"res://scripts/core/agents/loose_aggressive_decision_model_parameters.gd"
)
const STRATEGY_MODEL_SCRIPT := preload("res://scripts/core/agents/strategy_decision_model.gd")
const STRATEGY_PARAMETERS_SCRIPT := preload(
	"res://scripts/core/agents/strategy_decision_model_parameters.gd"
)

var _registry: DecisionModelRegistry


func _init(registry: DecisionModelRegistry = null) -> void:
	_registry = _default_registry() if registry == null else registry


func create(
	config: ResolvedTournamentConfig, seat_profiles: Dictionary[int, BotProfile]
) -> SimulationMatchCreationResult:
	var errors := PackedStringArray()
	if config == null:
		errors.append("A resolved tournament configuration is required.")
		return SimulationMatchCreationResult.new(null, errors)
	if seat_profiles.size() != config.player_count:
		errors.append("Every simulation seat must have one bot profile.")
		return SimulationMatchCreationResult.new(null, errors)

	var snapshots: Dictionary[int, BotProfile] = {}
	for seat: int in range(config.player_count):
		if not seat_profiles.has(seat) or seat_profiles[seat] == null:
			errors.append("Simulation seat %d has no bot profile." % seat)
			continue
		snapshots[seat] = (seat_profiles[seat] as BotProfile).duplicate(true) as BotProfile
	if not errors.is_empty():
		return SimulationMatchCreationResult.new(null, errors)

	var simulation_config := _simulation_config(config, snapshots)
	var streams := RngStreamFactory.new().create(simulation_config)
	var factory := AgentFactory.new(_registry)
	var agents: Dictionary[int, Agent] = {}
	for seat: int in range(simulation_config.player_count):
		var created_agent := factory.create_bot(snapshots[seat], streams.get_bot_rng(seat))
		if not created_agent.is_ok():
			for error: String in created_agent.errors:
				errors.append("Simulation seat %d: %s" % [seat, error])
			continue
		agents[seat] = created_agent.agent
	if not errors.is_empty():
		return SimulationMatchCreationResult.new(null, errors)

	return (
		SimulationMatchCreationResult
		. new(
			(
				TournamentMatch
				. new(
					simulation_config,
					agents,
					TournamentConstructionContract.simulation(),
					streams,
				)
			),
			PackedStringArray(),
			streams.effective_seed,
			streams.get_stream_seeds(),
		)
	)


func run_to_completion(match_instance: TournamentMatch, max_transitions: int = 256) -> StepResult:
	if match_instance == null:
		return StepResult.new(StepResult.Status.ERROR, "A simulation tournament match is required.")
	if max_transitions <= 0:
		return StepResult.new(StepResult.Status.ERROR, "Simulation transitions must be positive.")

	var result: StepResult = match_instance.start(max_transitions)
	while (
		result.status == StepResult.Status.HAND_COMPLETED
		or result.status == StepResult.Status.PREFLOP_COMPLETE
		or result.status == StepResult.Status.YIELDED
	):
		result = match_instance.advance_until_blocked(max_transitions)
	if result.status == StepResult.Status.WAITING_FOR_HUMAN:
		return (
			StepResult
			. new(
				StepResult.Status.ERROR,
				"A simulation tournament cannot wait for human input.",
			)
		)
	return result


func _simulation_config(
	config: ResolvedTournamentConfig, snapshots: Dictionary[int, BotProfile]
) -> ResolvedTournamentConfig:
	var seat_agents: Dictionary[int, StringName] = {}
	for seat: int in range(config.player_count):
		seat_agents[seat] = snapshots[seat].model_id
	return (
		ResolvedTournamentConfig
		. new(
			config.player_count,
			config.starting_stack,
			config.small_blind,
			config.big_blind,
			config.rng_seed,
			config.tournament_mode,
			seat_agents,
			config.allow_experimental_models,
		)
	)


func _default_registry() -> DecisionModelRegistry:
	var registry := DecisionModelRegistry.new()
	registry.register_model(&"random", RANDOM_MODEL_SCRIPT, RANDOM_PARAMETERS_SCRIPT)
	registry.register_model(
		&"tight_passive", TIGHT_PASSIVE_MODEL_SCRIPT, TIGHT_PASSIVE_PARAMETERS_SCRIPT
	)
	registry.register_model(
		&"loose_aggressive", LOOSE_AGGRESSIVE_MODEL_SCRIPT, LOOSE_AGGRESSIVE_PARAMETERS_SCRIPT
	)
	registry.register_model(
		&"strategy_parameterized", STRATEGY_MODEL_SCRIPT, STRATEGY_PARAMETERS_SCRIPT
	)
	return registry
