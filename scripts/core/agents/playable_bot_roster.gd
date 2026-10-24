class_name PlayableBotRoster
extends RefCounted

## Curated product bot catalog shared by GUI and interactive CLI composition.
##
## Profiles are loaded once as catalog entries but callers only receive deep
## copies, so a match cannot mutate the curated resource or another match.

const MAX_PLAYABLE_BOT_COUNT := 8
## Product games may retain at most this many StrategyDecisionModel profiles.
## Simulation manifests deliberately do not use this product-roster limit.
const MAX_STRATEGIC_PROFILE_COUNT := 25
## Source-controlled identity for the curated product catalog. Increment this
## whenever its membership or an included profile snapshot changes.
const ROSTER_VERSION: StringName = &"curated_v1"
const REQUIRED_LEGACY_PROFILE_IDS: Array[StringName] = [
	&"random_default", &"tight_passive_default", &"loose_aggressive_default"
]
const DEFAULT_PROFILE_PATHS: PackedStringArray = [
	"res://resources/bot_profiles/random_default.tres",
	"res://resources/bot_profiles/tight_passive_default.tres",
	"res://resources/bot_profiles/loose_aggressive_default.tres",
	"res://resources/bot_profiles/nit_caller.tres",
	"res://resources/bot_profiles/tight_aggressive.tres",
	"res://resources/bot_profiles/loose_passive.tres",
	"res://resources/bot_profiles/loose_aggressive.tres",
	"res://resources/bot_profiles/balanced.tres",
]

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

var _profiles: Array[BotProfile] = []
var _registry: DecisionModelRegistry


func _init(
	profiles: Array[BotProfile] = [],
	registry: DecisionModelRegistry = null,
	load_default_profiles: bool = true,
) -> void:
	_registry = registry if registry != null else _create_registry()
	if profiles.is_empty() and load_default_profiles:
		for profile_path: String in DEFAULT_PROFILE_PATHS:
			_profiles.append(load(profile_path) as BotProfile)
	else:
		for profile: BotProfile in profiles:
			_profiles.append(profile.duplicate(true) as BotProfile if profile != null else null)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if _profiles.is_empty():
		errors.append("The playable bot roster must contain at least one profile.")

	var seen_ids: Dictionary[StringName, bool] = {}
	var strategic_profile_count: int = 0
	for index: int in range(_profiles.size()):
		var profile: BotProfile = _profiles[index]
		if profile == null:
			errors.append("Playable bot roster profile %d could not be loaded." % index)
			continue
		if profile.profile_id.is_empty():
			errors.append("Playable bot roster profile %d has no stable profile ID." % index)
		elif seen_ids.has(profile.profile_id):
			errors.append(
				"Playable bot roster profile IDs must be unique: %s." % profile.profile_id
			)
		else:
			seen_ids[profile.profile_id] = true

		if _is_strategic_profile(profile):
			strategic_profile_count += 1
		var creation := AgentFactory.new(_registry).create_bot(profile, _validation_rng(index))
		if not creation.is_ok():
			for error: String in creation.errors:
				errors.append("Playable bot roster profile %s: %s" % [profile.profile_id, error])
	if strategic_profile_count > MAX_STRATEGIC_PROFILE_COUNT:
		errors.append(
			(
				"The playable bot roster cannot contain more than %d strategic profiles."
				% MAX_STRATEGIC_PROFILE_COUNT
			)
		)
	for legacy_id: StringName in REQUIRED_LEGACY_PROFILE_IDS:
		if not seen_ids.has(legacy_id):
			errors.append("Playable bot roster must retain legacy profile: %s." % legacy_id)
	return errors


func select(count: int, rng: RandomNumberGenerator) -> PlayableBotRosterSelection:
	var errors := validate()
	if count <= 0:
		errors.append("The playable bot selection count must be positive.")
	if count > MAX_PLAYABLE_BOT_COUNT:
		errors.append(
			"A normal tournament cannot select more than %d bots." % MAX_PLAYABLE_BOT_COUNT
		)
	if count > _profiles.size():
		errors.append(
			(
				"The playable bot roster has %d profiles but %d bots were requested."
				% [_profiles.size(), count]
			)
		)
	if rng == null:
		errors.append("A seeded roster selection random number generator is required.")
	if not errors.is_empty():
		return PlayableBotRosterSelection.new([], errors)

	var remaining: Array[BotProfile] = []
	for profile: BotProfile in _profiles:
		remaining.append(profile)
	var selected: Array[BotProfile] = []
	for selection_index: int in range(count):
		var remaining_index := rng.randi_range(selection_index, remaining.size() - 1)
		var selected_profile: BotProfile = remaining[remaining_index]
		remaining[remaining_index] = remaining[selection_index]
		remaining[selection_index] = selected_profile
		selected.append(selected_profile.duplicate(true) as BotProfile)
	return PlayableBotRosterSelection.new(selected)


func create_bot(profile: BotProfile, rng: RandomNumberGenerator) -> AgentCreationResult:
	return AgentFactory.new(_registry).create_bot(profile, rng)


## Returns independent immutable-at-runtime snapshots of every catalog profile.
##
## The catalog Resources remain private so simulation configuration cannot
## mutate the product roster or share nested parameter Resources between runs.
func get_catalog_profiles() -> Array[BotProfile]:
	var copied: Array[BotProfile] = []
	for profile: BotProfile in _profiles:
		copied.append(profile.duplicate(true) as BotProfile if profile != null else null)
	return copied


func get_profile_ids() -> Array[StringName]:
	var profile_ids: Array[StringName] = []
	for profile: BotProfile in _profiles:
		if profile != null:
			profile_ids.append(profile.profile_id)
	return profile_ids


func get_roster_version() -> StringName:
	return ROSTER_VERSION


func _is_strategic_profile(profile: BotProfile) -> bool:
	if profile == null:
		return false
	var model := _registry.create_model(profile.model_id)
	return model is StrategyDecisionModel


func _validation_rng(index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = index + 1
	return rng


func _create_registry() -> DecisionModelRegistry:
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
