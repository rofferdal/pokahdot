class_name CliInputLine
extends RefCounted

var text: String:
	get:
		return _text

var is_eof: bool:
	get:
		return _is_eof

var _text: String
var _is_eof: bool


func _init(input_text: String = "", input_is_eof: bool = false) -> void:
	_text = input_text
	_is_eof = input_is_eof


static func eof() -> CliInputLine:
	return CliInputLine.new("", true)
