class_name CliCommand
extends RefCounted

enum Kind {
	EMPTY,
	HELP,
	QUIT,
	CONTINUE,
	STATE,
	HISTORY,
	ACTION,
	POT_BET,
	POT_RAISE,
	UNKNOWN,
}

var kind: Kind:
	get:
		return _kind

var text: String:
	get:
		return _text
var action: PlayerAction:
	get:
		return _action

var _kind: Kind
var _text: String
var _action: PlayerAction


func _init(
	command_kind: Kind, command_text: String = "", player_action: PlayerAction = null
) -> void:
	_kind = command_kind
	_text = command_text
	_action = player_action
