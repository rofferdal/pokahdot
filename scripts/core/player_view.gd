class_name PlayerView
extends RefCounted

## Public, immutable snapshot of one seat. Hole cards deliberately do not live here.

var seat: int
var player_id: StringName
var display_name: String
var is_human: bool
var stack: int
var bet_this_round: int
var folded: bool
var all_in: bool
var busted: bool


func _init(player: Player) -> void:
	seat = player.seat
	player_id = player.player_id
	display_name = player.display_name
	is_human = player.agent is HumanAgent
	stack = player.stack
	bet_this_round = player.bet_this_round
	folded = player.folded
	all_in = player.all_in
	busted = player.busted
