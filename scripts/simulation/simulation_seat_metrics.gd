class_name SimulationSeatMetrics
extends RefCounted

## Non-financial, per-tournament metrics for one profile occupying one seat.

var profile_id: StringName
var seat: int
var starting_stack: int
var final_stack: int
var finishing_position: int
var won_tournament: bool
var top_third: bool
var chip_differential: int
var hands_survived: int
var tournament_hand_count: int
var player_count: int
var survival_ratio: float
var blind_normalized_chip_sum: float
var hands_observed: int
var bnc_per_100: float
var vpip_hands: int
var vpip_rate: float
var pfr_hands: int
var pfr_rate: float
var aggressive_actions: int
var calls: int
var aggression_factor: float
var invalid_action_fallbacks: int


func _init(id: StringName, seat_number: int, stack: int) -> void:
	profile_id = id
	seat = seat_number
	starting_stack = stack
	final_stack = stack


func finish(stack: int, position: int, winner: bool, player_count: int, hand_count: int) -> void:
	final_stack = stack
	finishing_position = position
	won_tournament = winner
	top_third = position <= ceili(float(player_count) / 3.0)
	chip_differential = final_stack - starting_stack
	tournament_hand_count = hand_count
	self.player_count = player_count if player_count > 0 else 1
	survival_ratio = float(hands_survived) / float(hand_count) if hand_count > 0 else 0.0
	bnc_per_100 = blind_normalized_chip_sum * 100.0 / float(hands_observed) if hands_observed > 0 else 0.0
	vpip_rate = float(vpip_hands) / float(hands_observed) if hands_observed > 0 else 0.0
	pfr_rate = float(pfr_hands) / float(hands_observed) if hands_observed > 0 else 0.0
	aggression_factor = float(aggressive_actions) / float(calls) if calls > 0 else 0.0
