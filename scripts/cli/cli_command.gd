class_name CliCommand
extends RefCounted

enum Kind {
	EMPTY,
	HELP,
	QUIT,
	UNKNOWN,
}

var kind: Kind:
	get:
		return _kind

var text: String:
	get:
		return _text

var _kind: Kind
var _text: String


func _init(command_kind: Kind, command_text: String = "") -> void:
	_kind = command_kind
	_text = command_text
