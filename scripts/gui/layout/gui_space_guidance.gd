class_name GuiSpaceGuidance
extends MarginContainer

## Passive presentation; the host retains menu/Quit and all game/input state.
@onready var _message: Label = %Message


func render(policy: GuiFitPolicy) -> void:
	if policy == null:
		visible = false
		return
	render_message(policy.guidance if policy.status != GuiFitPolicy.Status.FIT else "")


func render_message(message: String) -> void:
	visible = not message.is_empty()
	_message.text = message
