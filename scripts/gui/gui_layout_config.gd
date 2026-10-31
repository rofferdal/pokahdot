# gdlint: disable=class-variable-name
class_name GuiLayoutConfig
extends Resource

## Presentation preference only; never changes tournament state or poker rules.
@export var useTooLittleRoomWarning: bool = false:
	set(value):
		if useTooLittleRoomWarning == value:
			return
		useTooLittleRoomWarning = value
		emit_changed()
