class_name GuiSeatTextRun
extends RefCounted

## One complete seat-copy block. Blank text still reserves one status line.
var text: String
var emphasized: bool


func _init(copy: String = "", bold: bool = false) -> void:
	text = copy
	emphasized = bold
