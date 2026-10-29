class_name EventLogViewModel
extends RefCounted

## One detached log body for both docked and overlay presentation.
var entries := PackedStringArray()
var text: String = ""


static func from_lines(lines: Array[String]) -> EventLogViewModel:
	var result := EventLogViewModel.new()
	result.entries = PackedStringArray(lines)
	result.text = "\n".join(result.entries)
	return result
